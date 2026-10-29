-- AI-1 credits (06_SUPABASE_SCHEMA_PROPOSAL §3, D-07/D-08/D-09, L-D30).
--
-- An append-only ledger per user. The balance is the sum of the ledger.
-- * Every Monday 00:00 UTC week starts with an allowance that tops the
--   balance up to 10 (Free) / 60 (Pro) (Q5 placeholders); it never stacks.
-- * One charge per (user, request id) and at most one refund per charge
--   (D-09), enforced by unique keys.
-- * Clients can only read their ledger and ask for their balance. Charges
--   and refunds are made by the ai-request Edge Function with the service
--   role, around the provider call: a client can never grant itself credits
--   or refund a request that succeeded.
-- Basic post-workout feedback stays free (D-07) and never touches this.

do $$
begin
  if not exists (select 1 from pg_type where typname = 'credit_kind'
                 and typnamespace = 'public'::regnamespace) then
    create type public.credit_kind as enum
      ('weekly_allowance', 'consume', 'refund', 'rewarded_ad', 'admin_adjust');
  end if;
end $$;

create table if not exists public.ai_credit_ledger (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  kind public.credit_kind not null,
  amount int not null check (amount between -1000 and 1000),
  request_id text check (char_length(request_id) between 1 and 80),
  request_kind text check (request_kind in
    ('coach_chat', 'advanced_analysis', 'progress_review')),
  week_start date,
  created_at timestamptz not null default now(),
  check ((kind in ('consume', 'refund')) = (request_id is not null)),
  check ((kind = 'weekly_allowance') = (week_start is not null)),
  unique (user_id, request_id, kind),
  unique (user_id, week_start, kind)
);

create index if not exists ai_credit_ledger_user
  on public.ai_credit_ledger (user_id, created_at);

alter table public.ai_credit_ledger enable row level security;
revoke all on public.ai_credit_ledger from public, anon, authenticated;
grant select on public.ai_credit_ledger to authenticated;
grant select, insert, delete on public.ai_credit_ledger to service_role;

create policy "ai_credit_ledger: owner can read"
  on public.ai_credit_ledger for select to authenticated
  using ((select auth.uid()) = user_id);

create or replace view public.ai_credit_balance
  with (security_invoker = true) as
  select user_id, sum(amount)::int as balance
  from public.ai_credit_ledger group by user_id;

revoke all on public.ai_credit_balance from public, anon, authenticated;
grant select on public.ai_credit_balance to authenticated, service_role;

-- Pro status for the allowance. False until entitlements exist (P-1); the
-- entitlements migration replaces this function.
create or replace function public.ai_credit_is_pro(p_user uuid)
returns boolean language sql stable set search_path = '' as $$
  select false
$$;

-- D-08 / Q5 placeholder values. Change them with a new migration.
create or replace function public.ai_credit_weekly_allowance(p_pro boolean)
returns int language sql immutable set search_path = '' as $$
  select case when p_pro then 60 else 10 end
$$;

create or replace function public.ai_credit_week_start(p_at timestamptz)
returns date language sql immutable set search_path = '' as $$
  select date_trunc('week', p_at at time zone 'UTC')::date
$$;

create or replace function public.ai_credit_balance_of(p_user uuid)
returns int language sql stable set search_path = '' as $$
  select coalesce(sum(amount), 0)::int from public.ai_credit_ledger
  where user_id = p_user
$$;

-- Grants this week's allowance once (caller holds the user's lock).
create or replace function public.ai_credit_grant_week(p_user uuid)
returns void language plpgsql set search_path = '' as $$
declare
  v_week date := public.ai_credit_week_start(now());
  v_top int;
begin
  if exists (select 1 from public.ai_credit_ledger
             where user_id = p_user and kind = 'weekly_allowance'
               and week_start = v_week) then
    return;
  end if;
  v_top := greatest(
    public.ai_credit_weekly_allowance(public.ai_credit_is_pro(p_user))
      - public.ai_credit_balance_of(p_user), 0);
  insert into public.ai_credit_ledger (user_id, kind, amount, week_start)
  values (p_user, 'weekly_allowance', v_top, v_week)
  on conflict do nothing;
end $$;

create or replace function public.ai_credit_lock(p_user uuid)
returns void language sql set search_path = '' as $$
  select pg_advisory_xact_lock(hashtextextended('credits:' || p_user::text, 0))
$$;

create or replace function public.ai_credit_state(p_user uuid)
returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object(
    'balance', public.ai_credit_balance_of(p_user),
    'weekly_allowance',
      public.ai_credit_weekly_allowance(public.ai_credit_is_pro(p_user)),
    'week_start', public.ai_credit_week_start(now()),
    'pro', public.ai_credit_is_pro(p_user))
$$;

-- Client: my balance (grants this week's allowance first).
create or replace function public.ai_credit_balance()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  perform public.ai_credit_lock(v_user);
  perform public.ai_credit_grant_week(v_user);
  return public.ai_credit_state(v_user);
end $$;

-- ai-request (service role): charge one credit for a request id.
-- status: 'charged' | 'duplicate' (already charged, no second charge) |
-- 'insufficient' (nothing charged).
create or replace function public.ai_credit_consume(
  p_user uuid, p_request_id text, p_kind text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_status text;
begin
  if p_user is null or p_request_id is null
     or p_kind not in ('coach_chat', 'advanced_analysis', 'progress_review') then
    raise exception 'invalid_argument' using errcode = '22023';
  end if;
  perform public.ai_credit_lock(p_user);
  perform public.ai_credit_grant_week(p_user);
  if exists (select 1 from public.ai_credit_ledger
             where user_id = p_user and request_id = p_request_id
               and kind = 'consume') then
    v_status := 'duplicate';
  elsif public.ai_credit_balance_of(p_user) < 1 then
    v_status := 'insufficient';
  else
    insert into public.ai_credit_ledger
      (user_id, kind, amount, request_id, request_kind)
    values (p_user, 'consume', -1, p_request_id, p_kind);
    v_status := 'charged';
  end if;
  return public.ai_credit_state(p_user) || jsonb_build_object('status', v_status);
end $$;

-- ai-request (service role): give the credit back when the provider failed.
-- Only for a charged request, at most once.
create or replace function public.ai_credit_refund(
  p_user uuid, p_request_id text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_refunded boolean := false;
begin
  if p_user is null or p_request_id is null then
    raise exception 'invalid_argument' using errcode = '22023';
  end if;
  perform public.ai_credit_lock(p_user);
  if exists (select 1 from public.ai_credit_ledger
             where user_id = p_user and request_id = p_request_id
               and kind = 'consume') then
    insert into public.ai_credit_ledger (user_id, kind, amount, request_id)
    values (p_user, 'refund', 1, p_request_id)
    on conflict do nothing;
    v_refunded := found;
  end if;
  return public.ai_credit_state(p_user) || jsonb_build_object('refunded', v_refunded);
end $$;

revoke execute on function
  public.ai_credit_is_pro(uuid),
  public.ai_credit_weekly_allowance(boolean),
  public.ai_credit_week_start(timestamptz),
  public.ai_credit_balance_of(uuid),
  public.ai_credit_grant_week(uuid),
  public.ai_credit_lock(uuid),
  public.ai_credit_state(uuid),
  public.ai_credit_balance(),
  public.ai_credit_consume(uuid, text, text),
  public.ai_credit_refund(uuid, text)
from public, anon, authenticated;

grant execute on function public.ai_credit_balance() to authenticated;
grant execute on function
  public.ai_credit_consume(uuid, text, text),
  public.ai_credit_refund(uuid, text)
to service_role;
