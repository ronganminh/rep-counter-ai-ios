# PRODUCT_DECISIONS

RepCoach AI · Product Decision Register · Final C · 2026-10-22

Status: **CONFIRMED** = approved in an earlier phase brief or verified in shipping code · **PROPOSED** = design assumption awaiting owner sign-off · **REQUIRES VERIFICATION** = depends on backend, legal or store policy that has not been verified. Nothing here is production configuration.

| ID | Decision | Status | Evidence / source | Owner to approve |
|---|---|---|---|---|
| D-01 | Five tabs `Home \| Exercises \| Train \| Progress \| Profile`; Train is the centre action; no further tabs | CONFIRMED | Final B brief B-01; prototype | Product |
| D-02 | Tab bar hidden on onboarding, auth, camera/HUD, results, payment, destructive and permission flows; nothing overlays the HUD. Permission flows: a pre-permission screen has one action, "Continue" / "Tiếp tục", that always leads to the OS prompt; no "Allow" wording, no "Not now" or close before the prompt; after a denial, Open Settings (+ fallback). App Store 5.1.1(iv), rule changed 2026-10-28 (L-D24) | CONFIRMED | Final B B-02; App Review 2026-10-27 | Product / Design |
| D-03 | Dark theme only for v2; light palette exists in code but is not designed | CONFIRMED (dark) · light = out of scope | repo `AppPalette.light`, `main.dart` forces `ThemeMode.dark` | Design |
| D-04 | English + Tiếng Việt at launch; Vietnamese uses shipping-app terms (rep, set, streak, huy hiệu, Tiến bộ, Xóa) | PROPOSED (glossary) | `l10n/LOCALIZATION_GLOSSARY.md`; repo `S.vi` | Product + native VI reviewer |
| D-05 | Deleting a workout does **not** revoke earned XP or achievements; totals/records/streak/charts recalculate; server may correct invalid, fraudulent or duplicate rewards; verified competition results stay server-authoritative | PROPOSED (A-04) | Final A cleanup | Product + Backend |
| D-06 | Interrupted workout recovery window 12 h, configurable; never silently discard a saved workout; one record only | PROPOSED (A-05) | FA-10e; Final C N3/N12 tests | Product + Mobile |
| D-07 | Basic post-workout AI feedback is free; advanced analysis, coach conversations and progress reviews may consume credits | PROPOSED | Phase 8; prototype J6/J11 | Product |
| D-08 | Free 10 eligible AI requests/week; Pro 60/week; Android rewarded-ad cap 3/day; offline Pro entitlement cache ≤ 7 days | **10 Free / 60 Pro ACCEPTED as placeholder values for staging (owner, 2026-10-29, 06 Q5)**; not final production pricing; rest PROPOSED | Phase 8 handoff | Product + Backend + Finance |
| D-09 | Idempotency: one AI charge per `requestId`; one workout per `clientId`; one XP award per `(user, source)`; reopening a notification never awards XP | **DECIDED (owner, 2026-10-29, 06 Q1)**: enforced by unique keys in the database | API gap §3; Final B/C tests | Backend |
| D-10 | Entitlement only after server-side purchase verification; pending (Ask to Buy) and failed verification keep Free | CONFIRMED (design rule) · implementation REQUIRES VERIFICATION | Final B B-12; N7/N8 | Backend |
| D-11 | Guest mode available for basic workouts; account required for cloud sync and eligible social features, AI Coach chat and purchases | CONFIRMED (Phase 9) | prototype J12/J13 | Product |
| D-12 | Auth provider(s) and login methods (email, Apple, Google) | **DECIDED (owner, 2026-10-23): Supabase Auth; Google + Apple + email/password** | Client behind `ENABLE_ACCOUNTS` (off); setup steps in `docs/implementation/05_SUPABASE_SETUP.md`; decision log L-D03 | Product + Legal |
| D-13 | Billing: iOS StoreKit / Apple IAP; Android Google Play Billing; Lemon Squeezy web-only unless a verified policy review allows otherwise | CONFIRMED (direction) · policy REQUIRES VERIFICATION | Phase 8 | Product + Legal |
| D-14 | Store prices, product IDs, trial terms, renewal copy, support email, Terms/Privacy URLs, app version/build, store approval status | **Support and legal DECIDED (owner, 2026-10-27, as declared in App Store Connect / Google Play for v1):** SUPPORT_EMAIL = `ronganminh221@gmail.com` · SUPPORT_URL = `https://repcoach-ai.duckdns.org/support.html` · PRIVACY_URL = `https://repcoach-ai.duckdns.org/privacy-policy.html` · TERMS_URL = `https://repcoach-ai.duckdns.org/terms.html` · Website = `https://repcoach-ai.duckdns.org/`. **Still open:** `[Annual price]`, `[Monthly price]`, `[PRODUCT_ID_*]`, trial terms, renewal copy (billing stays off); `[APP_VERSION] ([BUILD_NUMBER])` comes from build metadata; `[TICKET_REFERENCE]` is generated per ticket | Owner D-14 message; values in `AppConfig` (overridable with `--dart-define`); decision log L-D04 / L-D23 | Product + Legal (prices: Product + Finance) |
| D-15 | Introduce `go_router` (StatefulShellRoute) incrementally; keep the camera→results imperative flow | PROPOSED | APP_NAVIGATION_MAP §1 | Mobile tech lead |
| D-16 | Move workout storage from SharedPreferences (100-record cap) to a local DB before cloud sync | PROPOSED | repo audit §4 | Mobile tech lead |
| D-17 | The production camera/pose/rep engine (ML Kit + `RepTracker`/`RepCounter`/`WorkoutController`) is the only source of reps; the new UI binds to it; accepted reps never decrement | CONFIRMED | repo; Final C engine protection section | Mobile tech lead |
| D-18 | Manual reps are labelled manual, never camera-verified, and don't count toward camera challenges, races or leaderboards | CONFIRMED (design) | prototype J2; P5/P7 copy | Product |
| D-19 | Notification permission independent of auth; local reminders need no backend; pushes held during workouts | CONFIRMED (Phase 10/Final B) | | Product |
| D-20 | History deletion scopes: phone / account / both; account deletion is a separate flow | CONFIRMED (A-01) | FA-08, P9-11e | Product + Legal |
| D-21 | Diagnostics: user reviews before sending; never passwords, tokens, payment details, camera footage; AI conversations, precise location, attachments opt-in only | CONFIRMED (A-06) | FA-12d | Product + Legal |
| D-22 | No response-time guarantee for support | CONFIRMED (A-06) | | Support |
| D-23 | Type-to-confirm word: `DELETE` (EN); VI accepts `XÓA` (proposed) | PROPOSED | v1 S3 used "XÓA"; Final A FA-08 uses DELETE | Product |
| D-24 | Chips/segments: 40 px visual is acceptable only with a ≥ 48 dp hit area in Flutter | PROPOSED (Final C a11y) | layout audit (P4–P7) | Design + Mobile |
| D-25 | Secondary caption colour `text3` (#7C7C82) on cards is 4.36:1 — use `text2` for body-size text on surfaces, or lighten `text3` | PROPOSED (Final C a11y) | contrast audit | Design |
| D-26 | Bundle Barlow Condensed 600 and 700 in addition to 800 (designs use all three) or restrict designs to 800 | PROPOSED | repo pubspec bundles 800 only | Design + Mobile |
| D-27 | October 500 and other challenge names are product names (not translated) | PROPOSED | glossary | Product |
| D-28 | Squat, sit-up and other exercises remain "coming soon" until engine profiles exist | CONFIRMED (repo) | `ExercisePickerScreen` placeholders | Product |
| PL-1 | Multi-day workout plans. (1) Default beginner plan: 3 workouts a week, Mon/Wed/Fri, Full Body A/B/C. (2) 2–6 planned sessions a week; user picks weekdays, exercises, sets, rep targets, duration targets and supported tracking modes. (3) Missed sessions are never moved automatically: marked missed, user-controlled rescheduling offered. (4) Recovery days are first-class calendar states; workout reminders skip them. (5) Progressive overload optional and OFF by default; suggestions need user confirmation and never change prescriptions automatically. (6) Guests create, follow and save basic plans locally without registration | **DECIDED (owner, 2026-10-26)** — supersedes the Phase 2 prototype defaults (4 days, 2–5 sessions) | Owner PL-1 specification; implementation notes in `docs/implementation/03_DECISION_LOG.md` L-D19 | Product |
| BE-1 | Backend data model for sync, credits, XP, social, billing and push (`docs/implementation/06_SUPABASE_SCHEMA_PROPOSAL.md` §10). Q1 conventions: tombstones instead of deletes, server-authoritative tables, `server_seq` sync cursor. Q2 the cloud copy of a workout keeps `rep_details`. Q3 tombstones are kept 90 days, then purged. Q4 manual and guided-timer workouts earn XP at a reduced rate, never for challenges or races. Q5 AI allowance 10 Free / 60 Pro per week (placeholder). Q6 profiles are not discoverable by display name; friends only via invite links. Q7 report retention and moderation owner: decided by Legal (no automatic purge until then). Q8 production project in the staging region (Tokyo), created only after staging sign-off | **DECIDED (owner, 2026-10-29)** — all eight proposals accepted | 06 §10; decision log L-D30 | Product + Backend (Q7: Legal) |
| BE-2 | Social limits (S-1): invites valid 7 days, at most 20 open invites per user, at most 20 reports per user per day, friends leaderboard per week from Monday 00:00 UTC | **DECIDED (owner, 2026-10-29)** — accepted as proposed in #82 | decision log L-D31 | Product |

## Legal / store-policy questions (not verified in this session — web access was unavailable)

1. Account deletion in-app requirement and web-deletion link (App Store / Google Play) — needed before accounts ship.
2. Subscription disclosure wording, renewal/cancellation terms, free-trial presentation, restore-purchases placement.
3. Whether any non-store purchase path may be linked from the apps (Lemon Squeezy).
4. Rewarded ads: disclosure and regional rules; whether iOS shows rewarded ads at all (Phase 8 default: hidden on iOS).
5. Camera usage purpose strings (exist in repo `Info.plist` + `InfoPlist.strings` EN/VI) — re-review copy against final features.
6. Data safety (Play) / privacy nutrition labels (App Store) once accounts, sync, AI and analytics change data flows.
7. AI consent text vs privacy policy (provider: Groq per repo docs) — legal review.
8. Children / age rating for social features and AI chat.
