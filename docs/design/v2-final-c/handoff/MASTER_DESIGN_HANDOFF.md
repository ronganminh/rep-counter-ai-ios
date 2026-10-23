# MASTER_DESIGN_HANDOFF

**RepCoach AI v2 · Final C · Master design handoff** · 2026-10-22
Design workspace: Claude Design canvas "RepCoach AI" (published version recorded in `FINAL_QA_REPORT.md`) · Implementation target: `ronganminh/rep-counter-ai-ios` @ `3594d8a` (Flutter `rep_counter_app` 2.0.0+8).

> Read with: `SCREEN_TO_FLUTTER_MAPPING.md` (every screen → route/widget/status) · `APP_NAVIGATION_MAP.md` · `DESIGN_SYSTEM_TOKENS.json` · `COMPONENT_REGISTRY.md` · `API_AND_BACKEND_GAP_ANALYSIS.md` · `FLUTTER_IMPLEMENTATION_ROADMAP.md` · `PRODUCT_DECISIONS.md` · `l10n/` · `FINAL_QA_REPORT.md` · `REPO_AUDIT.md`.
> Labels: **VERIFIED** = read from code/canvas in this session · **PROPOSED** = design assumption, needs sign-off · **SIMULATED** = prototype-only behaviour.

## 1 · Product overview

RepCoach AI counts exercise repetitions with the phone camera (on-device pose detection), then turns workouts into progress, plans, coaching and friendly competition. Today's shipping app (VERIFIED) is a local-only push-up counter: camera + ML Kit pose + Schmitt-trigger rep engine, results with form score, history/progress, routines, timed challenge, 6 local achievements, TTS cadence, export, story share, optional anonymous AI text feedback (Groq), EN/VI. The approved v2 design adds a 5-tab shell, exercise library, multi-day plans, analytics, AI Coach + credits, gamification, voice coach, friends/races, Pro subscriptions, accounts with guest mode, sync, notifications and complete support/privacy flows.

## 2 · Design principles

