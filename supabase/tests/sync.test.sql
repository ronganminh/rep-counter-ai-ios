-- A-2 sync: contract, RLS, idempotency, last-writer-wins, paging,
-- tombstones, purge, cascade. Run by supabase/tests/run.sh; everything is
-- rolled back at the end.
\set ON_ERROR_STOP 1
begin;

\set sync_contract `cat "$CONTRACTS_DIR/sync.json"`
-- psql variables are not expanded inside $$ bodies: pass them as settings.
select set_config('t.contract', :'sync_contract', false);

-- Contract: every RPC in contracts/sync.json exists with those parameter
-- names, is callable by signed-in users and not by anon.
do $$
declare
  c jsonb := current_setting('t.contract')::jsonb;
  f record;
  v_args text[];
begin
  for f in select key, value from jsonb_each(c -> 'functions') loop
    select coalesce(proargnames, '{}') into v_args
      from pg_proc where proname = f.key and pronamespace = 'public'::regnamespace;
    assert found, format('missing function %s', f.key);
    assert v_args = array(select jsonb_array_elements_text(f.value -> 'params')),
      format('%s params %s', f.key, v_args);
    assert has_function_privilege('authenticated', format('public.%I(%s)', f.key,
      (select string_agg(format_type(t, null), ',') from unnest(
        (select proargtypes::oid[] from pg_proc where proname = f.key
           and pronamespace = 'public'::regnamespace)) t)), 'execute'),
      format('authenticated cannot execute %s', f.key);
    assert not has_function_privilege('anon', format('public.%I(%s)', f.key,
      (select string_agg(format_type(t, null), ',') from unnest(
        (select proargtypes::oid[] from pg_proc where proname = f.key
           and pronamespace = 'public'::regnamespace)) t)), 'execute'),
      format('anon can execute %s', f.key);
  end loop;
end $$;

-- Grants: clients read through RLS and write only through the functions.
do $$
begin
  assert has_table_privilege('authenticated', 'public.workouts', 'select');
  assert not has_table_privilege('authenticated', 'public.workouts', 'insert');
  assert not has_table_privilege('authenticated', 'public.workouts', 'update');
  assert not has_table_privilege('authenticated', 'public.workouts', 'delete');
  assert not has_table_privilege('anon', 'public.workouts', 'select');
  assert not has_table_privilege('authenticated', 'public.plans', 'insert');
  assert not has_table_privilege('anon', 'public.plans', 'select');
  assert (select relrowsecurity from pg_class where oid = 'public.workouts'::regclass);
  assert (select relrowsecurity from pg_class where oid = 'public.plans'::regclass);
  assert not has_function_privilege('authenticated',
    'public.purge_sync_tombstones(interval)', 'execute');
  assert has_function_privilege('service_role',
    'public.purge_sync_tombstones(interval)', 'execute');
end $$;

select test.new_user('a@example.com') as u1 \gset
select test.new_user('b@example.com') as u2 \gset
select set_config('t.u1', :'u1', false), set_config('t.u2', :'u2', false);

create temp table t (k text primary key, v jsonb);
grant all on t to authenticated, anon, service_role;

-- First push stores the row, derives the columns from the app JSON and
-- stamps raw with the client id.
select test.as_user(:'u1');
insert into t values ('p1', public.sync_push_workouts(jsonb_build_array(jsonb_build_object(
  'client_id', 'c-1',
  'client_updated_at', '2026-10-29T10:00:00Z',
  'raw', jsonb_build_object('id', 'w1', 'exercise_id', 'pushup',
    'started_at', '2026-10-29T09:50:00Z', 'duration_seconds', 120, 'reps', 20,
    'rep_details', jsonb_build_array(jsonb_build_object('seconds', 1.2)))))));
reset role;

do $$
declare
  r jsonb := (select v -> 0 from t where k = 'p1');
  w public.workouts;
begin
  assert (select jsonb_array_length(v) from t where k = 'p1') = 1;
  assert r ->> 'client_id' = 'c-1';
  assert (r ->> 'server_seq')::bigint > 0;
  assert r ->> 'deleted_at' is null;
  assert r -> 'raw' ->> 'client_id' = 'c-1';
  assert r -> 'raw' -> 'rep_details' is not null, 'Q2: rep_details kept';
  select * into w from public.workouts where client_id = 'c-1';
  assert w.reps = 20 and w.duration_seconds = 120 and w.exercise_id = 'pushup';
  assert not w.manual and not w.partial;
  assert w.started_at = '2026-10-29T09:50:00Z';
  -- Row keys match the contract.
  assert (select array_agg(k order by k) from jsonb_object_keys(r) k) =
    (select array_agg(x order by x) from jsonb_array_elements_text(
      (select current_setting('t.contract')::jsonb -> 'workout_row')) x);
end $$;

-- Same push again: no change, same server_seq (D-09 retry is a no-op).
select test.as_user(:'u1');
insert into t values ('p1-again', public.sync_push_workouts(jsonb_build_array(jsonb_build_object(
  'client_id', 'c-1', 'client_updated_at', '2026-10-29T10:00:00Z',
  'raw', jsonb_build_object('exercise_id', 'pushup',
    'started_at', '2026-10-29T09:50:00Z', 'duration_seconds', 120, 'reps', 99)))));
