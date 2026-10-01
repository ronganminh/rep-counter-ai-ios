import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/exercise.dart';
import 'package:rep_counter_app/features/workout/application/workout_controller.dart';
import 'package:rep_counter_app/features/workout/application/workout_ui_state.dart';
import 'package:rep_counter_app/features/workout/data/workout_record.dart';
import 'package:rep_counter_app/features/workout/domain/quality_thresholds.dart';
import 'package:rep_counter_app/features/workout/domain/rep_metric.dart';
import 'package:rep_counter_app/features/workout/domain/workout_mode.dart';
import 'package:rep_counter_app/features/workout/domain/workout_personal_records.dart';
import 'package:rep_counter_app/features/workout/presentation/goal_setup_page.dart';
import 'package:rep_counter_app/features/workout/presentation/widgets/timed_challenge_result.dart';
import 'package:rep_counter_app/features/workout/presentation/widgets/workout_hud.dart';
import 'package:rep_counter_app/placement.dart';
import 'package:rep_counter_app/rep_counter.dart';
import 'package:rep_counter_app/theme/app_theme.dart';

class _Clock implements WorkoutClock {
  @override
  Duration elapsed = Duration.zero;
  @override
  bool isRunning = false;

  @override
  void start() => isRunning = true;

  @override
  void stop() => isRunning = false;

  void advance(Duration by) {
    if (isRunning) elapsed += by;
  }
}

RepObservation _rep(Duration completedAt) => RepObservation(
      startedAt: completedAt - const Duration(seconds: 2),
      bottomAt: completedAt - const Duration(seconds: 1),
      completedAt: completedAt,
      bottomAngle: 90,
      topAngle: 160,
      leftBottomAngle: 90,
      rightBottomAngle: 92,
      sampleCount: 20,
      averagePoseConfidence: .9,
    );

const _calibration =
    CalibrationSnapshot(repHi: 140, repLo: 100, minAmplitude: 40);

void _frame(WorkoutController controller) => controller.frameProcessed(
      at: controller.frameTime,
      poseFound: true,
      countable: true,
      status: PlacementStatus.ready,
      message: 'Ready',
      calibrationSamples: 10,
    );

