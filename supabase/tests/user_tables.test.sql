-- Every table that holds a user's rows (a column referencing auth.users)
-- has RLS on, is hidden from anon, cascades or nulls on account deletion,
-- and is listed in delete-account's USER_TABLES so the function can delete
-- it with the service role (which needs the delete grant).
\set ON_ERROR_STOP 1
begin;

\set delete_account `cat "$FUNCTIONS_DIR/delete-account/index.ts"`
select set_config('t.index', :'delete_account', false);

do $$
declare
  v_listed text[] := array(
    select m[1] from regexp_matches(
      substring(current_setting('t.index')
        from 'USER_TABLES = \[([^\]]*)\]'), '"([a-z_]+)"', 'g') m);
  r record;
begin
  assert cardinality(v_listed) > 0, 'USER_TABLES not found';
  for r in
    select distinct c.conrelid::regclass::text as tbl, c.conrelid,
      c.confdeltype, a.attname
    from pg_constraint c
    join pg_attribute a on a.attrelid = c.conrelid and a.attnum = any(c.conkey)
    where c.contype = 'f' and c.confrelid = 'auth.users'::regclass
      and c.connamespace = 'public'::regnamespace
  loop
    assert (select relrowsecurity from pg_class where oid = r.conrelid),
      format('%s: RLS off', r.tbl);
    assert not has_table_privilege('anon', r.conrelid, 'select'),
      format('%s: anon can read', r.tbl);
    assert r.confdeltype in ('c', 'n'),
      format('%s.%s: no cascade / set null on account deletion', r.tbl, r.attname);
    -- Tables keyed by user_id are deleted explicitly by delete-account.
    if r.attname = 'user_id' then
      assert replace(r.tbl, 'public.', '') = any(v_listed),
        format('%s missing from USER_TABLES', r.tbl);
      assert has_table_privilege('service_role', r.conrelid, 'delete'),
        format('%s: service_role cannot delete', r.tbl);
    end if;
  end loop;
  -- And nothing listed is missing from the database.
  assert (select bool_and(to_regclass('public.' || t) is not null)
          from unnest(v_listed) t), 'USER_TABLES names a missing table';
end $$;

rollback;
