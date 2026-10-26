-- D-12: first user-owned table and the convention every later one follows
-- (A-2 sync, AI credits, XP). Account deletion (functions/delete-account)
-- removes the auth user; ON DELETE CASCADE removes these rows with it.
--
-- The staging project has "Automatically expose new tables" OFF and
-- "Enable automatic RLS" ON, so grants and policies are explicit here.

create table if not exists public.profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  display_name text check (char_length(display_name) <= 80),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

grant select, insert, update on public.profiles to authenticated;
revoke all on public.profiles from anon;

create policy "profiles: owner can read"
  on public.profiles for select to authenticated
  using ((select auth.uid()) = user_id);

create policy "profiles: owner can insert"
  on public.profiles for insert to authenticated
  with check ((select auth.uid()) = user_id);

create policy "profiles: owner can update"
  on public.profiles for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- No delete policy: rows go away only with the account (cascade) or via the
-- service role in delete-account.

-- Template for later user-owned tables (keep in sync with USER_TABLES in
-- functions/delete-account/index.ts):
--   user_id uuid not null references auth.users (id) on delete cascade,
--   + enable row level security, explicit grants to authenticated,
--   + policies with (select auth.uid()) = user_id.
