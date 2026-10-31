# 05 · Supabase Auth setup (D-12)

**Owner decision D-12 (2026-10-23): Supabase Auth**, with three sign-in methods: Google, Apple, and email + password.

The client code is in place behind `ENABLE_ACCOUNTS` (default **off**), in PRs A-1a, A-1b and A-1c. This page lists, step by step, what the owner sets up and which values to send back. **Status 2026-10-31:** the staging project `rvysencgtomkzwgdjaqh` is configured, the backend v2 migrations are applied and `delete-account` + `ai-request` are deployed (§10); there is no production project yet.

> **Secrets.** Never paste the service-role key, the Google client **secret** or the Apple `.p8` key into chat, git or the app. They go only into the Supabase dashboard or Edge Function secrets. The app needs only the values marked *public* in §9.

## 0. How the app behaves

| Build | Result |
|---|---|
| `ENABLE_ACCOUNTS` not set (production default) | No account UI, no Supabase client, no network call |
| `ENABLE_ACCOUNTS=true`, `SUPABASE_URL` / `SUPABASE_ANON_KEY` missing or not `https` | Account UI says "Sign-in isn't available right now"; training works as a guest |
| `ENABLE_ACCOUNTS=true` + Supabase values | Email + password (sign up, verify, sign in, reset password, delete account) |
| … + `GOOGLE_WEB_CLIENT_ID` (and `GOOGLE_IOS_CLIENT_ID` on iOS) | Adds "Continue with Google" |
| … + `APPLE_SIGN_IN_ENABLED=true` (iOS only) | Adds "Continue with Apple" (needs the capability, §5) |

- **Sessions:** the access and refresh tokens are stored in the iOS Keychain or Android Keystore (`flutter_secure_storage`), never in SharedPreferences. They are never logged; `debug: false`.
- **Email links:** sign-up confirmation and password reset use the PKCE flow. Links return to `com.ronganminh.repcoach://login-callback`, which is already registered in `Info.plist` and `AndroidManifest.xml`.

## 1. Create the Supabase projects

1. Create a Supabase organisation at supabase.com.
2. Create two projects: **repcoach-staging** and **repcoach-prod**.
   - Pick the region closest to users (e.g. Southeast Asia / Singapore; confirm it is offered).
   - Use the paid plan for production. Free projects pause when idle and have no leaked-password protection.
3. Save the database password in your password manager.
4. In **Project Settings › API**, note the **Project URL** and the **anon / publishable key** (both public). Do **not** copy the service-role key anywhere.

## 2. Auth settings (each project)

**Authentication › URL Configuration**
1. Set **Site URL** to `com.ronganminh.repcoach://login-callback`, or to a web page you own.
2. Under **Redirect URLs**, add `com.ronganminh.repcoach://login-callback`.

**Authentication › Providers › Email**
1. Turn **Enable Email provider** and **Confirm email** ON.
2. Turn **Secure password change** ON.
3. Set **Minimum password length** to **10**, which matches the app's "Use at least 10 characters".
4. Turn **Leaked password protection** ON (paid plan). The sign-up screen promises this check.

**Rate limits and email**
1. Under **Authentication › Rate Limits**, keep the defaults or tighten them. The app shows "Too many attempts" when they trigger.
2. Under **Authentication › SMTP**, set up custom SMTP from a domain you own, with SPF and DKIM. The built-in sender is for testing only and is heavily rate-limited.
3. Under **Authentication › Email Templates**, keep the Confirm signup and Reset password templates using `{{ .ConfirmationURL }}`. The text can be translated (EN/VI) later.

## 3. Google sign-in

**Google Cloud Console** (console.cloud.google.com):
1. Create or choose a project, and configure the **OAuth consent screen**:
   - app name "RepCoach AI";
   - support email `ronganminh221@gmail.com`;
   - Privacy Policy `https://repcoach-ai.duckdns.org/privacy-policy.html` and Terms `https://repcoach-ai.duckdns.org/terms.html`; home page `https://repcoach-ai.duckdns.org/` (D-14, decided 2026-10-27);
   - scopes `email`, `profile`, `openid`.
2. Under **Credentials › Create OAuth client ID**, create three clients:
   - **Web application.** This is the client Supabase uses. Keep its **Client ID** and **Client secret**. No redirect URI is needed for the native ID-token flow.
   - **iOS**, with bundle ID `com.ronganminh.repCounterApp`. Keep its **Client ID** and its **reversed client ID** (`com.googleusercontent.apps.…`).
   - **Android**, with package `com.ronganminh.repcoach`. Add the **SHA-1** values of:
     - the debug keystore (`keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android`);
     - the upload key;
     - the **Play App Signing** key (Play Console › Setup › App integrity › App signing).

     Missing the Play SHA-1 breaks sign-in only in Play-installed builds.

