# 00 · Baseline audit — RepCoach AI v1 → v2 (Final C)

| Item | Value |
|---|---|
| Audit date | 2026-10-22 |
| Repository | `ronganminh/rep-counter-ai-ios` |
| `main` HEAD audited | `5a61ab8ba46264d2049ede43b4941302f45b23cf` ("fix(ios): synchronize App Store release version") |
| Design package baseline | Final C handoff, audited against `3594d8a` (one commit behind; the delta is the Settings version string + `tool/check_app_store_readiness.py`) |
| Handoff archive | `RepCoach-AI-Final-C-Handoff.zip`, SHA-256 `91beb84f36a5c7523c03627bc73fd39e8bf26bf8e2ba872a6762e1f11b4461ae` |
| Manifest check | `handoff/ASSET_MANIFEST.json`: **23/23 document files match SHA-256**; 21 `evidence/*.png` listed but not shipped in the first archive; delivered later in `RepCoach-AI-Final-C-DesignSource-Evidence.zip` together with `design-source/project/*.dc.html` + `canvas.json` — **21/21 evidence files match SHA-256**; design-source checksums recorded in `docs/design/v2-final-c/DESIGN_SOURCE_SHA256.txt` (not in the manifest) |
| Copied to | `docs/design/v2-final-c/` (unmodified; brief at `docs/design/v2-final-c/REPCOACH_AI_CLAUDE_IMPLEMENTATION_MASTER.md`) |

Labels: **VERIFIED** = read from code or produced by a command in this audit · **UNVERIFIED** = not checked, with the reason stated.

## 1 · Toolchain and build configuration (VERIFIED)

| Area | Fact | Evidence |
|---|---|---|
| App location | `rep-counter-ai-main/rep_counter_app` (monorepo also holds `backend/`, `contracts/`, notebooks, store listing, old `design-handoff/`) | tree |
| Flutter / Dart | CI pins Flutter **3.47.5** stable; locally verified Flutter 3.47.5 · Dart 3.13.4. `pubspec.yaml` says `sdk >=3.4.0`, but `pubspec.lock` requires Dart ≥3.12 / Flutter ≥3.44 | `.github/workflows/*.yml`, `pubspec.lock` |
| App version | `2.0.0+8` (Settings row hard-codes `'2.0.0 (8)'`) | `pubspec.yaml`, `lib/features/legal/settings_page.dart` |
| Android | Gradle 9.3.1, AGP 9.1.0, Kotlin 2.4.0, Java 17; `applicationId com.ronganminh.repcoach`; flavors `store` / `diag` (`.diag` suffix, screen recording, `.aab` packaging blocked for diag) | `android/app/build.gradle.kts`, `android/gradle/wrapper/gradle-wrapper.properties` |
| Android signing | `key.properties` (gitignored, not in repo); CI test-release creates a temporary key | `android/app/build.gradle.kts`, `android-test-release.yml` |
| iOS | Bundle `com.ronganminh.repCounterApp`, min iOS 15.5, iPhone only, Automatic signing, Team `NW22NWLTK4`, CocoaPods (SPM disabled), `Podfile.lock` not committed, **no `.entitlements`**, no iOS flavor/scheme equivalent to `diag` | `ios/Runner.xcodeproj/project.pbxproj`, `ios/Podfile` |
| Env management | `--dart-define` only: `AI_BASE_URL` (default `https://repcoach-ai.duckdns.org`), `ENABLE_ALL_EXERCISES`, `ENABLE_PULL_UP`, `ENABLE_AI_FEEDBACK` (**declared, unused**), `REPCOACH_CI_VIDEO_ASSET` | `lib/core/config/feature_flags.dart`, `lib/features/ai/ai_feedback_service.dart`, `lib/main.dart` |
| Secrets | None in git. Backend `.env.example` has empty keys. CI secret name `VPS_SSH_KEY` only | `backend/.env.example`, `production-ops-check.yml` |

## 2 · Architecture as implemented (VERIFIED)

