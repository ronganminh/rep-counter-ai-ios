# FLUTTER_IMPLEMENTATION_ROADMAP

RepCoach AI · Final C · 2026-10-22 · target repo `ronganminh/rep-counter-ai-ios` @ `3594d8a`

> Small, dependency-aware PRs integrated progressively into the existing production app. **No PR may change rep-counting results**: every PR that touches `lib/camera_page.dart`, `lib/rep_counter.dart`, `lib/exercise.dart`, `lib/placement.dart` or `features/workout/**` must pass the iOS and Android video-replay workflows with unchanged baselines. Paths marked PROPOSED do not exist yet.

## Suggested sequence

```
F-1 → F-2 → DS-1 → DS-2 → N-1 → W-1 → W-2 → W-3 → E-1 → H-1 → (F-3 → F-4 → W-5, W-4) → PL-1 → PL-2 → NT-1 → L-1
   → [backend auth/sync ready] A-1 → A-2 → H-2 → N-2 → AI-1 → AI-2 → G-1 → S-1 → S-2 → P-1 → P-2 → NT-2 → L-2 → Q-1 → Q-2
```

Release cut suggestion: **v2.1 (no backend changes)** = F-1…F-4, DS, N-1, W-1…W-5, E-1, H-1, PL-1/2, NT-1, L-1 · **v2.2+** = accounts, sync, AI Coach, social, billing, push.

## Foundation

### F-1 · Add gen-l10n infrastructure without changing UI

- **Prerequisites:** —
- **Expected files/modules:** `pubspec.yaml` (+`flutter_localizations`, `intl`), `l10n.yaml`, `lib/l10n/app_en.arb`, `app_vi.arb` (from this package), `MaterialApp.localizationsDelegates/supportedLocales`
- **Acceptance criteria:** App builds; `AppLocalizations.of(context)` available; existing `LocaleController` drives `locale`; Material widgets localized in VI
- **Required tests:** Widget test: switch EN↔VI updates a sample key; ARB key parity test
- **CI:** `flutter analyze --fatal-infos`, `flutter test`, iOS + Android video replay (rep baselines unchanged) + gen-l10n step
- **Regression risks:** Locale resolution change (system → persisted) must keep current behaviour
- **Depends on:** —

### F-2 · Build metadata + config placeholders

- **Prerequisites:** —
- **Expected files/modules:** `package_info_plus`; `lib/core/config/app_config.dart` (PROPOSED) holding `[SUPPORT_EMAIL]`, URLs, product IDs as dart-defines
- **Acceptance criteria:** About shows `[APP_VERSION] ([BUILD_NUMBER])` from metadata; no hard-coded URLs/emails
- **Required tests:** Unit test: config defaults are placeholders, never invented values
- **CI:** `flutter analyze --fatal-infos`, `flutter test`, iOS + Android video replay (rep baselines unchanged)
- **Regression risks:** Accidentally shipping placeholders → release checklist gate
- **Depends on:** F-1

### F-3 · Local DB for workouts (remove 100-record cap) with migration

- **Prerequisites:** D-16 approved
- **Expected files/modules:** `lib/features/workout/data/` (drift or sqflite, PROPOSED), migration from `workout_history_v1`
- **Acceptance criteria:** All existing records migrate once; cap removed; `clientId` (UUID) added to every record; reads/writes behind `WorkoutHistoryStore` API
- **Required tests:** Migration tests with fixture prefs; idempotent re-run
- **CI:** `flutter analyze --fatal-infos`, `flutter test`, iOS + Android video replay (rep baselines unchanged)
- **Regression risks:** Data loss on migration — keep prefs copy until verified
- **Depends on:** F-1

### F-4 · Workout draft persistence for recovery

- **Prerequisites:** F-3, D-06
- **Expected files/modules:** `WorkoutDraftStore` (PROPOSED), hooks in `WorkoutController` after accepted reps (debounced)
- **Acceptance criteria:** Kill during set → relaunch shows recovery; resume continues count; save partial = 1 record; window configurable (12 h default)
- **Required tests:** Controller tests + integration test with simulated kill; replay CI unchanged
- **CI:** `flutter analyze --fatal-infos`, `flutter test`, iOS + Android video replay (rep baselines unchanged)
- **Regression risks:** Writes on hot path → debounce, measure frame budget
- **Depends on:** F-3

