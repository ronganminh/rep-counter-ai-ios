# 04 · Auth backend options (D-12)

Status: **proposal, owner decision needed.** Nothing here is configured. No endpoint, OAuth client ID, Apple key or entitlement has been created or committed.

Owner decision D-12 (2026-10-23): sign-in with **Apple + Google + email/password accounts**.

The client side is built behind `ENABLE_ACCOUNTS` (default off; PRs A-1a/A-1b, decision log L-D03):
- an `AuthRepository` interface;
- a Guest / SignedIn / Expired state machine;
- the Phase 9 screens.

This document picks what sits behind `AuthRepository`.

## Current state (facts from the repo)

- **Backend** (`rep-counter-ai-main/backend`):
  - one Python process on the standard-library `http.server`, behind nginx on a single VM (`deploy/repcoach-backend.service`, `repcoach-ai.nginx`), at `repcoach-ai.duckdns.org`;
  - it has **no database and no user concept**;
  - it only serves `POST /v1/workout-feedback` and static legal pages.
- **App identifiers:**
  - iOS bundle ID `com.ronganminh.repCounterApp`;
  - Android `applicationId` `com.ronganminh.repcoach`;
  - no iOS entitlements file yet.
- **Local data:** workouts are local (SQLite since F-3) with a stable UUID `client_id` per workout. A later merge (A-2) uses that ID.
- **What else needs a server later:**
  - A-2 sync, AI credits (AI-1), XP/achievements (G-1), friends (S-1) and purchase verification (P-1) all need a user ID and a database;
  - the auth choice is therefore also a data-platform choice.

## Requirements any option must meet

1. **Sign in with Apple** on iOS. App Store guideline 4.8: an app that offers Google sign-in must also offer an equivalent privacy-focused option. Apple counts as one.
2. **Google sign-in** on iOS and Android, using the native SDK flows.
3. **Email/password**, with:
   - email verification;
   - password reset;
   - rate limiting / lockout (the copy says "paused … about 15 minutes");
   - a check against leaked passwords, which the sign-up copy promises: "Checked against leaked passwords when you submit".
4. **Account deletion inside the app** (App Store guideline 5.1.1(v)). It must also revoke Sign in with Apple tokens through Apple's REST API, and Google Play needs a web URL where users can request deletion. Deleting the account must also delete server data (sync, credits, XP).
5. **Session handling.** Tokens are stored in the platform keychain/keystore, and refresh is automatic. A rejected refresh maps to `AuthSession.expired`, so the app shows "Your session expired", keeps local workouts and keeps training.
6. **The Python AI backend can verify the user,** so AI credits can be per account. In practice that means verifying a JWT against published keys (JWKS), with no shared secret in the app.
7. **No secrets in the app or in git.** Client IDs are public identifiers but still go through `--dart-define` / build config. Server keys (Apple `.p8`, service-role keys) live only on the server.

## Options

### A. Extend the Python backend with its own accounts and database

What it takes:
- add a database (PostgreSQL or SQLite) to the VM, with backups;
- password hashing (argon2/bcrypt);
- email verification and reset tokens;
- an SMTP/transactional mail provider;
- per-account and per-IP rate limiting;
- leaked-password checks (Have I Been Pwned k-anonymity API);
- Apple ID-token validation and token revocation;
- Google ID-token validation;
- JWT issuing and refresh rotation;
- account deletion;
- a web page for deletion requests;
- migrating off `http.server` to a framework.

| Criterion | Assessment |
|---|---|
| Cost | Lowest cash cost: the existing VM plus a mail provider (free tiers exist). The real cost is engineering and on-call time. |
| Effort | **Highest.** Several weeks to reach parity, plus ongoing security maintenance. Every item in "What it takes" is custom code. |
| Security | **Highest risk.** Credential storage, token handling and lockout are easy to get subtly wrong. There is one VM with no redundancy, and the backend currently has no DB backup story. |
| Apple / Google | Possible (validate ID tokens server-side; implement Apple revocation yourself). Native client packages still needed (`sign_in_with_apple`, `google_sign_in`). |
| Account deletion | Fully custom (DB rows, Apple revocation, web deletion page). |
| Lock-in | None. |

### B. Firebase Authentication (Google)

- **Client:** `firebase_core` + `firebase_auth`, plus `google_sign_in` / `sign_in_with_apple` for the native flows.
- **Data:** a DB would be Firestore (document store) or the existing backend.

