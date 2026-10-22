# RepCoach AI — Repository Audit (design-to-code handoff)

- Repo: `rep-counter-ai-ios` (local clone, history depth 50)
- HEAD: `3594d8a7de6ab2c55ce72e0cb54341ea82183a9a` — 2026-10-19T14:11:17+07:00 — "ci(android): raise replay timeout for the long rest-regression video"
- Audit mode: read-only. All paths below are relative to the repo root unless noted. `APP` = `rep-counter-ai-main/rep_counter_app`.
- Legacy engine repo `Juliolayme/rep-counter-ai` is NOT accessible. It is referenced once: `rep-counter-ai-main/docs/CHUYEN_MAY.md:3` ("Repo trên GitHub: `Juliolayme/rep-counter-ai` (private, nhánh `main`)"). `rep-counter-ai-main/MIGRATION_NOTES.md` states `rep_counter_app/` *is* the legacy Flutter engine and source of truth for camera/ML Kit/rep detection/records/AI transport; `design-handoff/` is the source of truth for UX. So the engine code appears to be vendored here.

## TL;DR

The app is a **local-only, single-exercise (push-up) camera rep counter** with a 3-tab shell (Train | History | Settings), on-device ML Kit pose detection, a Schmitt-trigger rep engine, results with form score, local history/progress analytics, routines (sets+rest), timed challenge, 6 local achievements, TTS voice cadence, CSV/JSON export, a story-image share, and an **optional AI text feedback** call to a tiny Python backend (Groq LLM). **There is no auth, no account, no cloud sync, no billing/premium, no AI credits, no AI coach chat, no XP/leaderboards/friends, no notifications/reminders, no named routing.** EN + VI localization exists via a hand-written string class (no ARB). Strong test suite (333 Dart tests + 94 Python tests) and 8 CI workflows including real-video replay on iOS simulator and Android emulator.

---

## 1. Flutter app structure

### pubspec (`APP/pubspec.yaml`)
- `name: rep_counter_app` (line 1); description (VI): "Đếm rep tập luyện thời gian thực bằng camera và MediaPipe Pose." (note: runtime actually uses Google ML Kit, MediaPipe is used only in Python notebooks/tools)
- `version: 2.0.0+8` (line 4)
- `environment.sdk: ">=3.4.0 <4.0.0"` (line 7). `pubspec.lock` `sdks`: dart `>=3.12.0 <4.0.0`, flutter `>=3.44.0`. `docs/CHUYEN_MAY.md` says dev Flutter 3.47.
- Dependencies (constraint → locked):
  | package | constraint | locked |
  |---|---|---|
  | camera | ^0.11.0 | 0.11.4 |
  | google_mlkit_pose_detection | ^0.15.0 | 0.15.0 (commons 0.12.0) |
  | permission_handler | ^11.3.1 | 11.4.0 |
  | file_picker | ^12.2.0 | 12.3.0 |
  | image | ^4.3.0 | 4.10.1 |
  | video_player | ^2.9.2 | 2.14.0 |
  | shared_preferences | ^2.3.3 | 2.5.5 |
  | http | ^1.2.2 | 1.6.0 |
  | lucide_icons_flutter | ^3.1.20 | 3.1.20 |
  | flutter_tts | ^4.2.5 | 4.2.5 |
  | share_plus | ^13.3.0 | 13.3.0 |
  | gal | ^2.3.3 | 2.3.3 |
  | url_launcher | ^6.3.2 | 6.3.2 |
  | audioplayers | ^6.8.1 | 6.8.1 |
- dev: flutter_test, camera_platform_interface ^2.14.0, flutter_lints ^4.0.0, flutter_launcher_icons ^0.14.4.
- Assets: `assets/audio/` (set-start.wav, set-end.wav), `assets/vnext/`; fonts Inter, Barlow Condensed 800.
- NOT present: flutter_localizations/intl, go_router, provider/riverpod/bloc/get_it, firebase_*, supabase, in_app_purchase, purchases_flutter (RevenueCat), flutter_local_notifications, firebase_messaging, sqflite/drift/hive/isar, wakelock.

