-- NT-2 layer 2 (L-D44): credited kind `reminder_batch` (ai-request writes
-- reminder lines for the next 3-7 planned sessions; the app asks at most once
-- a week). Same ledger rules as every other kind.

alter table public.ai_credit_ledger
  drop constraint if exists ai_credit_ledger_request_kind_check;
alter table public.ai_credit_ledger
  add constraint ai_credit_ledger_request_kind_check
  check (request_kind in ('coach_chat', 'advanced_analysis', 'progress_review',
                          'workout_review', 'plan_suggestion', 'reminder_batch'));

create or replace function public.ai_credit_consume(
  p_user uuid, p_request_id text, p_kind text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_status text;
begin
  if p_user is null or p_request_id is null
     or p_kind not in ('coach_chat', 'advanced_analysis', 'progress_review',
                       'workout_review', 'plan_suggestion', 'reminder_batch') then
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
