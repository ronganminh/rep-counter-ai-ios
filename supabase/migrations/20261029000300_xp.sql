-- G-1 XP and levels (06_SUPABASE_SCHEMA_PROPOSAL §4, D-05/D-09/D-18,
-- L-D30 Q4).
--
-- XP is computed by the database from the stored workout when it syncs
-- (a trigger on public.workouts), never from a number the client sends.
-- * One award per (user, source_type, source_id) (D-09): edits, retries and
--   re-syncs of a workout award nothing more.
-- * Deleting a workout keeps its XP (D-05); the server corrects invalid or
--   duplicate awards with a negative 'correction' event (service role).
-- * Manual and guided-timer workouts earn half (Q4); they still never count
--   for challenges, races or leaderboards (D-18, enforced there).
-- * Clients only read their own progress.
-- Rules mirror XpRules in the app; supabase/contracts/xp.json holds the
-- shared examples both test suites check.

create table if not exists public.xp_events (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  source_type text not null check (source_type in
    ('workout', 'plan_week', 'achievement', 'challenge', 'correction')),
  source_id text not null check (char_length(source_id) between 1 and 120),
  amount int not null check (amount between -10000 and 10000),
  reason text check (char_length(reason) <= 200),
  created_at timestamptz not null default now(),
  unique (user_id, source_type, source_id)
);

create table if not exists public.user_progress (
  user_id uuid primary key references auth.users (id) on delete cascade,
  xp_total int not null default 0,
  level int not null default 1,
  updated_at timestamptz not null default now()
);

create table if not exists public.achievements_unlocked (
  user_id uuid not null references auth.users (id) on delete cascade,
  achievement_id text not null check (char_length(achievement_id) between 1 and 80),
  unlocked_at timestamptz not null default now(),
  primary key (user_id, achievement_id)
);

alter table public.xp_events enable row level security;
alter table public.user_progress enable row level security;
alter table public.achievements_unlocked enable row level security;

revoke all on public.xp_events, public.user_progress,
  public.achievements_unlocked from public, anon, authenticated;
grant select on public.xp_events, public.user_progress,
  public.achievements_unlocked to authenticated;
grant select, insert, update, delete on public.xp_events, public.user_progress,
  public.achievements_unlocked to service_role;

create policy "xp_events: owner can read"
  on public.xp_events for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "user_progress: owner can read"
  on public.user_progress for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "achievements_unlocked: owner can read"
  on public.achievements_unlocked for select to authenticated
  using ((select auth.uid()) = user_id);

-- Rules (Q4 values) ----------------------------------------------------------

create or replace function public.xp_for_workout(
  p_reps int, p_duration_seconds int, p_manual boolean)
returns int language sql immutable set search_path = '' as $$
  select case
    when coalesce(p_reps, 0) <= 0 and coalesce(p_duration_seconds, 0) <= 0 then 0
    else (
      least(10 + case when p_reps > 0 then p_reps
                      else coalesce(p_duration_seconds, 0) / 6 end, 150)
      / case when p_manual then 2 else 1 end)
  end
$$;

create or replace function public.xp_level_for(p_xp int)
returns int language sql immutable set search_path = '' as $$
  select floor(sqrt(greatest(coalesce(p_xp, 0), 0) / 50.0))::int + 1
$$;

create or replace function public.xp_state(p_user uuid)
returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object(
    'xp_total', coalesce(p.xp_total, 0),
    'level', public.xp_level_for(coalesce(p.xp_total, 0)))
  from (select 1) one
  left join public.user_progress p on p.user_id = p_user
$$;

-- Every event moves the user's total; the level follows from it.
create or replace function public.xp_apply_event() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.user_progress as p (user_id, xp_total, level, updated_at)
  values (new.user_id, new.amount, public.xp_level_for(new.amount), now())
  on conflict (user_id) do update set
    xp_total = p.xp_total + excluded.xp_total,
    level = public.xp_level_for(p.xp_total + excluded.xp_total),
    updated_at = now();
  return null;
end $$;

create or replace trigger xp_events_apply after insert on public.xp_events
  for each row execute function public.xp_apply_event();

-- Award on sync: a live workout earns its XP once. Tombstones earn
-- nothing; a later tombstone takes nothing away (D-05).
create or replace function public.xp_award_workout() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_amount int;
begin
  if new.deleted_at is not null then
    return null;
  end if;
  v_amount := public.xp_for_workout(new.reps, new.duration_seconds, new.manual);
  if v_amount > 0 then
    insert into public.xp_events (user_id, source_type, source_id, amount)
    values (new.user_id, 'workout', new.client_id, v_amount)
    on conflict (user_id, source_type, source_id) do nothing;
  end if;
  return null;
end $$;

create or replace trigger workouts_award_xp
  after insert or update on public.workouts
  for each row execute function public.xp_award_workout();

-- Client: my progress.
create or replace function public.xp_progress()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  return public.xp_state(v_user);
end $$;

-- Service role: correct an invalid or duplicate award (never positive).
-- One correction per source id.
create or replace function public.xp_correct(
  p_user uuid, p_source_id text, p_amount int, p_reason text)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  if p_user is null or p_source_id is null or p_amount is null then
    raise exception 'invalid_argument' using errcode = '22023';
  end if;
  insert into public.xp_events (user_id, source_type, source_id, amount, reason)
  values (p_user, 'correction', p_source_id, -abs(p_amount), p_reason)
  on conflict (user_id, source_type, source_id) do nothing;
  return public.xp_state(p_user);
end $$;

revoke execute on function
  public.xp_for_workout(int, int, boolean),
  public.xp_level_for(int),
  public.xp_state(uuid),
  public.xp_apply_event(),
  public.xp_award_workout(),
  public.xp_progress(),
  public.xp_correct(uuid, text, int, text)
from public, anon, authenticated;

grant execute on function public.xp_progress() to authenticated;
grant execute on function public.xp_correct(uuid, text, int, text) to service_role;