- **Navigation:** Navigator 1.0 + `MaterialPageRoute`; no named routes, no deep links, no router package. `main.dart` → `OnboardingPage` (pref `onboarding_v1`) or `AppShell` (3-tab `NavigationBar`: Train / History / Settings). `appRouteObserver` refreshes Home on `didPopNext`.
- **State:** plain `ChangeNotifier` / `ValueNotifier`; no Provider/Riverpod/Bloc.
- **Theme:** tokens in `lib/theme/` (`app_colors`, `app_spacing`, `app_radius`, `app_typography`, `app_motion`, `app_theme`); `lib/core/theme/app_theme.dart` is a compatibility shim. `ThemeMode.dark` forced. Fonts bundled: Inter (variable), Barlow Condensed **800 only**. Shared widgets: `lib/widgets/product_ui.dart` (`SectionLabel`, `SettingsGroup`, `SettingsRow`, `SegmentChip`, `MetricCard`).
- **Camera session:** `lib/camera_page.dart` (1,572 lines) owns `CameraController`, ML Kit `PoseDetector`, lifecycle suspend/resume, calibration, CI replay mode, diag recording, rest overlay, pause/finish. Session logic in `features/workout/application/workout_controller.dart` (`WorkoutUiState`/`WorkoutUiPhase`).
- **Pose & counting (protected):** `features/pose/domain/pose_mapper.dart`, `lib/placement.dart`, `lib/rep_counter.dart` (Schmitt trigger, 1-1 port of the Python notebook, vector test `test/rep_vector.json`), `features/workout/domain/rep_tracker.dart`, quality analyzers. Exercise profiles in `lib/exercise.dart`: push_up (visible), curl, overhead_extension, pull_up (diag / `ENABLE_PULL_UP` only; release gate BLOCKED).
- **Results:** `features/workout/presentation/result_page.dart` + `result_controller.dart` + widgets (`result_hero`, `form_score_details`, `rep_pace_chart`, `result_feedback_card`, `timed_challenge_result`) → `StoryPage`.
- **Local persistence:** SharedPreferences only. Keys: `workout_history_v1` (**capped at 100 valid records**, serialised writes), `routine_presets_v1`, `earned_achievements_v1`, `training_*_v1`, `app_language`, `automatic_ai_consent_2026_10_01_groq`, calibration, `onboarding_v1`.
- **History:** `features/workout/presentation/history_page.dart` (1,131 lines) with progress statistics, detail, delete + undo; export via Settings → `ExportDataSheet`.

## 3 · Feature matrix