-- An older edit never overwrites the newer one.
insert into t values ('p1-older', public.sync_push_workouts(jsonb_build_array(jsonb_build_object(
  'client_id', 'c-1', 'client_updated_at', '2026-10-29T09:00:00Z',
  'raw', jsonb_build_object('exercise_id', 'pushup',
    'started_at', '2026-10-29T09:50:00Z', 'duration_seconds', 120, 'reps', 1)))));
reset role;

do $$
begin
  assert (select v -> 0 ->> 'server_seq' from t where k = 'p1-again') =
         (select v -> 0 ->> 'server_seq' from t where k = 'p1');
  assert (select v -> 0 -> 'raw' ->> 'reps' from t where k = 'p1-older') = '20';
  assert (select reps from public.workouts where client_id = 'c-1') = 20;
  assert (select count(*) from public.workouts) = 1;
end $$;

-- A newer tombstone deletes it on the account and moves it up the cursor.
select test.as_user(:'u1');
insert into t values ('del', public.sync_push_workouts(jsonb_build_array(jsonb_build_object(
  'client_id', 'c-1', 'client_updated_at', '2026-10-29T11:00:00Z',
  'deleted_at', '2026-10-29T11:00:00Z',
  'raw', jsonb_build_object('exercise_id', 'pushup',
    'started_at', '2026-10-29T09:50:00Z', 'duration_seconds', 120, 'reps', 20)))));
-- Manual + partial records, for paging and derived flags.
insert into t values ('p2', public.sync_push_workouts(
  (select jsonb_agg(jsonb_build_object(
     'client_id', 'm-' || i, 'client_updated_at', '2026-10-29T12:00:00Z',
     'raw', jsonb_build_object('exercise_id', 'curl', 'source', 'manual',
       'partial', true, 'started_at', '2026-10-29T12:00:00Z',
       'duration_seconds', 30, 'reps', i)))
   from generate_series(1, 3) i)));
insert into t values ('pull-1', public.sync_pull_workouts(0, 2));
insert into t values ('ids', public.sync_workout_client_ids());
reset role;

do $$
declare
  d jsonb := (select v -> 0 from t where k = 'del');
  pg jsonb := (select v from t where k = 'pull-1');
begin
  assert d ->> 'deleted_at' is not null;
  assert (d ->> 'server_seq')::bigint >
         (select (v -> 0 ->> 'server_seq')::bigint from t where k = 'p1');
  assert (select bool_and(manual and partial) from public.workouts
          where client_id like 'm-%');
  assert jsonb_array_length(pg -> 'rows') = 2;
  assert (pg ->> 'has_more')::boolean;
  assert (pg ->> 'cursor')::bigint = (pg -> 'rows' -> 1 ->> 'server_seq')::bigint;
  -- Contract shape of the pull response.
  assert jsonb_typeof(pg -> 'rows') = 'array'
    and jsonb_typeof(pg -> 'cursor') = 'number'
    and jsonb_typeof(pg -> 'has_more') = 'boolean';
  -- Tombstones are not offered to the merge preview.
  assert (select v from t where k = 'ids') = '["m-1", "m-2", "m-3"]'::jsonb;
end $$;

-- Next page: the rest, no more pages; an empty pull keeps the cursor.
select test.as_user(:'u1');
insert into t values ('pull-2', public.sync_pull_workouts(
  (select (v ->> 'cursor')::bigint from t where k = 'pull-1'), 2));
insert into t values ('pull-3', public.sync_pull_workouts(
  (select (v ->> 'cursor')::bigint from t where k = 'pull-2'), 500));
reset role;

do $$
declare
  p2 jsonb := (select v from t where k = 'pull-2');
  p3 jsonb := (select v from t where k = 'pull-3');
begin
  assert jsonb_array_length(p2 -> 'rows') = 2, p2::text;
  assert not (p2 ->> 'has_more')::boolean;
  assert jsonb_array_length(p3 -> 'rows') = 0;
  assert p3 ->> 'cursor' = p2 ->> 'cursor';
end $$;

-- Another user: sees nothing of u1, and the same client id is a separate
-- workout in their account.
select test.as_user(:'u2');
insert into t values ('u2-pull', public.sync_pull_workouts(0, 500));
insert into t values ('u2-select', (select to_jsonb(count(*)) from public.workouts));
insert into t values ('u2-push', public.sync_push_workouts(jsonb_build_array(jsonb_build_object(
  'client_id', 'c-1', 'client_updated_at', '2026-10-28T10:00:00Z',
  'raw', jsonb_build_object('exercise_id', 'pullup',
    'started_at', '2026-10-28T09:50:00Z', 'duration_seconds', 60, 'reps', 5)))));