## Design System

### DS-1 · Extend theme tokens to Final C token file

- **Prerequisites:** —
- **Expected files/modules:** `lib/theme/app_colors.dart`, `app_radius.dart`, `app_motion.dart`, `app_typography.dart`
- **Acceptance criteria:** textMuted, info, radius 10/14, sheet/page motion added; Barlow 600/700 bundled or designs restricted (D-26)
- **Required tests:** Golden tests of `product_ui.dart` widgets unchanged except intended
- **CI:** `flutter analyze --fatal-infos`, `flutter test`, iOS + Android video replay (rep baselines unchanged)
- **Regression risks:** Accidental colour drift
- **Depends on:** —

### DS-2 · Shared widgets: AppButton, AppBanner, AppToast, StatusHero, StatTile, ChallengeMeter, SyncStatusBadge, TypeToConfirmField, PrivacyBadge

- **Prerequisites:** DS-1
- **Expected files/modules:** `lib/widgets/` (+ existing `product_ui.dart`)
- **Acceptance criteria:** Each widget: Semantics label, 48 dp targets, text scale 2.0 safe, EN/VI goldens
- **Required tests:** Golden tests EN/VI, 393×852 + 375×667, scale 1.0/1.3
- **CI:** `flutter analyze --fatal-infos`, `flutter test`, iOS + Android video replay (rep baselines unchanged) + goldens
- **Regression risks:** Golden flakiness across platforms — pin fonts
- **Depends on:** DS-1, F-1

## Navigation

### N-1 · 5-tab shell (Home, Exercises, Train, Progress, Profile) replacing the 3-tab `AppShell`

- **Prerequisites:** DS-2, D-15
- **Expected files/modules:** `lib/app/app_shell.dart` → `AppTabScaffold`, `TrainTabButton`; router (go_router PROPOSED) with StatefulShellRoute
- **Acceptance criteria:** Tabs per design; Train opens sheet; tab bar hidden on root routes; `appRouteObserver` still refreshes Home; existing screens reachable (History under Progress, Settings under Profile)
- **Required tests:** Widget tests for tab switching, stack preservation, Back behaviour
- **CI:** `flutter analyze --fatal-infos`, `flutter test`, iOS + Android video replay (rep baselines unchanged)
- **Regression risks:** Breaking `CameraPage → ResultPage` flow — keep it on root navigator
- **Depends on:** DS-2

### N-2 · Deep links + auth `returnTo` plumbing

- **Prerequisites:** N-1
- **Expected files/modules:** router config, `repcoach://` scheme + universal links (iOS `apple-app-site-association`, Android App Links)
- **Acceptance criteria:** All links in APP_NAVIGATION_MAP §5 resolve; stale targets show fallbacks; no deep link opens over a live workout
- **Required tests:** Router unit tests per link; widget tests for fallbacks
- **CI:** `flutter analyze --fatal-infos`, `flutter test`, iOS + Android video replay (rep baselines unchanged)
- **Regression risks:** Platform config mistakes
- **Depends on:** N-1

## Authentication

### A-1 · Auth provider + guest/authenticated state machine

- **Prerequisites:** D-12 decided
- **Expected files/modules:** `lib/features/auth/*` (PROPOSED), secure token storage
- **Acceptance criteria:** Guest default; sign in/up/out; session expiry → re-auth sheet keeping local data; notifications/entitlements untouched by sign-in
- **Required tests:** State-machine unit tests; widget tests of gate/returnTo
- **CI:** `flutter analyze --fatal-infos`, `flutter test`, iOS + Android video replay (rep baselines unchanged)
- **Regression risks:** Blocking training behind auth — forbidden
- **Depends on:** N-2, backend auth

### A-2 · Guest → account merge (dry-run, conflicts)

- **Prerequisites:** A-1, F-3, backend sync API
- **Expected files/modules:** `MigrationController`, `MergePreview`
- **Acceptance criteria:** Matches by clientId; conflicts must be resolved before upload; nothing counted twice; failure rolls back to guest namespace
- **Required tests:** Integration tests with fake server: matched/new/conflict/failure
- **CI:** `flutter analyze --fatal-infos`, `flutter test`, iOS + Android video replay (rep baselines unchanged) + staging contract smoke
- **Regression risks:** Duplicates or loss on merge
- **Depends on:** A-1

