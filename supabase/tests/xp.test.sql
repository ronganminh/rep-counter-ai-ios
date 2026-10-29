-- G-1 XP: shared rule examples, award on sync once (D-09), no revoke on
-- delete (D-05), half for manual (Q4), corrections, grants, isolation.
\set ON_ERROR_STOP 1
begin;

\set xp_contract `cat "$CONTRACTS_DIR/xp.json"`
select set_config('t.contract', :'xp_contract', false);

select test.check_contract(current_setting('t.contract')::jsonb,
  'functions', 'authenticated');
select test.check_contract(current_setting('t.contract')::jsonb,
  'service_functions', 'service_role', array['anon', 'authenticated']);

do $$
declare
  e jsonb;
  c jsonb := current_setting('t.contract')::jsonb;
begin
  for e in select jsonb_array_elements(c -> 'award_examples') loop
    assert public.xp_for_workout((e ->> 'reps')::int,
      (e ->> 'duration_seconds')::int, (e ->> 'manual')::boolean)
      = (e ->> 'xp')::int, e::text;
  end loop;
  for e in select jsonb_array_elements(c -> 'level_examples') loop
    assert public.xp_level_for((e ->> 'xp')::int) = (e ->> 'level')::int, e::text;
  end loop;
  assert not has_table_privilege('authenticated', 'public.xp_events', 'insert');
  assert not has_table_privilege('authenticated', 'public.user_progress', 'update');
  assert not has_table_privilege('anon', 'public.user_progress', 'select');
end $$;

select test.new_user() as u1 \gset
select test.new_user() as u2 \gset
select set_config('t.u1', :'u1', false), set_config('t.u2', :'u2', false);

create temp table t (k text primary key, v jsonb);
grant all on t to authenticated, anon, service_role;

-- Syncing workouts awards XP from the stored row: 20 camera reps = 30 XP,
-- a manual curl set of 20 = 15 XP, a tombstone-first push = nothing.
select test.as_user(:'u1');
insert into t values ('fresh', public.xp_progress());
select public.sync_push_workouts(jsonb_build_array(
  jsonb_build_object('client_id', 'cam', 'client_updated_at', '2026-10-29T10:00:00Z',
    'raw', jsonb_build_object('exercise_id', 'push_up', 'reps', 20,
      'duration_seconds', 120, 'started_at', '2026-10-29T09:58:00Z')),
  jsonb_build_object('client_id', 'man', 'client_updated_at', '2026-10-29T10:00:00Z',
    'raw', jsonb_build_object('exercise_id', 'curl', 'reps', 20, 'source', 'manual',
      'duration_seconds', 60, 'started_at', '2026-10-29T09:00:00Z')),
  jsonb_build_object('client_id', 'gone', 'client_updated_at', '2026-10-29T10:00:00Z',
    'deleted_at', '2026-10-29T10:00:00Z',
    'raw', jsonb_build_object('exercise_id', 'push_up', 'reps', 50,
      'duration_seconds', 120, 'started_at', '2026-10-29T08:00:00Z'))));
insert into t values ('after-sync', public.xp_progress());
-- A newer edit (more reps) and a deletion change nothing (D-09, D-05).
select public.sync_push_workouts(jsonb_build_array(
  jsonb_build_object('client_id', 'cam', 'client_updated_at', '2026-10-29T11:00:00Z',
    'raw', jsonb_build_object('exercise_id', 'push_up', 'reps', 140,
      'duration_seconds', 120, 'started_at', '2026-10-29T09:58:00Z')),
  jsonb_build_object('client_id', 'man', 'client_updated_at', '2026-10-29T11:00:00Z',
    'deleted_at', '2026-10-29T11:00:00Z',
    'raw', jsonb_build_object('exercise_id', 'curl', 'reps', 20, 'source', 'manual',
      'duration_seconds', 60, 'started_at', '2026-10-29T09:00:00Z'))));
insert into t values ('after-edit', public.xp_progress());
insert into t values ('own-events', (select to_jsonb(count(*)) from public.xp_events));
insert into t values ('insert-self', to_jsonb(test.error_of(format(
  'insert into public.xp_events (user_id, source_type, source_id, amount)
   values (%L, ''workout'', ''fake'', 10000)', :'u1'))));
insert into t values ('correct-self', to_jsonb(test.error_of(format(
  'select public.xp_correct(%L, ''x'', -100, null)', :'u1'))));
reset role;

do $$
declare
  c jsonb := current_setting('t.contract')::jsonb;
begin
  assert (select v from t where k = 'fresh') = '{"xp_total": 0, "level": 1}'::jsonb;
  assert test.has_shape((select v from t where k = 'after-sync'),
    c #> '{functions,xp_progress,returns}');
  assert (select v from t where k = 'after-sync') = '{"xp_total": 45, "level": 1}'::jsonb,
    (select v::text from t where k = 'after-sync');
  assert (select v from t where k = 'after-edit') = '{"xp_total": 45, "level": 1}'::jsonb;
  assert (select v from t where k = 'own-events') = '2'::jsonb;
  assert (select v #>> '{}' from t where k = 'insert-self') = '42501';
  assert (select v #>> '{}' from t where k = 'correct-self') = '42501';
end $$;

-- Level up from more syncs: 5 workouts of 30 XP → 195 → level 2.
select test.as_user(:'u1');
select public.sync_push_workouts((select jsonb_agg(jsonb_build_object(
  'client_id', 'more-' || i, 'client_updated_at', '2026-10-29T12:00:00Z',
  'raw', jsonb_build_object('exercise_id', 'push_up', 'reps', 20,
    'duration_seconds', 100, 'started_at', '2026-10-29T12:00:00Z')))
  from generate_series(1, 5) i));
insert into t values ('level2', public.xp_progress());
reset role;

-- The server corrects a bad award once; it can never add XP this way.
select test.as_service();
insert into t values ('corrected', public.xp_correct(:'u1', 'more-1', 30, 'duplicate'));
insert into t values ('corrected-again', public.xp_correct(:'u1', 'more-1', 30, 'duplicate'));
insert into t values ('corrected-positive', public.xp_correct(:'u1', 'more-2', -30, 'sign'));
reset role;

-- Another user sees none of it.
select test.as_user(:'u2');
insert into t values ('u2', public.xp_progress());
insert into t values ('u2-events', (select to_jsonb(count(*)) from public.xp_events));
reset role;

do $$
begin
  assert (select v from t where k = 'level2') = '{"xp_total": 195, "level": 2}'::jsonb;
  assert (select v ->> 'xp_total' from t where k = 'corrected') = '165';
  assert (select v ->> 'xp_total' from t where k = 'corrected-again') = '165';
  assert (select v ->> 'xp_total' from t where k = 'corrected-positive') = '135';
  assert (select v from t where k = 'u2') = '{"xp_total": 0, "level": 1}'::jsonb;
  assert (select v from t where k = 'u2-events') = '0'::jsonb;
end $$;

delete from auth.users where id = :'u1';
do $$
begin
  assert not exists (select 1 from public.xp_events
                     where user_id = current_setting('t.u1')::uuid);
  assert not exists (select 1 from public.user_progress
                     where user_id = current_setting('t.u1')::uuid);
end $$;

rollback;
