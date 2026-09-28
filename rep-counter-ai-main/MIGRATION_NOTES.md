# RepCoach AI migration notes

## Phase 0 baseline — 2026-09-27

### Source roles

- `rep_counter_app/` is the legacy Flutter engine and remains the source of truth for camera lifecycle, ML Kit pose processing, placement gating, calibration, rep detection, workout aggregation, local records, and AI transport.
- The repository root's `design-handoff/` is the source of truth for the product experience and visual system. Its HTML files are reference material only; they are not runtime UI.

### Baseline commands

| Command | Result |
| --- | --- |
| `flutter pub get` | PASS — run with Flutter stable installed locally for this migration. |
| `flutter analyze` | PASS — no issues. |
| `flutter test` | PASS — 141 tests. |

No engine source was changed during Phase 0.

### Existing application inventory

| Area | Existing source | Migration treatment |
| --- | --- | --- |
| App entry and home | `lib/main.dart` | Replace presentation with the new shell and routes. |
| Camera, frame conversion, pose processing | `lib/camera_page.dart` | Keep stable; extract presentation state/controller incrementally. |
| Rep engine and placement | `lib/rep_counter.dart`, `lib/exercise.dart`, `lib/placement.dart`, `lib/features/pose/domain/pose_mapper.dart` | Preserve. |
| Workout domain and calibration | `lib/features/workout/domain/`, `lib/features/workout/data/calibration_store.dart` | Preserve. |
| Local history | `lib/features/workout/data/workout_history_store.dart`, `workout_record.dart` | Reuse; extend only with backward-compatible fields. |
| AI and offline feedback | `lib/features/ai/ai_feedback_service.dart`, `rule_based_feedback.dart`, `backend/` | Preserve privacy and request contract; redesign result presentation. |
| User-facing screens | onboarding, goal setup, result, history, settings pages | Rewrite against the design handoff. |

### Current screens and storage

- Onboarding state: `onboarding_v1` in `SharedPreferences`.
- Locale choice: `LocaleController` in `SharedPreferences`.
- Workout history: `WorkoutHistoryStore` in `SharedPreferences`.
- Calibration: `CalibrationStore` in `SharedPreferences`.
- Current production navigation: onboarding → home → goal setup → camera → result; history and settings open from the home app bar.

### Platform baseline

- The archive includes an Android scaffold only. There is no checked-in `ios/` directory, `Info.plist`, Podfile, or Xcode project.
- `pubspec.yaml` uses `camera`, `google_mlkit_pose_detection`, `shared_preferences`, and `http`; it does not bundle the fonts required by the handoff.
- The legacy README explicitly says its camera/ML Kit path has not been built or validated on a physical device.

### Engine-critical files

- `lib/rep_counter.dart`
- `lib/exercise.dart`
- `lib/placement.dart`
- `lib/features/pose/domain/pose_mapper.dart`
- `lib/features/workout/domain/`
- `lib/features/workout/data/calibration_store.dart`

These files will not be rewritten during visual migration. The existing test suite targets the rep counter, placement guide, pose mapper, calibration, workout domain, records, and rule feedback.

### Known conflicts and decisions

1. The migration guide describes a side-view push-up engine, but the actual archived `lib/exercise.dart` configures `push_up` for a low, front-facing camera and `placement.dart` evaluates its torso as vertically oriented on screen. This migration preserves the checked-in engine unchanged. Camera copy and visual guides must be validated against device evidence before claiming either side or frontal placement.
2. The handoff specifies automatic AI feedback after consent; legacy UI offers a manual Gemini request and does not yet model the new consent/toggle flow. The adapter and settings work must be added without putting an API key in the app or making save depend on networking.
3. The handoff has a richer history/detail presentation than the legacy persisted aggregate record. Charts or per-rep detail must remain hidden for legacy records until a backward-compatible storage extension provides real data.
4. The handoff calls for iOS + Android, while the legacy archive has no iOS target. iOS scaffolding and device validation are required before calling the migration release-ready.

### Phase 0 outcome

The codebase is inventoried and ready for Phase 1. Automated baseline verification passed.