**Supabase › Authentication › Providers › Google:**
1. Turn the provider ON.
2. **Client ID:** enter the Web, iOS and Android client IDs, comma separated, with the Web ID first.
3. **Client secret:** the Web client secret. This is a secret and stays in Supabase only.
4. **Skip nonce check:** ON. The iOS Google SDK adds its own nonce, which Supabase cannot verify.

**App side (agent, after you send the values):**
- add the reversed iOS client ID as a second URL scheme in `Info.plist`;
- build with `GOOGLE_WEB_CLIENT_ID` and `GOOGLE_IOS_CLIENT_ID`.

## 4. Apple sign-in: Apple Developer side

Done at developer.apple.com, in Certificates, Identifiers & Profiles.

1. **Identifiers › App IDs ›** `com.ronganminh.repCounterApp` **›** enable **Sign in with Apple** (primary App ID).
2. **Identifiers › Services IDs:** create one, e.g. `com.ronganminh.repcoach.signin`.
   - It is needed for the Supabase provider secret, and for Apple on Android/web if wanted later.
   - Configure it with the primary App ID and the return URL `https://<project-ref>.supabase.co/auth/v1/callback`.
3. **Keys:** create a key with **Sign in with Apple** enabled.
   - Download the `.p8` (only once) and note the **Key ID** and your **Team ID**.
   - The `.p8` is a **secret**: keep it in your password manager.

**Supabase › Authentication › Providers › Apple:**
1. Turn the provider ON.
2. **Client IDs:** `com.ronganminh.repCounterApp` (the native iOS app). Add the Services ID too, if the web flow is used.
3. **Secret key (for OAuth):** generate it from Team ID + Key ID + `.p8` (Supabase docs provide a tool).
   - It **expires after 6 months at most**, so put a renewal reminder in your calendar.
   - The native ID-token flow does not need it, but the web flow and token revocation do.

## 5. Xcode capability (iOS)

1. In Xcode, open `ios/Runner.xcworkspace`.
2. Select the **Runner** target, open **Signing & Capabilities**, choose **+ Capability**, and add **Sign in with Apple**.
3. Xcode creates `Runner/Runner.entitlements` with `com.apple.developer.applesignin = [Default]`.

> The agent will commit this entitlements file and turn on `APPLE_SIGN_IN_ENABLED` **only after** you confirm step 4.1. Signing a build with the entitlement before the App ID has the capability makes the build fail.

## 6. Android

- No extra Supabase setting is needed. The `com.ronganminh.repcoach://login-callback` intent filter is already in `AndroidManifest.xml`.
- Google needs the SHA-1 values from §3.
- Apple on Android is **not offered** (no native sheet). It could be added later with the web flow and the Services ID.

## 7. Account deletion (server side)

**Owner decision (2026-10-26): approved for staging.** It is implemented in `supabase/functions/delete-account/`; see `supabase/README.md`.

App Store guideline 5.1.1(v) requires in-app account deletion. The app (Profile › Delete account, typed confirmation) calls the Edge Function with the user's JWT.
- **Apple accounts:** the app first asks the Apple sheet for a fresh **authorization code** and sends it along. If the user cancels the sheet, nothing is deleted.
- **What the function does:**
  1. verifies the JWT;
  2. for Apple accounts, exchanges the code at Apple and revokes the token. Apple secrets live only in the Edge Function secrets. A failed revoke does not block deletion, but it is reported in the response and the logs;
  3. deletes the user's rows (`USER_TABLES`);
  4. calls `auth.admin.deleteUser`. Every user-owned table has `user_id … references auth.users on delete cascade` (`supabase/migrations/`).
- **Local data:** workouts on the phone are kept as guest data.

**Deploy:** the agent has no Supabase access token, so it has not deployed anything. The exact `supabase link` / `secrets set` / `db push` / `functions deploy` commands for the owner are in `supabase/README.md`. Production waits for a production project and a separate approval.

Still open:
- **A web page for deletion requests:** Google Play requires one. D-14 gives the site (`https://repcoach-ai.duckdns.org/`) and support page (`https://repcoach-ai.duckdns.org/support.html`); the deletion-request page itself is still to be published there by the owner.
- **Grace period wording:** the copy mentions "the grace period set in the Privacy Policy (if any)"; the Privacy Policy at `https://repcoach-ai.duckdns.org/privacy-policy.html` must state it (owner / Legal).