| Feature | Design source (Final C) | Verified code path | State | Backend dependency | Risk | Proposed task |
|---|---|---|---|---|---|---|
| Camera permission + camera session | FA-02, v1 Camera C0–C4 | `lib/camera_page.dart`, `widgets/camera_permission_view.dart`, `permission_handler` | implemented | none | `camera_page.dart` is large; real camera only verifiable on device | W-1 (view only) |
| Pose + rep counting engine | MASTER §14, v1 HUD | `lib/rep_counter.dart`, `rep_tracker.dart`, `placement.dart`, `pose_mapper.dart` | implemented (push-up) | none | Replay baselines are regression-only (`human_ground_truth: null`) | none (protected) |
| Other exercises | v2 P1–P8, D-28 | `lib/exercise.dart`, `feature_flags.dart` | partial (flagged) | none | Pull-up gate BLOCKED; no squat profile | E-1 ("coming soon") |
| Calibration / countdown | FA-09, v1 C0–C4 | `camera_page.dart` `_toggleCalibration`, `workout/data/calibration_store.dart` | implemented | none | — | W-1 |
| HUD | v1 HUD A0–F1, FA-10 | `widgets/workout_hud.dart` | implemented (v1 look) | none | HIGH: must not touch counting | W-1, W-2 |
| Hold-to-finish / exit / lifecycle | FA-10 | `workout_hud.dart`, `camera_page.dart` `_confirmExit`, `_suspendCamera` | implemented | none | Double-finish idempotency to prove | W-2 |
| Interrupted-workout recovery | FA-10, D-06 | — | missing | none | Hot-path writes | F-4, W-5 |
| Results | FA-03/05, v1 R1–R2 | `result_page.dart` + widgets | implemented (v1 look) | AI card only | — | W-3 |
| AI feedback | P4-02, FA-05 | `features/ai/ai_feedback_service.dart` → `POST /v1/workout-feedback`; consent `features/ai/presentation/ai_consent.dart` | implemented | **VERIFIED EXISTING** (Groq `openai/gpt-oss-20b`, consent `2026-10-01-groq`) | No client auth; duckdns host | W-3 |
| Local history | P3-07/08, FA-07 | `history_page.dart`, `workout_history_store.dart` | implemented | none | 100-record cap; no `clientId`; prefs JSON | H-1, F-3 |
| Progress analytics / records | P3-01…06 | `progress_statistics.dart`, `workout_personal_records.dart` | partial | none | Hosted inside History today | H-1 |
| Routines / plan-today | P2 | `features/routine/*`, `plan/presentation/plan_today_sheet.dart` | partial (single-day) | none | — | PL-1, PL-2 |
| Achievements | P5-07…09 | `features/achievements/*` (6 local) | partial | none (server XP proposed) | — | G-1 (blocked) |
| Story / share | FA-06, P7-09 | `features/share/story_page.dart` | partial (no toggles) | none | — | W-3 |
| Export | P9-11 | `features/history/export/*` | implemented (local) | none | — | — |
| Voice / sounds / haptics | P6 | `core/services/workout_feedback.dart`, `set_sounds.dart`, `legal/voice_cadence_page.dart` | implemented | none | Device-only verification | — |
| Onboarding | v1 A1–A3, FA-01/02 | `features/legal/onboarding_page.dart` | implemented (v1) | none | — | N-1 |
| 5-tab shell | D-01, component #1 | `lib/app/app_shell.dart` (3 tabs) | missing | none | Must keep Camera→Result root flow | N-1 |
| Deep links / router | APP_NAVIGATION_MAP §1, §5 | — | missing | none (local) | Platform config | N-2 |
| Auth / guest / account | P9-01…06 | grep auth/login/oauth/firebase/supabase = 0 hits | missing | **UNKNOWN/BLOCKED** (D-12) | Do not invent provider | A-1, A-2 (blocked) |
| Sync | FA-04, gap §5 | — | missing | **PROPOSED NEW** | Needs local DB + clientId first | F-3 → A-2 (blocked) |
| Generic API client | gap §3 | only `http` inside `AiFeedbackService` | missing | — | — | introduced with A-1 |
| Credits / entitlements / billing | P8, D-08/D-10/D-13/D-14 | none (5 grep hits are legal copy) | missing | **PROPOSED NEW** | No product IDs, no iOS IAP capability | AI-1, P-1, P-2 (blocked) |
| Social | P7 | none | missing | **PROPOSED NEW** | — | S-1, S-2 (blocked) |
| Notifications | P10 | none (`POST_NOTIFICATIONS` only in `diag` manifest for the recorder) | missing | local: none · push: **PROPOSED NEW** | No Push entitlement | NT-1 (local), NT-2 (blocked) |
| Localization (vi/en) | l10n ARB, D-04 | `core/i18n/app_strings.dart` (`S`), `locale_controller.dart`, **395** inline `context.tr('vi','en')` calls | partial | none | No `flutter_localizations` → Material strings English-only | F-1, L-1, L-2 |
| Accessibility | FINAL_QA §6, D-24, D-25 | 51 `Semantics`/`semanticLabel` sites; `SegmentChip`; goal chips `minHeight: 40` | partial | none | 40 px chips; `text3` on cards 4.36:1 | DS-1, DS-2, Q-1 |
| Build metadata / config | F-2, D-14 | `LegalConfig` (email, privacy URL), Settings version literal | partial | none | Hard-coded version drifts (fixed by hand in `5a61ab8`) | F-2 |

## 4 · Tests and CI (VERIFIED by command output)

Local run on Linux, Flutter 3.47.5, at `5a61ab8`:

| Command | Result |
|---|---|
| `flutter analyze --fatal-infos` | `No issues found! (ran in 29.6s)` |
| `flutter test` | `+406: All tests passed!` (README says 302; handoff says 333 — both stale) |
| `python -m unittest discover -s tests` (backend) | `Ran 94 tests … OK` |
| `python3 tool/check_app_store_readiness.py` | `PASS: App Store static release gates for 2.0.0 (8)` |

- 39 Dart test files (unit + widget + visual render); **no `integration_test/`**. Fixtures: `test/rep_vector.json`, pull-up JSON fixtures, `test/fixtures/video_ground_truth.json`. Replay videos are downloaded in CI from the `ci-fixtures` release (not in git).
- Workflows (8): `ios-ci.yml` (RepCoach CI: analyze/test + iOS simulator replay matrix pushup-1/pushup-2/pushup-rest-regression + unsigned release build), `android-replay.yml` (informational), `android-test-release.yml`, `backend-ci.yml`, `staging-integration-ci.yml`, `app-store-readiness.yml`, `production-readiness.yml`, `production-ops-check.yml`.
- Latest completed runs on `main`: RepCoach CI #193–#195 **failed** only in "App Store release build → Verify App Store source metadata" (analyze/test and all 3 iOS replays green in #195); `5a61ab8` fixes that gate. RepCoach CI #196 and Android Replay #8 were in progress at audit time (result not observed). Android Replay #7 green.
- Live API probe (read-only): `GET https://repcoach-ai.duckdns.org/health` → 200 `{"status": "ok"}`; `GET /ready` → 200.

