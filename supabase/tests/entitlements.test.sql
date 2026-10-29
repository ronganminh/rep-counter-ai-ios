-- P-1 entitlements: contract, grants, record / ownership, best row,
-- store updates, Pro feeds the AI allowance (60), isolation, cascade.
\set ON_ERROR_STOP 1
begin;

\set ent_contract `cat "$CONTRACTS_DIR/entitlements.json"`
select set_config('t.contract', :'ent_contract', false);
select test.check_contract(current_setting('t.contract')::jsonb,
  'functions', 'authenticated');
select test.check_contract(current_setting('t.contract')::jsonb,
  'service_functions', 'service_role', array['anon', 'authenticated']);

do $$
begin
  assert not has_table_privilege('authenticated', 'public.entitlements', 'insert');
  assert not has_table_privilege('authenticated', 'public.entitlements', 'update');
  assert not has_table_privilege('authenticated', 'public.store_events', 'select');
  assert not has_table_privilege('anon', 'public.entitlements', 'select');
  assert has_table_privilege('service_role', 'public.store_events', 'insert');
end $$;

select test.new_user() as u1 \gset
select test.new_user() as u2 \gset
select set_config('t.u1', :'u1', false), set_config('t.u2', :'u2', false);

create temp table t (k text primary key, v jsonb);
grant all on t to authenticated, anon, service_role;

-- Free before any purchase; the app cannot grant itself Pro.
select test.as_user(:'u1');
insert into t values ('free', coalesce(public.entitlement_current(), 'null'::jsonb));
insert into t values ('self-grant', to_jsonb(test.error_of(format(
  'select public.entitlement_record(%L, ''app_store'', ''pro'', ''1'', ''active'', null)',
  :'u1'))));
insert into t values ('credits-free', public.ai_credit_balance());
reset role;

-- verify-purchase records a verified purchase; Pro now.
select test.as_service();
insert into t values ('pending', public.entitlement_record(:'u1', 'app_store', 'pro.monthly',
  'otx-pending', 'pending', null));
insert into t values ('rec', public.entitlement_record(:'u1', 'app_store', 'pro.monthly',
  'otx-1', 'active', now() + interval '30 days'));
insert into t values ('rec-again', public.entitlement_record(:'u1', 'app_store', 'pro.monthly',
  'otx-1', 'active', now() + interval '31 days'));
insert into t values ('stolen', public.entitlement_record(:'u2', 'app_store', 'pro.monthly',
  'otx-1', 'active', now() + interval '30 days'));
reset role;
select test.as_user(:'u1');
insert into t values ('pro', public.entitlement_current());
reset role;
select test.as_user(:'u2');
insert into t values ('u2-free', coalesce(public.entitlement_current(), 'null'::jsonb));
insert into t values ('u2-rows', (select to_jsonb(count(*)) from public.entitlements));
reset role;

do $$
declare
  c jsonb := current_setting('t.contract')::jsonb;
  p jsonb := (select v from t where k = 'pro');
begin
  assert (select v from t where k = 'free') = 'null'::jsonb;
  assert (select v #>> '{}' from t where k = 'self-grant') = '42501';
  assert (select v ->> 'weekly_allowance' from t where k = 'credits-free') = '10';
  assert not (select (v ->> 'pro')::boolean from t where k = 'pending'), 'D-10';
  assert test.has_shape(p, c #> '{functions,entitlement_current,returns}'), p::text;
  assert p ->> 'status' = 'active' and (p ->> 'pro')::boolean;
  assert p ->> 'product_id' = 'pro.monthly';
  assert (select v ->> 'error' from t where k = 'stolen') = 'owned_by_other_account';
  assert (select user_id from public.entitlements where original_transaction_id = 'otx-1')
    = current_setting('t.u1')::uuid;
  assert (select v from t where k = 'u2-free') = 'null'::jsonb;
  assert (select v from t where k = 'u2-rows') = '0'::jsonb;
end $$;

-- Pro raises the AI allowance at the next week (top-up to 60).
update public.ai_credit_ledger set week_start = week_start - 7
  where user_id = :'u1' and kind = 'weekly_allowance';
select test.as_user(:'u1');
insert into t values ('credits-pro', public.ai_credit_balance());
reset role;

-- store-webhook: grace keeps Pro, billing retry / revoked / expired end it.
select test.as_service();
insert into t values ('grace', public.entitlement_update_from_store('app_store', 'otx-1',
  null, 'grace', now() + interval '5 days'));
reset role;
select test.as_user(:'u1');
insert into t values ('grace-pro', public.entitlement_current());
reset role;
select test.as_service();
insert into t values ('revoked', public.entitlement_update_from_store('app_store', 'otx-1',
  'pro.monthly', 'revoked', now() + interval '5 days'));
insert into t values ('unknown', public.entitlement_update_from_store('play', 'nope',
  null, 'active', null));
reset role;
select test.as_user(:'u1');
insert into t values ('after-revoke', public.entitlement_current());
reset role;
-- An active row whose expiry passed is not Pro.
select test.as_service();
select public.entitlement_record(:'u2', 'play', 'pro.annual', 'tok-2', 'active',
  now() - interval '1 minute');
reset role;
select test.as_user(:'u2');
insert into t values ('expired-active', public.entitlement_current());
reset role;

do $$
begin
  assert (select v ->> 'weekly_allowance' from t where k = 'credits-pro') = '60';
  assert (select v ->> 'balance' from t where k = 'credits-pro') = '60';
  assert (select (v ->> 'pro')::boolean from t where k = 'grace-pro');
  assert (select (v ->> 'updated')::boolean from t where k = 'revoked');
  assert not (select (v ->> 'updated')::boolean from t where k = 'unknown');
  assert not (select (v ->> 'pro')::boolean from t where k = 'after-revoke');
  assert (select v ->> 'status' from t where k = 'after-revoke') in ('revoked', 'pending');
  assert not (select (v ->> 'pro')::boolean from t where k = 'expired-active');
  assert not public.ai_credit_is_pro(current_setting('t.u1')::uuid);
end $$;

delete from auth.users where id = :'u1';
do $$
begin
  assert not exists (select 1 from public.entitlements
                     where user_id = current_setting('t.u1')::uuid);
end $$;

rollback;
