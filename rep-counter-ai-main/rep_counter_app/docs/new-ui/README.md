# UI migration — 27 September 2026

## Screens now using the new presentation

- Onboarding (three swipeable pages, skip, local privacy/terms).
- Home, exercise picker, plan/goal setup (including custom/free goals).
- Camera consent, denied/unavailable/retry states.
- Camera positioning, real calibration samples, active HUD, goal/over-goal,
  pause/resume, hold-to-finish, saving/error recovery.
- Phase 6: explicit start, stable-pose countdown, speech/haptics and persistent
  training preferences. See [Phase 6 evidence and scope](../phase6/README.md).
- Phase 7: complete result hero variants and consolidated AI/on-device feedback,
  network retry and feedback-save recovery. See [Phase 7](../phase7/README.md).
- Phase 8: grouped rep pace, stored quality-note categories, history detail
  deletion/undo and compatible storage hardening. See [Phase 8](../phase8/README.md).
- Results/history detail: actual goal ring, offline feedback, optional AI request,
  form breakdown, per-rep timing when available, fixed Done button.
- History, settings, exercise help, legal pages.
- Supplied brand icon and dark native launch screen.

All are Flutter widgets. HTML remains a design reference only.

## Evidence

[Native iOS onboarding](ios26-onboarding.png) is the **actual updated app** installed
and launched on RepCoach iPhone 17 Pro, iOS 26.0 Universal, arm64 runtime / x86_64
app via Rosetta. The old path `../phase4/ios26-onboarding.png` has also been updated.
The simulator's system language is English, so its first-launch copy is English.

The following are **widget renders, not native camera screenshots**. Results/HUD
use test fixtures defined exclusively in `test/new_ui_test.dart`; production never
loads these sample records:

- [Onboarding 1](onboarding-1.png), [2](onboarding-2.png), [3](onboarding-3.png)
- [Plan](goal-setup.png)
- [Camera permission](camera-permission.png), [denied](camera-denied.png)
- [Positioning](hud-positioning.png), [active](hud-active.png),
  [calibration](hud-calibrating.png), [pause](hud-paused.png)
- [Result](result.png), [form and pace detail](result-detail.png)

Generate widget renders:

```bash
flutter test test/new_ui_test.dart \
  --dart-define=NEW_UI_SCREENSHOTS=/tmp/repcoach-new-ui
```

## Engine and behavior

- Original counter, exercise profiles, placement, pose mapper and all workout
  domain files are byte-identical to the original archive.
- Camera selection, image conversion and coordinate mapping are preserved.
- Pause interrupts transient trackers and clears placement grace. An explicit
  pause survives background/foreground; resume retains the session. It auto-saves
  after five minutes, and one-second hold cancels when released early.
- A goal banner appears once for three seconds without blocking counting.
- Saving stops frame acceptance and releases the camera; a local-save error
  retains the controller for retry. AI never blocks saving.
- `rep_details` is an optional local record field containing measured duration,
  set index and quality notes. Phase 8 adds optional flag names and detail version
  2, while retaining the same history key and legacy readers. Details remain
  excluded from the existing aggregate AI payload.

## Deliberate differences from the prototype

This change replaces existing screens, not every proposed future feature:
- Calibration remains manual, backed by actual samples/thresholds. It does not
  pretend that exactly three demonstration reps complete calibration.
- Counting now starts after explicit intent, 1.5 seconds of stable placement and
  a 3–2–1 countdown. Voice/haptic switches persist and control real services.
- AI defaults to manual requests. Settings can enable automatic feedback for newly
  saved workouts after explicit consent; history never uploads automatically.
- Results/history support a 1080 × 1920 story image, Photos saving and the native
  share sheet. See [feature completion](../feature-completion/README.md).
- Physical camera/10-rep validation remains required. Simulator screenshots and
  mocked plugin tests do not establish pose alignment or counting accuracy.
- Device Hub UI automation timed out; native installation/launch/screenshot was
  verified using simctl. Tap flows were exercised in widget tests.

## Checks

- `flutter analyze`: clean.
- `flutter test`: 302 passing (including the feature completion increment).
- Simulator debug build: passed; updated app installed and launched.
- Unsigned iPhone release build: passed (68.6 MB).