### lib/ tree (82 .dart files in lib; 124 tracked .dart files total incl. 41 tests + `tool/staging_contract_smoke.dart`)
```
lib/
  main.dart                 RepCounterApp (MaterialApp root, onboarding gate, CI video mode)
  camera_page.dart          CameraPage (1572 lines: camera, ML Kit, gating, HUD host)
  exercise.dart             ExerciseProfile, Landmarks, CountGateLatch; pushUp/pullUp/dumbbellCurl/overheadExtension
  rep_counter.dart          RollingMean, RepCounter, TwoArmMerger, SessionTracker, Calibrator
  placement.dart            PlacementStatus, GuideZone, StatusDebouncer
  overlay_painter.dart, guide_template.dart, local_video_test_page.dart (debug-only)
  app/ app_shell.dart (3-tab NavigationBar), route_observer.dart
  core/ config/feature_flags.dart, i18n/{app_strings,exercise_help,locale_controller}.dart,
        legal/legal_config.dart, services/{app_links,set_sounds,training_preferences,workout_feedback}.dart,
        theme/app_theme.dart
  features/
    achievements/ achievement.dart, achievement_service.dart, presentation/achievement_earned_card.dart
    ai/ ai_feedback_service.dart, ai_preferences.dart, presentation/ai_consent.dart
    diag/ diag_recorder.dart (MethodChannel 'repcoach/diag', diag flavor only)
    exercises/presentation/exercise_picker_screen.dart
    history/ history_statistics.dart, progress_statistics.dart, export/{export_data_sheet,workout_export_service}.dart
    home/presentation/home_screen.dart
    legal/ legal_page.dart, onboarding_page.dart, settings_page.dart, voice_cadence_page.dart
    onboarding/presentation/onboarding_art.dart
    plan/presentation/plan_today_sheet.dart
    pose/domain/pose_mapper.dart
    routine/ data/routine_store.dart, domain/routine_preset.dart, presentation/{rest_overlay,routine_editor_page,routine_list_page}.dart
    share/story_page.dart
    workout/ application/{rep_feedback,result_controller,workout_controller,workout_ui_state}.dart
             data/{calibration_store,workout_history_store,workout_record}.dart
             domain/{quality_thresholds,rep_metric,rep_quality_analyzer,rep_tracker,rule_based_feedback,set_metric,
                     workout_aggregator,workout_mode,workout_personal_records,workout_state,workout_summary}.dart
             presentation/{exercise_help_sheet,exercise_icon,feedback_card,goal_setup_page,history_page,result_page}.dart
             presentation/widgets/{camera_permission_view,form_score_details,rep_feedback_pill,rep_pace_chart,
                     result_feedback_card,result_hero,timed_challenge_result,workout_hud}.dart
  theme/ app_colors, app_motion, app_radius, app_spacing, app_theme (RepCoachTheme), app_typography
  widgets/product_ui.dart   SectionLabel, SettingsGroup, SettingsRow, SegmentChip, MetricCard
```

### State management / DI / layers
- State management: plain Flutter — `StatefulWidget` + `setState`, `ChangeNotifier` (`WorkoutController`, `ResultController`), `ValueNotifier` (`LocaleController`), `InheritedNotifier` (`LocaleScope`, `core/i18n/locale_controller.dart:46`), `ValueListenableBuilder` in `main.dart`. No third-party state lib.
- DI: none (no container). Constructor injection with defaults, e.g. `WorkoutController(saveRecord: ...)` defaults to `WorkoutHistoryStore().save`; `ResultController({analyze, saveFeedback, configured})`; `WorkoutFeedback({SpeechDriver? speech, haptic, sound})`; `AiFeedbackService({http.Client? client, baseUrlOverride})`. Stores are instantiated ad hoc (`WorkoutHistoryStore()`).
- Layers actually used: feature-first with `domain/` (pure Dart engine + models), `application/` (controllers, UI-state projection), `data/` (SharedPreferences stores), `presentation/` (widgets). Core engine pieces still live at `lib/` root (`camera_page.dart`, `rep_counter.dart`, `placement.dart`, `exercise.dart`) per `MIGRATION_NOTES.md` ("Keep stable; extract incrementally").
- Feature flags (`core/config/feature_flags.dart`): `ENABLE_ALL_EXERCISES` (default false), `ENABLE_AI_FEEDBACK` (default false — declared but **not referenced** anywhere else in lib), `mvpExerciseId='push_up'`, `enablePullUp` = `ENABLE_PULL_UP` dart-define or `appFlavor=='diag'`.

## 2. Route / screen inventory

- Navigation system: **Navigator 1.0 imperative** (`Navigator.push/pushReplacement/pop` with `MaterialPageRoute`), `showModalBottomSheet`, `showDialog`. **No named routes, no `routes:`/`onGenerateRoute`, no go_router.** One `RouteObserver` (`app/route_observer.dart: appRouteObserver`) used by `AppShell` (`RouteAware.didPopNext`) to refresh Home.
- Root (`main.dart:58-78`): `MaterialApp(home: ...)` chooses `CameraPage(ciVideoPath)` if `REPCOACH_CI_VIDEO_ASSET` dart-define set; else spinner → `OnboardingPage` (if pref `onboarding_v1` false) → `AppShell`. `themeMode: ThemeMode.dark` forced.
- Bottom tabs (`app/app_shell.dart`, `NavigationBar`, 3 destinations): index 0 "Tập/Train" → `HomeScreen`; 1 History (`s.historyTitle`) → `HistoryPage(onTrain)`; 2 Settings → `SettingsPage`. **Not 5 tabs**; no Exercises/Progress/Profile tabs (progress analytics live inside `HistoryPage`).