## 8. Row-level security

- Turn RLS ON for every table the app will read (A-2 sync, credits, XP).
- Add policies `user_id = auth.uid()`.
- The anon key is public. RLS is what protects data.
- The service-role key is used only in Edge Functions.

## 9. Build values (`--dart-define`)

| Name | Kind | Example / note |
|---|---|---|
| `ENABLE_ACCOUNTS` | flag | `true` only for staging/test builds until the owner turns it on for a release |
| `SUPABASE_URL` | public | `https://<project-ref>.supabase.co` (must be https) |
| `SUPABASE_ANON_KEY` | public | the anon / publishable key |
| `SUPABASE_REDIRECT_URL` | public, optional | default `com.ronganminh.repcoach://login-callback` |
| `GOOGLE_WEB_CLIENT_ID` | public | `…apps.googleusercontent.com` (Web client) |
| `GOOGLE_IOS_CLIENT_ID` | public | iOS client ID |
| `APPLE_SIGN_IN_ENABLED` | flag | `true` after §4–5 |
| `ENABLE_CLOUD_SYNC` | flag | backend v2, A-2 sync (needs `ENABLE_ACCOUNTS`) |
| `ENABLE_AI_CREDITS` | flag | AI-1 credits / `ai-request` |
| `ENABLE_XP` | flag | G-1 XP |
| `ENABLE_SOCIAL` | flag | S-1 friends, block, report, leaderboard |
| `ENABLE_INBOX` | flag | NT-2 in-app inbox (works without pushes) |
| `ENABLE_PUSH` | flag | NT-2 remote pushes; **off** until APNs / Firebase exist (implies the inbox) |
| `ENABLE_BILLING` | flag | P-1; **off** until D-14 (prices, product ids) |

Every flag is off unless set, and each backend v2 flag also needs `ENABLE_ACCOUNTS`. `test/features/auth/staging_config_test.dart` fails if the staging example names a define the app does not read (a typo such as `ENABLE_SYNC` would otherwise be ignored silently).