| Criterion | Assessment |
|---|---|
| Cost | Free tier covers email/password and social sign-in for a large number of monthly active users; upgrading to Identity Platform adds features (blocking functions, MFA) with per-MAU pricing above a free allowance. **Verify current pricing at decision time.** |
| Effort | **Low** for auth: mature FlutterFire SDK, email verification and reset emails built in, ID tokens verifiable by the Python backend via Google's public keys (`firebase-admin` or plain JWKS). |
| Security | Managed credential storage, token refresh and abuse protection. Leaked-password check: confirm availability in the chosen tier (password policy is an Identity Platform feature). |
| Apple / Google | First-class. Apple sign-in is supported, including token revocation on account deletion (via the Apple authorization code). |
| Account deletion | `user.delete()` from the client (needs recent sign-in); server data deleted by the backend or a Cloud Function. Web deletion URL still needs a page. |
| Lock-in | High for auth (user export exists but password hashes use Firebase's scrypt variant). Firestore is a document store, which fits the relational merge/credits/XP model less well. |

### C. Supabase Auth (Supabase, open source, PostgreSQL)

- **Client:** `supabase_flutter`, using native ID-token sign-in (`signInWithIdToken`) with `sign_in_with_apple` / `google_sign_in`.
- **Data:** PostgreSQL in the same project, with row-level security.

| Criterion | Assessment |
|---|---|
| Cost | Free plan for development (projects pause when idle, so it is not for production). The paid plan (a fixed monthly fee with a large MAU allowance) is the realistic production tier. **Verify current pricing at decision time.** |
| Effort | **Low–medium.** Auth flows, verification and reset emails are built in. The Python backend verifies Supabase JWTs via the project's JWKS. A-2 sync, credits and XP map naturally onto Postgres tables keyed by `user_id` and the existing `client_id`. |
| Security | Managed GoTrue auth, configurable rate limits. Leaked-password protection (Have I Been Pwned) is available on paid plans. Row-level security must be written carefully: the service-role key must never ship in the app. |
| Apple / Google | Supported, including native ID-token flows. Apple token revocation on deletion must be done server-side (backend or Edge Function with the Apple `.p8` key). |
| Account deletion | Admin API call from the backend or an Edge Function (needs the service-role key server-side). Postgres `ON DELETE CASCADE` removes user data in one step. A web deletion page is still needed. |
| Lock-in | Low: open source, self-hostable, standard Postgres (`pg_dump`). Password hashes are bcrypt, so they are portable. |

## Recommendation: **C. Supabase Auth**

Why Supabase:
- It meets every requirement above with managed auth (verification, reset, rate limits, leaked passwords on the paid plan).
- It gives the app the **relational database the next four blocked tasks need anyway**:
  - A-2 merge by `client_id`, with a unique `(user_id, client_id)` key, so a retry never duplicates a workout;
  - AI credits ledger;
  - server-confirmed XP;
  - friends.
- It has the lowest lock-in of the managed options.
- The existing Python AI backend stays as it is and only adds JWT verification.

Why not Firebase:
- Firebase Auth alone is equally easy.
- But the data side would push sync, credits and XP into Firestore's document model, or into a second database anyway.

Why not Option A:
- It is only worth it if a managed auth vendor is ruled out for policy reasons.
- It moves the riskiest code (credentials and tokens) onto a single VM.

Interim client path (no owner input needed beyond the choice):
- add `SupabaseAuthRepository implements AuthRepository` in a new PR;
- keep `ENABLE_ACCOUNTS` off in production until the owner inputs below exist and a staging project passes the flows end to end.

## What the owner must provide

None of these can be created by the agent: each needs the owner's accounts, legal identity or payment.

### Common (any option)

| Item | Where | Notes |
|---|---|---|
| Decision: A, B or C | — | Recommendation above: C |
| Apple Developer Program membership (team ID) | developer.apple.com | Needed for Sign in with Apple |
| **Sign in with Apple capability** on App ID `com.ronganminh.repCounterApp` | Certificates, Identifiers & Profiles | After this, the agent can add `Runner.entitlements` (`com.apple.developer.applesignin`) in a PR. |
| **Sign in with Apple key** (`.p8`, Key ID) | Apple Developer › Keys | Server-side only: token validation/revocation. **Never** commit it or put it in the app. |
| Services ID + return URL (only if Apple sign-in is wanted on **Android**) | Apple Developer › Identifiers | Android has no native Apple flow; it uses the web flow. Option: offer Apple on iOS only. |
| **Google Cloud project + OAuth consent screen** (app name, support email, privacy/terms URLs, logo) | console.cloud.google.com | Consent screen verification may be required. |
| Google **iOS OAuth client ID** (bundle `com.ronganminh.repCounterApp`) and its reversed-client-ID URL scheme | Google Cloud › Credentials | The agent adds the URL scheme to `Info.plist` in a PR once given. |
| Google **Android OAuth client** (package `com.ronganminh.repcoach` + SHA-1 of the upload key **and** the Play App Signing key) | Google Cloud › Credentials; Play Console › App integrity | Both SHA-1 values are needed or Play builds fail to sign in. |
| Google **Web client ID** (server audience) | Google Cloud › Credentials | Used to validate Google ID tokens server-side. |
| Transactional email sender: domain + SPF/DKIM, or the provider's default sender for testing | DNS + mail provider | Verification and reset mails. A real domain is strongly recommended over `duckdns.org` for deliverability and for universal links. |
| Domain for links (verify / reset), with iOS Associated Domains + Android App Links files | DNS + hosting | So links open the app. Needs an owned domain. |
| Updated **Privacy Policy** and **Terms** (account data, providers, retention, deletion), and a **web account-deletion URL** for Google Play | Legal (D-14 still open) | App Store privacy labels and the Play Data safety form must be updated too. |
| Support process for locked/disabled accounts | Product | The copy refers to "contact support". |

### Option C (Supabase) specifics

| Item | Kind | Where it lives |
|---|---|---|
| Supabase organisation + project (region close to users, e.g. Singapore; confirm availability), paid plan for production, a separate staging project | Owner account | supabase.com |
| `SUPABASE_URL` | Public | App `--dart-define`; backend env |
| `SUPABASE_ANON_KEY` (publishable key) | Public, restricted by row-level security | App `--dart-define` only |
| `SUPABASE_JWKS_URL` (or JWT issuer/audience) | Public | Backend env, for verifying users on `/v1/workout-feedback` |
| `SUPABASE_SERVICE_ROLE_KEY` | **Secret** | Backend env / Edge Function secrets only. Used for account deletion. |
| Apple provider settings (Services ID, team ID, key ID, `.p8`) | Secret parts server-side | Supabase dashboard › Auth › Providers |
| Google provider settings (Web client ID + secret; iOS/Android client IDs as authorized audiences) | Client secret is **secret** | Supabase dashboard › Auth › Providers |
| Custom SMTP credentials | **Secret** | Supabase dashboard › Auth › SMTP |
| Redirect URLs allow-list (deep-link scheme / universal-link domain) | Config | Supabase dashboard › Auth › URL configuration |

### Option B (Firebase) specifics, if chosen instead

| Item | Notes |
|---|---|
| Firebase project (staging + production) | Owner account |
| `GoogleService-Info.plist` (iOS) / `google-services.json` (Android) | Generated by Firebase; contain public identifiers. Inject per flavor; keep production files out of git if preferred. |
| Apple provider (Services ID, team ID, key ID, `.p8`) and Google provider enabled | Firebase console › Authentication |
| Backend: Firebase project ID for ID-token verification | Backend env (`FIREBASE_PROJECT_ID`) |

### Option A (own backend) specifics, if chosen instead

| Item | Notes |
|---|---|
| Database host + backups | VM disk or managed Postgres; backup and restore plan |
| `DATABASE_URL`, `JWT_SIGNING_KEY` (rotation plan), `SMTP_*`, `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY`, `GOOGLE_WEB_CLIENT_ID` | All **server secrets** except the client IDs |
| Security review of the auth code before launch | Strongly recommended |

## Next steps after the decision

1. **Owner:** chooses the option and creates the staging project and provider credentials listed above.
2. **Agent PR (client):**
   - write `SupabaseAuthRepository` (or the Firebase equivalent) behind `ENABLE_ACCOUNTS`;
   - add the entitlement and URL schemes;
   - add tests against the same `AuthRepository` contract as `FakeAuthRepository`.
3. **Agent PR (backend):**
   - verify the JWT on `/v1/workout-feedback` while still accepting guest requests;
   - add the account-deletion endpoint (provider data, Apple revocation, server rows);
   - write tests.
4. **Staging run of every flow:**
   - sign-up → verify;
   - sign-in;
   - Apple and Google sign-in;
   - expired session;
   - deletion.
   Then decide when to turn on `ENABLE_ACCOUNTS` for a release, which is the owner's call.
5. **A-2 merge** on top: upload by `client_id`, idempotent, using the existing merge preview screen.