| Screen widget | File | Reached from | Purpose |
|---|---|---|---|
| `RepCounterApp` | lib/main.dart | root | app root, onboarding gate |
| `OnboardingPage` | features/legal/onboarding_page.dart | root | 3-page intro (camera / privacy / safety), sets `onboarding_v1` |
| `AppShell` | app/app_shell.dart | root | 3-tab shell |
| `HomeScreen` | features/home/presentation/home_screen.dart | tab 0 | push-up card, plan sheet, routines, latest result, debug video test |
| `ExercisePickerScreen` | features/exercises/presentation/exercise_picker_screen.dart | Home | grid; only push_up enabled (pull-up in diag); squat/sit-up/jumping jack/lunge shown as placeholders (not available) |
| `showPlanTodaySheet` → `GoalSetupContent` | features/plan/presentation/plan_today_sheet.dart | Home / Train tab | modal sheet: free / target reps / timed → pushes `CameraPage` |
| `GoalSetupPage` | features/workout/presentation/goal_setup_page.dart | Home (other exercises when flags on) | same goal setup as page; pushReplacement `CameraPage` |
| `RoutineListSection` (embedded), `RoutineEditorPage` | features/routine/presentation/ | Home | routine presets CRUD; start → `CameraPage(routine:)` |
| `CameraPage` | lib/camera_page.dart | sheet/goal/routine | permission, positioning, calibration, countdown, HUD (`WorkoutHud`), pause, rest overlay, finish |
| `ResultPage` | features/workout/presentation/result_page.dart | CameraPage (pushReplacement, `offerAutomaticAi: true`), History/Home (`readOnly: true`) | result hero, form score, pace chart, timed result, AI feedback card, achievements, delete, share |
| `_FormScoreDetailsPage` | presentation/widgets/form_score_details.dart | ResultPage | form score breakdown (also as bottom sheet) |
| `StoryPage` | features/share/story_page.dart | ResultPage | renders story card, share (share_plus) / save to Photos (gal) |
| `HistoryPage` | features/workout/presentation/history_page.dart | tab 1 | progress: range 7d/30d/90d/all, exercise filter, summary metrics, personal records, trend bars, heatmap, session list; opens `ResultPage(readOnly)` with delete/undo |
| `SettingsPage` | features/legal/settings_page.dart | tab 2 | language, training prefs (coaching/voice/sound/cues/haptics), voice cadence, calibration, privacy/terms, export, delete local data, feedback/review |
| `VoiceCadencePage` | features/legal/voice_cadence_page.dart | Settings | rep speech cadence selection |
| `CalibrationSettingsPage` | features/legal/settings_page.dart | Settings | view/reset calibration |
| `LegalPage(kind: LegalKind.privacy/terms)` | features/legal/legal_page.dart | Settings/Onboarding/AI consent | legal text |
| `ExportDataSheet` | features/history/export/export_data_sheet.dart | Settings (bottom sheet) | CSV/JSON export |
| `showExerciseHelp` sheet | features/workout/presentation/exercise_help_sheet.dart | Camera/goal | placement help |
| AI consent dialogs | features/ai/presentation/ai_consent.dart | ResultPage | automatic / one-off AI consent |
| `LocalVideoTestPage` | lib/local_video_test_page.dart | Home, only `if (kDebugMode)` (home_screen.dart:233) | replay a local video through the engine |

## 3. Camera + pose + rep counting engine