## Phase 1 — design-system foundation

- Added the RepCoach dark/light palette, typography, spacing, radius, motion, and Material 3 theme under `rep_counter_app/lib/theme/`.
- Added `google_fonts` and `lucide_icons_flutter`; `pubspec.lock` was refreshed by `flutter pub get`.
- Switched the app entry to the new default-dark theme without editing the rep engine, pose mapper, placement gate, calibration, or workout domain.
- Validation after the change: `flutter analyze` passed and all 141 tests passed.

## Phase 2 — shell and navigation

- Replaced the legacy home entry with `AppShell`, an indexed three-tab shell for training, history, and settings.
- Added the new home screen, exercise picker, and Plan Today sheet. The home screen reads real workout history through `WorkoutHistoryStore`; it does not create sample records.
- Only push-up can start a workout. Future exercises render as coming soon and cannot invoke an engine.
- Plan Today maps directly to the existing `CameraPage(profile, targetReps)` contract; `Tập tự do` passes `null` for the existing free-workout behavior.
- Validation after the change: `flutter analyze` passed and all 141 tests passed.

## Phase 3 — Home / History / Settings (2026-09-27)

### Presentation and data

- Home reads real weekly totals and the latest saved session; empty state starts a workout.
- History reads `WorkoutHistoryStore`: exercise filter, current month totals/calendar,
  current streak, 30-day session trend, date groups, existing read-only result route,
  deletion and undo. Legacy records without quality fields do not receive fabricated metrics.
- Settings uses persisted Vietnamese/English selection, actual calibration snapshots,
  per-exercise reset, existing privacy/terms/safety routes and typed confirmation before
  clearing local history and calibration. AI remains a manual request on the legacy result screen.
- Shell reloads stores when switching tabs and returning from routes. Debug local-video tools
  and feature-flagged legacy exercises remain accessible.
- No fake production records. Test fixtures exist only in `test/`.

### Engine boundaries

Rep counter, camera pipeline, placement, pose mapper, workout domain, record schema,
history store, AI transport and feedback algorithm are byte-identical to the archive.
The sole engine-adjacent change is `CalibrationStore.reset(exerciseId)`: removes one existing
preference key, preserving other exercises and history. Covered by storage and UI tests.
The Phase 4 extraction is recorded in the next section.

### Build and compatibility

- Added an iOS scaffold, iOS 15.5 deployment target, camera usage description, portrait
  orientation and permission-handler camera configuration.
- Kept CocoaPods at the project level (`flutter.config.enable-swift-package-manager: false`)
  after a mixed SPM/Pods build failed to resolve `camera_avfoundation` on the device target.
- Bundled Inter and Barlow Condensed fonts with licenses; removed runtime Google Fonts dependency.
  Updated Lucide package for the installed Flutter SDK's `IconData` API.
- Build environment: Flutter 3.47.5, Dart 3.13.4, Xcode 27.0, CocoaPods 1.17.0.
  Use `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`; system xcode-select remains unchanged.
- `flutter build ios --debug --no-codesign`: PASS. Signing and installation on physical hardware pending.
- `flutter build ios --simulator --debug`: PASS (x86_64 binary).
- iPhone 18 Pro / iOS 27 simulator boot: PASS. Installing app: **BLOCKED** — runtime only executes
  ARM simulator apps while the existing ML Kit pods only provide x86_64 simulator libraries.
  Runtime iOS 26 Universal was subsequently installed during Phase 4; see the simulator update below.
  Do not report simulator app launch or camera validation as passed without separate evidence.

### Verification

- `flutter analyze`: PASS.
- `flutter test`: PASS — 153 tests (141 original + 12 Phase 3 tests).
  Regression tests cover month/streak totals, legacy history,
  empty-state CTA, delete/undo, typed data deletion, language persistence, legal navigation,
  calibration reset isolation and fresh tab data.
- Render tests load bundled fonts and check all three tabs at normal and 2x text sizes.
  Optional PNG captures in `/tmp/repcoach-phase3` are **widget renders**, not simulator screenshots.
