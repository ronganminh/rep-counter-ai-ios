# Phase A0 — Audit, baseline and Figma mapping

Audit date: 2026-09-30  
Repository: `ronganminh/rep-counter-ai-ios`  
Audited `main`: `902b6ab1acfe6f72f5d8f4676afa9bd1c1d53d61`  
Flutter app root: `rep-counter-ai-main/rep_counter_app`

## 1. Scope

A0 is audit/baseline work only. It does not implement A1 product UI.

Primary implementation references:

1. polished Figma pages `08–12`;
2. Track A phase plan and vNext Figma implementation handoff;
3. `13 — Prototype Flows` for interaction intent;
4. existing production code for truthful engine/data behavior.

## 2. Current code equivalents

| Required equivalent | Current source |
|---|---|
| AppShell | `lib/app/app_shell.dart` |
| HomeScreen / Train entry | `lib/features/home/presentation/home_screen.dart` |
| PlanTodaySheet / setup | `lib/features/plan/presentation/plan_today_sheet.dart` |
| CameraPage | `lib/camera_page.dart` |
| WorkoutHud | `lib/features/workout/presentation/widgets/workout_hud.dart` |
| WorkoutController | `lib/features/workout/application/workout_controller.dart` |
| WorkoutUiState | `lib/features/workout/application/workout_ui_state.dart` |
| RepTracker | `lib/features/workout/domain/rep_tracker.dart` |
| RepQualityAnalyzer | `lib/features/workout/domain/rep_quality_analyzer.dart` |
| ResultPage | `lib/features/workout/presentation/result_page.dart` |
| HistoryPage | `lib/features/workout/presentation/history_page.dart` |
| SettingsPage | `lib/features/legal/settings_page.dart` |
| TrainingPreferences | `lib/core/services/training_preferences.dart` |
| WorkoutFeedback | `lib/core/services/workout_feedback.dart` |
| WorkoutHistoryStore | `lib/features/workout/data/workout_history_store.dart` |
| WorkoutRecord | `lib/features/workout/data/workout_record.dart` |

## 3. Architecture audit

The current production chain is compatible with the vNext guardrail:

```text
RepCounter
→ RepTracker
→ WorkoutController
→ WorkoutUiState
→ WorkoutHud / WorkoutRecord / ResultPage
```

Observed contracts:

- `RepTracker` wraps `RepCounter`; it emits `RepCompleted` only after the
  production counter accepts the motion.
- `WorkoutController.acceptRep` consumes an already accepted observation and owns
  the session total exposed as `WorkoutUiState.reps`.
- `WorkoutUiState` is a read-only projection and does not contain a second counter.
- `CameraPage` routes completed tracker events into `WorkoutController.acceptRep`;
  quality flags are used for feedback/cues and do not subtract the accepted count.
- `WorkoutRecord.fromSummary` persists the workout summary total.
- CI production replay finishes through the normal save/result transition and checks
  `HUD == saved == result`.
- `AppShell` preserves the three destinations Train / History / Settings.
- `TrainingPreferences` and `WorkoutFeedback` already keep voice, haptics, set
  sounds and posture cues separate; speech uses latest-event-wins behavior.
- `WorkoutHistoryStore` is local SharedPreferences storage and preserves old/unknown
  record data during mutations.

No new global state-management framework is required for vNext.

## 4. Figma mapping

### 00 — Design System

| Shared component | Node |
|---|---|
| Feedback Pill | `23:26` |
| Segment Chip | `23:31` |
| Metric Card | `23:32` |
| Choice Row | `23:46` |
| Format Option | `23:57` |

Feedback Pill variants are present for Clean, Warning, Interrupted and PoseLost.

### 08 — vNext Feedback & Form

| # | Frame | Node |
|---|---|---|
| 01 | Camera — counted clean | `16:5` |
| 02 | Camera — counted with warning | `16:31` |
| 03 | Camera — interrupted placement | `16:57` |
| 04 | Camera — pose lost | `16:83` |
| 05 | Form Score details sheet | `16:109` |
| 06 | Form Score insufficient data | `16:142` |

### 09 — vNext Time Challenge

| # | Frame | Node |
|---|---|---|
| 07 | Time Challenge setup | `17:5` |
| 08 | Time Challenge active HUD | `17:35` |
| 09 | Time Challenge final 10 seconds | `17:65` |
| 10 | Result — new PR | `17:97` |
| 11 | Result — no PR | `17:117` |

### 10 — vNext Progress & PR

| # | Frame | Node |
|---|---|---|
| 12 | Progress — 7 day | `18:5` |
| 13 | Progress — 30 day | `18:101` |
| 14 | Progress — 90 day | `18:202` |
| 15 | Progress — empty | `18:303` |
| 16 | Personal Records | `18:327` |

### 11 — vNext Export & Routines

| # | Frame | Node |
|---|---|---|
| 17 | Export Data sheet | `19:5` |
| 18 | Export preparing | `19:30` |
| 19 | Export error / empty | `19:48` |
| 20 | Routine list | `19:72` |
| 21 | Routine editor | `19:99` |
| 22 | Routine rest state | `19:129` |

### 12 — vNext Achievements & Voice