- Packages: `camera` (`CameraController`, `ResolutionPreset.medium`, `ImageFormatGroup.nv21` Android / `bgra8888` iOS, `startImageStream(_onFrame)` camera_page.dart:820-831), `google_mlkit_pose_detection` (`PoseDetector(PoseDetectorOptions(mode: stream|single, model: PoseDetectionModel.base))` camera_page.dart:249-255). No tflite / mediapipe in the app (MediaPipe only in Python notebooks + `rep-counter-ai-main/tools/*.py`). MethodChannel `rep_counter/video_frames` for CI/local video replay.
- Key classes:
  - `CameraPage` / `_CameraPageState` (lib/camera_page.dart) with private `enum _CameraState { awaitingConsent, initializing, ready, denied, unavailable, suspended }`.
  - `PoseMapper` (features/pose/domain/pose_mapper.dart) — ML Kit pose → `Landmarks`.
  - `ExerciseProfile` (exercise.dart) — per-exercise signal config; `CountGateLatch` with `enum CountGateState { open, holding, closed }` (push-up posture gate; recent commits).
  - `GuideZone`, `StatusDebouncer`, `enum PlacementStatus` (placement.dart).
  - `RollingMean`, `RepCounter` (Schmitt trigger: `hi`, `lo`, `minAmplitude`, `minPeriod=500ms`, `startFromTop`; private `enum _Phase { unknown, down, up }`), `TwoArmMerger`, `SessionTracker` (`enum SessionState { idle, working, resting }`, `restTimeout` 6 s default), `Calibrator` (rep_counter.dart).
  - `RepTracker` (features/workout/domain/rep_tracker.dart) emitting `sealed class RepEvent` → `RepStarted`, `RepReachedBottom(bottomAngle)`, `RepCompleted(observation)`, `RepAborted(reason)`; `enum RepAbortReason { signalLost, placementLost, reset }`.
  - `RepObservation`, `RepMetric`, `enum RepQualityFlag { shallow, incompleteLockout, tooFast, tooSlow, leftRightUneven, bodyAlignmentLost, poseUnreliable }` (rep_metric.dart); `RepQualityAnalyzer`; `WorkoutAggregator` (setGap 6 s); `WorkoutSummary`, `PoseQualityStats`, `QualityScore`; `QualityThresholds`, `CalibrationSnapshot`, `enum CalibrationSource { defaults, userCalibration, sessionDerived }`.
  - `WorkoutController extends ChangeNotifier` (features/workout/application/workout_controller.dart) — session orchestrator; methods: `cameraStarted()`, `pause()`, `calibrationChanged()`, `acceptRep(RepObservation, Duration)`, `frameProcessed(...)`, `requestStart()`, `reportRepAborted()`, `repSignalRestored()`, `skipRoutineRest()`, `finish({calibration})`, `abort()`, `dispose()`. Clock abstraction `WorkoutClock` / `StopwatchWorkoutClock`.
  - `WorkoutUiState` (immutable projection) with `enum WorkoutUiPhase { positioning, ready, calibrating, countdown, active, resting, paused, ending, saving, done, aborted }`.
  - `enum WorkoutPhase { idle, initializingCamera, positioning, calibrating, countdown, active, paused, completing, completed, failed }` (domain/workout_state.dart) — only referenced by tests (`workout_domain_test.dart:521`); the live UI uses `WorkoutUiPhase`.
  - `enum WorkoutMode { free, targetReps, timed }`, `TimedChallengeConfig`, `WorkoutStartConfig.{free,target,timed}` (domain/workout_mode.dart).
  - `RepFeedback` / `enum RepFeedbackKind { countedClean, countedWarning, placementInterrupted, poseLost }`.
- Start flow: `requestStart()` → requires stable `status.canCount` for 1500 ms → 3-2-1 countdown (`_beginCountdown`, cancelled if no ready frame for >750 ms) → `_armed`, session clock starts. Reps only accepted when `acceptsReps` (armed, not paused/calibrating/expired).
- Rep monotonicity: `SessionTracker` doc: "Rep đã được engine xác nhận là nguồn sự thật và KHÔNG BAO GIỜ bị trừ lại" (confirmed reps are never decremented); `WorkoutUiState` comment: never "a second, independently incremented rep count". `RepCounter.count` only increments.
- Pause/resume: manual via HUD `onPause: _pauseWorkout` / `onResume: _resumeWorkout` (camera_page.dart:1552-1553, `_manualPaused`); automatic on `AppLifecycleState.inactive/paused/hidden/detached` → `_suspendCamera()` (stops clocks via `_workout.pause()`, aborts in-progress rep with `RepAbortReason.placementLost`, releases camera) and `resumed` → `_resumeCamera()` (camera_page.dart:428-500).
- Timing: two clocks — tracking clock (frame time) and session clock (`elapsed`, stops during pause/calibration/rest-expired). Timed challenge expires when `elapsed >= durationSeconds`; equal-time rep counts.
- Routine rest: `_beginRoutineRest()` / `RoutineRestOverlay`, `skipRoutineRest()`.
- Saving: `finish()` → single `Completer`, builds `WorkoutSummary` via `WorkoutAggregator.build`, `WorkoutRecord.fromSummary`, phases `ending → saving → done`, calls `_saveRecord` (`WorkoutHistoryStore.save`); on error unlocks retry and resumes clock. `CameraPage._finishWorkout` then `pushReplacement(ResultPage(record, offerAutomaticAi: true))`. Exit dialog offers continue / discard (`abort()`) / save.
- Permission: `permission_handler` `Permission.camera`; pre-permission explainer `CameraPermissionView` (`_CameraState.awaitingConsent`), skipped if already granted (`_skipConsentIfAlreadyGranted`, camera_page.dart:514); `denied` state view.
- Session recovery after process kill: NOT IMPLEMENTED (no in-progress persistence found).
- Voice/haptics during workout: `WorkoutFeedback` (core/services/workout_feedback.dart) with `SpeechDriver`/`SystemSpeechDriver` (flutter_tts), `HapticFeedback`, `SetSounds` (audioplayers). Default `coachingEnabled = false` ("count-only" default; training_preferences.dart:12).

## 4. Local persistence

