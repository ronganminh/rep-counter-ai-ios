# 06 · Supabase schema proposal: sync, credits, XP, social, billing, push

Status: **ACCEPTED by the owner on 2026-10-29: all §10 answers (Q1–Q8) as proposed** (PRODUCT_DECISIONS BE-1, decision log L-D30). Work order set by the owner: sync → credits → XP → social → entitlements → push/inbox, which replaces the order in §9. Each section becomes its own migration + Edge Function PR with tests, applied to staging (`rvysencgtomkzwgdjaqh`) by the owner (`supabase db push --linked`); the SQL blocks below are the agreed starting point, and the migrations in `supabase/migrations/` are the source of truth once merged. The only live migration so far is `20261026000000_user_owned_tables.sql` (`profiles`).

Scope: the backend parts of the roadmap that are BLOCKED today (01_TASK_DEPENDENCIES §1): A-2 sync and guest merge, H-2 account-scope deletes, AI-1/AI-2 credits, G-1 XP and achievements, S-1/S-2 social, P-1/P-2 entitlements, NT-2 push and inbox.

## 1 · Conventions (from the existing migration, applied everywhere)

1. **Ownership.** Every user-owned row has `user_id uuid not null references auth.users (id) on delete cascade`. Account deletion (`functions/delete-account`) deletes the auth user; the cascade removes the rows. `USER_TABLES` in `functions/delete-account/index.ts` lists every table so the function can also delete explicitly before the user.
2. **RLS on every table**, explicit grants (the project has "auto-expose new tables" OFF and "automatic RLS" ON), `revoke all … from anon`, policies written with `(select auth.uid())` (evaluated once per statement).
3. **Two kinds of tables.**
   - *Client-owned* (workouts, plans, profile): the owner may `select / insert / update` their rows through PostgREST. No `delete` grant: deletions are tombstones (`deleted_at`) so they sync.
   - *Server-authoritative* (credits, XP, entitlements, race results, push sends): clients may only `select` their own rows. Writes happen in Edge Functions with the service role, or in `security definer` SQL functions that check `auth.uid()` themselves. A client can never grant itself credits, XP or Pro.
4. **Idempotency (D-09)** by unique keys, not by client promises: one workout per `(user_id, client_id)`, one AI charge per `(user_id, request_id)`, one XP award per `(user_id, source_type, source_id)`, one entitlement per `(platform, original_transaction_id)`. Retries become no-ops (`on conflict do nothing` / return the existing row).
5. **Timestamps.** `created_at` / `updated_at timestamptz default now()`, `updated_at` maintained by one shared trigger `set_updated_at()`. Clients send their own times as data (`started_at`, `client_updated_at`), never as the server clock.
6. **Sync cursor.** Client-owned tables get a `server_seq bigint` column set on every insert and update by a trigger from one shared sequence (`sync_seq`), so a pull can ask for "everything after N" across tables without clock skew.
7. **Privacy.** No camera frames, video, audio or raw landmarks are ever stored (unchanged from v1). Workout `raw` keeps the same JSON the app already stores locally; `rep_details` stays optional and can be stripped server-side if the owner prefers.

```sql
-- shared helpers (one migration)
create sequence if not exists public.sync_seq;
create or replace function public.set_updated_at() returns trigger
language plpgsql as $$ begin new.updated_at = now(); return new; end $$;
create or replace function public.bump_sync_seq() returns trigger
language plpgsql as $$ begin new.server_seq = nextval('public.sync_seq'); return new; end $$;
```

## 2 · Sync and guest merge (A-2) · delete scopes (H-2)

The app is local-first (F-3 SQLite `repcoach.db`: `workouts(id, client_id, started_at, raw)`; plans in `workout_plans_v1`). The server mirrors it; the phone stays usable offline and as a guest.