## Exercise Library

### E-1 · Exercises tab: library, search, detail, demo

- **Prerequisites:** N-1
- **Expected files/modules:** `features/exercises/presentation/*` (extend `ExercisePickerScreen`)
- **Acceptance criteria:** Only enabled exercises start workouts; others "coming soon"; detail shows PR
- **Required tests:** Widget tests incl. flags `ENABLE_ALL_EXERCISES`
- **CI:** `flutter analyze --fatal-infos`, `flutter test`, iOS + Android video replay (rep baselines unchanged)
- **Regression risks:** Exposing exercises without engine profiles
- **Depends on:** N-1

## Camera & Workout UI

### W-1 · Restyle HUD to v2 bound to `WorkoutUiState` (no engine change)

- **Prerequisites:** DS-2
- **Expected files/modules:** `widgets/workout_hud.dart`, `camera_page.dart` (view code only)
- **Acceptance criteria:** All HUD states (positioning…saving) match design; counter only from engine; tracking-lost banner from `RepAborted`/feedback kinds; nothing overlays HUD
- **Required tests:** HUD goldens EN/VI; controller tests; **video replay rep baselines identical**
- **CI:** `flutter analyze --fatal-infos`, `flutter test`, iOS + Android video replay (rep baselines unchanged) (mandatory replay)
- **Regression risks:** HIGH — counting regressions; review by engine owner
- **Depends on:** DS-2

### W-2 · Hold-to-finish, Back sheet, discard confirm, double-finish idempotency

- **Prerequisites:** W-1
- **Expected files/modules:** `HoldToFinishButton`, exit sheet
- **Acceptance criteria:** Quick tap shows hint; 1 s hold finishes once; Android Back opens sheet; double finish → one record
- **Required tests:** Widget + controller tests
- **CI:** `flutter analyze --fatal-infos`, `flutter test`, iOS + Android video replay (rep baselines unchanged)
- **Regression risks:** Accidental save/discard
- **Depends on:** W-1

### W-3 · Results v2 + AI card states + share preview toggles

- **Prerequisites:** W-1
- **Expected files/modules:** `result_page.dart`, `result_feedback_card.dart`, `story_page.dart`
- **Acceptance criteria:** Saved/partial/offline/sync states; AI off/consent/loading/ready/failed (retry free); share toggles hide name/reps/date
- **Required tests:** Widget tests; AI MockClient tests unchanged
- **CI:** `flutter analyze --fatal-infos`, `flutter test`, iOS + Android video replay (rep baselines unchanged) + staging AI smoke
- **Regression risks:** Breaking existing AI consent flow
- **Depends on:** W-1

### W-4 · Manual tracking + guided timer

- **Prerequisites:** W-1, F-3
- **Expected files/modules:** `ManualLogPage`, `GuidedTimerPage`, record `source` field
- **Acceptance criteria:** Manual reps saved as manual, excluded from camera challenges
- **Required tests:** Unit + widget tests
- **CI:** `flutter analyze --fatal-infos`, `flutter test`, iOS + Android video replay (rep baselines unchanged)
- **Regression risks:** Mislabelling manual as camera
- **Depends on:** F-3

### W-5 · Recovery screen

- **Prerequisites:** F-4
- **Expected files/modules:** `RecoveryPage`
- **Acceptance criteria:** Resume / Save partial / Discard (confirm); expired → no Resume
- **Required tests:** Integration test
- **CI:** `flutter analyze --fatal-infos`, `flutter test`, iOS + Android video replay (rep baselines unchanged)
- **Regression risks:** Silent discard — forbidden
- **Depends on:** F-4

## Plans

### PL-1 · Multi-day plan model, setup flow, overview, day detail

- **Prerequisites:** N-1
- **Expected files/modules:** `features/plan/*` (extend `PlanTodaySheet`, routines)
- **Acceptance criteria:** Week view with done/missed/moved/recovery; start session uses routine engine mode
- **Required tests:** Unit tests for schedule rules (moved keeps reminder)
- **CI:** `flutter analyze --fatal-infos`, `flutter test`, iOS + Android video replay (rep baselines unchanged)
- **Regression risks:** Conflict with existing routines
- **Depends on:** N-1