- **SharedPreferences only** (no sqlite/hive/drift). Keys:
  - `workout_history_v1` — `WorkoutHistoryStore` (StringList of JSON; serialized via static `_serial` queue; capped at 100 valid records; `save`, `load`, `clear`, `saveFeedback(id, text)`, `delete(id)`→`DeletedWorkout`, `restore`).
  - `onboarding_v1`, `app_language`, `routine_presets_v1` (`RoutineStore`), `earned_achievements_v1` (`AchievementService`), calibration (`CalibrationStore`), `automatic_ai_consent_2026_10_01_groq` (`AiPreferences`), training prefs `training_live_coaching_v1`, `training_voice_v1`, `training_sound_v1`, `training_cues_v1`, `training_haptics_v1`, `training_rep_speech_cadence_v1`.
- `WorkoutRecord` fields (workout_record.dart): `id`, `exerciseId`, `exerciseName`, `startedAt`, `durationSeconds`, `reps`, `sets`, `targetReps?`, `poseFrames`, `readyFrames`, `lostFrames`, `mode` (`WorkoutMode`, inferred for legacy), `challengeSeconds?`, `aiFeedback?`, `quality?` (`WorkoutQuality`), `repDetails?` (`List<StoredRep>`), `routine?` (`RoutineSnapshot`). Derived: `goalReached`, `completedTimedChallenge`, `placementScore`. JSON uses snake_case (`exercise_id`, `started_at`, ...). `toAiPayload()` builds the AI request.
- `WorkoutQuality`: `flaggedReps`, `avgRepSeconds`, `avgAmplitude`, `amplitudeDropPercent`, `leftRightDiffPercent`, `qualityScore`, `rangeOfMotion`, `cadenceConsistency`, `leftRightBalance`, `poseAlignment`, `hasEnoughData` (+ others).
- `StoredRep`: `seconds`, `setIndex`, `flagged`, `qualityFlags?`.
- Personal records: `WorkoutPersonalRecordStore` (domain/workout_personal_records.dart) computed from history.

## 5. AI feedback, credits, entitlements

- Service: `AiFeedbackService` (features/ai/ai_feedback_service.dart). `POST {AI_BASE_URL}/v1/workout-feedback`, header `content-type: application/json` only (no auth), timeout 25 s, HTTPS required. Base URL: `String.fromEnvironment('AI_BASE_URL', defaultValue: defaultBaseUrl)` where `defaultBaseUrl` is the public production host (repcoach-ai.duckdns.org). Request = `WorkoutRecord.toAiPayload()` + `schema_version: 2`, `consent_version: LegalConfig.aiConsentVersion` ('2026-10-01-groq'), `locale`. Response must be `{schema_version: 1, feedback: string}`. Failures: `enum AiFeedbackFailure { notConfigured, timeout, offline, server }`.
- Called from: `ResultController.request()` (features/workout/application/result_controller.dart; `enum ResultFeedbackPhase { idle, loading, ready, offline, error, unavailable }`), used by `ResultPage` (manual button, or automatic if `AiPreferences.enabled()` after consent; result_page.dart:58-89). Feedback persisted via `WorkoutHistoryStore.saveFeedback`.
- Offline rule-based feedback: `RuleBasedFeedback` (domain/rule_based_feedback.dart) with `enum FeedbackSource { rules, ai }`, `enum FeedbackNote {...}`.
- Consent: `features/ai/presentation/ai_consent.dart` dialogs; versioned consent key.
- AI credits / usage metering / entitlements: **NOT IMPLEMENTED** (no matches for credit/premium/subscription/entitlement in lib or backend). Server-side only nginx IP rate limit (10 r/m).
- AI coach chat: NOT IMPLEMENTED.

## 6. Auth / session
- **None.** No Firebase/Supabase/custom auth, no login, no user ID, no tokens. The app is single-device, anonymous by design (`AchievementService` doc: "There is no XP, token, social, account, or cloud state."). "Guest mode" is effectively the only mode; no guest/account distinction exists. Account deletion: N/A; Settings has **"delete local data"** (`SettingsPage._deleteData`: clears history, calibration, achievements; `_DeleteDataDialog` type-to-confirm).

