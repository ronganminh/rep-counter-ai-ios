-- The parts of a Supabase database the migrations rely on, for running them
-- on a plain Postgres 16 in tests (supabase/tests/run.sh). Not a migration:
-- never applied to a real project, where these objects already exist.
--
-- Mirrors the staging settings: no automatic grants on new tables
-- ("Automatically expose new tables" OFF), service_role bypasses RLS.

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin noinherit bypassrls;
  end if;
end $$;

grant usage on schema public to anon, authenticated, service_role;

create schema if not exists auth;
grant usage on schema auth to anon, authenticated, service_role;

create table if not exists auth.users (
  id uuid primary key default gen_random_uuid(),
  email text,
  created_at timestamptz not null default now()
);

-- Same contract as Supabase: the caller's id from the JWT claims PostgREST
-- sets for the request, null for anon or the service role.
create or replace function auth.uid() returns uuid
language sql stable as $$
  select nullif(
    coalesce(
      nullif(current_setting('request.jwt.claim.sub', true), ''),
      nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub'
    ), '')::uuid
$$;

create or replace function auth.role() returns text
language sql stable as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.role', true), ''),
    nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role'
  )
$$;

grant execute on function auth.uid(), auth.role()
  to anon, authenticated, service_role;

-- Test helpers (only in this stub): act as a user, as anon, or as the
-- service role for the rest of the transaction.
create schema if not exists test;

create or replace function test.new_user(p_email text default null)
returns uuid language sql as $$
  insert into auth.users (email) values (p_email) returning id
$$;

create or replace function test.as_user(p_user uuid) returns void
language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end $$;

create or replace function test.as_anon() returns void
language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
  execute 'set local role anon';
end $$;

create or replace function test.as_service() returns void
language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '{"role":"service_role"}', true);
  execute 'set local role service_role';
end $$;

-- Runs [sql] and returns the SQLSTATE it failed with, or null if it ran.
create or replace function test.error_of(p_sql text) returns text
language plpgsql as $$
begin
  execute p_sql;
  return null;
exception when others then
  return sqlstate;
end $$;

grant usage on schema test to anon, authenticated, service_role;
grant execute on all functions in schema test
  to anon, authenticated, service_role;
