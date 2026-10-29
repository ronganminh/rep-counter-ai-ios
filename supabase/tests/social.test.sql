-- S-1 social: invites, requests, blocks (silent), reports (hidden),
-- friends-only camera leaderboard (D-18), limits, isolation, deletion.
\set ON_ERROR_STOP 1
begin;

\set social_contract `cat "$CONTRACTS_DIR/social.json"`
select set_config('t.contract', :'social_contract', false);
select test.check_contract(current_setting('t.contract')::jsonb,
  'functions', 'authenticated');

do $$
begin
  assert not has_table_privilege('authenticated', 'public.friendships', 'insert');
  assert not has_table_privilege('authenticated', 'public.blocks', 'insert');
  assert not has_table_privilege('authenticated', 'public.reports', 'select');
  assert not has_table_privilege('authenticated', 'public.reports', 'insert');
  assert not has_table_privilege('authenticated', 'public.invites', 'insert');
  assert not has_table_privilege('anon', 'public.friendships', 'select');
end $$;

select test.new_user() as ann \gset
select test.new_user() as bob \gset
select test.new_user() as cam \gset
select test.new_user() as dan \gset
select set_config('t.ann', :'ann', false), set_config('t.bob', :'bob', false),
  set_config('t.cam', :'cam', false), set_config('t.dan', :'dan', false);
insert into public.profiles (user_id, display_name) values
  (:'ann', 'Ann'), (:'bob', 'Bob'), (:'cam', 'Cam'), (:'dan', 'Dan');

create temp table t (k text primary key, v jsonb);
grant all on t to authenticated, anon, service_role;

-- Invite → accept → respond.
select test.as_user(:'ann');
insert into t values ('invite', public.social_create_invite());
reset role;
select set_config('t.code', (select v ->> 'code' from t where k = 'invite'), false);

select test.as_user(:'bob');
insert into t values ('accept', public.social_accept_invite(current_setting('t.code')));
insert into t values ('bob-sees', public.social_state(:'ann'));
reset role;
select test.as_user(:'ann');
insert into t values ('ann-sees', public.social_state(:'bob'));
insert into t values ('self', public.social_accept_invite(current_setting('t.code')));
reset role;
select test.as_user(:'bob');
insert into t values ('respond', public.social_respond(:'ann', true));
insert into t values ('respond-again', public.social_respond(:'ann', true));
reset role;
select test.as_user(:'ann');
insert into t values ('ann-friends', public.social_state(:'bob'));
reset role;
select test.as_user(:'cam');
insert into t values ('used', public.social_accept_invite(current_setting('t.code')));
insert into t values ('unknown', public.social_accept_invite('0000000000000000'));
reset role;

do $$
declare
  c jsonb := current_setting('t.contract')::jsonb;