1. **Training never waits for the network or an account.** Guest mode trains, saves and shows history locally.
2. **The engine is the truth.** Reps come only from the production engine; accepted reps never decrease; manual reps are labelled manual.
3. **Nothing interrupts a live workout.** No tab bar, paywall, ad, toast or push over the HUD; pushes are held.
4. **Honest states.** Every save, sync, purchase and AI request shows its real state (saved locally / waiting / synced / failed); Pro only after verification; one charge per request.
5. **Calm, premium, dark.** #0B0B0C background, #C8FF2E accent for one primary action, Barlow Condensed for numbers/headings, Inter for UI, Lucide icons, flat surfaces.
6. **Bilingual by default.** Every string is a key; Vietnamese is first-class (default language in today's app).
7. **Privacy by design.** Video never leaves the device; diagnostics reviewable; destructive actions scoped and typed-confirmed.

## 3 · Navigation architecture

Five tabs `Home | Exercises | Train | Progress | Profile`; Train opens the start sheet. Full-screen root routes for onboarding, auth, the workout flow, results, payment, destructive and permission flows. Auth gate with `returnTo`; guest → account merge with dry-run and conflicts. Details and back-stack rules: `APP_NAVIGATION_MAP.md`.

## 4 · Screen inventory

536 designed frames in 162 families across 31 active boards (v1 Foundation incl. Design System and Flow viewer 39 · Home/Exercises 13 · Phases 2–10 423 · Final A 54 · Final B prototype 1 phone frame with 39 routes · App Store/icon art 6). Full list with frame IDs, sizes, mapping family, proposed route, status and priority: `SCREEN_INVENTORY.csv`. Family-level mapping: `SCREEN_TO_FLUTTER_MAPPING.md`.

## 5 · Canonical user journeys

22 integrated journeys (Final B) + 12 negative paths (Final C), all runnable in the integrated prototype with one shared state and an EN/VI switch:

| # | Journey | # | Journey |
|---|---|---|---|
| 1 | New user → onboarding → guest → first workout | 12 | Guest → Friends → auth → return to Friends |
| 2 | Camera denied → manual tracking | 13 | Guest data → account migration |
| 3 | Exercise library → train → results → history | 14 | Friends → challenge invite → head-to-head |
| 4 | Workout interrupted → recovery | 15 | Social notification → challenge |
| 5 | Offline save → sync later | 16 | Pro discovery → purchase (simulated) |
| 6 | Results → AI feedback | 17 | Restore subscription |
| 7 | Results → share preview | 18 | Profile → Settings → language |
| 8 | Home → plan → scheduled workout | 19 | Profile → Privacy → delete history safely |
| 9 | Progress → personal records | 20 | Notification → deep link → destination |
| 10 | Progress → achievements | 21 | Profile → Help / Support |
| 11 | AI Coach → credits → contextual paywall | 22 | Live workout → pause/resume → finish |
| N1 | Tracking lost → counting paused → resumes | N7 | Purchase pending (Ask to Buy) → approved |
| N2 | Cloud sync failure → retry → synced once | N8 | Restore fails → retry → restored |
| N3 | Duplicate save attempt → one record | N9 | Notification permission denied → inbox works |
| N4 | AI feedback off → turn on | N10 | Expired deep link → safe fallback |
| N5 | Expired session → sign in → return | N11 | Incomplete workout (0 reps) → nothing saved |
| N6 | Guest merge conflict → resolve → no duplicates | N12 | App interrupted → auto-pause → resume → finish |

## 6 · Business rules and canonical sample data

Canonical sample (Tue, Oct 20, 2026): before the 6:41 PM workout 14 workouts · 572 reps · streak 9 · LV 4 370/500 XP · October 500 at 227/500; the Push & core builder workout adds 35 camera push-ups + 20 core reps + 1:15 plank in 17:40 → **15 workouts · 627 reps · 6:05 held · 2:55 training time · 10-day streak · LV 4 395/500 XP · October 500 262/500 · 323 all-time camera push-ups · record 35 (prev 34, Oct 8)**. Free AI 7 of 10 left (resets Sun, Oct 25). Final C fixed the one remaining inconsistency (Home H1 showed 340/500 XP).

Rules (status in `PRODUCT_DECISIONS.md`): history deletion keeps earned XP/achievements (D-05) · 12 h recovery window (D-06) · basic AI feedback free (D-07) · proposed limits 10/60/3/7 days (D-08) · idempotency per clientId/requestId/source (D-09) · Pro only after verification (D-10) · manual ≠ camera-verified (D-18) · hypothetical/demo sessions never merge into canonical history (prototype tags demo runs "not the canonical sample").

## 7 · State machines

**Workout session (bind to VERIFIED `WorkoutUiPhase`):**
```
positioning ─stable 1.5 s─▶ ready ─▶ (calibrating) ─▶ countdown 3-2-1 ─▶ active ⇄ paused
active ─routine set done─▶ resting ─▶ active        active/paused ─hold 1 s / finish─▶ ending ─▶ saving ─▶ done ─▶ ResultPage
any ─abort (confirmed discard)─▶ aborted          app background ─▶ paused (camera released)          process killed ─▶ [next launch] recovery (NEW)
```
**Save/sync per workout (PROPOSED):** `localSaved → queued → uploading → synced` · `uploading → failed(retryable) → queued` · `deleted(tombstone)`; key = clientId.
**AI feedback (VERIFIED `ResultFeedbackPhase`):** `idle → loading → ready | offline | error | unavailable`; plus design states `off` (consent/setting) and `queued`.
**Auth (PROPOSED, Phase 9):** `guest → authenticating → authenticated ⇄ tokenRefreshing → sessionExpired → reauth`; `authenticated → signingOut → guest (local kept)`; `deletingAccount → guest`.
**Entitlement (PROPOSED):** `free → purchasing → pending | verifying → pro | failed(free)`; `pro → grace | billingRetry | expired | revoked → free`.
**Merge (PROPOSED):** `preview → (conflict → resolved) → working → done | failed(rollback to guest namespace)`.
**Notification permission:** `notAsked → prePrompt → (osPrompt) → granted | denied`; "Not now" keeps `notAsked`.

## 8 · UI components

Canonical registry with sources, variants, states, Flutter mapping and deprecated variants: `COMPONENT_REGISTRY.md`. Tokens: `DESIGN_SYSTEM_TOKENS.json` (values cross-checked against repo `lib/theme/*`).

## 9 · Error states (pattern)

Status hero or banner + one recovery action + what is safe. Catalogue: camera denied / unavailable / tracking lost / no person; save failed (retry, nothing lost); offline save; sync failed (auto-retry + Retry now); duplicate detected (kept once); AI off / consent missing / offline / timeout / provider error (retry free) / no credits (contextual paywall); auth invalid / expired / too many attempts; merge conflict / merge failed; purchase cancelled / pending / verification failed / restore none / restore failed; notification denied; deep link expired / missing; delete failed / partial; support send failed (offline queue); generic error; empty states (no workouts, no friends, no search results).

## 10 · Accessibility

WCAG 2.1 AA target. Measured: text 17.84:1, text2 7.65:1 on bg (7.03:1 on cards); text3 4.74:1 on bg but 4.36:1 on cards (D-25); accent on bg 16.68:1; onAccent on accent 16.68:1. Touch targets ≥ 44 pt / 48 dp (40 px chips need padded hit areas, D-24). Live regions for the rep counter, sync and status banners. Every icon-only control labelled (prototype: 0 unlabeled buttons). Dynamic Type to 200 % without truncating primary actions. Reduced motion: no pulses/shimmer; hold-to-finish keeps 1 s with static fill. VoiceOver/TalkBack labels are in the ARB files (e.g. `notifBellLabel`, `workoutRepCounterLabel`).

## 11 · Localization

`l10n/app_en.arb` + `l10n/app_vi.arb`: **4,286 keys**, ICU-validated, identical key sets. 151 canonical keys (ICU plurals/placeholders) for implementation, 824 existing human-written pairs (shipping app + prototype + phase tables), 3,311 machine-assisted translations **that need native review** (localization QA = PARTIAL). Static visible-string coverage 99.96 % (7,071 / 7,074; the 3 remaining are canvas annotations) → details in `l10n/UNTRANSLATED_STRINGS_AUDIT.md`. Glossary: `l10n/LOCALIZATION_GLOSSARY.md`. Prices always from the store SDK. Dates/times/numbers via `intl` (VI 24-hour, `T3, 20/10`). Barlow Condensed + Inter Vietnamese glyphs VERIFIED (web subsets and the repo's bundled TTFs).

## 12 · Platform differences

iOS: StoreKit sheet, Ask to Buy pending, Manage subscriptions in App Store, Sign in with Apple likely required if third-party login ships (REQUIRES VERIFICATION), no rewarded ads by default. Android: Play Billing, rewarded ads opt-in (cap 3/day proposed), system Back on HUD opens the leave sheet, `POST_NOTIFICATIONS` runtime permission (Android 13+). Web: Lemon Squeezy only.

## 13 · Implementation constraints

1. **Engine protection (CRITICAL)** — §14.
2. Integrate into the existing architecture (plain Flutter + ChangeNotifier, feature-first folders, SharedPreferences stores); add packages only per the roadmap.
3. Keep the 333 Dart tests and 8 CI workflows green; video-replay CI must keep passing with unchanged rep baselines.
4. No hard-coded prices, product IDs, URLs, emails, versions; use the unresolved config placeholders until owners provide values.
5. No production coding was done in Final C.

## 14 · Camera & workout engine protection

**Preserve exactly (VERIFIED components):** `CameraPage` camera pipeline (`CameraController`, NV21/BGRA8888 image stream), ML Kit `PoseDetector` (`PoseDetectionModel.base`), `PoseMapper`, `PlacementStatus`/`GuideZone`/`StatusDebouncer`, `CountGateLatch`, `RepCounter` (Schmitt trigger, `minPeriod` 500 ms), `RepTracker` events (`RepStarted`, `RepReachedBottom`, `RepCompleted`, `RepAborted{signalLost, placementLost, reset}`), `SessionTracker` (never decrements), `WorkoutController` (`requestStart`, `pause`, `acceptRep`, `finish`, `abort`, lifecycle suspend/resume), `WorkoutAggregator`/`WorkoutSummary`, `WorkoutHistoryStore.save`, `pushReplacement(ResultPage)`, `permission_handler` camera flow, timing clocks (tracking vs session).

**Design → engine mapping**

| Design state / element | Engine source of truth |
|---|---|
| HUD counter value | `WorkoutUiState` rep count (from accepted `RepCompleted`) — never a UI counter |
| Positioning guide, "step into frame" | `PlacementStatus`, `GuideZone` |
| Ready / countdown | `WorkoutUiPhase.ready/countdown` (1500 ms stable, 3-2-1, cancel > 750 ms not ready) |
| Calibrating | `WorkoutUiPhase.calibrating`, `Calibrator`, `CalibrationStore` |
| Tracking paused banner (Final C) | `RepAborted(placementLost/signalLost)` + `RepFeedbackKind.poseLost/placementInterrupted`; clears on `repSignalRestored()` |
| Paused overlay | `WorkoutUiPhase.paused` (manual) / lifecycle suspend |
| Rest overlay | `WorkoutUiPhase.resting`, `RoutineRestOverlay`, `skipRoutineRest()` |
| Hold to finish (1 s) | `AppMotion.holdToEnd` → `WorkoutController.finish()` (single `Completer`) |
| Discard | `WorkoutController.abort()` |
| Saving → results | `ending → saving → done` → `pushReplacement(ResultPage(record, offerAutomaticAi: true))` |
| Rep quality chips / form score | `RepQualityAnalyzer`, `RepQualityFlag`, `QualityScore` |
| Recovery prompt (NEW) | PROPOSED `WorkoutDraftStore` written on each accepted rep/set (debounced), read at startup; never re-counts |

**Regression test plan (required before merging any HUD/Results change):**
1. Existing CI video replay (iOS simulator matrix pushup-1/2/rest-regression; Android emulator pushup-1/rest-regression) — rep counts must equal `test/fixtures/video_ground_truth.json` baselines; no reps during annotated rest.
2. Unit: `rep_counter_test.dart` vectors unchanged; `workout_controller` tests for pause/resume/finish idempotency (double finish → one save); monotonicity property test (count never decreases across RepAborted).
3. Widget/golden: HUD states (active, paused, tracking lost, resting, holding) in EN/VI at 393×852 and 375×667.
4. Integration: finish → one `WorkoutRecord` in `WorkoutHistoryStore`; ResultPage shows the same reps/duration; History list shows it once; delete/undo restores identical record.
5. Lifecycle: background during active set → paused, camera released, no rep accepted while backgrounded; resume continues count.
6. Recovery (new): kill during set → relaunch → Resume continues from the saved count; Save partial creates one partial record; expired (> window) offers only Save/Discard.
7. Manual: manual entries saved with `source: manual` and excluded from challenge/race totals.
8. Performance: frame processing budget unchanged (compare `frameProcessed` timings before/after UI change on the CI replay).
