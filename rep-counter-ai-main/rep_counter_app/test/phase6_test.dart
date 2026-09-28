import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/core/services/training_preferences.dart';
import 'package:rep_counter_app/core/services/workout_feedback.dart';
import 'package:rep_counter_app/exercise.dart';
import 'package:rep_counter_app/placement.dart';
import 'package:rep_counter_app/features/legal/settings_page.dart';
import 'package:rep_counter_app/features/workout/application/workout_controller.dart';
import 'package:rep_counter_app/features/workout/application/workout_ui_state.dart';
import 'package:rep_counter_app/features/workout/presentation/widgets/workout_hud.dart';
import 'package:rep_counter_app/theme/app_theme.dart';
import 'features/workout/workout_controller_test.dart'
    show FakeClock, observation, calibration;

class FakeSpeech implements SpeechDriver {
  final spoken = <String>[];
  final locales = <String>[];
  int stops = 0;
  bool fail = false;
  Completer<void>? gate;
  @override
  Future<void> configure(String locale) async {
    await gate?.future;
    if (fail) throw StateError('No voice');
    locales.add(locale);
  }

  @override
  Future<void> speak(String text) async {
    spoken.add(text);
  }

  @override
  Future<void> stop() async {
    stops++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeClock clock, tracking;
  late WorkoutController controller;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    clock = FakeClock();
    tracking = FakeClock();
    controller = WorkoutController(
        profile: pushUp,
        targetReps: 2,
        clock: clock,
        trackingClock: tracking,
        saveRecord: (_) async {});
  });
  tearDown(() => controller.dispose());
  void frame({bool ready = true, bool grace = false}) =>
      controller.frameProcessed(
          at: tracking.elapsed,
          poseFound: ready,
          countable: ready || grace,
          status: ready ? PlacementStatus.ready : PlacementStatus.noPose,
          message: '',
          calibrationSamples: 32);
  Future<void> advance(WidgetTester tester, int milliseconds,
      {bool frames = true}) async {
    for (var i = 0; i < milliseconds; i += 250) {
      if (tracking.isRunning) {
        tracking.elapsed += const Duration(milliseconds: 250);
      }
      if (clock.isRunning) clock.elapsed += const Duration(milliseconds: 250);
      await tester.pump(const Duration(milliseconds: 250));
      if (frames) frame();
    }
  }

  Future<void> beginCountdown(WidgetTester tester) async {
    controller.cameraStarted();
    controller.requestStart();
    frame();
    await advance(tester, 1500);
    expect(controller.state.countdown, 3);
  }

  testWidgets('stable placement then exact 3-2-1; no warmup reps/time/quality',
      (tester) async {
    controller.cameraStarted();
    frame();
    await advance(tester, 2500);
    expect(
        controller.state.countdown, isNull); // Explicit start intent required.
    expect(clock.elapsed, Duration.zero);
    controller.requestStart();
    frame();
    await advance(tester, 1500);
    for (final number in [3, 2, 1]) {
      expect(controller.state.countdown, number);
      controller.acceptRep(observation(5), tracking.elapsed);
      expect(controller.state.reps, 0);
      expect(clock.elapsed, Duration.zero);
      await advance(tester, 1000);
    }
    expect(controller.state.sessionStarted, isTrue);
    expect(controller.acceptsReps, isTrue);
    expect(controller.state.countdown, isNull);
    await advance(tester, 2000);
    expect(controller.elapsed, const Duration(seconds: 2));
    controller.acceptRep(observation(9), tracking.elapsed);
    expect(controller.state.reps, 1);
    final record = await controller.finish(calibration: calibration);
    expect(record.poseFrames, 9);
    expect(record.durationSeconds, 2);
  });
  testWidgets(
      'placement grace cannot keep countdown alive; restarts from three',
      (tester) async {
    await beginCountdown(tester);
    frame(ready: false, grace: true);
    expect(controller.state.countdown, isNull);
    await advance(tester, 1000);
    expect(controller.state.sessionStarted, isFalse);
    await advance(tester, 500);
    // The first new ready sample is at +250ms, so full stability takes 1750ms.
    expect(controller.state.countdown, isNull);
    await advance(tester, 250);
    expect(controller.state.countdown, 3);
    controller.abort();
  });
  testWidgets('a frame gap resets readiness before countdown begins',
      (tester) async {
    controller.cameraStarted();
    controller.requestStart();
    frame();
    await advance(tester, 500);
    await advance(tester, 2000, frames: false);
    frame();
    expect(controller.state.countdown, isNull);
    await advance(tester, 1500);
    expect(controller.state.countdown, 3);
    controller.abort();
  });
  testWidgets('calibration interrupts countdown and abort cannot arm later',
      (tester) async {
    await beginCountdown(tester);
    controller.calibrationChanged(
        collecting: true, calibrated: false, samples: 0);
    await advance(tester, 5000);
    expect(controller.state.phase, WorkoutUiPhase.calibrating);
    expect(controller.state.sessionStarted, isFalse);
    controller.calibrationChanged(
        collecting: false, calibrated: true, samples: 120);
    frame();
    await advance(tester, 1500);
    expect(controller.state.countdown, 3);
    controller.abort();
    await advance(tester, 5000);
    expect(controller.state.phase, WorkoutUiPhase.aborted);
    expect(controller.state.sessionStarted, isFalse);
  });
  testWidgets(
      'stalled pose processing cancels instead of arming from old frame',
      (tester) async {
    await beginCountdown(tester);
    await advance(tester, 4000, frames: false);
    expect(controller.state.countdown, isNull);
    expect(controller.state.sessionStarted, isFalse);
    expect(clock.elapsed, Duration.zero);
  });
  testWidgets(
      'background cancels countdown and resume requires fresh stability',
      (tester) async {
    await beginCountdown(tester);
    controller.pause();
    await advance(tester, 5000);
    expect(controller.state.phase, WorkoutUiPhase.paused);
    expect(controller.state.countdown, isNull);
    controller.cameraStarted();
    frame();
    await advance(tester, 1500);
    expect(controller.state.countdown, 3);
    await advance(tester, 3000);
    expect(controller.acceptsReps, isTrue);
    await advance(tester, 1000);
    controller.pause();
    await advance(tester, 4000);
    controller.cameraStarted();
    await advance(tester, 1000);
    expect(
        controller.state.countdown, isNull); // Resume an active session once.
    expect(controller.elapsed, const Duration(seconds: 2));
  });
  testWidgets('real calibration samples cannot add workout reps or time',
      (tester) async {
    controller.cameraStarted();
    controller.calibrationChanged(
        collecting: true, calibrated: false, samples: 0);
    controller.requestStart();
    await advance(tester, 5000);
    controller.acceptRep(observation(4), tracking.elapsed);
    expect(controller.state.calibrationSamples, 32);
    expect(controller.state.reps, 0);
    expect(controller.state.countdown, isNull);
    expect(clock.elapsed, Duration.zero);
    controller.calibrationChanged(
        collecting: false, calibrated: true, samples: 100);
    controller.requestStart();
    frame();
    await advance(tester, 4500);
    expect(controller.acceptsReps, isTrue);
    await advance(tester, 1000);
    controller.calibrationChanged(
        collecting: true, calibrated: true, samples: 0);
    await advance(tester, 3000);
    controller.acceptRep(observation(10), tracking.elapsed);
    expect(controller.elapsed, const Duration(seconds: 1));
    expect(controller.state.reps, 0);
    controller.calibrationChanged(
        collecting: false, calibrated: true, samples: 120);
    await advance(tester, 1000);
    expect(controller.elapsed, const Duration(seconds: 2));
  });
  testWidgets('finish and abort cancel all countdown callbacks',
      (tester) async {
    await beginCountdown(tester);
    await controller.finish(calibration: calibration);
    await advance(tester, 5000);
    expect(controller.state.phase, WorkoutUiPhase.done);
    expect(controller.state.sessionStarted, isFalse);
    expect(clock.isRunning, isFalse);
  });
  testWidgets('countdown UI and start action render at 2x text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final locale = LocaleController();
    addTearDown(locale.dispose);
    controller.cameraStarted();
    await tester.pumpWidget(LocaleScope(
        controller: locale,
        child: MaterialApp(
            theme: RepCoachTheme.dark(),
            home: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: Scaffold(
                    body: ListenableBuilder(
                        listenable: controller,
                        builder: (context, _) => WorkoutHud(
                            state: controller.state,
                            exerciseName: 'Hít đất',
                            hint: 'Đặt máy thấp',
                            onStart: controller.requestStart,
                            voiceEnabled: false,
                            onExit: () {},
                            onPause: controller.pause,
                            onResume: controller.cameraStarted,
                            onFinish: () {},
                            onCalibrate: () {},
                            onHelp: () {},
                            goalBanner: false,
                            onDismissGoal: () {})))))));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('start-countdown')));
    await tester.tap(find.byKey(const Key('start-countdown')));
    frame();
    await advance(tester, 1500);
    await tester.pump();
    expect(find.byKey(const Key('countdown-number')), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(tester.takeException(), isNull);
    controller.abort();
    await tester.pumpWidget(const SizedBox());
  });
  test('feedback speaks each rep/goal once and respects mute/haptic settings',
      () async {
    final speech = FakeSpeech();
    final vibrations = <bool>[];
    final f = WorkoutFeedback(
        speech: speech,
        haptic: (v) async {
          vibrations.add(v);
        });
    f.rep(1, goalReached: false);
    await f.settled;
    f.rep(1, goalReached: false);
    await f.settled;
    f.rep(2, goalReached: true);
    await f.settled;
    expect(speech.spoken, ['1', '2. Đạt mục tiêu!']);
    expect(vibrations, [false, true]);
    f.configure(const TrainingPreferences(voice: false, haptics: false),
        AppLanguage.en);
    f.rep(3, goalReached: false);
    await f.settled;
    expect(speech.spoken.length, 2);
    expect(vibrations.length, 2);
    f.configure(const TrainingPreferences(), AppLanguage.en);
    f.rep(4, goalReached: false);
    await f.settled;
    expect(speech.spoken.last, '4');
    expect(speech.locales.last, 'en-US');
    f.dispose();
    await f.settled;
  });
  test(
      'newest speech replaces pending counts, pause and dispose invalidate late work',
      () async {
    final speech = FakeSpeech()..gate = Completer<void>();
    final f = WorkoutFeedback(speech: speech, haptic: (_) async {});
    f.rep(1, goalReached: false);
    await Future<void>.delayed(Duration.zero);
    f.rep(2, goalReached: false);
    f.rep(3, goalReached: false);
    speech.gate!.complete();
    await f.settled;
    expect(speech.spoken, ['3']);
    speech.gate = Completer<void>();
    f.countdown(3);
    await Future<void>.delayed(Duration.zero);
    f.stop();
    speech.gate!.complete();
    await f.settled;
    expect(speech.spoken, ['3']);
    f.rep(4, goalReached: false);
    f.dispose();
    await f.settled;
    expect(speech.spoken, ['3']);
  });
  test('system haptics map one rep and one goal to light and medium', () async {
    final calls = <Object?>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') calls.add(call.arguments);
      return null;
    });
    final f = WorkoutFeedback(speech: FakeSpeech());
    f.configure(const TrainingPreferences(voice: false), AppLanguage.vi);
    f.rep(1, goalReached: false);
    f.rep(1, goalReached: false);
    f.rep(2, goalReached: true);
    await f.settled;
    expect(calls,
        ['HapticFeedbackType.lightImpact', 'HapticFeedbackType.mediumImpact']);
    f.dispose();
    await f.settled;
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });
  test('countdown and start speak Vietnamese in order', () async {
    final speech = FakeSpeech();
    final f = WorkoutFeedback(speech: speech, haptic: (_) async {});
    for (final n in [3, 2, 1]) {
      f.countdown(n);
      await f.settled;
    }
    f.started();
    await f.settled;
    expect(speech.spoken, ['Ba', 'Hai', 'Một', 'Bắt đầu!']);
    f.dispose();
    await f.settled;
  });
  test('missing voice reports once and never breaks haptics or counting events',
      () async {
    final speech = FakeSpeech()..fail = true;
    var errors = 0, haptics = 0;
    final f = WorkoutFeedback(
        speech: speech,
        onVoiceUnavailable: () => errors++,
        haptic: (_) async {
          haptics++;
        });
    f.countdown(3);
    await f.settled;
    f.countdown(2);
    await f.settled;
    f.rep(1, goalReached: false);
    await f.settled;
    expect(errors, 1);
    expect(haptics, 3);
    expect(speech.spoken, isEmpty);
    f.dispose();
    await f.settled;
  });
  testWidgets('settings toggles persist and reload independently',
      (tester) async {
    final locale = LocaleController();
    addTearDown(locale.dispose);
    await tester.pumpWidget(LocaleScope(
        controller: locale,
        child: MaterialApp(
            theme: RepCoachTheme.dark(), home: const SettingsPage())));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('voice-setting')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('haptics-setting')));
    await tester.tap(find.byKey(const Key('haptics-setting')));
    await tester.pumpAndSettle();
    final saved = await TrainingPreferences.load();
    expect(saved.voice, isFalse);
    expect(saved.haptics, isFalse);
    expect(tester.takeException(), isNull);
  });
}
