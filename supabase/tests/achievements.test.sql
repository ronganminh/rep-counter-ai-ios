-- G-1 achievements on the server: unlocked from synced workouts with the
-- app's rules, never revoked (D-05), listed only to their owner.
\set ON_ERROR_STOP 1
begin;

\set xp_contract `cat "$CONTRACTS_DIR/xp.json"`
select set_config('t.contract', :'xp_contract', false);

select test.new_user() as u1 \gset
select test.new_user() as u2 \gset
select set_config('t.u1', :'u1', false);

create temp table t (k text primary key, v jsonb);
grant all on t to authenticated, anon, service_role;

-- One workout per day for 7 days (UTC), 20 reps each, free mode; then a
-- timed challenge. A tombstone of 500 reps unlocks nothing by itself.
select test.as_user(:'u1');
insert into t values ('empty', public.achievements_list());
select public.sync_push_workouts((
  select jsonb_agg(jsonb_build_object(
    'client_id', 'd' || i,
    'client_updated_at', '2026-10-31T10:00:00Z',
    'raw', jsonb_build_object('exercise_id', 'push_up', 'reps', 10 + i,
      'duration_seconds', 60, 'mode', 'free',
      'started_at', format('2026-10-%sT08:00:00Z', 20 + i)))
  order by i) from generate_series(1, 6) i));
insert into t values ('six-days', public.achievements_list());
select public.sync_push_workouts(jsonb_build_array(
  jsonb_build_object('client_id', 'd7', 'client_updated_at', '2026-10-31T10:00:00Z',
    'raw', jsonb_build_object('exercise_id', 'push_up', 'reps', 5,
      'duration_seconds', 60, 'mode', 'free', 'started_at', '2026-10-27T20:00:00Z')),
  jsonb_build_object('client_id', 'd8', 'client_updated_at', '2026-10-31T10:00:00Z',
    'raw', jsonb_build_object('exercise_id', 'push_up', 'reps', 3,
      'duration_seconds', 60, 'mode', 'timed', 'started_at', '2026-10-27T21:00:00Z'))));
insert into t values ('seven-days', public.achievements_list());
-- Delete everything: unlocks stay (D-05).
select public.sync_push_workouts((
  select jsonb_agg(jsonb_build_object(
    'client_id', 'd' || i,
    'client_updated_at', '2026-10-31T12:00:00Z',
    'deleted_at', '2026-10-31T12:00:00Z',
    'raw', jsonb_build_object('exercise_id', 'push_up', 'reps', 1,
      'duration_seconds', 60, 'started_at', '2026-10-21T08:00:00Z')))
  from generate_series(1, 8) i));
insert into t values ('after-delete', public.achievements_list());
reset role;

select test.as_user(:'u2');
insert into t values ('u2', public.achievements_list());
reset role;

select test.as_anon();
insert into t values ('anon', to_jsonb(test.error_of('select public.achievements_list()')));
reset role;

do $$
declare
  ids text[];
  six text[];
  row_keys text[];
begin
  assert (select v from t where k = 'empty') = '[]'::jsonb;
  select array_agg(x ->> 'achievement_id' order by x ->> 'achievement_id')
    into six from jsonb_array_elements((select v from t where k = 'six-days')) x;
  -- 6 workouts, 81 reps, 6 days: first workout and a personal record only.
  assert six = array['firstWorkout', 'newPersonalRecord'], six::text;
  select array_agg(x ->> 'achievement_id' order by x ->> 'achievement_id')
    into ids from jsonb_array_elements((select v from t where k = 'seven-days')) x;
  -- 8 workouts, 89 reps (< 100), 7 days in a row, a timed challenge.
  assert ids = array['firstTimeChallenge', 'firstWorkout', 'newPersonalRecord',
    'streak7'], ids::text;
  assert (select v from t where k = 'after-delete') =
    (select v from t where k = 'seven-days'), 'D-05: never revoked';
  -- Ids and row keys follow the contract.
  assert ids <@ array(select jsonb_array_elements_text(
    current_setting('t.contract')::jsonb -> 'achievement_ids'));
  select array_agg(k order by k) into row_keys
    from jsonb_object_keys((select v -> 0 from t where k = 'seven-days')) k;
  assert row_keys = array(select x from jsonb_array_elements_text(
    current_setting('t.contract')::jsonb -> 'achievement_row') x order by x);
  assert (select v from t where k = 'u2') = '[]'::jsonb;
  assert (select v #>> '{}' from t where k = 'anon') = '42501';
end $$;

-- 100 reps and 10 workouts.
select test.as_user(:'u2');
select public.sync_push_workouts((
  select jsonb_agg(jsonb_build_object(
    'client_id', 'w' || i,
    'client_updated_at', '2026-10-31T10:00:00Z',
    'raw', jsonb_build_object('exercise_id', 'squat', 'reps', 10,
      'duration_seconds', 60, 'mode', 'targetReps',
      'started_at', '2026-10-30T08:00:00Z')))
  from generate_series(1, 10) i));
insert into t values ('u2-ten', public.achievements_list());
reset role;

do $$
declare
  ids text[];
begin
  select array_agg(x ->> 'achievement_id' order by x ->> 'achievement_id')
    into ids from jsonb_array_elements((select v from t where k = 'u2-ten')) x;
  -- Target-reps workouts never set a personal record (as on the phone).
  assert ids = array['firstWorkout', 'totalReps100', 'workouts10'], ids::text;
end $$;

rollback;
