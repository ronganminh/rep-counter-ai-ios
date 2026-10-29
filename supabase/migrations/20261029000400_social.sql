-- S-1 social: friends by invite link, block, report, friends-only
-- leaderboard (06_SUPABASE_SCHEMA_PROPOSAL §5, D-11/D-18, L-D30 Q6/Q7).
--
-- * No discovery by display name (Q6): the only way to connect is an
--   invite code; there is no user search.
-- * A block ends the friendship; the blocker becomes invisible to the
--   blocked user (who is never told) and neither can reach the other.
-- * Reports are kept for moderation; nobody but the service role can read
--   them. Retention is Legal's decision (Q7), so nothing purges them and
--   they survive account deletion with the user ids nulled.
-- * Leaderboards count camera workouts only (D-18): manual and
--   guided-timer workouts never appear. They show display names and reps
--   of the caller and their friends, never anyone else.
-- * Every write goes through the social_* functions; clients read only rows
--   that involve them.
-- Races (S-2) come in a later migration.

create table if not exists public.friendships (
  requester uuid not null references auth.users (id) on delete cascade,
  addressee uuid not null references auth.users (id) on delete cascade,
  status text not null check (status in ('pending', 'accepted')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (requester, addressee),
  check (requester <> addressee)
);
create index if not exists friendships_addressee on public.friendships (addressee);

create table if not exists public.blocks (
  blocker uuid not null references auth.users (id) on delete cascade,
  blocked uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker, blocked),
  check (blocker <> blocked)
);
create index if not exists blocks_blocked on public.blocks (blocked);

create table if not exists public.reports (
  id bigint generated always as identity primary key,
  reporter uuid references auth.users (id) on delete set null,
  reported uuid references auth.users (id) on delete set null,
  reason text not null check (char_length(reason) <= 500),
  created_at timestamptz not null default now()
);
create index if not exists reports_reporter on public.reports (reporter, created_at);

