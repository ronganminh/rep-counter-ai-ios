-- AI-1 credits: contract, grants, weekly top-up, one charge per request,
-- one refund per charge, insufficient balance, isolation, cascade.
\set ON_ERROR_STOP 1
begin;

\set credits_contract `cat "$CONTRACTS_DIR/credits.json"`
select set_config('t.contract', :'credits_contract', false);

select test.check_contract(current_setting('t.contract')::jsonb,
  'functions', 'authenticated');
select test.check_contract(current_setting('t.contract')::jsonb,
  'service_functions', 'service_role', array['anon', 'authenticated']);

do $$
begin
  assert has_table_privilege('authenticated', 'public.ai_credit_ledger', 'select');
  assert not has_table_privilege('authenticated', 'public.ai_credit_ledger', 'insert');
  assert not has_table_privilege('authenticated', 'public.ai_credit_ledger', 'update');
  assert not has_table_privilege('authenticated', 'public.ai_credit_ledger', 'delete');
  assert not has_table_privilege('anon', 'public.ai_credit_ledger', 'select');
  assert not has_table_privilege('anon', 'public.ai_credit_balance', 'select');
  assert (select relrowsecurity from pg_class
          where oid = 'public.ai_credit_ledger'::regclass);
end $$;

select test.new_user() as u1 \gset
select test.new_user() as u2 \gset
select set_config('t.u1', :'u1', false), set_config('t.u2', :'u2', false);

create temp table t (k text primary key, v jsonb);
grant all on t to authenticated, anon, service_role;

-- The first balance grants the week's Free allowance, once.
select test.as_user(:'u1');
insert into t values ('b1', public.ai_credit_balance());
insert into t values ('b2', public.ai_credit_balance());
insert into t values ('consume-self', to_jsonb(test.error_of(format(
  'select public.ai_credit_consume(%L, ''r1'', ''coach_chat'')', :'u1'))));
