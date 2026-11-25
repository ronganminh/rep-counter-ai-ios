-- AI-1 coach v2 ("virtual PT", L-D43): two new credited request kinds, a
-- usage count for the per-user daily and the monthly total limits, and the
-- numbers-only training history ai-request summarises for the coach.
--
-- Nothing here stores a conversation (D-21): the ledger keeps the request id
-- and kind it already kept, and the history is read from the synced
-- workouts the user already has.

-- 1. New kinds: post-workout review and next-session / next-week plan.
alter table public.ai_credit_ledger
  drop constraint if exists ai_credit_ledger_request_kind_check;
alter table public.ai_credit_ledger
  add constraint ai_credit_ledger_request_kind_check
  check (request_kind in ('coach_chat', 'advanced_analysis', 'progress_review',
                          'workout_review', 'plan_suggestion'));

create or replace function public.ai_credit_consume(
  p_user uuid, p_request_id text, p_kind text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_status text;
begin
  if p_user is null or p_request_id is null
     or p_kind not in ('coach_chat', 'advanced_analysis', 'progress_review',
                       'workout_review', 'plan_suggestion') then
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

-- 2. ai-request (service role): AI requests that reached the provider and
-- were not refunded, for this user today (UTC) and for everyone this month
-- (UTC). The limits themselves are Edge Function settings.
create or replace function public.ai_usage_counts(p_user uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'user_today', (
      select count(*) from public.ai_credit_ledger c
      where c.user_id = p_user and c.kind = 'consume'
        and c.created_at >= date_trunc('day', now() at time zone 'utc') at time zone 'utc'
        and not exists (select 1 from public.ai_credit_ledger r
                        where r.user_id = c.user_id and r.request_id = c.request_id
                          and r.kind = 'refund')),
    'total_month', (
      select count(*) from public.ai_credit_ledger c
      where c.kind = 'consume'
        and c.created_at >= date_trunc('month', now() at time zone 'utc') at time zone 'utc'
        and not exists (select 1 from public.ai_credit_ledger r
                        where r.user_id = c.user_id and r.request_id = c.request_id
                          and r.kind = 'refund')))
$$;

create index if not exists ai_credit_ledger_kind_created
  on public.ai_credit_ledger (kind, created_at);

-- 3. ai-request (service role): the user's live synced workouts of the last
-- p_days days, as numbers only (no names typed by the user, no frames).
-- ai-request turns them into the coach's history summary.
create or replace function public.ai_coach_history(p_user uuid, p_days int default 28)
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(row order by (row ->> 'started_at')), '[]'::jsonb)
  from (
    select jsonb_strip_nulls(jsonb_build_object(
      'started_at', to_char(w.started_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
      'exercise', w.exercise_id,
      'reps', w.reps,
      'sets', (w.raw ->> 'sets')::int,
      'target_reps', (w.raw ->> 'target_reps')::int,
      'duration_seconds', w.duration_seconds,
      'manual', w.manual,
      'partial', w.partial,
      'quality_score', (w.raw #>> '{quality,quality_score}')::numeric,
      'avg_rep_sec', (w.raw #>> '{quality,avg_rep_sec}')::numeric,
      'cadence_consistency', (w.raw #>> '{quality,cadence_consistency}')::numeric,
      'range_of_motion', (w.raw #>> '{quality,range_of_motion}')::numeric,
      'flagged_reps', (w.raw #>> '{quality,flagged_reps}')::int)) as row
    from public.workouts w
    where w.user_id = p_user and w.deleted_at is null
      and w.started_at >= now() - make_interval(days => least(greatest(p_days, 1), 31))
    order by w.started_at desc
    limit 120
  ) recent
$$;

revoke execute on function
  public.ai_usage_counts(uuid),
  public.ai_coach_history(uuid, int)
from public, anon, authenticated;
grant execute on function
  public.ai_usage_counts(uuid),
  public.ai_coach_history(uuid, int)
to service_role;