-- Direct writes are refused: only the functions write.
insert into t values ('u2-insert', to_jsonb(test.error_of(format(
  'insert into public.workouts (user_id, client_id, started_at, exercise_id, reps,
     duration_seconds, raw, client_updated_at)
   values (%L, ''x'', now(), ''pushup'', 1, 1, ''{}'', now())', :'u2'))));
insert into t values ('u2-update', to_jsonb(test.error_of(
  'update public.workouts set reps = 1000')));
reset role;

do $$
begin
  assert jsonb_array_length((select v -> 'rows' from t where k = 'u2-pull')) = 0;
  assert (select v from t where k = 'u2-select') = '0'::jsonb;
  assert (select count(*) from public.workouts where client_id = 'c-1') = 2;
  assert (select v #>> '{}' from t where k = 'u2-insert') = '42501';
  assert (select v #>> '{}' from t where k = 'u2-update') = '42501';
end $$;

-- Errors: not signed in, too many rows, malformed row; anon cannot call.
select set_config('request.jwt.claims', '{"role":"authenticated"}', true);
set local role authenticated;
insert into t values ('no-sub', to_jsonb(test.error_of(
  'select public.sync_pull_workouts(0, 10)')));
reset role;
select test.as_user(:'u1');
insert into t values ('too-many', to_jsonb(test.error_of(format(
  'select public.sync_push_workouts(%L::jsonb)',
  (select jsonb_agg(jsonb_build_object('client_id', i::text)) from generate_series(1, 501) i)))));
insert into t values ('bad-row', to_jsonb(test.error_of(
  'select public.sync_push_workouts(''[{"client_id":"z"}]''::jsonb)')));
insert into t values ('not-array', to_jsonb(test.error_of(
  'select public.sync_push_workouts(''{}''::jsonb)')));
reset role;
select test.as_anon();
insert into t values ('anon', to_jsonb(test.error_of(
  'select public.sync_pull_workouts(0, 10)')));
insert into t values ('anon-select', to_jsonb(test.error_of(
  'select count(*) from public.workouts')));
reset role;

do $$
begin
  assert (select v #>> '{}' from t where k = 'no-sub') = '28000';
  assert (select v #>> '{}' from t where k = 'too-many') = '54000';
  assert (select v #>> '{}' from t where k = 'bad-row') = '22023';
  assert (select v #>> '{}' from t where k = 'not-array') = '22023';
  assert (select v #>> '{}' from t where k = 'anon') = '42501';
  assert (select v #>> '{}' from t where k = 'anon-select') = '42501';
end $$;

-- Plans follow the same rules.
select test.as_user(:'u1');
insert into t values ('plan', public.sync_push_plans(jsonb_build_array(jsonb_build_object(
  'plan_id', 'plan-1', 'client_updated_at', '2026-10-29T10:00:00Z',
  'doc', jsonb_build_object('name', 'Full body')))));
insert into t values ('plan-older', public.sync_push_plans(jsonb_build_array(jsonb_build_object(
  'plan_id', 'plan-1', 'client_updated_at', '2026-10-29T09:00:00Z',
  'doc', jsonb_build_object('name', 'Old')))));
insert into t values ('plan-pull', public.sync_pull_plans(0, 500));
reset role;

do $$
begin
  assert (select v -> 0 -> 'doc' ->> 'name' from t where k = 'plan-older') = 'Full body';
  assert jsonb_array_length((select v -> 'rows' from t where k = 'plan-pull')) = 1;
  -- Plan row keys match the contract (the app's SupabasePlanSyncApi).
  assert (select array_agg(k order by k) from jsonb_object_keys(
      (select v -> 'rows' -> 0 from t where k = 'plan-pull')) k) =
    (select array_agg(x order by x) from jsonb_array_elements_text(
      (select current_setting('t.contract')::jsonb -> 'plan_row')) x);
end $$;

-- Q3 purge: only tombstones older than the window go; signed-in users
-- cannot run it.
update public.workouts set deleted_at = now() - interval '91 days'
  where client_id = 'c-1' and user_id = :'u1';
update public.workouts set deleted_at = now() - interval '10 days'
  where client_id = 'm-1';
select test.as_user(:'u1');
insert into t values ('purge-user', to_jsonb(test.error_of(
  'select public.purge_sync_tombstones()')));
reset role;
select test.as_service();
insert into t values ('purged', to_jsonb(public.purge_sync_tombstones()));
reset role;

do $$
begin
  assert (select v #>> '{}' from t where k = 'purge-user') = '42501';
  assert (select v from t where k = 'purged') = '1'::jsonb;
  assert not exists (select 1 from public.workouts
                     where client_id = 'c-1' and user_id = current_setting('t.u1')::uuid);
  assert exists (select 1 from public.workouts where client_id = 'm-1');
end $$;

-- Account deletion: the cascade removes the user's workouts and plans.
delete from auth.users where id = :'u1';
do $$
begin
  assert not exists (select 1 from public.workouts where user_id = current_setting('t.u1')::uuid);
  assert not exists (select 1 from public.plans where user_id = current_setting('t.u1')::uuid);
  assert exists (select 1 from public.workouts where user_id = current_setting('t.u2')::uuid);
end $$;

rollback;
