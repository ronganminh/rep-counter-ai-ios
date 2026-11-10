// QA v2 · J-02 camera permission journeys from the real shell
// (App Store 5.1.1(iv), L-D24 / L-D38; Play restricted permissions).
//
// Home › Train › Start free workout › camera gate, with the OS prompt
// scripted by the permission_handler fake. The engine is never started
// (no camera on the fake platform).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/app/app_shell.dart';
import 'package:rep_counter_app/app/app_tab_bar.dart';
import 'package:rep_counter_app/camera_page.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/features/workout/data/workout_history_store.dart';
import 'package:rep_counter_app/features/workout/presentation/history_page.dart';
import 'package:rep_counter_app/features/workout/presentation/manual_log_page.dart';
import 'package:rep_counter_app/features/workout/presentation/widgets/camera_permission_view.dart';

import 'support/app_harness.dart';

void main() {
  final binding = ensureQaBinding();
  late PluginFakes fakes;
  const s = S.en;

  setUp(() {
    fakes = PluginFakes(binding.defaultBinaryMessenger)..install();
  });
  tearDown(() => fakes.uninstall());

  Finder tab(String label) =>
      find.descendant(of: find.byType(AppTabBar), matching: find.text(label));

  /// Home › Train (centre action) › sheet › Start free workout.
  Future<void> startFreeWorkout(WidgetTester tester) async {
    await tapKey(tester, 'tab-train');
    expect(find.byKey(const Key('mode-free')), findsOneWidget,
        reason: 'Train sheet with the goal setup');
    await tapKey(tester, 'mode-free');
    await tapKey(tester, 'start-free-workout');
    expect(find.byType(CameraPage), findsOneWidget);
    expect(find.byType(AppTabBar), findsNothing,
        reason: 'D-02: no tab bar over the camera flow');
  }

  testWidgets(
      'not asked yet: explanation with Continue only; back does nothing; '
      'Continue shows the OS prompt once', (tester) async {
    await pumpApp(tester, prefs: {'onboarding_v1': true, 'app_language': 'en'});
    expect(fakes.permissionCalls, isEmpty, reason: 'nothing at launch');
    await startFreeWorkout(tester);

    expect(find.text(s.cameraPermissionTitle), findsOneWidget);
    expect(find.widgetWithText(FilledButton, s.cameraContinue), findsOneWidget);
    for (final text in visibleTexts(tester)) {
      expect(text.toLowerCase(), isNot(contains('allow')), reason: text);
    }
    expect(find.text('Not now'), findsNothing);
    expect(find.byKey(const Key('camera-track-manually')), findsNothing);
    expect(find.byType(BackButton), findsNothing);
    expect(find.byType(CloseButton), findsNothing);
    expect(fakes.cameraPrompts, 0, reason: 'no prompt before Continue');

    await systemBack(tester);
    expect(find.text(s.cameraPermissionTitle), findsOneWidget,
        reason: 'no way out before the prompt (iOS rule, applied to both)');

    await tapText(tester, s.cameraContinue);
    expect(fakes.cameraPrompts, 1);
    await closeApp(tester);
  });

  for (final answer in [permissionPermanentlyDenied, permissionDenied]) {
    testWidgets(
        "Don't Allow (status $answer) returns to Home: no denied screen, "
        'no Settings, no second prompt, nothing saved', (tester) async {
      fakes.cameraRequestResult = answer;
      await pumpApp(tester,
          prefs: {'onboarding_v1': true, 'app_language': 'en'});
      await startFreeWorkout(tester);
      await tapText(tester, s.cameraContinue);

      expect(find.byType(CameraPage), findsNothing);
      expect(find.byType(CameraOffNotice), findsNothing);
      expect(find.text(s.cameraOffMessage), findsNothing);
      expect(find.byType(AppShell), findsOneWidget);
      expect(tab('Home'), findsOneWidget, reason: 'back on the shell');
      expect(find.byType(SnackBar), findsNothing,
          reason: 'no message that asks the user to reconsider');
      expect(fakes.cameraPrompts, 1);
      expect(fakes.settingsOpened, 0);
      expect(fakes.cameraRequests, 0, reason: 'camera never opened');
      expect(await WorkoutHistoryStore().load(), isEmpty);
      await closeApp(tester);
    });
  }

  for (final status in [permissionPermanentlyDenied, permissionRestricted]) {
    testWidgets(
        'camera off when starting (status $status): neutral notice only; '
        'Back returns to Home; Open Settings is a plain link', (tester) async {
      fakes.cameraStatus = status;
      await pumpApp(tester,
          prefs: {'onboarding_v1': true, 'app_language': 'en'});
      await startFreeWorkout(tester);

      expect(find.byType(CameraOffNotice), findsOneWidget);
      expect(visibleTexts(tester).toList(),
          [s.cameraOffMessage, s.cameraBack, s.openSettings],
          reason: 'one sentence and two equal buttons, nothing else');
      expect(fakes.cameraPrompts, 0, reason: 'never asked again');

      await tapKey(tester, 'camera-off-settings');
      expect(fakes.settingsOpened, 1);
      expect(find.byType(CameraOffNotice), findsOneWidget,
          reason: 'the app only opens Settings; nothing else changes');

      await tapKey(tester, 'camera-off-back');
      expect(find.byType(CameraPage), findsNothing);
      expect(tab('Home'), findsOneWidget);
      await closeApp(tester);
    });
  }

  testWidgets('camera off: Android system back also leaves the notice',
      (tester) async {
    fakes.cameraStatus = permissionPermanentlyDenied;
    await pumpApp(tester, prefs: {'onboarding_v1': true, 'app_language': 'en'});
    await startFreeWorkout(tester);
    expect(find.byType(CameraOffNotice), findsOneWidget);
    await systemBack(tester);
    expect(find.byType(CameraPage), findsNothing);
    expect(fakes.settingsOpened, 0);
    await closeApp(tester);
  });

  testWidgets(
      'granted but no camera: unavailable state offers Track manually; '
      'a manual workout reaches History labelled Manual', (tester) async {
    fakes.cameraStatus = permissionGranted;
    await pumpApp(tester, prefs: {'onboarding_v1': true, 'app_language': 'en'});
    await startFreeWorkout(tester);
    expect(find.text(s.cameraUnavailable), findsOneWidget);
    expect(fakes.cameraRequests, greaterThanOrEqualTo(1));
    expect(find.text(s.retry), findsOneWidget);

    await tapKey(tester, 'camera-track-manually');
    expect(find.byType(ManualLogPage), findsOneWidget);
    expect(find.byType(CameraPage), findsNothing);
    await tapKey(tester, 'manual-plus');
    await tapKey(tester, 'manual-plus');
    await tapKey(tester, 'manual-plus');
    await tapKey(tester, 'manual-save');

    expect(find.byType(ManualLogPage), findsNothing);
    expect(find.byType(AppShell), findsOneWidget);
    final saved = await WorkoutHistoryStore().load();
    expect(saved, hasLength(1));
    expect(saved.single.reps, 3);
    expect(saved.single.manual, isTrue);

    await tester.tap(tab('Progress'));
    await settle(tester);
    await tapKey(tester, 'open-history-list');
    expect(find.byType(HistoryPage), findsWidgets);
    expect(find.byKey(const Key('history-manual')), findsOneWidget,
        reason: 'W-4: manual records are labelled in History');
    await closeApp(tester);
  });

  testWidgets('Vietnamese copy on the gate and the notice', (tester) async {
    const vi = S.vi;
    fakes.cameraStatus = permissionDenied;
    await pumpApp(tester, prefs: {'onboarding_v1': true, 'app_language': 'vi'});
    await tapKey(tester, 'tab-train');
    await tapKey(tester, 'mode-free');
    await tapKey(tester, 'start-free-workout');
    expect(find.text(vi.cameraPermissionTitle), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Tiếp tục'), findsOneWidget);
    for (final text in visibleTexts(tester)) {
      expect(text.toLowerCase(), isNot(contains('cho phép')), reason: text);
    }
    await closeApp(tester);

    fakes.cameraStatus = permissionPermanentlyDenied;
    await pumpApp(tester, prefs: {'onboarding_v1': true, 'app_language': 'vi'});
    await tapKey(tester, 'tab-train');
    await tapKey(tester, 'mode-free');
    await tapKey(tester, 'start-free-workout');
    expect(visibleTexts(tester).toList(),
        [vi.cameraOffMessage, vi.cameraBack, vi.openSettings]);
    await closeApp(tester);
  });
}
