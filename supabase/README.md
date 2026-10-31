# Supabase (D-12)

Staging project: `rvysencgtomkzwgdjaqh` (Tokyo). No production project yet.

| Path                         | What                                                                                                                                                                                                                                                                                                                                                    |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `functions/ai-request/`      | Credited AI (coach chat, advanced analysis, progress review): verify JWT → charge one credit per `request_id` → GroqCloud → refund on provider failure. Stores and logs no conversation (D-21). Free post-workout feedback stays on the existing backend (D-07).                                                                                        |
| `functions/verify-purchase/` | P-1: JWT → product id allowed (`STORE_PRODUCT_IDS`) → state read from the App Store Server API / Play Developer API with our credentials → account check (appAccountToken / obfuscatedExternalAccountId = user id) → `entitlement_record` → Play acknowledge. 503 until product ids exist (D-14).                                                       |
| `functions/store-webhook/`   | P-1: App Store Server Notifications v2 + Play RTDN (Pub/Sub push), `?secret=` required; stores the raw event, re-reads the purchase from the store, updates the known entitlement. Deployed with `--no-verify-jwt`.                                                                                                                                     |
| `functions/_shared/`         | `jwt.ts` (ES256 / RS256), `stores.ts` (Apple / Google APIs), `store_config.ts` (secrets), `assert.ts` + `test_helpers.ts` (tests only).                                                                                                                                                                                                                 |
| `functions/delete-account/`  | Account deletion (App Store 5.1.1(v)): verify JWT → revoke Sign in with Apple (if the app sent an authorization code) → delete the user's rows → `auth.admin.deleteUser`. `handler.ts` holds the logic, `apple.ts` the Apple revocation, `index.ts` the wiring.                                                                                         |
| `migrations/`                | User-owned tables: `user_id … references auth.users on delete cascade`, RLS on, explicit grants (the project does not auto-expose tables). Schema agreed in `docs/implementation/06_SUPABASE_SCHEMA_PROPOSAL.md` (owner decision L-D30).                                                                                                                |
| `contracts/`                 | Request/response shapes of the SQL functions and Edge Functions the app calls. Checked by the SQL tests against the database and by the Flutter tests against the client adapters.                                                                                                                                                                      |
| `tests/`                     | `run.sh` applies every migration to a fresh plain Postgres with `supabase_stub.sql` (roles, `auth.users`, `auth.uid()`) and runs `*.test.sql` (RLS, grants, idempotency, contracts; `user_tables.test.sql` checks that every table holding user rows has RLS, cascades, is in `delete-account`'s `USER_TABLES` and can be deleted by the service role). |

### Migrations

| File                                     | Group            | What                                                                                                                                                                                                                                                                                                                                 |
| ---------------------------------------- | ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `20261026000000_user_owned_tables.sql`   | D-12             | `profiles`                                                                                                                                                                                                                                                                                                                           |
| `20261029000100_sync_workouts_plans.sql` | A-2 sync, H-2    | `workouts`, `plans` (tombstones, `server_seq`); RPCs `sync_push_workouts`, `sync_pull_workouts`, `sync_workout_client_ids`, `sync_push_plans`, `sync_pull_plans`; `purge_sync_tombstones()` (service role, 90 days)                                                                                                                  |
| `20261029000150_service_role_grants.sql` | D-12 fix         | explicit `service_role` grants on `profiles`, so `delete-account` can delete it whatever the project's default grants                                                                                                                                                                                                                |
| `20261029000200_ai_credits.sql`          | AI-1 credits     | `ai_credit_ledger` (append-only), view `ai_credit_balance`; `ai_credit_balance()` for the app; `ai_credit_consume` / `ai_credit_refund` for `ai-request` only (service role). Weekly top-up to 10 Free / 60 Pro (Q5 placeholders), Pro read from `ai_credit_is_pro` (false until P-1)                                                |
| `20261029000300_xp.sql`                  | G-1 XP           | `xp_events` (one per user + source, D-09), `user_progress`, `achievements_unlocked`; a trigger on `workouts` awards XP from the synced row (manual = half, Q4; tombstones nothing; no revoke on delete, D-05) instead of a separate `award-xp` function; `xp_progress()` for the app; `xp_correct()` (service role, negative only)   |
| `20261029000400_social.sql`              | S-1 social       | `friendships`, `blocks`, `reports` (service role only, kept with ids nulled on account deletion, Q7), `invites` (7 days, 20 open per user); `social_*` functions for invite / respond / state / block / report / friends; `social_leaderboard` (me + friends, camera workouts only, D-18). No search by name (Q6). Races (S-2) later |
| `20261029000500_entitlements.sql`        | P-1 entitlements | `entitlements` (one per store purchase, first account keeps it), `store_events` (raw notifications, service role only); `entitlement_current()` for the app; `entitlement_record` / `entitlement_update_from_store` for the functions; `ai_credit_is_pro` now reads entitlements (Pro → 60 credits)                                  |
| `20261029000600_push_inbox.sql`          | NT-2 push/inbox  | `push_tokens` (a token follows the signed-in account), `inbox_items` (`repcoach://` links only); `push_register_token` / `push_unregister_token` / `inbox_list` / `inbox_mark_read` for the app; `inbox_create` / `push_drop_token` for `send-push`                                                                                  |
| `20261031000100_achievements.sql`        | G-1 achievements | `achievements_unlocked` gets a writer: a trigger on `workouts` unlocks the app's six achievements from live synced workouts (UTC days), never revoked (D-05); `achievements_list()` for the app; one-time backfill. **Not on staging yet: `supabase db push --linked`**                                                              |

## Tests

```
deno test --no-remote supabase/functions/
PGHOST=… PGUSER=postgres supabase/tests/run.sh     # any Postgres 16 you can create databases on
```

CI runs both in `.github/workflows/supabase-functions.yml` (the SQL tests
against a `postgres:16` service). The function tests use generated keys and a
mocked `fetch`; the SQL tests use a stub of the Supabase roles and `auth`
schema. No network calls, no Supabase project, no secrets.

## Staging status (deployed by the owner on 2026-10-31)

The agent has no Supabase access token and deploys nothing; this is what the
owner reported.

| Part                               | State on `rvysencgtomkzwgdjaqh`                                                                                        |
| ---------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| Migrations                         | ✅ 8/8 applied, `supabase migration list` Local == Remote (`20261026000000` … `20261029000600`)                        |
| `delete-account`                   | ✅ ACTIVE v1, JWT verification ON; secrets `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_CLIENT_ID`, `APPLE_PRIVATE_KEY` set |
| `ai-request`                       | ✅ ACTIVE v1, JWT verification ON; secrets `GROQ_API_KEY`, `GROQ_MODEL` set                                            |
| `verify-purchase`, `store-webhook` | ⏸ not deployed: waits for prices and product ids (D-14), the App Store IAP key and the Play service account            |
| `send-push`                        | ⏸ not deployed: waits for the APNs key and the Firebase project (06 §7)                                                |
| Tombstone purge (cron)             | ⏳ the owner runs the SQL under **A-2 sync** below once in the SQL editor                                              |
| Smoke test without a session       | ✅ `ai-request` → 401, `delete-account` → 401 (`UNAUTHORIZED_INVALID_JWT_FORMAT`, from the gateway)                    |
| Signed-in flow                     | ⏳ `test/staging/staging_backend_test.dart` (below), run by the owner with a throwaway account                         |

The inbox works with the migration alone (no `send-push` needed): the app reads
`inbox_list`; items are written by `send-push` later or from the SQL editor
(`select public.inbox_create('<user uuid>', 'system', 'repcoach://inbox',
'Hello', null);`).

### Integration test on staging (owner, on your machine)

The app's own Supabase adapters against the real project: sign up → sign in →
sync push / pull / tombstone → XP awarded from the synced workout → `ai-request`
with the JWT (one credit, never twice for the same request id) →
`delete-account`. It is skipped when the variables are missing, so CI and
`flutter test` never call staging.

```bash
cd rep-counter-ai-main/rep_counter_app
export SUPABASE_URL=https://rvysencgtomkzwgdjaqh.supabase.co
export SUPABASE_ANON_KEY='<staging publishable key>'      # the public key, never the service role
export STAGING_TEST_EMAIL='<you>+rcit1@gmail.com'          # must contain +rcit: the run deletes it
export STAGING_TEST_PASSWORD='<at least 10 characters>'
flutter test test/staging/staging_backend_test.dart --reporter expanded
```

"Confirm email" is ON, so the first run signs up and stops at step 1 with
"Confirm the email sent to …". Open the Supabase email on any device (the link
may try to open the app; the account is confirmed either way), then run the same
command again: steps 2–5 run and the account is deleted at the end. Use a new
`+rcitN` address for each later run. It costs one AI credit and one Groq call
per run.

## Deploy to staging (owner, on your machine)

Commands for the first deploy and for later groups. The token comes from
`supabase login`, and is never stored in this repo.

```bash
# 0. Supabase CLI ≥ 2.x  (brew install supabase/tap/supabase  or  npm i -g supabase)
supabase login                                   # opens the browser; stores your personal token locally
cd <repo root>                                   # the folder that contains supabase/
supabase link --project-ref rvysencgtomkzwgdjaqh # asks for the database password

# 1. Apple secrets for token revocation. The .p8 stays outside the repo.
supabase secrets set --project-ref rvysencgtomkzwgdjaqh \
  APPLE_TEAM_ID=NW22NWLTK4 \
  APPLE_KEY_ID=ANA4NT26KP \
  APPLE_CLIENT_ID=com.ronganminh.repCounterApp \
  APPLE_PRIVATE_KEY="$(cat ~/secure/AuthKey_ANA4NT26KP.p8)"
#    SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are injected by Supabase; do not set them.

# 2. Schema (profiles + RLS). Review the SQL first; this changes the staging database.
supabase db push --linked

# 3. The function. JWT verification stays ON (default): only signed-in users can call it.
supabase functions deploy delete-account --project-ref rvysencgtomkzwgdjaqh

# 4. Check
supabase functions list --project-ref rvysencgtomkzwgdjaqh
supabase secrets list   --project-ref rvysencgtomkzwgdjaqh   # names only, values are hidden
```

### Backend groups (06, applied in order)

Each group adds a migration (and Edge Functions where it has them). After
pulling a new group, review the SQL, then:

```bash
supabase db push --linked --dry-run   # lists the migrations that would run
supabase db push --linked             # applies them to staging
```

**A-2 sync** (`20261029000100_sync_workouts_plans.sql`, no Edge Function):
nothing to set. Schedule the 90-day tombstone purge (Q3) once, in the SQL
editor. Enable `pg_cron` first (Database › Extensions › pg_cron), or run the
first line:

```sql
create extension if not exists pg_cron with schema pg_catalog;

-- Every day at 03:17 UTC. Scheduling the same name again replaces the job.
select cron.schedule(
  'purge-sync-tombstones',
  '17 3 * * *',
  $$select public.purge_sync_tombstones()$$
);

-- Check: the job, then its runs after 03:17 UTC.
select jobid, jobname, schedule, command, active
  from cron.job where jobname = 'purge-sync-tombstones';
select status, return_message, start_time
  from cron.job_run_details
 where jobid = (select jobid from cron.job where jobname = 'purge-sync-tombstones')
 order by start_time desc limit 5;

-- Run once by hand (returns how many tombstones were removed; 0 on a new project).
select public.purge_sync_tombstones();

-- To stop it: select cron.unschedule('purge-sync-tombstones');
```

`purge_sync_tombstones(p_older_than interval default '90 days')` deletes
workouts and plans whose `deleted_at` is older than that. The app cannot call it
(no grant to `anon` / `authenticated`); the job runs as the `postgres` user that
scheduled it.

Check: `select public.sync_pull_workouts(0, 10);` in the SQL editor fails with
`not_authenticated` (no user), which is expected; the app calls it with the
user's JWT. The client stays off until a build sets
`--dart-define=ENABLE_ACCOUNTS=true --dart-define=ENABLE_CLOUD_SYNC=true`.

**AI-1 credits** (`20261029000200_ai_credits.sql` + `functions/ai-request`). The
Groq key is the same kind of key the feedback backend uses; set it only here,
never in the app:

```bash
supabase secrets set --project-ref rvysencgtomkzwgdjaqh GROQ_API_KEY=<your Groq key>
# optional, default openai/gpt-oss-20b (as backend/ai_provider.py)
supabase secrets set --project-ref rvysencgtomkzwgdjaqh GROQ_MODEL=openai/gpt-oss-20b
supabase functions deploy ai-request --project-ref rvysencgtomkzwgdjaqh   # JWT verification ON
```

Without `GROQ_API_KEY` the function answers `503 not_configured` and charges
nothing. Smoke test: expect `401`. With JWT verification ON the gateway answers
first (`{"code":"UNAUTHORIZED_INVALID_JWT_FORMAT",…}` for this token), so the
function's own `{"error":"unauthorized"}` only appears for a well-formed but
invalid JWT. Both are 401, and the app treats them the same:

```bash
curl -i -X POST https://rvysencgtomkzwgdjaqh.supabase.co/functions/v1/ai-request \
  -H "Authorization: Bearer invalid"
```

**G-1 XP** (`20261029000300_xp.sql`, no Edge Function): nothing to set. XP is
awarded inside the database when a workout syncs. To correct a bad award from
the SQL editor:
`select public.xp_correct('<user uuid>', '<workout client_id>', 30, 'duplicate');`

**S-1 social** (`20261029000400_social.sql`, no Edge Function): nothing to set.
The leaderboard is a SQL function (`security definer`), so no `leaderboard` Edge
Function is needed. Reports are read only from the dashboard (service role):
`select * from public.reports order by created_at desc;`

**P-1 entitlements** (`20261029000500_entitlements.sql` +
`functions/verify-purchase` + `functions/store-webhook`). **Billing stays off**
until prices and product ids are decided (D-14). Applying the migration is safe
now; the functions answer `503 not_configured` and record nothing while
`STORE_PRODUCT_IDS` is unset. When D-14 is decided:

```bash
# App Store Connect › Users and Access › Integrations › In-App Purchase: a key (.p8), its Key ID, the Issuer ID.
supabase secrets set --project-ref rvysencgtomkzwgdjaqh \
  APPSTORE_ISSUER_ID=<issuer id> APPSTORE_KEY_ID=<key id> \
  APPSTORE_PRIVATE_KEY="$(cat ~/secure/SubscriptionKey_<key id>.p8)"
# Google Cloud service account with access to the app in Play Console (financial data, manage orders).
supabase secrets set --project-ref rvysencgtomkzwgdjaqh \
  PLAY_SERVICE_ACCOUNT_JSON="$(cat ~/secure/play-service-account.json)"
supabase secrets set --project-ref rvysencgtomkzwgdjaqh \
  STORE_WEBHOOK_SECRET="$(openssl rand -hex 24)" \
  STORE_PRODUCT_IDS=<monthly id>,<annual id>
#   APPSTORE_BUNDLE_ID (default com.ronganminh.repCounterApp) and
#   PLAY_PACKAGE_NAME (default com.ronganminh.repcoach) only if they differ.
supabase functions deploy verify-purchase --project-ref rvysencgtomkzwgdjaqh
supabase functions deploy store-webhook --no-verify-jwt --project-ref rvysencgtomkzwgdjaqh
```

Then point the stores at
`https://rvysencgtomkzwgdjaqh.supabase.co/functions/v1/store-webhook?secret=<STORE_WEBHOOK_SECRET>`:
App Store Connect › App › App Information › App Store Server Notifications
(Version 2, sandbox and production), and a Pub/Sub push subscription on the Play
RTDN topic. The app must set `appAccountToken` (StoreKit) /
`obfuscatedExternalAccountId` (Play Billing) to the user's id at purchase.

**NT-2 push and inbox** (`20261029000600_push_inbox.sql` +
`functions/send-push`). The inbox works with the migration alone; pushes need
the APNs key and the Firebase project (06 §7, still open):

```bash
supabase secrets set --project-ref rvysencgtomkzwgdjaqh \
  PUSH_SEND_SECRET="$(openssl rand -hex 24)"
# Apple Developer › Keys: a key with Apple Push Notifications service (.p8).
supabase secrets set --project-ref rvysencgtomkzwgdjaqh \
  APNS_TEAM_ID=NW22NWLTK4 APNS_KEY_ID=<key id> \
  APNS_PRIVATE_KEY="$(cat ~/secure/AuthKey_<key id>.p8)" APNS_ENV=sandbox
#   APNS_ENV=production for TestFlight / App Store builds.
# Firebase console › Project settings › Service accounts › Generate key.
supabase secrets set --project-ref rvysencgtomkzwgdjaqh \
  FCM_SERVICE_ACCOUNT_JSON="$(cat ~/secure/firebase-service-account.json)"
supabase functions deploy send-push --no-verify-jwt --project-ref rvysencgtomkzwgdjaqh
```

Test (writes one inbox item for that user):

```bash
curl -X POST https://rvysencgtomkzwgdjaqh.supabase.co/functions/v1/send-push \
  -H "x-push-secret: <PUSH_SEND_SECRET>" -H "content-type: application/json" \
  -d '{"user_id":"<user uuid>","kind":"system","link":"repcoach://inbox","title":"Hello"}'
```

**Smoke test on staging, without deleting a real user.** Expect `401`
(`UNAUTHORIZED_INVALID_JWT_FORMAT` from the gateway, as for `ai-request`):

```bash
curl -i -X POST https://rvysencgtomkzwgdjaqh.supabase.co/functions/v1/delete-account \
  -H "Authorization: Bearer invalid"
```

**Full test:** the integration test above (step 5), or device step D9 in
`docs/implementation/05_SUPABASE_SETUP.md` §11 with a throwaway account. Then
check in the dashboard:

- the user is gone from Authentication › Users;
- the `profiles` row is gone;
- for an Apple account, the function log shows
  `{"event":"apple_revoke","ok":true}`, and the app disappears from Settings ›
  Apple ID › Sign in with Apple on the iPhone.

## Production

Not created yet. When it is, repeat the steps with the production project ref
and its own secrets, after an explicit owner approval.