- Fixed regressions found by these tests: Future-returning `setState` callbacks, large-text
  settings layout and inconsistent default font/foreground colors.

### Remaining validation

Simulator installation/launch was subsequently verified during Phase 4 on iOS 26 Universal;
no rep/camera behavior has been validated on physical hardware. Live camera redesign, result redesign,
storage v2 and release artwork remain in later phases.

## Phase 4 — extract workout orchestration (2026-09-27)

### Ownership after extraction

| Owner | State/responsibilities |
| --- | --- |
| Existing engine classes | Rep thresholds and state machine; pose geometry; placement rules; calibration formulas; quality analysis; aggregation policy. |
| `WorkoutController` | The **original** `SessionTracker`, accepted `RepMetric` collection, quality analyzer/aggregator instances, monotonic elapsed time, first camera start timestamp, pose-frame totals, one-time goal event, save lifecycle and history write. |
| `WorkoutUiState` | Immutable projection: reps/current set/completed sets, existing session state, goal/progress, elapsed, placement status/message/grace readiness, calibration samples/source flag and lifecycle phase. No camera images, poses or raw landmarks. |
| `CameraPage` native/engine adapter | Camera and permission state, ML Kit detector/conversion/remapping, placement debounce/grace, two-arm merging, trackers/smoothers, calibrator and calibration store. These feed accepted events and metadata into the controller. |
| `CameraPage` presentation | Existing gate/HUD, overlay landmarks, rep flash, dialogs/snackbars, navigation, diagnostic UI and route pop permission. HUD totals/placement/calibration read the UI projection. |

### Changes

- Added `lib/features/workout/application/workout_controller.dart` and `workout_ui_state.dart`.
- CameraPage forwards already gated/merged rep observations and processed-frame metadata.
  The controller does not detect reps independently or bypass placement gating.
- Moved background pause/resume timing, one-time goal bookkeeping, record aggregation and local
  saving out of the widget. Navigation and native camera release remain in the widget.
- Finish freezes a snapshot, stops elapsed time and ignores new frames. Concurrent finish calls
  share one future/write. Failed saves unlock retry, preserve reps and resume time only in foreground.
- Protected the native boundary against late initialization/pose results after suspend, finish or
  disposal. Detector processing remains serialized across camera restarts. Camera teardown now
  tolerates an already stopped stream and waits for old-camera release before reopening.
- No countdown or new manual-pause UI existed in the legacy screen. Reserved phases are declared
  but no fabricated countdown/progress, voice preferences or new workout flow is introduced here.

### Preserved behavior and evidence

- `remapPose`, `_toInputImage`, `_buildCounters`, torso-deviation and pose-confidence calculations
  in CameraPage are byte-identical to the archive. Signal processing, placement grace (2 seconds),
  counter thresholds and two-arm merge rules remain unchanged.
- All engine-critical domain files remain unchanged by Phase 4, as do the history schema, AI
  transport and calibration persistence introduced earlier.
- The legacy live-session short-set policy and final aggregator policy remain separate and
  unchanged (`profile.minRepsPerSet` vs `min(2, profile.minRepsPerSet)`). This extraction does not
  silently unify them or recalculate totals in presentation.
- Controller tests compare saved records and session fields against the original orchestration
  for every existing exercise. Native-boundary tests use a fake camera and stub ML Kit **only in tests**.

### Verification

- `flutter analyze`: PASS — no issues.
- `flutter test`: PASS — **173 tests**, including 13 controller tests and 7 CameraPage integration
  widget tests in addition to the 153 existing tests.
- Covered: one-time goals, unchanged record output, calibration projection, elapsed time across
  background/resume, simultaneous finishes, save failure/retry, background during failed save,
  disposal during save, consent/denied/unavailable camera, normal result navigation, late camera
  initialization, stale frames and in-flight detector completion after finish.
- iOS simulator and unsigned device builds: PASS. Simulator runtime compatibility and physical
  camera accuracy remain separate checks; mocked-camera tests do not establish either.

### Next

Phase 5 replaces the camera positioning/HUD presentation using this controller state. Keep the
remaining native adapter and engine math stable, and validate live camera behavior on hardware.