create table if not exists public.invites (
  code text primary key check (code ~ '^[a-f0-9]{16}$'),
  inviter uuid not null references auth.users (id) on delete cascade,
  expires_at timestamptz not null,
  used_by uuid references auth.users (id) on delete set null,
  used_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists invites_inviter on public.invites (inviter, created_at);

alter table public.friendships enable row level security;
alter table public.blocks enable row level security;
alter table public.reports enable row level security;
alter table public.invites enable row level security;

revoke all on public.friendships, public.blocks, public.reports, public.invites
  from public, anon, authenticated;
grant select on public.friendships, public.blocks, public.invites to authenticated;
grant select, insert, update, delete on public.friendships, public.blocks,
  public.reports, public.invites to service_role;

create policy "friendships: the two users can read"
  on public.friendships for select to authenticated
  using ((select auth.uid()) in (requester, addressee));
-- (A block deletes the friendship, so no row links two blocked users.)
create policy "blocks: the blocker can read"
  on public.blocks for select to authenticated
  using ((select auth.uid()) = blocker);
create policy "invites: the inviter can read"
  on public.invites for select to authenticated
  using ((select auth.uid()) = inviter);
-- reports: no policy for authenticated, so no client can read any report.

create or replace trigger friendships_updated_at
  before update on public.friendships
  for each row execute function public.set_updated_at();

-- Helpers -------------------------------------------------------------------

create or replace function public.social_me() returns uuid
language plpgsql stable set search_path = '' as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  return v_user;
end $$;

create or replace function public.social_blocked_between(p_a uuid, p_b uuid)
returns boolean language sql stable set search_path = '' as $$
  select exists (select 1 from public.blocks
    where (blocker = p_a and blocked = p_b) or (blocker = p_b and blocked = p_a))
$$;

-- What [p_me] sees about [p_other]: someone who blocked me looks like a
-- stranger, never "blocked you".
create or replace function public.social_state_of(p_me uuid, p_other uuid)
returns text language sql stable set search_path = '' as $$
  select case
    when exists (select 1 from public.blocks
                 where blocker = p_me and blocked = p_other) then 'blocked'
    when exists (select 1 from public.blocks
                 where blocker = p_other and blocked = p_me) then 'none'
    when exists (select 1 from public.friendships
                 where status = 'accepted'
                   and ((requester = p_me and addressee = p_other)
                     or (requester = p_other and addressee = p_me))) then 'friends'
    when exists (select 1 from public.friendships
                 where status = 'pending' and requester = p_me
                   and addressee = p_other) then 'request_sent'
    when exists (select 1 from public.friendships
                 where status = 'pending' and requester = p_other
                   and addressee = p_me) then 'request_received'
    else 'none'
  end
$$;

-- Client functions --------------------------------------------------------------
-- Business refusals come back as {"error": code}; codes match SocialError in
-- the app: not_found, self, invite_used, invite_expired, blocked,
-- too_many_invites, too_many_reports.

-- PROPOSED limits: invites live 7 days (as the app's Social.inviteLifetime),
-- at most 20 open invites and 20 reports a day per user.
create or replace function public.social_create_invite()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_me uuid := public.social_me();
  v_code text;
  v_expires timestamptz := now() + interval '7 days';
begin
  if (select count(*) from public.invites
      where inviter = v_me and used_by is null and expires_at > now()) >= 20 then
    return jsonb_build_object('error', 'too_many_invites');
  end if;
  v_code := substr(replace(gen_random_uuid()::text, '-', ''), 1, 16);
  insert into public.invites (code, inviter, expires_at)
  values (v_code, v_me, v_expires);
  return jsonb_build_object('code', v_code, 'expires_at', v_expires);
end $$;

-- Accepting an invite sends a request from the inviter to me; I then
-- confirm it with social_respond (two steps, as in the app's rules).
create or replace function public.social_accept_invite(p_code text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_me uuid := public.social_me();
  v_inv public.invites;
begin
  select * into v_inv from public.invites where code = p_code for update;
  if not found then
    return jsonb_build_object('error', 'not_found');
  elsif v_inv.inviter = v_me then
    return jsonb_build_object('error', 'self');
  elsif v_inv.used_by is not null or v_inv.used_at is not null then
    return jsonb_build_object('error', 'invite_used');
  elsif v_inv.expires_at <= now() then
    return jsonb_build_object('error', 'invite_expired');
  elsif public.social_blocked_between(v_inv.inviter, v_me) then
    return jsonb_build_object('error', 'blocked');
  end if;
  update public.invites set used_by = v_me, used_at = now() where code = p_code;
  insert into public.friendships (requester, addressee, status)
  values (v_inv.inviter, v_me, 'pending')
  on conflict do nothing;
  return jsonb_build_object('user_id', v_inv.inviter,
    'state', public.social_state_of(v_me, v_inv.inviter));
end $$;

create or replace function public.social_respond(p_user uuid, p_accept boolean)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_me uuid := public.social_me();
begin
  if not exists (select 1 from public.friendships
                 where requester = p_user and addressee = v_me
                   and status = 'pending') then
    return jsonb_build_object('error', 'not_found');
  end if;
  if coalesce(p_accept, false) then
    update public.friendships set status = 'accepted'
      where requester = p_user and addressee = v_me;
  else
    delete from public.friendships where requester = p_user and addressee = v_me;
  end if;
  return jsonb_build_object('state', public.social_state_of(v_me, p_user));
end $$;

create or replace function public.social_state(p_user uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('state', public.social_state_of(public.social_me(), p_user))
$$;

create or replace function public.social_block(p_user uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_me uuid := public.social_me();
begin
  if p_user is null or p_user = v_me then
    return jsonb_build_object('error', 'self');
  end if;
  if not exists (select 1 from auth.users where id = p_user) then
    return jsonb_build_object('error', 'not_found');
  end if;
  insert into public.blocks (blocker, blocked) values (v_me, p_user)
  on conflict do nothing;
  delete from public.friendships
    where (requester = v_me and addressee = p_user)
       or (requester = p_user and addressee = v_me);
  return jsonb_build_object('state', 'blocked');
end $$;

create or replace function public.social_report(p_user uuid, p_reason text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_me uuid := public.social_me();
begin
  if p_user is null or p_user = v_me then
    return jsonb_build_object('error', 'self');
  end if;
  if not exists (select 1 from auth.users where id = p_user) then
    return jsonb_build_object('error', 'not_found');
  end if;
  if (select count(*) from public.reports
      where reporter = v_me and created_at > now() - interval '1 day') >= 20 then
    return jsonb_build_object('error', 'too_many_reports');
  end if;
  insert into public.reports (reporter, reported, reason)
  values (v_me, p_user, left(coalesce(p_reason, ''), 500));
  return jsonb_build_object('ok', true);
end $$;

-- My friends and requests (display names only), newest first. People who
-- blocked me do not appear.
create or replace function public.social_friends()
returns jsonb language sql stable security definer set search_path = '' as $$
  with me as (select public.social_me() as id),
  other as (
    select case when f.requester = me.id then f.addressee else f.requester end as id,
           f.updated_at
    from public.friendships f, me
    where me.id in (f.requester, f.addressee)
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'user_id', o.id,
      'display_name', p.display_name,
      'state', public.social_state_of(me.id, o.id))
    order by o.updated_at desc), '[]'::jsonb)
  from other o
  cross join me
  left join public.profiles p on p.user_id = o.id
  where public.social_state_of(me.id, o.id) <> 'none'
$$;

-- Friends-only leaderboard: total camera reps for one exercise since
-- p_since (at most a year back), me and my friends, best first.
create or replace function public.social_leaderboard(
  p_exercise_id text, p_since timestamptz)
returns jsonb language sql stable security definer set search_path = '' as $$
  with me as (select public.social_me() as id),
  people as (
    select me.id from me
    union
    select case when f.requester = me.id then f.addressee else f.requester end
    from public.friendships f, me
    where f.status = 'accepted' and me.id in (f.requester, f.addressee)
      and not public.social_blocked_between(f.requester, f.addressee)
  ),
  totals as (
    select w.user_id, sum(w.reps)::int as reps
    from public.workouts w
    join people on people.id = w.user_id
    where w.exercise_id = p_exercise_id
      and not w.manual                       -- D-18: camera workouts only
      and w.deleted_at is null
      and w.started_at >= greatest(p_since, now() - interval '366 days')
    group by w.user_id
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'display_name', coalesce(p.display_name, ''),
      'reps', t.reps,
      'me', t.user_id = me.id)
    order by t.reps desc, coalesce(p.display_name, '')), '[]'::jsonb)
  from totals t
  cross join me
  left join public.profiles p on p.user_id = t.user_id
$$;

revoke execute on function
  public.social_me(),
  public.social_blocked_between(uuid, uuid),
  public.social_state_of(uuid, uuid),
  public.social_create_invite(),
  public.social_accept_invite(text),
  public.social_respond(uuid, boolean),
  public.social_state(uuid),
  public.social_block(uuid),
  public.social_report(uuid, text),
  public.social_friends(),
  public.social_leaderboard(text, timestamptz)
from public, anon, authenticated;

grant execute on function
  public.social_create_invite(),
  public.social_accept_invite(text),
  public.social_respond(uuid, boolean),
  public.social_state(uuid),
  public.social_block(uuid),
  public.social_report(uuid, text),
  public.social_friends(),
  public.social_leaderboard(text, timestamptz)
to authenticated;