insert into t values ('insert-self', to_jsonb(test.error_of(format(
  'insert into public.ai_credit_ledger (user_id, kind, amount, week_start)
   values (%L, ''admin_adjust'', 100, null)', :'u1'))));
reset role;

do $$
declare
  b jsonb := (select v from t where k = 'b1');
begin
  assert test.has_shape(b, current_setting('t.contract')::jsonb
    #> '{functions,ai_credit_balance,returns}'), b::text;
  assert (b ->> 'balance')::int = 10, 'Q5: 10 Free';
  assert (b ->> 'weekly_allowance')::int = 10;
  assert not (b ->> 'pro')::boolean;
  assert extract(isodow from (b ->> 'week_start')::date) = 1, 'weeks start Monday';
  assert (select v ->> 'balance' from t where k = 'b2') = '10';
  assert (select count(*) from public.ai_credit_ledger
          where kind = 'weekly_allowance') = 1;
  assert (select v #>> '{}' from t where k = 'consume-self') = '42501';
  assert (select v #>> '{}' from t where k = 'insert-self') = '42501';
end $$;

-- ai-request with the service role: charge, retry, refund.
select test.as_service();
insert into t values ('c1', public.ai_credit_consume(:'u1', 'r1', 'coach_chat'));
insert into t values ('c1-again', public.ai_credit_consume(:'u1', 'r1', 'coach_chat'));
insert into t values ('f1', public.ai_credit_refund(:'u1', 'r1'));
insert into t values ('f1-again', public.ai_credit_refund(:'u1', 'r1'));
insert into t values ('f-unknown', public.ai_credit_refund(:'u1', 'never-charged'));
insert into t values ('c1-after-refund', public.ai_credit_consume(:'u1', 'r1', 'coach_chat'));
insert into t values ('bad-kind', to_jsonb(test.error_of(format(
  'select public.ai_credit_consume(%L, ''r2'', ''free_feedback'')', :'u1'))));
reset role;

do $$
declare
  c jsonb := current_setting('t.contract')::jsonb;
begin
  assert test.has_shape((select v from t where k = 'c1'),
    c #> '{service_functions,ai_credit_consume,returns}');
  assert test.has_shape((select v from t where k = 'f1'),
    c #> '{service_functions,ai_credit_refund,returns}');
  assert (select v ->> 'status' from t where k = 'c1') = 'charged';
  assert (select v ->> 'balance' from t where k = 'c1') = '9';
  assert (select v ->> 'status' from t where k = 'c1-again') = 'duplicate';
  assert (select v ->> 'balance' from t where k = 'c1-again') = '9', 'D-09';
  assert (select (v ->> 'refunded')::boolean from t where k = 'f1');
  assert (select v ->> 'balance' from t where k = 'f1') = '10';
  assert not (select (v ->> 'refunded')::boolean from t where k = 'f1-again');
  assert (select v ->> 'balance' from t where k = 'f1-again') = '10';
  assert not (select (v ->> 'refunded')::boolean from t where k = 'f-unknown');
  -- A refunded request id stays used: a retry needs a new id.
  assert (select v ->> 'status' from t where k = 'c1-after-refund') = 'duplicate';
  assert (select v #>> '{}' from t where k = 'bad-kind') = '22023';
end $$;

-- Spend the rest: the eleventh request is refused and charges nothing.
select test.as_service();
select public.ai_credit_consume(:'u1', 'spend-' || i, 'advanced_analysis')
  from generate_series(1, 10) i;
insert into t values ('empty', public.ai_credit_consume(:'u1', 'r-11', 'progress_review'));
reset role;

do $$
begin
  assert (select v ->> 'status' from t where k = 'empty') = 'insufficient';
  assert (select v ->> 'balance' from t where k = 'empty') = '0';
  assert not exists (select 1 from public.ai_credit_ledger
                     where request_id = 'r-11');
end $$;

-- A new week tops up to the allowance; it does not stack. Simulate by
-- moving this week's allowance into last week.
update public.ai_credit_ledger set week_start = week_start - 7
  where user_id = :'u1' and kind = 'weekly_allowance';
insert into public.ai_credit_ledger (user_id, kind, amount)
  values (:'u1', 'admin_adjust', 4);  -- balance 4 before the new week
select test.as_user(:'u1');
insert into t values ('new-week', public.ai_credit_balance());
reset role;

do $$
begin
  assert (select v ->> 'balance' from t where k = 'new-week') = '10';
  assert (select amount from public.ai_credit_ledger
          where user_id = current_setting('t.u1')::uuid
            and kind = 'weekly_allowance'
          order by week_start desc limit 1) = 6;
end $$;

-- Isolation: u2 sees none of u1's ledger and has their own allowance.
select test.as_user(:'u2');
insert into t values ('u2-rows', (select to_jsonb(count(*)) from public.ai_credit_ledger
  where user_id = :'u1'));
insert into t values ('u2-balance', public.ai_credit_balance());
reset role;
select set_config('request.jwt.claims', '{"role":"authenticated"}', true);
set local role authenticated;
insert into t values ('no-sub', to_jsonb(test.error_of('select public.ai_credit_balance()')));
reset role;
select test.as_anon();
insert into t values ('anon', to_jsonb(test.error_of('select public.ai_credit_balance()')));
reset role;

do $$
begin
  assert (select v from t where k = 'u2-rows') = '0'::jsonb;
  assert (select v ->> 'balance' from t where k = 'u2-balance') = '10';
  assert (select v #>> '{}' from t where k = 'no-sub') = '28000';
  assert (select v #>> '{}' from t where k = 'anon') = '42501';
end $$;

delete from auth.users where id = :'u1';
do $$
begin
  assert not exists (select 1 from public.ai_credit_ledger
                     where user_id = current_setting('t.u1')::uuid);
end $$;

rollback;