### PL-2 · Reschedule missed session

- **Prerequisites:** PL-1
- **Expected files/modules:** `RescheduleSheet`
- **Acceptance criteria:** Move to a day; history unchanged; reminder follows
- **Required tests:** Unit tests
- **CI:** `flutter analyze --fatal-infos`, `flutter test`, iOS + Android video replay (rep baselines unchanged)
- **Regression risks:** —
- **Depends on:** PL-1

## History & Progress

### H-1 · Progress tab split from History; records, streaks, form trends

- **Prerequisites:** N-1
- **Expected files/modules:** `history_page.dart` → `ProgressPage` + `HistoryListPage`
- **Acceptance criteria:** Totals computed once (single source); delete recalculates totals but keeps XP/achievements
- **Required tests:** Statistics unit tests (existing) + new
- **CI:** `flutter analyze --fatal-infos`, `flutter test`, iOS + Android video replay (rep baselines unchanged)
- **Regression risks:** Double-counting partials
- **Depends on:** N-1

### H-2 · History delete scopes + tombstones

- **Prerequisites:** F-3, A-1 (account scope)
- **Expected files/modules:** privacy pages, `TypeToConfirmField`
- **Acceptance criteria:** Phone/account/both separate; account deletion separate flow
- **Required tests:** Widget + integration
- **CI:** `flutter analyze --fatal-infos`, `flutter test`, iOS + Android video replay (rep baselines unchanged)
- **Regression risks:** Deleting the wrong scope
- **Depends on:** H-1

## AI Coach

### AI-1 · Credits ledger client + usage UI

- **Prerequisites:** backend credits API
- **Expected files/modules:** `CreditsController`, `CreditsChip`
- **Acceptance criteria:** Balance from server only; one charge per requestId; retry not charged twice
- **Required tests:** MockClient tests for idempotency
- **CI:** `flutter analyze --fatal-infos`, `flutter test`, iOS + Android video replay (rep baselines unchanged) + staging
- **Regression risks:** Client-side counting drift
- **Depends on:** A-1

### AI-2 · Coach chat + analysis + contextual paywall

- **Prerequisites:** AI-1, P-1
- **Expected files/modules:** `features/coach/*`
- **Acceptance criteria:** Paywall only after user action and never during workouts
- **Required tests:** Widget tests
- **CI:** `flutter analyze --fatal-infos`, `flutter test`, iOS + Android video replay (rep baselines unchanged)
- **Regression risks:** Paywall placement
- **Depends on:** AI-1

## Gamification

### G-1 · Server XP/levels, achievements sync, challenges

- **Prerequisites:** backend XP/challenges
- **Expected files/modules:** `features/achievements/*` (extend), challenges feature
- **Acceptance criteria:** Awards idempotent; reopening notification never re-awards; deletion keeps earned
- **Required tests:** Unit tests
- **CI:** `flutter analyze --fatal-infos`, `flutter test`, iOS + Android video replay (rep baselines unchanged)
- **Regression risks:** Duplicate awards
- **Depends on:** A-1

## Social

### S-1 · Friends, requests, block/report

- **Prerequisites:** A-1, backend social
- **Expected files/modules:** `features/social/*`
- **Acceptance criteria:** Guest → gate; privacy defaults; block/report present
- **Required tests:** Widget + contract tests
- **CI:** `flutter analyze --fatal-infos`, `flutter test`, iOS + Android video replay (rep baselines unchanged)
- **Regression risks:** Privacy leaks
- **Depends on:** A-1

### S-2 · Races/head-to-head, leaderboards

- **Prerequisites:** S-1
- **Expected files/modules:** social feature
- **Acceptance criteria:** Camera-counted only; server-verified results
- **Required tests:** Unit + widget
- **CI:** `flutter analyze --fatal-infos`, `flutter test`, iOS + Android video replay (rep baselines unchanged)
- **Regression risks:** Counting manual reps
- **Depends on:** S-1

## Premium & Billing

### P-1 · Store integration (StoreKit / Play Billing) + server verification