> **State of the app with the backend v2 flags on.** Wired into the app one feature per PR (owner approval 2026-10-31):
> - **Sync (A-2), wired:** `SyncController` (`lib/features/sync/`) runs when the app opens signed in, at sign-in, about 2 s after a workout or plan is saved or deleted, when the app returns to the foreground, on "Sync now" (Profile), and retries after 30 s / 2 min / 10 min on failure. Home and Profile show the sync badge ("N waiting to sync", offline, couldn't sync, synced). Guest workouts are offered with "Bring your workouts" (dry run first, one choice for workouts that differ, or keep them on this phone). Settings › Delete workout history asks phone / account / both (D-20).
> - Credits, XP, social and inbox: adapters only, no screen yet (next PRs).

### Building the staging app

The template `rep_counter_app/dart_defines.staging.example.json` holds the staging values. They are all public identifiers, and the publishable key is a placeholder.

1. Copy it to `dart_defines.staging.json`. That name is git-ignored, so it is never committed.
2. Paste the **staging publishable key** from Supabase › Project Settings › API.
3. Build:

```
cd rep-counter-ai-main/rep_counter_app
cp dart_defines.staging.example.json dart_defines.staging.json   # then paste the key
flutter run   --flavor store --dart-define-from-file=dart_defines.staging.json            # Android device
flutter run   --dart-define-from-file=dart_defines.staging.json                           # iPhone (signed, see §5)
flutter build apk --flavor store --release --dart-define-from-file=dart_defines.staging.json
flutter build ipa --release --dart-define-from-file=dart_defines.staging.json
```

| Value (staging) | |
|---|---|
| Project | `rvysencgtomkzwgdjaqh` (Asia-Pacific / Tokyo, Free plan) |
| `SUPABASE_URL` | `https://rvysencgtomkzwgdjaqh.supabase.co` |
| `SUPABASE_REDIRECT_URL` | `com.ronganminh.repcoach://login-callback` (allow-listed) |
| `GOOGLE_WEB_CLIENT_ID` | `354784213486-h6v9h1jt98ul1v701sr5b1acevqmj06b.apps.googleusercontent.com` |
| `GOOGLE_IOS_CLIENT_ID` | `354784213486-8bpqbeqn6kggtkub48t1v14soak77sv2.apps.googleusercontent.com` (reversed form in `Info.plist`) |
| `APPLE_SIGN_IN_ENABLED` | `true` (iOS; entitlement in `Runner.entitlements`) |

### Staging builds for testers: TestFlight internal and Play internal testing

Build from `main`, with the staging file, on the owner's Mac (iOS) or any machine with the upload key (Android). These binaries talk to **staging**: give them to internal testers only, never submit them for review, and never promote the Play release to production. The store release is a separate build without the staging file.

```bash
git checkout main && git pull
cd rep-counter-ai-main/rep_counter_app
cp dart_defines.staging.example.json dart_defines.staging.json   # paste the publishable key; git-ignored
flutter test test/features/auth/staging_config_test.dart          # the file is still well-formed
```

Pick a build number higher than every build already uploaded (App Store Connect › TestFlight, Play Console › App bundle explorer). The version name stays as in `pubspec.yaml` (`2.0.0`).

**iOS → TestFlight, internal testing**

```bash
# Signed IPA (automatic signing with the team NW22NWLTK4 in Xcode).
tool/build_ios.sh --ipa --release --build-number=<N> \
  --dart-define-from-file=dart_defines.staging.json
# → build/ios/ipa/*.ipa
```

1. Upload with **Transporter** (or Xcode › Organizer › Distribute App › App Store Connect › Upload).
2. App Store Connect › TestFlight: wait for processing; answer the export-compliance question (the app uses only the standard encryption of HTTPS).
3. Add the build to an **Internal Testing** group only (App Store Connect users, no Beta App Review). Do not add it to an external group.
4. Write "STAGING" and the build number in the "What to Test" field.

**Android → Play internal testing**

```bash
# Needs android/key.properties with the upload key (never committed).
flutter build appbundle --release --flavor store --build-number=<N> \
  --dart-define-from-file=dart_defines.staging.json
# → build/app/outputs/bundle/storeRelease/app-store-release.aab
```

1. Play Console › Testing › **Internal testing** › Create new release › upload the `.aab`.
2. Release notes: "STAGING build <N>". Testers: the internal list (the Google account `thanhyt2024@gmail.com` is the one that can use Google sign-in while the consent screen is in *Testing*).
3. Do **not** use "Promote release" to closed, open or production tracks for this build.

Google sign-in works on the Play build, because Play App Signing's SHA-1 is registered (§10 row 7). Then run the checklist in §11.

**Notes**
- **Android Google sign-in** needs the build's signing certificate SHA-1 to be registered. Upload-key and Play App Signing SHA-1 are registered. The **debug keystore is not**, so Google sign-in fails on `flutter run` debug builds until a debug Android client is added.
- **Google consent screen** is in *Testing*. Only the listed test users (`thanhyt2024@gmail.com`) can sign in with Google until it is published.
- **CI:** no workflow builds the app with accounts yet. If a staging build job is added, store each value as a GitHub Actions secret, write the file in the job, then build with `--dart-define-from-file`. Never put the values in the workflow file:

  ```yaml
  - run: |
      cat > dart_defines.staging.json <<EOF
      {"ENABLE_ACCOUNTS":"true","SUPABASE_URL":"${{ secrets.STAGING_SUPABASE_URL }}","SUPABASE_ANON_KEY":"${{ secrets.STAGING_SUPABASE_ANON_KEY }}", ...}
      EOF
  ```

## 10. Values to send back (status 2026-10-31, staging)

| # | Value | Status |
|---|---|---|
| 1 | Staging **Project URL** | ✅ `https://rvysencgtomkzwgdjaqh.supabase.co` (Tokyo, Free plan) |
| 2 | Staging **publishable key** | ✅ received; kept out of git (local `dart_defines.staging.json`, future CI secret) |
| 3 | Production URL + key | ⏳ **open:** no production project yet |
| 4a | Redirect allow-listed, Confirm email ON, Secure password change ON, min length 10 | ✅ |
| 4b | Leaked-password protection | ⏳ **open:** needs the Pro plan |
| 4c | Custom SMTP | ⏳ **open:** staging uses Supabase's default sender (rate-limited) |
| 5 | Google **Web client ID** | ✅ `354784213486-h6v9…` (§9) |
| 6 | Google **iOS client ID** + reversed ID | ✅ reversed ID registered in `Info.plist` |
| 7 | Google Android clients | ✅ Play App Signing + upload key SHA-1. ⏳ **open:** debug keystore client (needed only to test Google on debug builds) |
| 8 | Google provider ON, Skip nonce check ON | ✅ |
| 8b | Google consent screen | ⏳ **open:** still *Testing* (test user only); publish before external testers |
| 9 | Apple Team ID / Services ID / Key ID | ✅ `NW22NWLTK4` / `com.ronganminh.repcoach.signin` / `ANA4NT26KP` |
| 10 | Sign in with Apple on the App ID, Apple provider ON | ✅ entitlement in `Runner.entitlements` |
| 10b | Apple **Secret Key (for OAuth)** | ⏳ **open:** generate with `tool/apple_oauth_secret.py` (below) and paste into Supabase; renew every ≤ 6 months |
| 11 | `delete-account` Edge Function | ✅ deployed by the owner 2026-10-31: ACTIVE v1, JWT verification ON, `APPLE_*` secrets set; unauthenticated call → 401 ✅ |
| 12 | Support / legal URLs for consent screens and stores (D-14) | ✅ decided 2026-10-27: support `ronganminh221@gmail.com`, `https://repcoach-ai.duckdns.org/support.html`; privacy `https://repcoach-ai.duckdns.org/privacy-policy.html`; terms `https://repcoach-ai.duckdns.org/terms.html`; home `https://repcoach-ai.duckdns.org/`. ⏳ **open:** account-deletion request page on that site (Google Play) |
| 13 | Backend v2 migrations (06) | ✅ 8/8 applied 2026-10-31, Local == Remote |
| 14 | `ai-request` Edge Function | ✅ ACTIVE v1, JWT verification ON, `GROQ_API_KEY` + `GROQ_MODEL` set; unauthenticated call → 401 ✅ |
| 15 | Tombstone purge (`purge_sync_tombstones`, daily 03:17 UTC) | ⏳ **open:** owner runs the SQL in `supabase/README.md` (A-2 sync) |
| 16 | `verify-purchase`, `store-webhook` | ⏸ **blocked:** D-14 prices and product ids, App Store IAP key, Play service account |
| 17 | `send-push` | ⏸ **blocked:** APNs key, Firebase project |
| 18 | Signed-in backend flow on staging | ⏳ **open:** owner runs `test/staging/staging_backend_test.dart` (`supabase/README.md`) |
| — | Apple `.p8`, Google client secret, service-role key | **secret**: dashboard / Edge Function secrets / password manager only |

Supabase settings to know: "Automatically expose new tables" OFF and "Enable automatic RLS" ON. Every new table therefore needs explicit grants and policies.

**Apple OAuth secret** (owner, locally; the `.p8` never enters the repo):

```
python3 tool/apple_oauth_secret.py --p8 ~/secure/AuthKey_ANA4NT26KP.p8 \
  --team-id NW22NWLTK4 --key-id ANA4NT26KP --client-id com.ronganminh.repcoach.signin
```

Paste the printed JWT into Supabase › Authentication › Providers › Apple › Secret Key (for OAuth). The script prints the expiry date; set a reminder.

## 11. Staging test checklist

**Automated (no device), passing:** `test/features/auth/staging_config_test.dart`, `supabase_auth_repository_test.dart`, `auth_screens_test.dart`, `auth_reset_delete_test.dart`. They run with the staging values against a simulated Supabase API, without the network. They cover:
- native config: redirect scheme, Google scheme, Apple entitlement;
- providers per platform;
- with the flag off, nothing is created;
- the session is stored in Keychain/Keystore;
- sign-up → link → confirmed; wrong password; reset → new password; Google/Apple token exchange and cancel; expiry; delete;
- the screens;
- training stays available as a guest.

**Automated, backend v2 (no device, no network), passing:**
- `test/core/backend/supabase_backend_rpc_test.dart`: the real Supabase SDK against a fake server. 401 (expired JWT, gateway `UNAUTHORIZED_INVALID_JWT_FORMAT`), 404 (missing function), 5xx with an HTML page, a malformed 200 and no network all come out as one error type the features handle; nothing crashes.
- `test/features/sync/cloud_sync_test.dart`: with 401 / 28000 / 404 / 500 / no network on pull or push, local workouts and deletions are untouched, nothing is marked pushed, the cursor does not move, and the result is "N changes pending" (signed out, offline or server). Once the server is back everything is pushed exactly once.
- `test/features/auth/supabase_auth_repository_test.dart`: delete account without network says "Can't connect", a 5xx says "not available", and the user stays signed in.
- The contract tests of each adapter against `supabase/contracts/*.json`.

**Against staging (network, owner's machine), UNVERIFIED until run:** `test/staging/staging_backend_test.dart` (commands in `supabase/README.md`). Steps: no-session calls refused → sign up / sign in → sync push, pull, tombstone → XP awarded once → `ai-request` charges one credit, never twice → `delete-account`.

**On a real device: UNVERIFIED.** The owner runs these on a staging build (§9). Report ✅/❌ per line.

| # | Device | Steps | Expected |
|---|---|---|---|
| D1 | iPhone + Android | Profile › Sign in › Create account with a new email (password ≥ 10 characters, tick Terms) | "Confirm your email" with your address |
| D2 | same phone | Open the email link (sender: Supabase) | The app opens, then "Email confirmed"; Profile shows the account |
| D3 | any | Sign out; sign in with a wrong password, then the right one | "Email or password is incorrect", then signed in |
| D4 | any | Sign in › Forgot password? › send; open the link on the phone; set a new password | "Choose a new password", then "Password updated" |
| D5 | iPhone | Continue with Google (account `thanhyt2024@gmail.com`); repeat and cancel the sheet | Signed in; cancel shows "Sign-in cancelled" and changes nothing |
| D6 | Android **release/Play** build | Continue with Google | Signed in (debug builds fail until a debug client exists) |
| D7 | iPhone | Continue with Apple (also try "Hide My Email"); repeat and cancel | Signed in; cancel changes nothing |
| D8 | any | Supabase › Authentication › Users › sign the user out / revoke sessions; reopen the app after the access token expires (≤ 1 h) | "Your session expired · sign in again" banner; training still works |
| D9 | any | Profile › Delete account › type DELETE | **Needs the `delete-account` function deployed**; then the user is gone in the dashboard |
| D10 | any | Airplane mode | Training, history and counting work as a guest; sign-in shows "Can't connect" |
| D11 | any | Fresh install **without** `ENABLE_ACCOUNTS` | No account UI at all |
| D12 | any | Staging build (all backend v2 flags as in the example). Signed in, record 2 workouts (camera + manual), then airplane mode, record 1 more, force-quit, reopen | Training, history and counting work; nothing lost; no crash. Home badge "Offline · 1 waiting to sync" while offline; back online it turns "Synced" within a few seconds (or tap Profile › Sync now) |
| D13 | any | Same build, then in the dashboard sign the user out / revoke sessions; keep training | "Your session expired" banner (D8); local history intact; no crash |
| D14a | phone A + phone B (or reinstall) | Same account on both. Record a workout on A; on B open the app (or Profile › Sync now) | B shows the workout once in History; Home badge "Synced" on both. In the dashboard, `workouts` has one row for it |
| D14b | phone A + B | Delete that workout on A (History); sync B | Gone on B too (tombstone). Undo on A within 5 s instead: it stays on both |
| D14c | any | As a guest record 2 workouts, then sign in to an account that already has workouts | Banner "Bring your workouts" on Home / Profile; the preview counts "already in your account" / "new"; Merge uploads only the new ones (dashboard row count goes up by exactly those). "Keep workouts on this phone only" makes the banner go away and uploads nothing |
| D14d | any | Same workout edited on two phones before syncing (e.g. AI feedback on one) | The merge preview shows "1 workout differs" with "Keep the account version" / "Keep this phone's version"; the chosen one ends up on both |
| D14e | any | Settings › Delete workout history › This phone only / My account / Both, type DELETE | Phone only: History empty here, the account (dashboard) keeps the rows and they don't come back to this phone. My account: rows become tombstones in the dashboard, this phone keeps its copy. Both: both empty. Airplane mode with My account / Both: "Couldn't reach your account, so nothing was deleted" and nothing changes. The account itself is never deleted |
| D14f | any | Create a plan; sync; open the app on phone B | The plan is on B. Start a different plan on B: the newer one stays active on both |
| D15 | — | AI credits (`ai-request`, balance) | **Not testable in the app yet.** Integration test, step 4. Basic post-workout feedback is unchanged and stays free (D-07) |
| D16 | — | XP / level | **Not testable in the app yet.** Integration test, steps 2–3 |
| D17 | — | Social (invite, accept, block, report, leaderboard) and inbox | **Not testable in the app yet** (no screens). Backend covered by `supabase/tests/social.test.sql` and `push_inbox.test.sql` in CI |
| D18 | any | Profile › Delete account on the staging build, then check the dashboard | User gone; `workouts`, `ai_credit_ledger`, `xp_events`, `inbox_items` rows for that user gone (cascade) |
