-- G-1 achievements on the server (owner approval 2026-10-31 to wire XP and
-- "achievements from the server" into the app).
--
-- achievements_unlocked (20261029000300_xp.sql) had no writer. This adds:
-- * achievements_evaluate(): unlocks from the user's live synced workouts,
--   with the same six rules as the app's AchievementService
--   (lib/features/achievements/achievement_service.dart). Ids are the app's
--   AchievementId names.
-- * a trigger on public.workouts, like the XP award: a live workout pushed
--   by sync is evaluated; a tombstone evaluates nothing.
-- * Unlocks are never revoked (D-05): deleting workouts keeps them.
-- * achievements_list() for the app (contracts/xp.json).
-- * A one-time backfill for workouts already synced.
-- Differences from the device rules: days are UTC days (the phone uses its
-- own time zone) and the 7-day streak counts any run of 7 days, not only
-- the current one. No XP is awarded for achievements.

create or replace function public.achievement_unlock(p_user uuid, p_id text)
returns void language sql security definer set search_path = '' as $$
  insert into public.achievements_unlocked (user_id, achievement_id)
  values (p_user, p_id)
  on conflict (user_id, achievement_id) do nothing
$$;

create or replace function public.achievements_evaluate(
  p_user uuid, p_workout public.workouts default null)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_count int;
  v_reps bigint;
  v_run int;
  v_best int;
begin
  select count(*), coalesce(sum(reps), 0) into v_count, v_reps
  from public.workouts where user_id = p_user and deleted_at is null;

  if v_count >= 1 then
    perform public.achievement_unlock(p_user, 'firstWorkout');
  end if;
  if v_reps >= 100 then
    perform public.achievement_unlock(p_user, 'totalReps100');
  end if;
  if v_count >= 10 then
    perform public.achievement_unlock(p_user, 'workouts10');
  end if;
  if exists (select 1 from public.workouts
             where user_id = p_user and deleted_at is null
               and raw ->> 'mode' = 'timed') then
    perform public.achievement_unlock(p_user, 'firstTimeChallenge');
  end if;

  -- Longest run of consecutive (UTC) days with a workout.
  select coalesce(max(n), 0) into v_run from (
    select count(*) as n from (
      select d, d - (row_number() over (order by d))::int as grp
      from (select distinct (started_at at time zone 'utc')::date as d
            from public.workouts
            where user_id = p_user and deleted_at is null) days
    ) g group by grp
  ) runs;
  if v_run >= 7 then
    perform public.achievement_unlock(p_user, 'streak7');
  end if;

  -- New personal record: a free workout with more reps than every earlier
  -- free workout of that exercise (the first one counts, as on the phone).
  if p_workout.client_id is not null
     and coalesce(p_workout.raw ->> 'mode', 'free') = 'free' then
    select max(reps) into v_best from public.workouts
    where user_id = p_user and deleted_at is null
      and exercise_id = p_workout.exercise_id
      and client_id <> p_workout.client_id
      and coalesce(raw ->> 'mode', 'free') = 'free';
    if v_best is null or p_workout.reps > v_best then
      perform public.achievement_unlock(p_user, 'newPersonalRecord');
    end if;
  end if;
end $$;

create or replace function public.achievements_on_workout() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.deleted_at is null then
    perform public.achievements_evaluate(new.user_id, new);
  end if;
  return null;
end $$;

create or replace trigger workouts_achievements
  after insert or update on public.workouts
  for each row execute function public.achievements_on_workout();

-- Client: my unlocked achievements, oldest first.
create or replace function public.achievements_list()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'achievement_id', a.achievement_id,
             'unlocked_at', a.unlocked_at)
           order by a.unlocked_at, a.achievement_id)
    from public.achievements_unlocked a where a.user_id = v_user), '[]'::jsonb);
end $$;

revoke execute on function
  public.achievement_unlock(uuid, text),
  public.achievements_evaluate(uuid, public.workouts),
  public.achievements_on_workout(),
  public.achievements_list()
from public, anon, authenticated;

grant execute on function public.achievements_list() to authenticated;

-- Backfill: workouts synced before this migration.
do $$
declare
  v_user uuid;
begin
  for v_user in select distinct user_id from public.workouts loop
    perform public.achievements_evaluate(v_user);
    if exists (select 1 from public.workouts
               where user_id = v_user and deleted_at is null
                 and coalesce(raw ->> 'mode', 'free') = 'free') then
      perform public.achievement_unlock(v_user, 'newPersonalRecord');
    end if;
  end loop;
end $$;