```sql
create table public.workouts (
  user_id uuid not null references auth.users (id) on delete cascade,
  client_id text not null check (char_length(client_id) between 1 and 80),
  started_at timestamptz not null,
  exercise_id text not null,
  reps int not null check (reps between 0 and 100000),
  duration_seconds int not null check (duration_seconds between 0 and 86400),
  manual boolean not null default false,       -- D-18
  partial boolean not null default false,
  raw jsonb not null,                           -- the app's WorkoutRecord JSON
  deleted_at timestamptz,                       -- tombstone (H-2 account scope)
  client_updated_at timestamptz not null,
  server_seq bigint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, client_id)
);
create index workouts_user_seq on public.workouts (user_id, server_seq);

create table public.plans (
  user_id uuid not null references auth.users (id) on delete cascade,
  plan_id text not null,
  doc jsonb not null,                           -- WorkoutPlan JSON incl. sessions
  deleted_at timestamptz,
  client_updated_at timestamptz not null,
  server_seq bigint not null default 0,
  updated_at timestamptz not null default now(),
  primary key (user_id, plan_id)
);
-- + RLS: select/insert/update where (select auth.uid()) = user_id; no delete.
-- + triggers set_updated_at, bump_sync_seq on both.
```

**Protocol** (Edge Function `sync`, or plain PostgREST if the owner prefers fewer functions):
- *Push:* `upsert … on conflict (user_id, client_id) do update … where excluded.client_updated_at > workouts.client_updated_at` (last writer by client time wins; a workout's counted reps never change after save, only AI feedback, partial→saved, or a tombstone).
- *Pull:* `select … where user_id = auth.uid() and server_seq > :cursor order by server_seq limit 500`; the client stores the highest `server_seq`.
- *Tombstones:* deleting "on this account" sets `deleted_at`; other devices remove the row locally on pull. Tombstones older than 90 days can be purged by a scheduled job (owner to confirm the window).

**Guest → account merge (A-2, `/auth/merge`):** done on the client as a dry run first: upload nothing, pull the account's `client_id`s, show "N workouts from this phone, M already in the account, 0 conflicts" (same `client_id` = same workout, never duplicated). On confirm, push the guest rows. Plans: if both sides have an active plan, the user picks one (the other is archived, never deleted).

**Delete scopes (D-20, H-2):** *this phone* = local delete only (exists today); *this account* = tombstone on the server, kept on the phone if the user chose "account only"; *both* = both. Deleting the account is separate (`delete-account`, already built).

## 3 · AI credits (AI-1, AI-2) · D-07, D-08, D-09

Basic post-workout feedback stays free (D-07). Coach chat, advanced analysis and progress reviews consume credits.

```sql
create type public.credit_kind as enum
  ('weekly_allowance', 'consume', 'refund', 'rewarded_ad', 'admin_adjust');

create table public.ai_credit_ledger (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  kind public.credit_kind not null,
  amount int not null,                          -- + grant, - consume
  request_id text,                              -- set for consume/refund
  week_start date,                              -- set for weekly_allowance
  created_at timestamptz not null default now(),
  unique (user_id, request_id, kind),           -- D-09: one charge per request
  unique (user_id, week_start, kind)            -- one allowance per week
);
create view public.ai_credit_balance with (security_invoker = true) as
  select user_id, sum(amount)::int as balance from public.ai_credit_ledger group by user_id;
-- RLS: owner select only. No client insert/update/delete grants.
```

**Edge Function `ai-request`** (replaces the anonymous proxy for paid kinds; the existing `backend/server.py` GroqCloud path stays for free feedback until migrated):
1. Verify the JWT; read entitlement (§6) → weekly allowance **10 Free / 60 Pro** (D-08, values not final).
2. In one transaction: grant the week's allowance if missing; insert `consume` (−1) for `request_id` (conflict → return the earlier answer, no second charge); fail with `402 insufficient_credits` if the balance would go below 0.
3. Call the AI provider. On provider failure insert `refund` (+1) for the same `request_id`.
4. Store nothing of the conversation unless the user opted in (D-21); the response goes back to the client.

Rewarded ads (Android only, cap 3/day, D-08) insert `rewarded_ad` only after the ad network's server-side verification callback, never from the client.

## 4 · XP, levels, achievements (G-1) · D-05, D-09, D-18

```sql
create table public.xp_events (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  source_type text not null,                    -- 'workout', 'plan_week', 'achievement', 'challenge'
  source_id text not null,                      -- e.g. workouts.client_id
  amount int not null check (amount between -10000 and 10000),
  reason text,
  created_at timestamptz not null default now(),
  unique (user_id, source_type, source_id)      -- D-09
);
create table public.user_progress (
  user_id uuid primary key references auth.users (id) on delete cascade,
  xp_total int not null default 0,
  level int not null default 1,
  updated_at timestamptz not null default now()
);
create table public.achievements_unlocked (
  user_id uuid not null references auth.users (id) on delete cascade,
  achievement_id text not null,
  unlocked_at timestamptz not null default now(),
  primary key (user_id, achievement_id)
);
-- RLS: owner select only; writes by the award function.
```

**Award rules** run server-side in `award-xp` (called by the sync push, not by the client): XP is computed from the stored workout, so a modified client cannot inflate it. Deleting a workout does **not** revoke XP or achievements (D-05); the server may correct fraudulent or duplicate awards with a negative `admin_adjust`-style event. Reopening a notification never awards XP (D-09). **Decision needed:** do manual and guided-timer workouts earn XP? D-18 excludes them from challenges, races and leaderboards but says nothing about XP; this proposal awards them XP at a reduced rate and never counts them for challenges.

## 5 · Social (S-1, S-2)

```sql
create table public.friendships (
  requester uuid not null references auth.users (id) on delete cascade,
  addressee uuid not null references auth.users (id) on delete cascade,
  status text not null check (status in ('pending', 'accepted')),
  created_at timestamptz not null default now(),
  primary key (requester, addressee),
  check (requester <> addressee)
);
create table public.blocks (
  blocker uuid not null references auth.users (id) on delete cascade,
  blocked uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker, blocked)
);
create table public.reports (
  id bigint generated always as identity primary key,
  reporter uuid references auth.users (id) on delete set null,
  reported uuid references auth.users (id) on delete set null,
  reason text not null check (char_length(reason) <= 500),
  created_at timestamptz not null default now()
);
create table public.invites (
  code text primary key,                        -- short random code for links
  inviter uuid not null references auth.users (id) on delete cascade,
  expires_at timestamptz not null,
  used_by uuid references auth.users (id) on delete set null
);
create table public.races (
  id uuid primary key default gen_random_uuid(),
  exercise_id text not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  created_by uuid not null references auth.users (id) on delete cascade
);
create table public.race_entries (
  race_id uuid not null references public.races (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  workout_client_id text,                       -- the camera workout that counts
  reps int,                                     -- copied server-side, never from the client
  primary key (race_id, user_id)
);
```

RLS: a friendship row is visible to its two users; a block is visible only to the blocker; reports are insert-only for the reporter and readable by nobody but the service role; race rows are visible to participants. A blocked user can't see or invite the blocker (checked in the policies with `not exists (select 1 from blocks …)`). **Leaderboards** are a `security definer` function returning `display_name, reps` for friends only, never emails or ids of non-friends. Race results are server-authoritative (D-05) and only count camera workouts (D-18): `race_entries.reps` is copied from `workouts` by the server, `manual = false` only.

Owner decisions: report review process and retention (legal), whether profiles are discoverable by display name, age rating impact (RELEASE_CHECKLIST R-21).

## 6 · Entitlements and billing (P-1, P-2) · D-10, D-13

```sql
create table public.entitlements (
  user_id uuid not null references auth.users (id) on delete cascade,
  platform text not null check (platform in ('app_store', 'play')),
  product_id text not null,
  original_transaction_id text not null,
  status text not null check (status in
    ('active', 'grace', 'billing_retry', 'expired', 'revoked', 'pending')),
  expires_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key (platform, original_transaction_id)
);
create table public.store_events (                -- raw notifications, service role only
  id bigint generated always as identity primary key,
  platform text not null,
  payload jsonb not null,
  received_at timestamptz not null default now()
);
-- RLS: entitlements owner select only; store_events no grants at all.
```

Edge Functions: **`verify-purchase`** (client sends the StoreKit 2 signed transaction / Play purchase token; the function verifies with the App Store Server API / Google Play Developer API and upserts `entitlements`), **`store-webhook`** (App Store Server Notifications v2 and Play RTDN via Pub/Sub push; updates status: renewals, grace, refunds → `revoked`). Pro only after server verification (D-10); pending (Ask to Buy) and failures stay Free. The app may cache Pro offline for ≤ 7 days (D-08). Secrets (App Store Connect API key, Play service account) live only in Edge Function secrets. **Blocked on:** D-13/D-14 prices, product IDs, trial terms, store agreements.

## 7 · Push and inbox (NT-2) · D-19

```sql
create table public.push_tokens (
  user_id uuid not null references auth.users (id) on delete cascade,
  token text not null,
  platform text not null check (platform in ('apns', 'fcm')),
  updated_at timestamptz not null default now(),
  primary key (user_id, token)
);
create table public.inbox_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  kind text not null,                           -- 'friend_request', 'race', 'invite', 'billing'
  link text not null check (link like 'repcoach://%'),   -- N-2a router input
  title text not null,
  body text,
  read_at timestamptz,
  created_at timestamptz not null default now()
);
-- RLS: push_tokens owner insert/update/delete own tokens; inbox owner select + update(read_at).
```

`send-push` (service role) writes the inbox row first, then sends via APNs (token-based .p8) / FCM v1; payloads carry only the `repcoach://` link and a short title, never personal data. The app holds pushes during a live workout (D-19; N-2a already holds links). Local reminders (NT-1) stay local and need none of this. **Blocked on:** APNs key and FCM project.

## 8 · Account deletion

`delete-account` already removes the auth user (cascade) after revoking Sign in with Apple. Each table above is added to `USER_TABLES` in the same PR that creates it. `reports.reporter/reported` use `on delete set null` so a report survives the account for moderation (owner/legal to confirm). `store_events` keep only platform payloads, which may contain transaction ids; retention to be set with legal.

## 9 · Order of work once approved (superseded by the owner's order in the status line)

1. Shared helpers + `workouts` + `plans` + sync function, behind `ENABLE_ACCOUNTS` (A-2, H-2).
2. `user_progress` / `xp_events` / `achievements_unlocked` + `award-xp` (G-1).
3. Credits ledger + `ai-request` (AI-1), then coach UI (AI-2).
4. Entitlements + `verify-purchase` + `store-webhook` (P-1) once D-13/D-14 are decided.
5. Social tables + leaderboard function (S-1, S-2).
6. Push tokens + inbox + `send-push` (NT-2).

Each step: migration with RLS tests (pgTAP or the Supabase CLI test runner), Deno tests for the function, client repository behind its flag, and the existing in-memory fakes kept for widget tests.

## 10 · Decisions (all accepted by the owner, 2026-10-29)

| # | Question | Proposal |
|---|---|---|
| Q1 | Approve the conventions in §1 (tombstones instead of deletes, server-authoritative tables, `server_seq` cursor) | Yes |
| Q2 | Store `rep_details` in the cloud copy of a workout? | Keep (needed for history detail); can be stripped |
| Q3 | Tombstone retention | 90 days |
| Q4 | XP for manual / guided-timer workouts | Yes, reduced; never for challenges/races |
| Q5 | D-08 weekly AI allowance values | 10 Free / 60 Pro (placeholder) |
| Q6 | Profile discoverability by display name | Off; friends via invite link only |
| Q7 | Report retention and moderation owner | Legal to decide |
| Q8 | Production project region and when to create it | Same region as staging (Tokyo), after staging sign-off |
