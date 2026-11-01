-- P-1 entitlements (06_SUPABASE_SCHEMA_PROPOSAL §6, D-08/D-10/D-13,
-- L-D30). Billing stays OFF: product ids and prices are not decided
-- (D-14); the functions refuse to verify until the owner sets
-- STORE_PRODUCT_IDS.
--
-- * Pro only after the server verified the purchase with Apple / Google
--   (D-10): rows are written by verify-purchase and store-webhook with the
--   service role, never by the app. Pending (Ask to Buy) and failures stay
--   Free.
-- * One row per store purchase (platform, original transaction id): a
--   purchase belongs to the first account that verified it.
-- * store_events keep the raw store notifications for support; no client
--   can read them (retention to be set with Legal, 06 §8).
-- * ai_credit_is_pro (AI-1) now reads these rows.

create table if not exists public.entitlements (
  user_id uuid not null references auth.users (id) on delete cascade,
  platform text not null check (platform in ('app_store', 'play')),
  product_id text not null check (char_length(product_id) between 1 and 200),
  original_transaction_id text not null
    check (char_length(original_transaction_id) between 1 and 512),
  status text not null check (status in
    ('active', 'grace', 'billing_retry', 'expired', 'revoked', 'pending')),
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (platform, original_transaction_id)
);
create index if not exists entitlements_user on public.entitlements (user_id);

create table if not exists public.store_events (
  id bigint generated always as identity primary key,
  platform text not null check (platform in ('app_store', 'play')),
  payload jsonb not null check (octet_length(payload::text) <= 65536),
  received_at timestamptz not null default now()
);

create or replace trigger entitlements_updated_at
  before update on public.entitlements
  for each row execute function public.set_updated_at();

alter table public.entitlements enable row level security;
alter table public.store_events enable row level security;
revoke all on public.entitlements, public.store_events
  from public, anon, authenticated;
grant select on public.entitlements to authenticated;
grant select, insert, update, delete on public.entitlements to service_role;
grant select, insert on public.store_events to service_role;

create policy "entitlements: owner can read"
  on public.entitlements for select to authenticated
  using ((select auth.uid()) = user_id);
-- store_events: no policy, no grant for clients.

create or replace function public.entitlement_is_pro_row(e public.entitlements)
returns boolean language sql stable set search_path = '' as $$
  select e.status in ('active', 'grace')
    and (e.expires_at is null or e.expires_at > now())
$$;

create or replace function public.entitlement_json(e public.entitlements)
returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object(
    'product_id', e.product_id,
    'status', e.status,
    'expires_at', e.expires_at,
    'verified_at', e.updated_at,
    'pro', public.entitlement_is_pro_row(e))
$$;

-- The user's best row: Pro rows first (latest expiry), then the most
-- recently confirmed one. Null for Free with no purchase.
create or replace function public.entitlement_best(p_user uuid)
returns jsonb language sql stable set search_path = '' as $$
  select public.entitlement_json(e)
  from public.entitlements e
  where e.user_id = p_user
  order by public.entitlement_is_pro_row(e) desc,
    e.expires_at desc nulls last, e.updated_at desc
  limit 1
$$;

-- App: my entitlement (null = Free).
create or replace function public.entitlement_current()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  return public.entitlement_best(v_user);
end $$;

-- verify-purchase (service role): record what the store confirmed for this
-- user. A purchase already owned by another account is refused.
create or replace function public.entitlement_record(
  p_user uuid, p_platform text, p_product_id text,
  p_original_transaction_id text, p_status text, p_expires_at timestamptz)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_row public.entitlements;
begin
  if p_user is null then
    raise exception 'invalid_argument' using errcode = '22023';
  end if;
  insert into public.entitlements as e (user_id, platform, product_id,
    original_transaction_id, status, expires_at)
  values (p_user, p_platform, p_product_id, p_original_transaction_id,
    p_status, p_expires_at)
  on conflict (platform, original_transaction_id) do update set
    product_id = excluded.product_id,
    status = excluded.status,
    expires_at = excluded.expires_at
  where e.user_id = excluded.user_id
  returning * into v_row;
  if not found then
    return jsonb_build_object('error', 'owned_by_other_account');
  end if;
  return public.entitlement_json(v_row);
end $$;

-- store-webhook (service role): apply the store's current state to a known
-- purchase. Unknown purchases are ignored (the app verifies them first).
create or replace function public.entitlement_update_from_store(
  p_platform text, p_original_transaction_id text, p_product_id text,
  p_status text, p_expires_at timestamptz)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_row public.entitlements;
begin
  update public.entitlements set
    product_id = coalesce(p_product_id, product_id),
    status = p_status,
    expires_at = p_expires_at
  where platform = p_platform
    and original_transaction_id = p_original_transaction_id
  returning * into v_row;
  if not found then
    return jsonb_build_object('updated', false);
  end if;
  return jsonb_build_object('updated', true) || public.entitlement_json(v_row);
end $$;

-- AI-1: Pro allowance now follows the verified entitlement.
create or replace function public.ai_credit_is_pro(p_user uuid)
returns boolean language sql stable set search_path = '' as $$
  select exists (
    select 1 from public.entitlements e
    where e.user_id = p_user and public.entitlement_is_pro_row(e))
$$;

revoke execute on function
  public.entitlement_is_pro_row(public.entitlements),
  public.entitlement_json(public.entitlements),
  public.entitlement_best(uuid),
  public.entitlement_current(),
  public.entitlement_record(uuid, text, text, text, text, timestamptz),
  public.entitlement_update_from_store(text, text, text, text, timestamptz),
  public.ai_credit_is_pro(uuid)
from public, anon, authenticated;

grant execute on function public.entitlement_current() to authenticated;
grant execute on function
  public.entitlement_record(uuid, text, text, text, text, timestamptz),
  public.entitlement_update_from_store(text, text, text, text, timestamptz)
to service_role;
