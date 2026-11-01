-- A-2 sync and H-2 account-scope deletes (06_SUPABASE_SCHEMA_PROPOSAL §1-§2,
-- owner decision L-D30). Workouts and plans mirror the phone's local data.
--
-- * Clients read their own rows (RLS) and write only through the
--   sync_push_* functions, which take the user from the JWT, derive the
--   indexed columns from the app's own JSON and keep the newer edit by
--   client time. No insert/update/delete grants on the tables.
-- * Deletions are tombstones (deleted_at); tombstones are purged after 90
--   days (Q3) by purge_sync_tombstones(), run on a schedule by the owner.
-- * server_seq (one shared sequence) is the pull cursor. Pushes for one
--   user are serialised with an advisory lock, so a user's rows commit in
--   server_seq order and a pull never skips a row that commits later.

-- Shared helpers ------------------------------------------------------------

create sequence if not exists public.sync_seq;
revoke all on sequence public.sync_seq from public, anon, authenticated;
grant usage on sequence public.sync_seq to service_role;

create or replace function public.set_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end $$;

create or replace function public.bump_sync_seq() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.server_seq := nextval('public.sync_seq');
  return new;
end $$;

revoke execute on function public.set_updated_at(), public.bump_sync_seq()
  from public, anon, authenticated;

-- Workouts ------------------------------------------------------------------

create table if not exists public.workouts (
  user_id uuid not null references auth.users (id) on delete cascade,
  client_id text not null check (char_length(client_id) between 1 and 80),
  started_at timestamptz not null,
  exercise_id text not null check (char_length(exercise_id) between 1 and 80),
  reps int not null check (reps between 0 and 100000),
  duration_seconds int not null check (duration_seconds between 0 and 86400),
  manual boolean not null default false,          -- D-18
  partial boolean not null default false,
  raw jsonb not null check (octet_length(raw::text) <= 262144), -- Q2: incl. rep_details
  deleted_at timestamptz,                          -- tombstone
  client_updated_at timestamptz not null,
  server_seq bigint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, client_id)
);

create index if not exists workouts_user_seq
  on public.workouts (user_id, server_seq);
create index if not exists workouts_deleted_at
  on public.workouts (deleted_at) where deleted_at is not null;

create or replace trigger workouts_updated_at before update on public.workouts
  for each row execute function public.set_updated_at();
create or replace trigger workouts_sync_seq before insert or update on public.workouts
  for each row execute function public.bump_sync_seq();

alter table public.workouts enable row level security;
revoke all on public.workouts from public, anon, authenticated;
grant select on public.workouts to authenticated;
grant select, insert, update, delete on public.workouts to service_role;

create policy "workouts: owner can read"
  on public.workouts for select to authenticated
  using ((select auth.uid()) = user_id);

-- Plans ---------------------------------------------------------------------
-- Same rules; the plan client (PL-1 is local today) syncs through
-- sync_push_plans / sync_pull_plans.

create table if not exists public.plans (
  user_id uuid not null references auth.users (id) on delete cascade,
  plan_id text not null check (char_length(plan_id) between 1 and 80),
  doc jsonb not null check (octet_length(doc::text) <= 262144),
  deleted_at timestamptz,
  client_updated_at timestamptz not null,
  server_seq bigint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, plan_id)
);

create index if not exists plans_user_seq on public.plans (user_id, server_seq);
create index if not exists plans_deleted_at
  on public.plans (deleted_at) where deleted_at is not null;

create or replace trigger plans_updated_at before update on public.plans
  for each row execute function public.set_updated_at();
create or replace trigger plans_sync_seq before insert or update on public.plans
  for each row execute function public.bump_sync_seq();

alter table public.plans enable row level security;
revoke all on public.plans from public, anon, authenticated;
grant select on public.plans to authenticated;
grant select, insert, update, delete on public.plans to service_role;

create policy "plans: owner can read"
  on public.plans for select to authenticated
  using ((select auth.uid()) = user_id);

-- Sync functions --------------------------------------------------------------

create or replace function public.sync_require_user() returns uuid
language plpgsql stable set search_path = '' as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  return v_user;
end $$;

create or replace function public.sync_rows_arg(p_rows jsonb) returns void
language plpgsql immutable set search_path = '' as $$
begin
  if p_rows is null or jsonb_typeof(p_rows) <> 'array' then
    raise exception 'rows_must_be_an_array' using errcode = '22023';
  end if;
  if jsonb_array_length(p_rows) > 500 then
    raise exception 'too_many_rows' using errcode = '54000';
  end if;
