-- NT-2: contract, tokens move between accounts, inbox newest first and
-- read state, link rules, service-only writes, isolation, cascade.
\set ON_ERROR_STOP 1
begin;

\set push_contract `cat "$CONTRACTS_DIR/push_inbox.json"`
select set_config('t.contract', :'push_contract', false);
select test.check_contract(current_setting('t.contract')::jsonb,
  'functions', 'authenticated');
select test.check_contract(current_setting('t.contract')::jsonb,
  'service_functions', 'service_role', array['anon', 'authenticated']);

do $$
begin
  assert not has_table_privilege('authenticated', 'public.inbox_items', 'insert');
  assert not has_table_privilege('authenticated', 'public.inbox_items', 'update');
  assert not has_table_privilege('authenticated', 'public.push_tokens', 'insert');
  assert not has_table_privilege('anon', 'public.inbox_items', 'select');
end $$;

select test.new_user() as u1 \gset
select test.new_user() as u2 \gset
select set_config('t.u1', :'u1', false), set_config('t.u2', :'u2', false);
create temp table t (k text primary key, v jsonb);
grant all on t to authenticated, anon, service_role;

-- A device token follows the signed-in account.
select test.as_user(:'u1');
insert into t values ('reg', public.push_register_token('apns', 'device-token-1'));
select public.push_register_token('apns', 'device-token-1');
insert into t values ('bad-platform', to_jsonb(test.error_of(
  'select public.push_register_token(''sms'', ''device-token-x'')')));
reset role;
select test.as_user(:'u2');
select public.push_register_token('apns', 'device-token-1');
select public.push_register_token('fcm', 'fcm-token-2');
reset role;

do $$
begin
  assert (select v from t where k = 'reg') = '{"ok": true}'::jsonb;
  assert (select v #>> '{}' from t where k = 'bad-platform') = '22023';
  assert (select user_id from public.push_tokens where token = 'device-token-1')
    = current_setting('t.u2')::uuid, 'moved to the new account';
  assert (select count(*) from public.push_tokens) = 2;
end $$;

-- send-push writes the inbox row first and gets the user's tokens.
select test.as_service();
insert into t values ('n1', public.inbox_create(:'u2', 'friend_request',
  'repcoach://friends/requests', 'New friend request', null));
insert into t values ('n2', public.inbox_create(:'u2', 'invite',
  'repcoach://invites/abc', 'Ann invited you', 'Tap to answer'));
insert into t values ('bad-link', to_jsonb(test.error_of(format(
  'select public.inbox_create(%L, ''system'', ''https://evil.example'', ''x'', null)', :'u2'))));
reset role;
-- (One transaction has one now(): make the first item older.)
update public.inbox_items set created_at = now() - interval '1 minute'
  where kind = 'friend_request';

select test.as_user(:'u2');
insert into t values ('list', public.inbox_list(50));
select public.inbox_mark_read(((select v from t where k = 'n1') #>> '{item,id}')::uuid);
insert into t values ('list-after', public.inbox_list(1));
insert into t values ('create-self', to_jsonb(test.error_of(format(
  'select public.inbox_create(%L, ''system'', ''repcoach://inbox'', ''x'', null)', :'u2'))));
select public.push_unregister_token('fcm-token-2');
reset role;
select test.as_user(:'u1');
insert into t values ('u1-list', public.inbox_list(50));
-- Marking someone else's item does nothing.
select public.inbox_mark_read(((select v from t where k = 'n2') #>> '{item,id}')::uuid);
reset role;

do $$
declare
  n1 jsonb := (select v from t where k = 'n1');
  l jsonb := (select v from t where k = 'list');
begin
  assert jsonb_array_length(n1 -> 'tokens') = 2, n1::text;
  assert (select array_agg(k order by k) from jsonb_object_keys(n1 -> 'item') k) =
    (select array_agg(x order by x) from jsonb_array_elements_text(
      current_setting('t.contract')::jsonb -> 'inbox_row') x);
  assert (select v #>> '{}' from t where k = 'bad-link') = '23514';
  assert jsonb_array_length(l) = 2;
  assert l -> 0 ->> 'title' = 'Ann invited you', 'newest first';
  assert (select jsonb_array_length(v) from t where k = 'list-after') = 1;
  assert (select read_at from public.inbox_items where kind = 'friend_request') is not null;
  assert (select read_at from public.inbox_items where kind = 'invite') is null;
  assert (select v #>> '{}' from t where k = 'create-self') = '42501';
  assert not exists (select 1 from public.push_tokens where token = 'fcm-token-2');
  assert (select v from t where k = 'u1-list') = '[]'::jsonb;
end $$;

-- A rejected token is dropped by the service role only.
select test.as_service();
select public.push_drop_token('device-token-1');
reset role;
delete from auth.users where id = :'u2';
do $$
begin
  assert not exists (select 1 from public.push_tokens);
  assert not exists (select 1 from public.inbox_items
                     where user_id = current_setting('t.u2')::uuid);
end $$;

rollback;