### Simulator environment update

- iOS 26.0 Universal (23A343) download/install completed. Rosetta 2 installation completed;
  the host can now execute x86_64 commands.
- Created `RepCoach iPhone 17 Pro`, UUID `1B9AAA8C-CF32-4A9E-B6AC-E212674078AE`.
- First boot with `--arch=x86_64` started simulator services but the display did not become ready:
  `simctl io screenshot` returned `Timeout waiting for screen surfaces`.
- **Resolved:** shut down that simulator and boot the **Universal runtime with `--arch=arm64`**.
  `simctl install` succeeded for the x86_64 app, and `simctl launch` returned a running process.
  A native screenshot confirms the app's onboarding screen rendered successfully:
  `rep_counter_app/docs/phase4/ios26-onboarding.png`. No engine/plugin stubs are in this app build.
- iOS 27 ARM-only remains incompatible with the legacy ML Kit simulator binary.
- Device Hub's UI automation connection still times out; interaction through its window was not
  verified. Native launch/onboarding, mocked-camera widget tests and physical camera validation
  are distinct results. Live pose/rep accuracy still requires an actual iPhone.


## 2026-09-27 — Replace remaining legacy presentation (user requested all UI)

The original phase 4 screenshot still showed legacy onboarding because phase 4
only extracted orchestration. The user explicitly requested all existing screens
use the new design. Remaining presentation has now been replaced: onboarding,
permission gates, camera HUD/calibration/pause/goal/save, results, help/legal,
legacy goal setup, with responsive/localized picker and shared plan content.
Supplied native icon/splash assets were copied into the app.

Validation: 196 tests passed and analysis clean; native simulator debug build,
install and launch passed. The screenshot at docs/phase4/ios26-onboarding.png is
now replaced with the updated native capture. More views and scope notes are in
rep_counter_app/docs/new-ui/README.md (widget renders explicitly labeled).

Regression safeguards: original rep_counter, exercise, placement, pose mapper and
all workout domain sources verified byte-identical against the original ZIP.
New local-only optional rep_details preserves aggregate payload/privacy and
backward compatibility. Camera image conversion/geometry remains unchanged.

New behavior tested: hold-to-finish cancellation/completion, explicit pause across
background/resume, late native callbacks, real calibration-sample UI, actual
result scores, legacy detail fallback, onboarding persistence/skip/privacy,
custom/null goal mapping, narrow screens and 2x text. Fixed a pointer-up callback
arriving after the hold button was disposed during finish.

No claim of full Phase 6/9 feature or store readiness: existing automatic start
and manual calibration are preserved, TTS/countdown/story sharing are not added,
and physical camera validation remains outstanding. Device Hub interaction timed
out, so native launch screenshot + mocked camera widget tests are the available
evidence, not a physical-camera or end-to-end simulator tap test.

## Phase 6 — Calibration / countdown / goal feedback (2026-09-27)

Implemented on top of the new UI. This supersedes the previous migration entry's
temporary automatic-start/no-TTS scope. Full details and evidence:
[`rep_counter_app/docs/phase6/README.md`](rep_counter_app/docs/phase6/README.md).

- Explicit start intent, 1.5 seconds of real ready placement, then 3–2–1.
  Preparation/calibration excludes workout reps, elapsed time and quality totals.
  Lost placement, stale frames, pause/background and terminal states cancel setup.
- Real calibration samples and existing formulas retained. Save now reports a
  boolean result so UI does not claim persistence after failure.
- Existing once-only goal banner/over-goal flow now has speech/haptic feedback.
  Local voice/haptic settings and HUD mute persist; queued speech is invalidated
  on pause/mute/disposal and failures never block counting.
- Added flutter_tts 4.2.5 and native registration/Android TTS discovery query.
- Analysis clean; 214 tests pass. Simulator debug and unsigned device release
  builds pass; latest app installed/launched and native onboarding captured.
- 13 core engine/domain files remain byte-identical to the original archive.
  Physical camera accuracy, audible voice and tactile haptics remain unverified;
  native launch, widget rendering and mocked-plugin behavior are separate evidence.