## 7. Backend (`rep-counter-ai-main/backend`)
- Language/framework: **Python 3 stdlib** `http.server.ThreadingHTTPServer` + `BaseHTTPRequestHandler` (server.py, 438 lines). No framework, **no database**. Provider module `ai_provider.py`: `GroqProvider` (default; env `AI_PROVIDER`=groq, `GROQ_API_KEY`, `GROQ_MODEL` default `openai/gpt-oss-20b`) and legacy `GeminiProvider` (`GEMINI_API_KEY`, `GEMINI_MODEL`, `GEMINI_SERVICE_MODE`). Env loaded from `backend/.env` (gitignored); `PORT` (8787), `BIND_HOST` (127.0.0.1).
- Endpoints (all unauthenticated; all responses carry `x-request-id`, `cache-control: no-store`):
  | Method | Path | Request | Response |
  |---|---|---|---|
  | GET | /health | – | 200 `{"status":"ok"}` |
  | GET | /ready | – | 200 `{"status":"ready"}` / 503 `{"status":"not_ready"}` (provider config) |
  | GET | /privacy-policy.html, /support.html, /terms.html | – | static HTML from `backend/static/` |
  | POST | /v1/workout-feedback | `application/json`, ≤16,384 bytes; schema v1 or v2 (v2 requires `consent_version`). Fields: core `exercise` (push_up/pull_up/curl/overhead_extension), `duration_seconds`, `reps`, `sets`, `target_reps`, `goal_reached`, `placement_score`, `pose_frames`, `pose_lost_frames`, `locale` (vi/en); quality `flagged_reps`, `avg_rep_sec`, `avg_amplitude`, `amplitude_drop_percent`, `left_right_diff_percent`, `quality_score`, `has_enough_data`. Example: `rep-counter-ai-main/contracts/workout_feedback_v2.json` | 200 `{"schema_version":1,"feedback":"..."}`; errors `{"error": CODE}`: 400 INVALID_REQUEST, 413, 405 (non-POST), 503 AI_UNAVAILABLE, 504 AI_TIMEOUT, 502 AI_RESPONSE_INVALID, 500 SERVER_ERROR, 404 NOT_FOUND |
- Webhooks / purchase verification (App Store Server API, Play Developer API, Lemon Squeezy): **NOT IMPLEMENTED**.
- Deployment (`backend/deploy/`): nginx vhost `repcoach-ai.nginx` (TLS host repcoach-ai.duckdns.org, `limit_req zone=repcoach_api` 10 r/m burst 10, metadata-only logging), `repcoach-rate-limit.conf`, systemd `repcoach-backend.service` (`/usr/bin/python3 .../server.py`, `EnvironmentFile=.../.env`), logrotate, `b7_apply.sh` / `b7_rollback.sh`. Manual deploy to a VPS; docs in `backend/docs/` (production-release.md, groq-provider.md, staging-integration.md, gemini-service-mode.md). Tools: `tools/fake_staging_server.py`, `tools/production_smoke.py`.
- Mobile config keys: dart-define `AI_BASE_URL` (default in `AiFeedbackService.defaultBaseUrl`), `APP_STORE_ID` (core/services/app_links.dart), `ENABLE_ALL_EXERCISES`, `ENABLE_AI_FEEDBACK`, `ENABLE_PULL_UP`, `REPCOACH_CI_VIDEO_ASSET`; staging smoke uses env `STAGING_BASE_URL`.
- Secrets: **no secret values found in tracked files**. `backend/.env.example` has empty `GROQ_API_KEY`/`GEMINI_API_KEY`. Android signing reads gitignored `key.properties`/`upload-keystore.jks` (not committed). CI references `secrets.VPS_SSH_KEY` (`.github/workflows/production-ops-check.yml:25`) by name only. iOS `DEVELOPMENT_TEAM` id is in project.pbxproj (not a secret). `password="false"` hits in `rep-counter-ai-main/analysis/*.xml` are UI-dump attributes, not secrets.

## 8. Billing, notifications, platforms, l10n
- Billing: **NOT IMPLEMENTED** — no in_app_purchase / RevenueCat / StoreKit / Play Billing / Lemon Squeezy code.
- Notifications: **NOT IMPLEMENTED** — no local/push notification packages. Only `POST_NOTIFICATIONS` + `FOREGROUND_SERVICE` in the **diag** flavor manifest (for screen-recording service `DiagRecorderService.kt`). "Posture reminders" in Settings are in-workout voice cues, not notifications.
- iOS (`APP/ios`): bundle `com.ronganminh.repCounterApp`, deployment target 15.5, `CFBundleLocalizations` en (+vi via lproj), `NSCameraUsageDescription` and `NSPhotoLibraryAddUsageDescription` in Info.plist with `en.lproj` / `vi.lproj/InfoPlist.strings`; `ITSAppUsesNonExemptEncryption=false`; `PrivacyInfo.xcprivacy` (UserDefaults required-reason). SceneDelegate present.
- Android (`APP/android`): `applicationId com.ronganminh.repcoach`, flavors `store` and `diag` (`.diag` suffix), versionCode/Name from Flutter. Main manifest: `CAMERA`, `INTERNET`, `RECORD_AUDIO` removed, `uses-feature camera required=false`, `WRITE_EXTERNAL_STORAGE` maxSdk override; release manifest removes READ/WRITE_EXTERNAL_STORAGE, READ_MEDIA_IMAGES/VIDEO.
- Locales: **vi (default) and en**. Implementation: hand-written `class S` with 209 required fields, `static const S vi` (app_strings.dart:499) and `static const S en` (:742), `enum AppLanguage { vi, en }`, plus ~394 inline `context.tr('VI', 'EN')` calls. No ARB, no `flutter_localizations`, no `supportedLocales` → Material widgets are not localized by the framework. Language chosen first from system locale (`en*`→en, else vi) then persisted (`app_language`). Vietnamese strings are extensive (e.g. `pushUpName: 'Hít đất'`, `appTitle: 'Đếm rep'`). Store listings in EN and VI (`rep-counter-ai-main/store_listing/PLAY_STORE_LISTING_{EN,VI}.md`).
- Accessibility: PARTIAL — `Semantics` used in ~15 files (HUD, rep pill, result hero, pace chart, history, export sheet, etc.), text-scale aware layout (`ExercisePickerScreen` switches to 1 column at large scale). Design handoff §10 has an accessibility checklist.

