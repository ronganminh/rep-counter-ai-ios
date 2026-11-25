-- AI-1 coach v2 (L-D43): new request kinds, usage counts for the limits,
-- numbers-only history; service role only.
\set ON_ERROR_STOP 1
begin;

do $$
begin
  assert not has_function_privilege('authenticated', 'public.ai_usage_counts(uuid)', 'execute');
  assert not has_function_privilege('anon', 'public.ai_usage_counts(uuid)', 'execute');
  assert not has_function_privilege('authenticated', 'public.ai_coach_history(uuid, int)', 'execute');
  assert has_function_privilege('service_role', 'public.ai_usage_counts(uuid)', 'execute');
  assert has_function_privilege('service_role', 'public.ai_coach_history(uuid, int)', 'execute');
end $$;

select test.new_user() as u1 \gset
select test.new_user() as u2 \gset
select set_config('t.u1', :'u1', false), set_config('t.u2', :'u2', false);

create temp table t (k text primary key, v jsonb);
grant all on t to authenticated, anon, service_role;

-- A synced workout with quality numbers, a deleted one, an old one, and one
-- of another user.
select test.as_user(:'u1');
select public.sync_push_workouts(jsonb_build_array(
  jsonb_build_object('client_id', 'h-1', 'client_updated_at', now(),
    'raw', jsonb_build_object('id', 'w1', 'exercise_id', 'pushup', 'exercise_name', 'My secret name',
      'started_at', now() - interval '2 days', 'duration_seconds', 300, 'reps', 30, 'sets', 3,
      'target_reps', 10, 'quality', jsonb_build_object('quality_score', 82, 'avg_rep_sec', 1.6,
        'cadence_consistency', 74, 'range_of_motion', 90, 'flagged_reps', 2),
      'rep_details', jsonb_build_array(jsonb_build_object('seconds', 1.2)))),
  jsonb_build_object('client_id', 'h-2', 'client_updated_at', now(), 'deleted_at', now(),
    'raw', jsonb_build_object('id', 'w2', 'exercise_id', 'squat',
      'started_at', now() - interval '1 day', 'duration_seconds', 60, 'reps', 10)),
  jsonb_build_object('client_id', 'h-3', 'client_updated_at', now(),
    'raw', jsonb_build_object('id', 'w3', 'exercise_id', 'squat',
      'started_at', now() - interval '40 days', 'duration_seconds', 60, 'reps', 10))));
select test.as_user(:'u2');
select public.sync_push_workouts(jsonb_build_array(
  jsonb_build_object('client_id', 'o-1', 'client_updated_at', now(),
    'raw', jsonb_build_object('id', 'o1', 'exercise_id', 'pullup',
      'started_at', now() - interval '1 day', 'duration_seconds', 60, 'reps', 5))));
reset role;

select test.as_service();
insert into t values ('history', public.ai_coach_history(:'u1', 28));
insert into t values ('history-u2', public.ai_coach_history(:'u2'));

-- Two charges for u1 today, one refunded; one for u2; a new kind is accepted.
insert into t values ('c1', public.ai_credit_consume(:'u1', 'q1', 'workout_review'));
insert into t values ('c2', public.ai_credit_consume(:'u1', 'q2', 'plan_suggestion'));
insert into t values ('c3', public.ai_credit_consume(:'u1', 'q3', 'coach_chat'));
select public.ai_credit_refund(:'u1', 'q3');
insert into t values ('c4', public.ai_credit_consume(:'u2', 'q1', 'coach_chat'));
insert into t values ('c5', public.ai_credit_consume(:'u2', 'q5', 'reminder_batch'));
insert into t values ('bad-kind', to_jsonb(test.error_of(format(
  'select public.ai_credit_consume(%L, ''q9'', ''photo_check'')', :'u1'))));
insert into t values ('usage-u1', public.ai_usage_counts(:'u1'));
insert into t values ('usage-u2', public.ai_usage_counts(:'u2'));
reset role;

do $$
declare
  h jsonb := (select v from t where k = 'history');
  w jsonb := h -> 0;
  u1 jsonb := (select v from t where k = 'usage-u1');
  u2 jsonb := (select v from t where k = 'usage-u2');
begin
  -- Only the live, recent workout of this user, numbers only.
  assert jsonb_array_length(h) = 1, h::text;
  assert w ->> 'exercise' = 'pushup';
  assert (w ->> 'reps')::int = 30 and (w ->> 'sets')::int = 3;
  assert (w ->> 'quality_score')::numeric = 82;
  assert (w ->> 'avg_rep_sec')::numeric = 1.6;
  assert (w ->> 'flagged_reps')::int = 2;
  assert w ->> 'manual' = 'false';
  assert not (w ? 'exercise_name') and not (w ? 'rep_details') and not (w ? 'raw'), w::text;
  assert position('secret' in h::text) = 0;
  assert jsonb_array_length((select v from t where k = 'history-u2')) = 1;

  assert (select v ->> 'status' from t where k = 'c1') = 'charged';
  assert (select v ->> 'status' from t where k = 'c2') = 'charged';
  assert (select v #>> '{}' from t where k = 'bad-kind') = '22023';
  assert (select v ->> 'status' from t where k = 'c5') = 'charged', 'NT-2 reminder_batch';
  -- The refunded request does not count.
  assert (u1 ->> 'user_today')::int = 2, u1::text;
  assert (u2 ->> 'user_today')::int = 2, u2::text;
  assert (u1 ->> 'total_month')::int = 4, u1::text;
  assert (u1 ->> 'total_month') = (u2 ->> 'total_month');
end $$;

-- Clients cannot call them.
select test.as_user(:'u1');
insert into t values ('usage-self', to_jsonb(test.error_of(format(
  'select public.ai_usage_counts(%L)', :'u1'))));
insert into t values ('history-self', to_jsonb(test.error_of(format(
  'select public.ai_coach_history(%L, 28)', :'u1'))));
reset role;

do $$
begin
  assert (select v #>> '{}' from t where k = 'usage-self') = '42501';
  assert (select v #>> '{}' from t where k = 'history-self') = '42501';
end $$;

rollback;