end $$;

create or replace function public.sync_workout_json(w public.workouts)
returns jsonb language sql immutable set search_path = '' as $$
  select jsonb_build_object(
    'client_id', w.client_id,
    'raw', w.raw,
    'client_updated_at', w.client_updated_at,
    'deleted_at', w.deleted_at,
    'server_seq', w.server_seq)
$$;

-- Push: p_rows = [{client_id, raw, client_updated_at, deleted_at?}, …].
-- Returns the stored row for each input, in order: the pushed one, or the
-- server's newer copy when the push was older (last writer by client time).
create or replace function public.sync_push_workouts(p_rows jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := public.sync_require_user();
  v_in jsonb;
  v_raw jsonb;
  v_client_id text;
  v_stored public.workouts;
  v_out jsonb := '[]'::jsonb;
begin
  perform public.sync_rows_arg(p_rows);
  perform pg_advisory_xact_lock(hashtextextended('sync:' || v_user::text, 0));
  for v_in in select value from jsonb_array_elements(p_rows) loop
    v_client_id := v_in ->> 'client_id';
    v_raw := v_in -> 'raw';
    if v_client_id is null or jsonb_typeof(v_raw) is distinct from 'object'
       or v_in ->> 'client_updated_at' is null then
      raise exception 'invalid_row' using errcode = '22023';
    end if;
    v_raw := v_raw || jsonb_build_object('client_id', v_client_id);

    insert into public.workouts as w (
      user_id, client_id, started_at, exercise_id, reps, duration_seconds,
      manual, partial, raw, deleted_at, client_updated_at)
    values (
      v_user, v_client_id,
      (v_raw ->> 'started_at')::timestamptz,
      v_raw ->> 'exercise_id',
      coalesce((v_raw ->> 'reps')::int, 0),
      coalesce((v_raw ->> 'duration_seconds')::int, 0),
      coalesce(v_raw ->> 'source', '') = 'manual',
      coalesce((v_raw ->> 'partial')::boolean, false),
      v_raw,
      (v_in ->> 'deleted_at')::timestamptz,
      (v_in ->> 'client_updated_at')::timestamptz)
    on conflict (user_id, client_id) do update set
      started_at = excluded.started_at,
      exercise_id = excluded.exercise_id,
      reps = excluded.reps,
      duration_seconds = excluded.duration_seconds,
      manual = excluded.manual,
      partial = excluded.partial,
      raw = excluded.raw,
      deleted_at = excluded.deleted_at,
      client_updated_at = excluded.client_updated_at
    where excluded.client_updated_at > w.client_updated_at
    returning * into v_stored;

    if not found then
      select * into v_stored from public.workouts
        where user_id = v_user and client_id = v_client_id;
    end if;
    v_out := v_out || jsonb_build_array(public.sync_workout_json(v_stored));
  end loop;
  return v_out;
end $$;

-- Pull: rows after the cursor, oldest first, at most p_limit (1..500).
-- Returns {rows, cursor, has_more}; cursor = the last row's server_seq.
create or replace function public.sync_pull_workouts(
  p_after bigint, p_limit int default 500)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_user uuid := public.sync_require_user();
  v_limit int := least(greatest(coalesce(p_limit, 500), 1), 500);
  v_rows jsonb;
  v_cursor bigint;
begin
  select
    coalesce(jsonb_agg(public.sync_workout_json(s.w) order by (s.w).server_seq),
      '[]'::jsonb),
    max((s.w).server_seq)
  into v_rows, v_cursor
  from (
    select w from public.workouts w
    where w.user_id = v_user and w.server_seq > coalesce(p_after, 0)
    order by w.server_seq
    limit v_limit
  ) s;

  return jsonb_build_object(
    'rows', v_rows,
    'cursor', coalesce(v_cursor, coalesce(p_after, 0)),
    'has_more', v_cursor is not null and exists (
      select 1 from public.workouts w
      where w.user_id = v_user and w.server_seq > v_cursor));
end $$;

-- Client ids of the account's live (not deleted) workouts, for the guest
-- merge preview.
create or replace function public.sync_workout_client_ids()
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(w.client_id order by w.client_id), '[]'::jsonb)
  from public.workouts w
  where w.user_id = public.sync_require_user() and w.deleted_at is null
$$;