## 5 · Backend access and API contract (VERIFIED)

The backend lives in this repository (`rep-counter-ai-main/backend`, stdlib `http.server`, no database, no auth). Contract: `rep-counter-ai-main/contracts/workout_feedback_v2.json`.

| Screen/feature | Request | Endpoint | Auth | Request/response | Evidence | Status | Error/retry |
|---|---|---|---|---|---|---|---|
| Results AI card | POST | `/v1/workout-feedback` | none (nginx IP rate limit) | `WorkoutRecord.toAiPayload()` + `schema_version 2`, `consent_version`, `locale` → `{schema_version: 1, feedback}` | `ai_feedback_service.dart`, `server.py` | VERIFIED EXISTING | 25 s timeout; `AiFeedbackFailure` timeout/offline/server; offline `RuleBasedFeedback` |
| Ops | GET | `/health`, `/ready` | none | `{status}` | `server.py` | VERIFIED EXISTING | — |
| Legal/support pages | GET | `/privacy-policy.html`, `/terms.html`, `/support.html` | none | HTML | `server.py`, `LegalConfig.privacyPolicyUrl` | VERIFIED EXISTING (owner to confirm canonical, D-14) | — |
| Auth, sync, credits, entitlements, social, push, account deletion | — | none | — | — | none | UNKNOWN/BLOCKED (proposed contracts only in `API_AND_BACKEND_GAP_ANALYSIS.md` §3) | — |

No separate backend repository is referenced. `Juliolayme/rep-counter-ai` (private) appears in the account's repo list but was **not opened** (outside this session's scope); the brief names it as a read-only legacy engine reference.

## 6 · Discrepancies between the brief, the handoff and the repository

| # | Topic | Brief / handoff says | Repository says | Resolution |
|---|---|---|---|---|
| X-1 | Baseline commit | Handoff audited `3594d8a` | `main` is `5a61ab8` | Delta is cosmetic (version string + readiness script); handoff still valid |
| X-2 | Test count | Handoff: 333 tests; README: 302 | 406 passing | Use 406 as baseline |
| X-3 | Task order | Brief: W0 → W1 design foundations first | Roadmap: F-1 (gen-l10n) first; DS-2 depends on F-1 | Follow the roadmap's dependency graph, but schedule DS-1 (no deps) first as the owner asked; see `01_TASK_DEPENDENCIES.md` |
| X-4 | Touch-target fix | Brief §7: ≥ 44 pt | Roadmap/tokens: 48 dp (`AppSpacing.minTouch`) | Implement 48 dp (satisfies both) |
| X-5 | Contrast fix | Brief §7: caption ≥ 4.5:1 | D-25 offers "use `text2` on surfaces" or "lighten `text3`" | Use existing `text2` (no invented colour value) |
| X-6 | Router | Brief §4: deep links return to destination | D-15 go_router is PROPOSED | N-1 keeps Navigator 1.0 (reversible); router decision deferred to N-2 |
| X-7 | Auth guards | Brief §3 puts auth guards in W2 | Roadmap puts them in N-2/A-1, behind backend auth | Guards wait for A-1; auth is BLOCKED (D-12) |
| X-8 | History cap | Handoff: 100-record cap | `WorkoutHistoryStore` keeps 100 records | Confirmed; F-3 needs D-16 approval |
| X-9 | `ENABLE_AI_FEEDBACK` | Mapping: declared but unused | declared, unused | Leave until a cleanup PR; documented |
| X-10 | Legal values | Handoff: placeholders `[SUPPORT_EMAIL]` etc. | Repo ships real values (`ronganminh221@gmail.com`, duckdns URLs) | F-2 keeps shipping values as defaults (not invented), overridable; owner to confirm (D-14) |

## 7 · Key risks

See `02_RELEASE_RISK_REGISTER.md`. Top three: engine regressions from HUD/Results work; every account/billing/social/push feature is blocked on backend and owner decisions; replay baselines are not human ground truth.
