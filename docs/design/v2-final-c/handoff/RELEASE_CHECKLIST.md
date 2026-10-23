# RELEASE_CHECKLIST (design-level)

RepCoach AI · Final C · 2026-10-22

> **Verification limit:** web search and web fetch were disabled for this organisation during Final C, so current App Store / Google Play guidance was **not** fetched. Guideline references below come from prior knowledge and are labelled "ref (unverified this session)". Nothing here asserts legal or platform compliance. Repo evidence refers to `ronganminh/rep-counter-ai-ios` @ `3594d8a`.

Status: **READY** (design + current code satisfy it for the current feature set) · **NEEDS CODE** · **NEEDS POLICY REVIEW** · **BLOCKED** (missing owner input) · **UNKNOWN**.

| # | Item | Design state | Current code (VERIFIED) | Status | Notes |
|---|---|---|---|---|---|
| R-01 | App Store privacy "nutrition" labels / Play Data safety | Data flows designed (local-first, AI numbers only, sync later) | `PrivacyInfo.xcprivacy` (UserDefaults reason); `check_app_store_readiness.py` gate in CI | NEEDS POLICY REVIEW | Must be redone when accounts, sync, AI Coach, ads, purchases ship |
| R-02 | Camera usage description | Camera explanation screen precedes the OS prompt; video never leaves the device | `NSCameraUsageDescription` EN + `vi.lproj/InfoPlist.strings`; Android `CAMERA` | READY (current scope) | Re-review copy if pose data use changes |
| R-03 | Photo library add usage | Share → Save image | `NSPhotoLibraryAddUsageDescription` present; `gal` | READY | |
| R-04 | AI consent | P4-08, FA-05, `aiConsentBody` key | `ai_consent.dart`, versioned `2026-10-01-groq` | READY (feedback) · NEEDS POLICY REVIEW (coach chat) | Provider named in privacy policy? Legal to confirm |
| R-05 | Account deletion in app | P9-11e flow + separate history scopes (A-01) | No accounts today | NEEDS CODE (when accounts ship) · NEEDS POLICY REVIEW | ref (unverified this session): Apple 5.1.1(v); Google Play account-deletion requirement incl. web link |
| R-06 | Login providers | P9-02–05 | none | BLOCKED (D-12) | If third-party social login ships, Sign in with Apple may be required — ref 4.8 (unverified this session) |
| R-07 | In-app purchase transparency | P8 plan cards with SDK price, renewal disclosure key | none | NEEDS CODE · NEEDS POLICY REVIEW | `proRenewalDisclosure` wording needs legal sign-off; prices only from SDK |
| R-08 | Restore purchases | P8-10, Profile row, Pro screen | none | NEEDS CODE | Must be reachable without purchase |
| R-09 | Subscription renewal / cancellation disclosure | P8-03/07 copy | none | NEEDS POLICY REVIEW | ref (unverified): Apple 3.1.2 |
| R-10 | External purchase links (Lemon Squeezy) | Web-only in design | none | NEEDS POLICY REVIEW | Not linked from apps unless policy review allows |
| R-11 | Rewarded ads disclosure | Android opt-in, cap 3/day (proposed), hidden on iOS, never in workouts | none | NEEDS CODE · NEEDS POLICY REVIEW | Ad SDK not chosen; regional consent (e.g. GDPR/UMP) UNKNOWN |
| R-12 | Notification permission | Pre-permission + denied recovery (P10) | none (diag-only POST_NOTIFICATIONS) | NEEDS CODE | Android 13 runtime permission |
| R-13 | User data export | Local export + cloud export flow (P9-11b) | Local CSV/JSON export | READY (local) · NEEDS CODE (cloud) | |
| R-14 | Social privacy, blocking, reporting | P7-10 | none | NEEDS CODE · NEEDS POLICY REVIEW | User-generated content policies apply once social ships |
| R-15 | Offline data handling | Local-first, sync states, tombstones | Local only, 100-record cap | NEEDS CODE (DB + sync) | D-16 |
| R-16 | Support & legal pages | FA-12, placeholders | backend `/support.html`, `/terms.html`, `/privacy-policy.html` exist | BLOCKED (D-14) | Owner must confirm canonical URLs and support email; no response-time promise |
| R-17 | Accessibility | Final C a11y audit | `Semantics` in ~15 files | NEEDS CODE | Chips hit area, contrast D-24/D-25, Dynamic Type goldens |
| R-18 | Localization EN/VI | ARB 4,286 keys | hand-written `S` + `context.tr` | NEEDS CODE (gen-l10n migration) · native review pending | |
| R-19 | App version/build display | `[APP_VERSION] ([BUILD_NUMBER])` | pubspec 2.0.0+8 | NEEDS CODE (`package_info_plus`) | |
| R-20 | Store screenshots / listing | App Store EN screenshots (v1 era, unchanged per brief) | `store_listing/*` EN/VI | NEEDS POLICY REVIEW | Screenshots show the 3-tab v1 UI; refresh needs a separately approved task |
| R-21 | Age rating / kids | — | — | UNKNOWN | Social + AI chat may change rating |
| R-22 | Encryption export compliance | — | `ITSAppUsesNonExemptEncryption=false` | READY (current) | Re-check when auth/crypto added |
| R-23 | Health/fitness claims | "For training reference only, not medical advice" copy exists in designs | — | NEEDS POLICY REVIEW | |