## 9. Tests & CI
- Dart tests: 41 files under `APP/test`, **333 test cases** (239 `test(` + 94 `testWidgets(`); no `integration_test/` dir. Coverage: rep engine vs Python vectors (`rep_counter_test.dart` + `test/rep_vector.json`), workout domain (50), workout controller, camera page controller, time challenge, count-only mode, pose mapper (20), placement guide, pull-up + pull-up release gate (fixtures `pull_up_*.json`), A9 stabilization manifest, calibration store, rule-based feedback, AI service + AI result integration (MockClient), export service/sheet, progress statistics, routines, achievements, voice cadence, phase3/6/7/8 + new_ui + feature_completion widget tests.
- Replay tests: CI plays real push-up videos through the production `CameraPage` (`REPCOACH_CI_VIDEO_ASSET` mode), with ground truth `test/fixtures/video_ground_truth.json` and checks `tool/check_video_rep_baseline.py`, `tool/check_video_rest_timeline.py`; Android via `tool/ci_android_replay.sh`.
- Python backend tests: 9 files, **94 tests** (`backend/tests/`: validation 22, security 16, production_release 15, privacy_contract 12, observability 10, deploy_config 9, provider 7, privacy_route 2, staging_contract 1).
- CI workflows (`.github/workflows/`):
  | File | Triggers | Jobs / verification |
  |---|---|---|
  | ios-ci.yml ("RepCoach CI") | push main/master + PR (paths rep_counter_app/**), dispatch | `quality`: `flutter analyze --fatal-infos`, `flutter test --coverage`; App Store unsigned release build (macos-26, Xcode 26, `check_app_store_readiness.py`); Apple Silicon iOS simulator replay matrix pushup-1 / pushup-2 / pushup-rest-regression (non-PR), reject reps during annotated rest, preserve rep baseline, upload evidence |
  | android-replay.yml | push main/master (paths), dispatch | emulator replay matrix pushup-1, pushup-rest-regression (pushup-2 commented out as too slow); verify reps during exercise not rest; informational |
  | android-test-release.yml | push main (paths), dispatch | build store-flavor release APK with temporary signing key, verify signature, GitHub prerelease |
  | app-store-readiness.yml | PR (paths), dispatch | metadata/privacy contract script; Xcode 26 unsigned iPhone release build |
  | backend-ci.yml | push main/master + PR (paths), dispatch | compileall + `python -m unittest discover` |
  | staging-integration-ci.yml | push + PR (paths), dispatch | start fake staging backend, `dart run tool/staging_contract_smoke.dart`, AI Flutter tests |
  | production-readiness.yml ("Production Smoke") | dispatch only | `tools/production_smoke.py` against public host |
  | production-ops-check.yml | dispatch only | SSH (secret `VPS_SSH_KEY`) read-only verification, deployed-hash comparison, public routes |

## 10. design-handoff/
- Last touched 2026-09-29 (only date seen for this folder in `git log`; the clone is depth 50, so earlier history may be hidden). `README.md` (VI) + `docs/DESIGN_HANDOFF.md` (1735 lines) + `design/*.dc.html` (app-icon, camera, design-system, flow click-through, history-settings, home, hud, onboarding, results) + `support.js`.
- DESIGN_HANDOFF sections: product/UX principles, tokens (dark default + light), typography (Inter + Barlow Condensed), spacing/radius/motion, ready-to-copy Dart theme code, 26 component specs, 23 screens in flow order (onboarding ×3, camera permission/denied, Home tab, exercises, PlanTodaySheet, camera phases C1–C4, HUD active/paused/goal reached/over goal/saving, results `/results/:sessionId`, story `/share/:sessionId`, history tab, history detail, settings tab, calibration, delete dialog, AI consent sheet), routes (§6), `WorkoutPhase` state machine (§7), data model + AI payload (§8), assets, accessibility checklist, suggested packages.
- It is an **earlier, smaller design**: **3-tab bar** (Tập / Lịch sử / Cài đặt, §4.23), no Exercises/Progress/Profile tabs, no auth, premium, credits, social or notifications. The current code largely implements this handoff (theme files in `lib/theme/` match §3 file names). Its route names (`/home`, `/exercises`, `/workout`, `/results/:sessionId`, ...) are **not** used in code (no named routing).

## 11. Recent git log themes (last 50 commits, 2026-10-01 → 2026-10-19)
- Android replay CI (emulator, logcat streaming, rest-regression, timeouts).
- Push-up false-rep fixes: posture gate, seated push-up blocking, jitter debounce, re-baselined replay counts; default count-only mode; avoid false fast-rep feedback.
- Release prep: v2.0.0 / Play versionCode 8, iOS build 6, TestFlight team, App Store readiness gate (PR #25), privacy manifest, ring-logo icon, Play v2 assets/screenshots.
- Feature tracks A3–A9 (PRs #15, #18–#23): Time Challenge + local PRs (A3), Progress/PR (A4), privacy-preserving local export (A5), routine presets + rest (A6), achievements + voice cadence (A7), pull-up production gate (A8, still BLOCKED), stabilization (A9); Android test APK prerelease (#24).
- Track B (B7/B8) backend ops: GroqCloud provider, production readiness, manual deploy model, removal of temporary diagnostics workflows, Gemini marked legacy; backend serves support/terms pages.

---

## Feature classification

| Feature | Status | Evidence |
|---|---|---|
| Navigation 5 tabs (Home/Exercises/Train/Progress/Profile) | PARTIALLY IMPLEMENTED | Only 3 tabs Train/History/Settings, `app/app_shell.dart` NavigationBar |
| Exercise library | PARTIALLY IMPLEMENTED | `ExercisePickerScreen`; only push_up live; pull_up diag-only; curl/overhead hidden; squat/sit-up/jumping jack/lunge placeholders |
| Camera pose detection | IMPLEMENTED | ML Kit `PoseDetector` in `camera_page.dart:249`; `PoseMapper` |
| Rep counting | IMPLEMENTED | `RepCounter`, `RepTracker`, `CountGateLatch`, `SessionTracker`; replay CI |
| Workout session pause/resume | IMPLEMENTED | `WorkoutController.pause()`, `_pauseWorkout/_resumeWorkout`, lifecycle suspend/resume |
| Session recovery (after kill/crash) | NOT IMPLEMENTED | no in-progress persistence; only in-process background suspend/resume |
| Results page | IMPLEMENTED | `ResultPage`, form score, pace chart, timed result, AI card, achievements, share |
| History | IMPLEMENTED | `HistoryPage`, `WorkoutHistoryStore` (delete/undo) |
| Local persistence | IMPLEMENTED | SharedPreferences stores (JSON), 100-record cap |
| Cloud sync | NOT IMPLEMENTED | no backend storage/auth |
| Workout plans | PARTIALLY IMPLEMENTED | `PlanTodaySheet` (single-session goal), routine presets (sets×reps+rest) `features/routine/`; no multi-day plans |
| Analytics / progress | IMPLEMENTED (local) | `progress_statistics.dart` (7d/30d/90d/all), trend bars, heatmap, PRs in `HistoryPage` |
| AI feedback | IMPLEMENTED | `AiFeedbackService` → backend `/v1/workout-feedback` (Groq), consent, offline rule-based fallback |
| AI coach chat | NOT IMPLEMENTED | none |
| AI credits | NOT IMPLEMENTED | none; only nginx IP rate limit |
| XP / achievements / challenges | PARTIALLY IMPLEMENTED | 6 local `AchievementId`s + Time Challenge mode + PRs; no XP, no challenge system |
| Voice coach | PARTIALLY IMPLEMENTED | TTS rep counts/posture cues (`WorkoutFeedback`, `VoiceCadencePage`); no conversational coach; off by default |
| Friends / leaderboards | NOT IMPLEMENTED | none (only share story image) |
| Billing iOS (StoreKit) | NOT IMPLEMENTED | no package/code |
| Billing Android (Play Billing) | NOT IMPLEMENTED | no package/code |
| Entitlement verification | NOT IMPLEMENTED | no backend endpoint/webhook |
| Auth | NOT IMPLEMENTED | none |
| Guest mode | NOT IMPLEMENTED (as a feature) | app is anonymous-only; no account to contrast |
| Account deletion | NOT IMPLEMENTED | no accounts; local-data delete exists (`SettingsPage._deleteData`) |
| Data export | IMPLEMENTED (local) | `WorkoutExportService` CSV/JSON via share sheet, `ExportDataSheet` |
| Notifications / reminders | NOT IMPLEMENTED | no notification packages; POST_NOTIFICATIONS only in diag flavor |
| Localization EN | IMPLEMENTED | `S.en`, `context.tr`, en.lproj |
| Localization VI | IMPLEMENTED | `S.vi` (default), vi.lproj, VI store listing |
| Accessibility | PARTIALLY IMPLEMENTED | `Semantics` in ~15 files, text-scale-aware layouts; no full audit evidence |
| Tests | IMPLEMENTED | 333 Dart + 94 Python tests, video replay |
| CI | IMPLEMENTED | 8 workflows in `.github/workflows/` |