| # | Frame | Node |
|---|---|---|
| 23 | Achievement earned card | `20:5` |
| 24 | Voice cadence settings | `20:24` |

### 13 — Prototype Flows

Mapped reference nodes:

- Time Challenge: `32:2`, `32:23`, `32:46`, `32:71`, `32:85`
- Export: `32:99`, `32:120`, `32:132`
- Routines: `32:149`, `32:171`, `32:195`
- Form reference: `32:208`, `32:236`
- Achievement: `32:251`
- Voice cadence: `32:265`

Prototype hotspots are demonstration-only. Production state/time remains authoritative.

## 5. Regression baseline evidence

Expected engine regression metadata:

```text
pushup-a = 28
pushup-b = 67
HUD == saved == result
accepted rep count is monotonic
```

The counts are regression baselines, not human-verified accuracy labels.

### Current main — GitHub Actions run #24

Commit: `902b6ab1acfe6f72f5d8f4676afa9bd1c1d53d61`

- Analyze and Flutter tests: **PASS**
- pushup-1 production replay: **PASS**
  - frames: 3901
  - HUD reps: 28
  - saved reps: 28
  - result reps: 28
- pushup-2 production replay, attempt 1: **INCONCLUSIVE / POLL TIMEOUT**
  - fixture loaded successfully;
  - build/replay started;
  - polling ended before `CI_VIDEO_RESULT`;
  - there is no logged count mismatch to justify a re-baseline.
- pushup-2 production replay, attempt 2: **CANCELLED BY JOB TIME LIMIT**
  - analyze/tests and pushup-1 remained green;
  - replay continued making forward progress and did not hit the five-minute stall detector;
  - last recorded status before cancellation:
    - `at_ms=1550000` of `total_ms=1801219`;
    - `frames=7751`;
    - `reps=65`;
    - `phase=active`;
  - the job then ended with `The operation was canceled.`;
  - the workflow config sets `timeout-minutes: 75` for this iOS replay job, so the
    observed cancellation is consistent with infrastructure timeout rather than a
    rep-count mismatch.

Therefore current `main` still does not have a completed green pushup-2 result. The
evidence points to insufficient CI time budget, not to a demonstrated engine regression.
Do not change the 67 baseline to make CI green.

### Last complete green two-video run — GitHub Actions run #23

Commit: `bacff38e00eef46e3d1acb79bc563f78a2edbecf`

- Analyze and Flutter tests: **PASS**
- pushup-1:
  - HUD = 28
  - saved = 28
  - result = 28
- pushup-2:
  - HUD = 67
  - saved = 67
  - result = 67

The current audited main is three commits ahead of that run. The changed paths between
run #23 and current main are limited to:

- `lib/features/ai/presentation/ai_consent.dart`
- `lib/features/workout/presentation/widgets/result_feedback_card.dart`
- `test/phase7_test.dart`

No camera, RepCounter, RepTracker, WorkoutController, WorkoutUiState or persistence
engine file changed in that comparison. This supports keeping 28/67 as the regression
baseline, but it does **not** convert the timed-out current pushup-2 run into a pass.

### Final A0 validation — GitHub Actions run #29

Commit: `434f402597b2fab71377584a23863fcdaec7676a`

- Analyze and Flutter tests: **PASS**
- pushup-1 production replay: **PASS**
  - frames: 3901
  - HUD reps: 28
  - saved reps: 28
  - result reps: 28
- pushup-2 production replay: **PASS**
  - frames: 9007
  - HUD reps: 67
  - saved reps: 67
  - result reps: 67

Run #29 completed successfully after extending the job timeout and the internal polling
window. The rep engine and frozen regression baselines were not changed.

## 6. Ground-truth metadata rule

`test/fixtures/video_ground_truth.json` deliberately keeps
`human_ground_truth: null` for both push-up fixtures.

Human ground truth must only be populated after manual annotation. Engine baseline and
human annotation must remain separately measurable.

## 7. A0 acceptance status

| Acceptance item | Status |
|---|---|
| Architecture documented | PASS |
| Figma pages/frames mapped | PASS |
| Shared Figma components confirmed | PASS |
| Current analyze/tests | PASS |
| Current production replay A = 28 and HUD=saved=result | PASS |
| Current production replay B = 67 and HUD=saved=result | PASS |
| Ground-truth metadata file created | PASS |
| Guardrail ADR created | PASS |
| Unnecessary product code changes | NONE |

A0 is fully green on run #29. Baselines remain 28 / 67 and are still distinct from
human ground truth.

## 8. CI timeout remediation

The infrastructure timeout identified during A0 was fixed on `main` without touching
the rep engine:

- commit `9bfc57057fb03c7ba671c72b2a3136c3ef3fcd7e`: iOS replay job
  `timeout-minutes` increased from `75` to `110`;
- commit `434f402597b2fab71377584a23863fcdaec7676a`: internal replay polling
  window increased from `660` to `960` iterations;
- five-minute stall detection remains unchanged;
- final validation: GitHub Actions run #29 (`36806535665`) — **SUCCESS**;
- baseline remains `pushup-a = 28`, `pushup-b = 67`.

These were infrastructure-only changes. No rep-counting algorithm or production
baseline was changed to make CI green.

## 9. Stop boundary

No A1 implementation is included in this branch.
