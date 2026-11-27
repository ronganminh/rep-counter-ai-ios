# Sign in with Apple: setup checklist (owner)

App Store guideline 4.8: the app offers Google sign-in, so it must also offer
Sign in with Apple, with the same prominence (D-12, S-5, L-D42). The app
side is done; this page lists what only the owner can do, in Apple Developer
and Supabase. **No key, `.p8` file or generated secret goes into the repo, a
dart-define file, CI or chat.** Keep the `.p8` in your password manager.

## What the app does

| | iOS | Android |
|---|---|---|
| Flow | Native Apple sheet (`sign_in_with_apple`), ID token → Supabase `signInWithIdToken` (provider `apple`) | Supabase's web (OAuth) flow in the browser → Apple → back to the app through `com.ronganminh.repcoach://login-callback` (PKCE) |
| Needs | Capability on the App ID + `Runner.entitlements` (already committed) | A Services ID and the provider's OAuth secret in Supabase |
| Turned on by | `APPLE_SIGN_IN_ENABLED=true` (dart-define, already `true` in `dart_defines.staging.example.json`) | same flag |

- **Data asked for: name and email only** (`email` + `fullName` scopes on iOS,
  `name email` on the web). Nothing else is requested or stored; the app
  keeps the email Supabase returns and does not save the name.
- **Hide My Email works as is.** When the user hides their email, Apple gives
  a private relay address (`…@privaterelay.appleid.com`). That address is
  the account's email: it is shown in Profile, used for sync and account
  deletion, and never compared with or merged into another account. The
  account is "verified" (Apple vouches for it).
- **Buttons (HIG):** Apple's own "Continue with Apple" button (Apple logo,
  white on the dark theme, black on light) sits **above** "Continue with
  Google", full width, same height (48 dp). On iOS, Google is hidden
  whenever Apple is off (gate 4.8 in `tool/check_app_store_readiness.py`).
- **Account deletion (5.1.1(v)):** on iOS the app gets a fresh
  authorization code and the `delete-account` function revokes the Apple
  token before deleting the account. On Android (web flow) there is no
  native sheet to get that code: the account and its data are still
  deleted; the user can remove the app under appleid.apple.com → Sign in
  with Apple.
- **No allow-list:** staging has no email/Apple ID allow-list, so the
  owner's Apple ID can sign in as soon as the provider is on. Nothing to
  add.

## 1. Apple Developer (developer.apple.com → Certificates, Identifiers & Profiles)

1. **Identifiers → App IDs →** `com.ronganminh.repCounterApp` → enable
   **Sign in with Apple** (as a primary App ID). Save, then regenerate the
   provisioning profiles that use this App ID (Xcode automatic signing does
   this on the next build).
2. **Identifiers → + → Services IDs →** create one, for example
   `com.ronganminh.repcoach.signin` (description "RepCoach web sign-in").
   Enable **Sign in with Apple → Configure**:
   - Primary App ID: `com.ronganminh.repCounterApp`
   - Domains and Subdomains: `<project-ref>.supabase.co` (staging and,
     later, production: one line each)
   - Return URLs: `https://<project-ref>.supabase.co/auth/v1/callback`
     (one per project)
3. **Keys → +** → name "RepCoach Sign in with Apple" → enable **Sign in
   with Apple → Configure** with the primary App ID → Continue → Register →
   **Download** the `.p8`. You can download it **once**. Note the **Key ID**
   (10 characters) and your **Team ID** (Membership details, top right).
   - The key used for token revocation (`delete-account` secrets
     `APPLE_KEY_ID` / `APPLE_PRIVATE_KEY`, see `supabase/README.md`) can be
     the same key.
4. Optional, only if the backend ever emails Apple users (Supabase Auth does
   not for Apple accounts): **Services → Sign in with Apple for Email
   Communication** → register the sending domain or address, or mail to
   relay addresses is dropped.

## 2. Supabase (each project: staging, then production)

Dashboard → **Authentication → Sign In / Providers → Apple**:

1. **Enable** Sign in with Apple.
2. **Client IDs:** the bundle ID and the Services ID, comma-separated:
   `com.ronganminh.repCounterApp,com.ronganminh.repcoach.signin`
   (the bundle ID for the iOS native flow, the Services ID for Android).
3. **Secret Key (for OAuth):** used by the Android web flow. Depending on the
   dashboard version, it either asks for the **Team ID, Key ID and the
   `.p8` contents** directly, or for a **client secret (JWT)** that you
   generate from those three values plus the Services ID with the generator
   linked from that field / from Supabase's "Login with Apple" guide. The
   generated secret **expires after at most 6 months**: put a renewal
   reminder in your calendar (an expired secret breaks Apple sign-in on
   Android only; iOS keeps working).
4. Save.

Dashboard → **Authentication → URL Configuration → Redirect URLs**: check
that `com.ronganminh.repcoach://login-callback` is listed (it already is
for email links). The web flow comes back to the app through it.

## 3. Build

- `APPLE_SIGN_IN_ENABLED=true` in the dart-defines of the build (staging
  already has it). iOS builds also need step 1.1 done first, or signing
  fails.
- Nothing else in the app changes; no key is passed to the app.

## 4. Check (owner, on devices)

1. iPhone: Profile → Sign in → **Continue with Apple** → Face ID →
   signed in. Try once with **Hide My Email**: Profile shows the
   `privaterelay.appleid.com` address.
2. Android: Profile → Sign in → **Continue with Apple** → the browser opens
   Apple's page → sign in → the app comes back signed in. Closing the
   browser instead returns to the sign-in screen with nothing changed.
3. Supabase → Authentication → Users: the user's provider is `apple`.
4. iPhone: Profile → Delete account with an Apple account → the
   `delete-account` log shows `{"event":"apple_revoke","ok":true}`.

## Troubleshooting

- Android returns to the app but stays signed out: the Services ID is
  missing from **Client IDs**, the Return URL in the Services ID does not
  match the project, or the OAuth secret expired.
- iOS "Sign in failed": the bundle ID is missing from **Client IDs**, or the
  App ID does not have the capability (step 1.1).
- `invalid_client` on Apple's page: the Services ID or its domain/return URL
  is wrong.