create or replace function public.sync_plan_json(p public.plans)
returns jsonb language sql immutable set search_path = '' as $$
  select jsonb_build_object(
    'plan_id', p.plan_id,
    'doc', p.doc,
    'client_updated_at', p.client_updated_at,
    'deleted_at', p.deleted_at,
    'server_seq', p.server_seq)
$$;

-- Plans: p_rows = [{plan_id, doc, client_updated_at, deleted_at?}, …].
create or replace function public.sync_push_plans(p_rows jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := public.sync_require_user();
  v_in jsonb;
  v_stored public.plans;
  v_out jsonb := '[]'::jsonb;
begin
  perform public.sync_rows_arg(p_rows);
  perform pg_advisory_xact_lock(hashtextextended('sync:' || v_user::text, 0));
  for v_in in select value from jsonb_array_elements(p_rows) loop
    if v_in ->> 'plan_id' is null
       or jsonb_typeof(v_in -> 'doc') is distinct from 'object'
       or v_in ->> 'client_updated_at' is null then
      raise exception 'invalid_row' using errcode = '22023';
    end if;
    insert into public.plans as p (
      user_id, plan_id, doc, deleted_at, client_updated_at)
    values (
      v_user, v_in ->> 'plan_id', v_in -> 'doc',
      (v_in ->> 'deleted_at')::timestamptz,
      (v_in ->> 'client_updated_at')::timestamptz)
    on conflict (user_id, plan_id) do update set
      doc = excluded.doc,
      deleted_at = excluded.deleted_at,
      client_updated_at = excluded.client_updated_at
    where excluded.client_updated_at > p.client_updated_at
    returning * into v_stored;

    if not found then
      select * into v_stored from public.plans
        where user_id = v_user and plan_id = v_in ->> 'plan_id';
    end if;
    v_out := v_out || jsonb_build_array(public.sync_plan_json(v_stored));
  end loop;
  return v_out;
end $$;

create or replace function public.sync_pull_plans(
  p_after bigint, p_limit int default 500)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_user uuid := public.sync_require_user();
  v_limit int := least(greatest(coalesce(p_limit, 500), 1), 500);
  v_rows jsonb;
  v_cursor bigint;
begin
  select
    coalesce(jsonb_agg(public.sync_plan_json(s.p) order by (s.p).server_seq),
      '[]'::jsonb),
    max((s.p).server_seq)
  into v_rows, v_cursor
  from (
    select p from public.plans p
    where p.user_id = v_user and p.server_seq > coalesce(p_after, 0)
    order by p.server_seq
    limit v_limit
  ) s;

  return jsonb_build_object(
    'rows', v_rows,
    'cursor', coalesce(v_cursor, coalesce(p_after, 0)),
    'has_more', v_cursor is not null and exists (
      select 1 from public.plans p
      where p.user_id = v_user and p.server_seq > v_cursor));
end $$;

-- Q3: tombstones older than 90 days are removed. Run by the owner's
-- schedule (pg_cron, see supabase/README.md) with the service role.
-- A phone that has not synced for longer than that keeps those workouts
-- locally (it never sees the tombstone); the owner accepted the window.
create or replace function public.purge_sync_tombstones(
  p_older_than interval default interval '90 days')
returns int language plpgsql security definer set search_path = '' as $$
declare
  v_workouts int;
  v_plans int;
begin
  delete from public.workouts where deleted_at < now() - p_older_than;
  get diagnostics v_workouts = row_count;
  delete from public.plans where deleted_at < now() - p_older_than;
  get diagnostics v_plans = row_count;
  return v_workouts + v_plans;
end $$;

-- Functions are executable by PUBLIC by default: close that, then open
-- exactly what each role needs.
revoke execute on function
  public.sync_require_user(),
  public.sync_rows_arg(jsonb),
  public.sync_workout_json(public.workouts),
  public.sync_plan_json(public.plans),
  public.sync_push_workouts(jsonb),
  public.sync_pull_workouts(bigint, int),
  public.sync_workout_client_ids(),
  public.sync_push_plans(jsonb),
  public.sync_pull_plans(bigint, int),
  public.purge_sync_tombstones(interval)
from public, anon, authenticated;

grant execute on function
  public.sync_push_workouts(jsonb),
  public.sync_pull_workouts(bigint, int),
  public.sync_workout_client_ids(),
  public.sync_push_plans(jsonb),
  public.sync_pull_plans(bigint, int)
to authenticated;

grant execute on function public.purge_sync_tombstones(interval) to service_role;