begin
  assert test.has_shape((select v from t where k = 'invite'),
    c #> '{functions,social_create_invite,returns}');
  assert (select (v ->> 'expires_at')::timestamptz from t where k = 'invite')
    between now() + interval '6 days 23 hours' and now() + interval '7 days 1 hour';
  assert test.has_shape((select v from t where k = 'accept'),
    c #> '{functions,social_accept_invite,returns}');
  assert (select v ->> 'user_id' from t where k = 'accept') = current_setting('t.ann');
  assert (select v ->> 'state' from t where k = 'bob-sees') = 'request_received';
  assert (select v ->> 'state' from t where k = 'ann-sees') = 'request_sent';
  assert (select v ->> 'error' from t where k = 'self') = 'self';
  assert (select v ->> 'state' from t where k = 'respond') = 'friends';
  assert (select v ->> 'error' from t where k = 'respond-again') = 'not_found';
  assert (select v ->> 'state' from t where k = 'ann-friends') = 'friends';
  assert (select v ->> 'error' from t where k = 'used') = 'invite_used';
  assert (select v ->> 'error' from t where k = 'unknown') = 'not_found';
end $$;

-- An expired invite is refused; declining removes the request.
select test.as_user(:'cam');
insert into t values ('cam-invite', public.social_create_invite());
reset role;
update public.invites set expires_at = now() - interval '1 minute'
  where code = (select v ->> 'code' from t where k = 'cam-invite');
select test.as_user(:'dan');
insert into t values ('expired', public.social_accept_invite(
  (select v ->> 'code' from t where k = 'cam-invite')));
reset role;
select test.as_user(:'dan');
insert into t values ('dan-invite', public.social_create_invite());
reset role;
select test.as_user(:'cam');
select public.social_accept_invite((select v ->> 'code' from t where k = 'dan-invite'));
insert into t values ('decline', public.social_respond(:'dan', false));
reset role;

do $$
begin
  assert (select v ->> 'error' from t where k = 'expired') = 'invite_expired';
  assert (select v ->> 'state' from t where k = 'decline') = 'none';
  assert not exists (select 1 from public.friendships
    where requester = current_setting('t.dan')::uuid);
end $$;

-- Leaderboard: camera reps of me and my friends only (D-18).
select test.as_user(:'ann');
select public.sync_push_workouts(jsonb_build_array(jsonb_build_object(
  'client_id', 'a1', 'client_updated_at', now(),
  'raw', jsonb_build_object('exercise_id', 'push_up', 'reps', 30,
    'duration_seconds', 60, 'started_at', now() - interval '1 day'))));
reset role;
select test.as_user(:'bob');
select public.sync_push_workouts(jsonb_build_array(
  jsonb_build_object('client_id', 'b1', 'client_updated_at', now(),
    'raw', jsonb_build_object('exercise_id', 'push_up', 'reps', 25,
      'duration_seconds', 60, 'started_at', now() - interval '1 day')),
  jsonb_build_object('client_id', 'b2', 'client_updated_at', now(),
    'raw', jsonb_build_object('exercise_id', 'push_up', 'reps', 20,
      'duration_seconds', 60, 'started_at', now() - interval '2 days')),
  jsonb_build_object('client_id', 'b-manual', 'client_updated_at', now(),
    'raw', jsonb_build_object('exercise_id', 'push_up', 'reps', 500,
      'source', 'manual', 'duration_seconds', 60, 'started_at', now())),
  jsonb_build_object('client_id', 'b-old', 'client_updated_at', now(),
    'raw', jsonb_build_object('exercise_id', 'push_up', 'reps', 99,
      'duration_seconds', 60, 'started_at', now() - interval '30 days'))));
reset role;
select test.as_user(:'cam');
select public.sync_push_workouts(jsonb_build_array(jsonb_build_object(
  'client_id', 'c1', 'client_updated_at', now(),
  'raw', jsonb_build_object('exercise_id', 'push_up', 'reps', 300,
    'duration_seconds', 60, 'started_at', now()))));
reset role;
select test.as_user(:'ann');
insert into t values ('board', public.social_leaderboard('push_up', now() - interval '7 days'));
insert into t values ('board-other', public.social_leaderboard('pull_up', now() - interval '7 days'));
reset role;

do $$
declare
  b jsonb := (select v from t where k = 'board');
begin
  assert jsonb_array_length(b) = 2, b::text;
  assert b -> 0 = '{"display_name": "Bob", "reps": 45, "me": false}'::jsonb, b::text;
  assert b -> 1 = '{"display_name": "Ann", "reps": 30, "me": true}'::jsonb, b::text;
  assert (select array_agg(k order by k) from jsonb_object_keys(b -> 0) k) =
    (select array_agg(x order by x) from jsonb_array_elements_text(
      current_setting('t.contract')::jsonb -> 'leaderboard_row') x);
  assert (select v from t where k = 'board-other') = '[]'::jsonb;
end $$;

-- Block: silent for the blocked user, ends the friendship, hides boards.
select test.as_user(:'ann');
insert into t values ('ann-invite-2', public.social_create_invite());
reset role;
select test.as_user(:'cam');
select public.social_accept_invite((select v ->> 'code' from t where k = 'ann-invite-2'));
select public.social_respond(:'ann', true);
insert into t values ('cam-block', public.social_block(:'ann'));
insert into t values ('cam-sees', public.social_state(:'ann'));
insert into t values ('cam-self-block', public.social_block(:'cam'));
reset role;
select test.as_user(:'ann');
insert into t values ('ann-sees-cam', public.social_state(:'cam'));
insert into t values ('ann-friends-list', public.social_friends());
insert into t values ('ann-board-2', public.social_leaderboard('push_up', now() - interval '7 days'));
insert into t values ('ann-reads-blocks', (select to_jsonb(count(*)) from public.blocks));
reset role;
select test.as_user(:'cam');
insert into t values ('cam-invite-3', public.social_create_invite());
reset role;
select test.as_user(:'ann');
insert into t values ('blocked-invite', public.social_accept_invite(
  (select v ->> 'code' from t where k = 'cam-invite-3')));
reset role;

do $$
declare
  f jsonb := (select v from t where k = 'ann-friends-list');
begin
  assert (select v ->> 'state' from t where k = 'cam-block') = 'blocked';
  assert (select v ->> 'state' from t where k = 'cam-sees') = 'blocked';
  assert (select v ->> 'error' from t where k = 'cam-self-block') = 'self';
  assert (select v ->> 'state' from t where k = 'ann-sees-cam') = 'none',
    'the blocked user is never told';
  assert jsonb_array_length(f) = 1, f::text;
  assert f -> 0 ->> 'display_name' = 'Bob' and f -> 0 ->> 'state' = 'friends';
  assert (select array_agg(k order by k) from jsonb_object_keys(f -> 0) k) =
    (select array_agg(x order by x) from jsonb_array_elements_text(
      current_setting('t.contract')::jsonb -> 'friend_row') x);
  assert jsonb_array_length((select v from t where k = 'ann-board-2')) = 2;
  assert (select v from t where k = 'ann-reads-blocks') = '0'::jsonb;
  assert (select v ->> 'error' from t where k = 'blocked-invite') = 'blocked';
end $$;

-- Reports: kept, capped at 500 characters, 20 a day, unreadable by clients.
select test.as_user(:'ann');
insert into t values ('report', public.social_report(:'dan', repeat('x', 600)));
select public.social_report(:'dan', 'spam') from generate_series(1, 19);
insert into t values ('report-21', public.social_report(:'dan', 'spam'));
insert into t values ('read-reports', to_jsonb(test.error_of(
  'select count(*) from public.reports')));
insert into t values ('report-self', public.social_report(:'ann', 'me'));
reset role;

do $$
begin
  assert (select v from t where k = 'report') = '{"ok": true}'::jsonb;
  assert (select v ->> 'error' from t where k = 'report-21') = 'too_many_reports';
  assert (select v #>> '{}' from t where k = 'read-reports') = '42501';
  assert (select v ->> 'error' from t where k = 'report-self') = 'self';
  assert (select count(*) from public.reports) = 20;
  assert (select max(char_length(reason)) from public.reports) = 500;
end $$;

-- Invites are limited to 20 open ones per user (dan's first one is used).
select test.as_user(:'dan');
select public.social_create_invite() from generate_series(1, 20);
insert into t values ('invite-21', public.social_create_invite());
reset role;

-- Isolation and anon.
select test.as_user(:'dan');
insert into t values ('dan-rows', (select to_jsonb(count(*)) from public.friendships));
insert into t values ('dan-invites', (select to_jsonb(count(*)) from public.invites));
reset role;
select test.as_anon();
insert into t values ('anon', to_jsonb(test.error_of('select public.social_friends()')));
reset role;

do $$
begin
  assert (select v ->> 'error' from t where k = 'invite-21') = 'too_many_invites';
  assert (select v from t where k = 'dan-rows') = '0'::jsonb;
  assert (select v from t where k = 'dan-invites') = '21'::jsonb;
  assert (select v #>> '{}' from t where k = 'anon') = '42501';
end $$;

-- Account deletion: friendships, blocks and invites go; reports stay for
-- moderation with the user nulled (Q7).
delete from auth.users where id = :'ann';
do $$
declare
  a uuid := current_setting('t.ann')::uuid;
begin
  assert not exists (select 1 from public.friendships where a in (requester, addressee));
  assert not exists (select 1 from public.blocks where a in (blocker, blocked));
  assert not exists (select 1 from public.invites where inviter = a);
  assert (select count(*) from public.reports where reporter is null) = 20;
end $$;

rollback;
