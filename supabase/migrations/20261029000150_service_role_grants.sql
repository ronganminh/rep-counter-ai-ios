-- delete-account deletes each USER_TABLES table with the service role
-- before deleting the auth user. profiles (20261026000000) relied on the
-- project's default grants for service_role; with "Automatically expose
-- new tables" OFF that is not guaranteed, so grant it explicitly, like every
-- later table does. Checked by supabase/tests/user_tables.test.sql.
grant select, insert, update, delete on public.profiles to service_role;