- **Prerequisites:** D-13, D-14 config, backend verify
- **Expected files/modules:** `in_app_purchase`, `PurchaseController`, `EntitlementController`
- **Acceptance criteria:** Prices from SDK; pending/failed keep Free; Pro only after verification; restore works
- **Required tests:** Fake store tests; sandbox manual test plan
- **CI:** `flutter analyze --fatal-infos`, `flutter test`, iOS + Android video replay (rep baselines unchanged) + store sandbox checklist
- **Regression risks:** HIGH — store rejection / entitlement bugs
- **Depends on:** A-1

### P-2 · Membership/manage/restore UI, rewarded ads (Android)

- **Prerequisites:** P-1
- **Expected files/modules:** membership pages, ad SDK (TBD)
- **Acceptance criteria:** Ads opt-in, capped, never in workouts; hidden on iOS
- **Required tests:** Widget tests
- **CI:** `flutter analyze --fatal-infos`, `flutter test`, iOS + Android video replay (rep baselines unchanged)
- **Regression risks:** Policy violations
- **Depends on:** P-1

## Notifications

### NT-1 · Local reminders + permission flow

- **Prerequisites:** PL-1
- **Expected files/modules:** `flutter_local_notifications`, `ReminderScheduler`
- **Acceptance criteria:** Pre-permission before OS prompt; denied state; quiet hours; moved session keeps reminder; held during workouts
- **Required tests:** Unit tests for schedule; widget tests
- **CI:** `flutter analyze --fatal-infos`, `flutter test`, iOS + Android video replay (rep baselines unchanged)
- **Regression risks:** Notification spam
- **Depends on:** PL-1

### NT-2 · Push + inbox + deep links

- **Prerequisites:** NT-1, N-2, backend push
- **Expected files/modules:** push SDK, `InboxPage`
- **Acceptance criteria:** Stale links → fallback; no XP on reopen
- **Required tests:** Router + widget tests
- **CI:** `flutter analyze --fatal-infos`, `flutter test`, iOS + Android video replay (rep baselines unchanged)
- **Regression risks:** Token handling
- **Depends on:** NT-1

## Localization

### L-1 · Migrate inline `context.tr` and `S` fields to ARB keys

- **Prerequisites:** F-1
- **Expected files/modules:** all features (394 call sites)
- **Acceptance criteria:** No inline strings left; VI copy preserved verbatim from `S.vi` keys
- **Required tests:** Lint/grep test: no `context.tr(` remaining; ARB parity
- **CI:** `flutter analyze --fatal-infos`, `flutter test`, iOS + Android video replay (rep baselines unchanged)
- **Regression risks:** Copy drift
- **Depends on:** F-1

### L-2 · Native VI review of machine-assisted keys + parameterise sample-data strings

- **Prerequisites:** F-1
- **Expected files/modules:** ARB files
- **Acceptance criteria:** Reviewer sign-off; 899 sample-data strings parameterised or removed
- **Required tests:** ARB ICU validation test
- **CI:** `flutter analyze --fatal-infos`, `flutter test`, iOS + Android video replay (rep baselines unchanged)
- **Regression risks:** Untranslated or awkward copy
- **Depends on:** L-1

## QA & Release

### Q-1 · Accessibility pass (VoiceOver/TalkBack, Dynamic Type, contrast)

- **Prerequisites:** DS-2
- **Expected files/modules:** all screens
- **Acceptance criteria:** All issues in FINAL_QA_REPORT a11y section closed
- **Required tests:** Manual + golden
- **CI:** `flutter analyze --fatal-infos`, `flutter test`, iOS + Android video replay (rep baselines unchanged)
- **Regression risks:** —
- **Depends on:** DS-2

### Q-2 · Release readiness gate

- **Prerequisites:** all tracks for release scope
- **Expected files/modules:** store metadata, privacy labels, `check_app_store_readiness.py`
- **Acceptance criteria:** RELEASE_CHECKLIST all READY or explicitly deferred
- **Required tests:** Existing readiness workflows
- **CI:** `flutter analyze --fatal-infos`, `flutter test`, iOS + Android video replay (rep baselines unchanged) + app-store-readiness.yml
- **Regression risks:** Store rejection
- **Depends on:** all