## Phase 7 — Result screen completion (2026-09-27)

Built on the earlier all-UI migration. Full scope and widget captures:
[`rep_counter_app/docs/phase7/README.md`](rep_counter_app/docs/phase7/README.md).

- Extracted ResultHero with partial/exact/over/free/zero variants. Extra arc maps
  actual reps above target; all metadata and form scores come from saved records.
- Consolidated AI and on-device feedback into one source-labeled card, preserving
  the old rule engine and plaintext AI contract. Opening results never requests AI.
- ResultController prevents duplicate requests, keeps cached text during errors,
  ignores late responses after disposal/record changes and separates AI errors
  from feedback persistence errors. Disk retry does not issue another AI request.
- Added saveFeedback to update text on an existing history record while keeping
  current metrics. Missing records and refused writes report failure.
- Fixed footer remains visible; Done/close goes home for fresh workouts and pops
  to the previous route for history detail. Scores have valid progress semantics.
- Analysis clean; 254 tests pass (40 new). iOS simulator debug and unsigned device
  release builds pass. Latest build installed/launched on iOS 26 Universal.
- Engine/domain byte comparison: 13 files unchanged. No new dependencies, AI
  payload or history schema changes. Share story and automatic AI consent/toggle
  remain outside this increment. Backend requests are mocked in tests; native
  result tap flows and physical-camera validation are not claimed as verified.

## Phase 8 — History detail and compatible rep storage (2026-09-27)

Full scope and evidence:
[`rep_counter_app/docs/phase8/README.md`](rep_counter_app/docs/phase8/README.md).

- Existing rep_details already stored measured timing/set membership; retained
  workout_history_v1 and added optional flags plus rep_details_version 2. No
  destructive/bulk migration. Unknown categories remain unknown; invalid optional
  details do not discard aggregate records. AI aggregate payload is unchanged.
- RepPaceChart groups by stored set, shows measured average, allows rep selection
  with saved note categories and never invents speed classifications for legacy
  generic flags. Partial timing availability is labeled without changing totals.
- History detail uses the saved AI response, date/time heading and confirmed
  deletion with exact-JSON Undo. AppShell preserves History's return/Undo state.
- Store operations serialize across instances, detect failed writes and retain
  unreadable raw entries and unknown fields during unrelated operations. A failed
  operation does not poison the queue; deleted workouts cannot be recreated by
  late AI updates. Retain at most 100 readable sessions by start date.
- Widget checks exposed a Home wordmark overflow at 320 px / 2x text; fixed with
  a constrained wordmark. History Undo now has dark-theme contrast.
- Analysis clean; 279 tests pass (25 new). Simulator debug and unsigned device
  release builds pass; latest app installed/launched on iOS 26 Universal.
- 13 engine/domain files remain byte-identical to ZIP. Story sharing and Phase 9
  device/release validation remain separate; widget fixture images are labeled.


## Chức năng bổ sung sau Phase 8 (2026-09-28)

Chi tiết: [`rep_counter_app/docs/feature-completion/README.md`](rep_counter_app/docs/feature-completion/README.md).

- Story PNG 1080 × 1920, lưu Photos khi được cấp quyền và chia sẻ hệ thống.
- AI tự động mặc định tắt; có consent rõ ràng và bật/tắt trong Settings. Chỉ buổi
  tập mới đã lưu được xét gửi; mở lịch sử không phát sinh yêu cầu tự động.
- Âm báo set, lời nhắc tư thế có giới hạn tần suất; tất cả tôn trọng cài đặt.
- Góp ý qua email đã xác nhận, link Google Play đúng package; iOS chờ listing ID.
- Mở lại 4 bài có engine và lọc lịch sử/hiệu chỉnh tương ứng.
- Analyze sạch; 302 test qua (23 mới). 13 file engine/domain nguyên trạng so ZIP.
- Calibration đúng 3 rep và các bài chưa có engine vẫn cần R&D/validation; không
  giả lập chức năng bằng dữ liệu mẫu. Phase 9 kiểm tra thiết bị thật chưa hoàn tất.
