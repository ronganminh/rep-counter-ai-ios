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

-- Checks the functions listed under [p_section] of a contract file: each
-- exists with exactly those parameter names, [p_role] may execute it, and
-- the roles in [p_denied] may not.
create or replace function test.check_contract(
  p_contract jsonb, p_section text, p_role text,
  p_denied text[] default array['anon'])
returns void language plpgsql as $$
declare
  f record;
  v_oid oid;
  v_args text[];
  v_sig text;
  v_denied text;
begin
  for f in select key, value from jsonb_each(p_contract -> p_section) loop
    select p.oid, coalesce(p.proargnames, '{}') into v_oid, v_args
      from pg_proc p
      where p.proname = f.key and p.pronamespace = 'public'::regnamespace;
    if v_oid is null then
      raise exception 'contract: missing function %', f.key;
    end if;
    if v_args <> array(select jsonb_array_elements_text(f.value -> 'params')) then
      raise exception 'contract: % has params %', f.key, v_args;
    end if;
    v_sig := v_oid::regprocedure::text;
    if not has_function_privilege(p_role, v_sig, 'execute') then
      raise exception 'contract: % cannot execute %', p_role, v_sig;
    end if;
    foreach v_denied in array p_denied loop
      if has_function_privilege(v_denied, v_sig, 'execute') then
        raise exception 'contract: % can execute %', v_denied, v_sig;
      end if;
    end loop;
  end loop;
end $$;

-- True when [p_obj] has exactly the keys of the contract object [p_shape].
create or replace function test.has_shape(p_obj jsonb, p_shape jsonb)
returns boolean language sql immutable as $$
  select array(select jsonb_object_keys(p_obj) order by 1)
       = array(select jsonb_object_keys(p_shape) order by 1)
$$;

grant execute on all functions in schema test
  to anon, authenticated, service_role;