WorkoutRecord _record({
  required String id,
  required int reps,
  required int duration,
  int challenge = 60,
  String exerciseId = 'push_up',
  WorkoutMode mode = WorkoutMode.timed,
}) =>
    WorkoutRecord(
      id: id,
      exerciseId: exerciseId,
      exerciseName: 'Push-up',
      startedAt: DateTime(2026, 10, 1),
      durationSeconds: duration,
      reps: reps,
      sets: 1,
      targetReps: null,
      mode: mode,
      challengeSeconds: mode == WorkoutMode.timed ? challenge : null,
      poseFrames: 100,
      readyFrames: 90,
      lostFrames: 10,
    );

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  AppLanguage language = AppLanguage.vi,
  double width = 393,
  double scale = 1,
}) async {
  tester.view.physicalSize = Size(width, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final locale = LocaleController(language);
  addTearDown(locale.dispose);
  await tester.pumpWidget(
    LocaleScope(
      controller: locale,
      child: MaterialApp(
        theme: RepCoachTheme.dark(),
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 852),
            textScaler: TextScaler.linear(scale),
          ),
          child: Scaffold(body: child),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('timed controller deadline', () {
    test('rep at exact deadline counts and challenge then expires', () async {
      final clock = _Clock();
      final saved = <WorkoutRecord>[];
      final controller = WorkoutController(
        profile: pushUp,
        requireCountdown: false,
        mode: WorkoutMode.timed,
        timedChallenge: const TimedChallengeConfig(durationSeconds: 60),
        trackingClock: clock,
        clock: clock,
        saveRecord: (record) async => saved.add(record),
      );
      addTearDown(controller.dispose);
      controller.cameraStarted();
      _frame(controller);

      clock.elapsed = const Duration(seconds: 60);
      expect(
        controller.acceptRep(_rep(clock.elapsed), clock.elapsed),
        isFalse,
      );
      expect(controller.state.reps, 1);

      _frame(controller);
      expect(controller.state.challengeExpired, isTrue);
      expect(controller.state.challengeRemainingSeconds, 0);
      expect(controller.acceptsReps, isFalse);

      final result = await controller.finish(calibration: _calibration);
      expect(result.reps, 1);
      expect(result.mode, WorkoutMode.timed);
      expect(result.challengeSeconds, 60);
      expect(result.durationSeconds, 60);
      expect(result.completedTimedChallenge, isTrue);
    });

    test('rep after deadline is excluded without changing accepted total', () {
      final clock = _Clock();
      final controller = WorkoutController(
        profile: pushUp,
        requireCountdown: false,
        mode: WorkoutMode.timed,
        timedChallenge: const TimedChallengeConfig(durationSeconds: 60),
        trackingClock: clock,
        clock: clock,
      );
      addTearDown(controller.dispose);
      controller.cameraStarted();
      _frame(controller);

      clock.elapsed = const Duration(seconds: 59);
      controller.acceptRep(_rep(clock.elapsed), clock.elapsed);
      expect(controller.state.reps, 1);

      clock.elapsed = const Duration(seconds: 61);
      expect(
        controller.acceptRep(_rep(clock.elapsed), clock.elapsed),
        isFalse,
      );
      expect(controller.state.reps, 1);
    });

    test('manual pause and background-style pause freeze challenge time', () {
      final clock = _Clock();
      final controller = WorkoutController(
        profile: pushUp,
        requireCountdown: false,
        mode: WorkoutMode.timed,
        timedChallenge: const TimedChallengeConfig(durationSeconds: 60),
        trackingClock: clock,
        clock: clock,
      );
      addTearDown(controller.dispose);
      controller.cameraStarted();
      _frame(controller);

      clock.advance(const Duration(seconds: 20));
      expect(controller.state.challengeRemainingSeconds, 40);

      controller.pause();
      clock.advance(const Duration(seconds: 25));
      expect(controller.state.challengeRemainingSeconds, 40);

      // CameraPage uses the same pause/cameraStarted pair for app background.
      controller.cameraStarted();
      clock.advance(const Duration(seconds: 10));
      expect(controller.state.challengeRemainingSeconds, 30);
      expect(controller.state.challengeExpired, isFalse);
    });

    test('final-ten state is driven only by controller time', () {
      final clock = _Clock();
      final controller = WorkoutController(
        profile: pushUp,
        requireCountdown: false,
        mode: WorkoutMode.timed,
        timedChallenge: const TimedChallengeConfig(durationSeconds: 60),
        trackingClock: clock,
        clock: clock,
      );
      addTearDown(controller.dispose);
      controller.cameraStarted();
      _frame(controller);

      clock.elapsed = const Duration(seconds: 49);
      expect(controller.state.isFinalTenSeconds, isFalse);
      clock.elapsed = const Duration(seconds: 50);
      expect(controller.state.isFinalTenSeconds, isTrue);
      expect(controller.state.challengeRemainingSeconds, 10);
    });
  });

  group('timed persistence and local PR', () {
    test('new timed record round trips mode and duration', () {
      final original = _record(id: 'new', reps: 28, duration: 60);
      final copy = WorkoutRecord.fromJson(original.toJson());
      expect(copy.mode, WorkoutMode.timed);
      expect(copy.challengeSeconds, 60);
      expect(copy.completedTimedChallenge, isTrue);
    });

    test('legacy records infer free or target modes without migration failure', () {
      final freeJson = _record(
        id: 'legacy-free',
        reps: 12,
        duration: 40,
        mode: WorkoutMode.free,
      ).toJson()
        ..remove('mode')
        ..remove('challenge_seconds');
      final targetJson = Map<String, dynamic>.from(freeJson)
        ..['id'] = 'legacy-target'
        ..['target_reps'] = 20;

      expect(WorkoutRecord.fromJson(freeJson).mode, WorkoutMode.free);
      expect(
        WorkoutRecord.fromJson(targetJson).mode,
        WorkoutMode.targetReps,
      );
    });

    test('PR compares only completed challenges with exact exercise and duration',
        () {
      final history = [
        _record(id: '30', reps: 40, duration: 30, challenge: 30),
        _record(id: '60a', reps: 25, duration: 60),
        _record(id: '60b', reps: 31, duration: 60),
        _record(id: '60early', reps: 50, duration: 42),
        _record(
          id: 'pullup',
          reps: 99,
          duration: 60,
          exerciseId: 'pull_up',
        ),
        _record(id: 'current', reps: 35, duration: 60),
      ];

      expect(
        WorkoutPersonalRecordStore.bestTimedRepsFrom(
          history,
          exerciseId: 'push_up',
          challengeSeconds: 60,
          excludeRecordId: 'current',
        ),
        31,
      );
      expect(
        WorkoutPersonalRecordStore.bestTimedRepsFrom(
          history,
          exerciseId: 'push_up',
          challengeSeconds: 30,
        ),
        40,
      );
    });
  });

  group('Time Challenge setup and presentation', () {
    testWidgets('30 60 90 and custom durations route explicit timed config',
        (tester) async {
      final starts = <WorkoutStartConfig>[];
      await _pump(
        tester,
        SingleChildScrollView(
          child: GoalSetupContent(
            profile: pushUp,
            onStart: starts.add,
            loadTimedBest: (_, seconds) async => seconds == 60 ? 31 : null,
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('mode-timed')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('timed-personal-best-card')), findsOneWidget);

      for (final seconds in [30, 60, 90]) {
        await tester.tap(find.text('$seconds giây'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('start-time-challenge')));
        await tester.pumpAndSettle();
        expect(starts.last.mode, WorkoutMode.timed);
        expect(starts.last.timedChallenge?.durationSeconds, seconds);
      }

      await tester.tap(find.text('Tùy chỉnh'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('custom-challenge-seconds')),
        '75',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('start-time-challenge')));
      await tester.pumpAndSettle();
      expect(starts.last.timedChallenge?.durationSeconds, 75);
    });

    testWidgets('final ten HUD shows controller timer reps and truthful live form',
        (tester) async {
      final state = WorkoutUiState(
        phase: WorkoutUiPhase.active,
        exerciseId: 'push_up',
        exerciseName: 'Push-up',
        reps: 28,
        repsInCurrentSet: 28,
        completedSets: 0,
        sessionState: SessionState.working,
        goal: null,
        elapsed: const Duration(seconds: 50),
        placementReady: true,
        placementStatus: PlacementStatus.ready,
        placementMessage: '',
        calibrated: false,
        calibrationSamples: 0,
        goalReachedOnce: false,
        saveError: null,
        sessionStarted: true,
        mode: WorkoutMode.timed,
        challengeSeconds: 60,
        challengeRemaining: const Duration(seconds: 10),
      );

      await _pump(
        tester,
        SafeArea(
          child: WorkoutHud(
            state: state,
            exerciseName: 'Hít đất',
            hint: '',
            onExit: () {},
            onPause: () {},
            onResume: () {},
            onFinish: () {},
            onCalibrate: () {},
            onHelp: () {},
            goalBanner: false,
            onDismissGoal: () {},
            challengeBestReps: 31,
          ),
        ),
        width: 320,
        scale: 2,
      );

      expect(find.byKey(const Key('timed-final-ten-label')), findsOneWidget);
      expect(find.text('00:10'), findsOneWidget);
      expect(find.text('28'), findsOneWidget);
      expect(find.text('FORM —'), findsOneWidget);
      expect(find.text('BEST 31'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('result states distinguish new PR no PR match first and early finish',
        (tester) async {
      Future<void> check({
        required WorkoutRecord record,
        required int? best,
        required Key key,
      }) async {
        await _pump(
          tester,
          SingleChildScrollView(
            child: TimedChallengeResultSection(
              record: record,
              loadPreviousBest: (_) async => best,
            ),
          ),
        );
        expect(find.byKey(key), findsOneWidget);
        expect(tester.takeException(), isNull);
      }

      await check(
        record: _record(id: 'new-pr', reps: 28, duration: 60),
        best: 25,
        key: const Key('timed-result-new-pr'),
      );
      await check(
        record: _record(id: 'no-pr', reps: 28, duration: 60),
        best: 31,
        key: const Key('timed-result-no-pr'),
      );
      await check(
        record: _record(id: 'match', reps: 31, duration: 60),
        best: 31,
        key: const Key('timed-result-matched-pr'),
      );
      await check(
        record: _record(id: 'first', reps: 12, duration: 60),
        best: null,
        key: const Key('timed-result-new-pr'),
      );
      await check(
        record: _record(id: 'early', reps: 40, duration: 45),
        best: 31,
        key: const Key('timed-result-early'),
      );
    });
  });
}
