# integration_test — QA v2 app-level journeys

Added by the independent QA pass (docs/qa/QA_REPORT_v2.md). These drive the
**real app root** (`RepCounterApp`, `AppShell`) through whole journeys; the
native boundaries are faked in `support/app_harness.dart` (permission prompt
answers, no camera, no TTS, no notifications granted, no network). The rep
engine is never started and no app code was changed.

Run on the host (no device; what CI can run). `flutter test` refuses files
under `integration_test/` without a device, so each journey is re-exported by
a one-line runner in `test/qa_journeys/` (which also picks up
`test/flutter_test_config.dart`: in-memory workout database):

```bash
flutter test test/qa_journeys
```

Result on 2026-11-10 (Flutter 3.47.5, Linux host): 36 journeys, all passed.

Run on a device or simulator (same tests; the OS prompts are still faked, so a
device run checks layout/plugins, not the real permission dialogs — those are
in docs/qa/DEVICE_CHECKLIST_v2.md):

```bash
flutter test integration_test -d <device-id>
```

| File | Journey |
|---|---|
| `onboarding_shell_test.dart` | fresh install → EN onboarding → shell; Skip; relaunch; Android back on Home; language switch persists |
| `camera_permission_journey_test.dart` | Home › Train › start → camera gate: Continue only; Don't Allow → Home (no notice, no Settings); camera off → neutral notice; granted-but-no-camera → Track manually → History "Manual"; VI copy |
| `recovery_journey_test.dart` | draft from a killed workout → Recovery: Save partial → History "Partial"; Discard; expired draft without Resume |
| `deep_link_journey_test.dart` | `repcoach://` links: needs-account fallback, stale session/workout notices, held while another route is open, launch link |
| `settings_legal_journey_test.dart` | Settings › Privacy/Terms with web links, About rows, no placeholders, delete local history (typed word), automatic-AI consent |
| `accounts_ui_journey_test.dart` | in-memory auth: guest → Sign in (Apple above Google, equal size, email); signed in → Delete account (typed word, network failure, success); VI "XÓA" |
| `plan_reminder_journey_test.dart` | create default plan → overview › Workout reminders: Continue only, Don't Allow → overview, notice on reopen |
| `large_text_journey_test.dart` | EN/VI at text scale 2.0: onboarding, tabs, Settings, Privacy, camera gate, camera-off notice (overflow = failure) |
