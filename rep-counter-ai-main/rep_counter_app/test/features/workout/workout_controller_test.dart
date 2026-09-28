import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/exercise.dart';
import 'package:rep_counter_app/placement.dart';
import 'package:rep_counter_app/rep_counter.dart';
import 'package:rep_counter_app/features/workout/application/workout_controller.dart';
import 'package:rep_counter_app/features/workout/application/workout_ui_state.dart';
import 'package:rep_counter_app/features/workout/data/workout_record.dart';
import 'package:rep_counter_app/features/workout/domain/quality_thresholds.dart';
import 'package:rep_counter_app/features/workout/domain/rep_metric.dart';
import 'package:rep_counter_app/features/workout/domain/rep_quality_analyzer.dart';
import 'package:rep_counter_app/features/workout/domain/workout_aggregator.dart';
import 'package:rep_counter_app/features/workout/domain/workout_summary.dart';

class FakeClock implements WorkoutClock {
  @override
  Duration elapsed = Duration.zero;
  @override
  bool isRunning = false;
  @override
  void start() => isRunning = true;
  @override
  void stop() => isRunning = false;
  void advance(int seconds) {
    if (isRunning) elapsed += Duration(seconds: seconds);
  }
}

RepObservation observation(int second) => RepObservation(
      startedAt: Duration(seconds: second - 2),
      bottomAt: Duration(seconds: second - 1),
      completedAt: Duration(seconds: second),
      bottomAngle: 90,
      topAngle: 160,
      leftBottomAngle: 90,
      rightBottomAngle: 92,
      sampleCount: 20,
      averagePoseConfidence: .9,
    );

const calibration =
    CalibrationSnapshot(repHi: 140, repLo: 100, minAmplitude: 40);
void frame(WorkoutController controller,
        {bool found = true, bool ready = true}) =>
    controller.frameProcessed(
        at: controller.elapsed,
        poseFound: found,
        countable: ready,
        status: ready ? PlacementStatus.ready : PlacementStatus.noPose,
        message: ready ? 'Ready' : 'No pose',
        calibrationSamples: 12);

void main() {
  late FakeClock clock;
  late WorkoutController controller;
  late DateTime now;
  late List<WorkoutRecord> saved;
  setUp(() {
    clock = FakeClock();
    now = DateTime(2026, 9, 27, 10);
    saved = [];
    controller = WorkoutController(
        requireCountdown: false,
        profile: pushUp,
        targetReps: 3,
        clock: clock,
        now: () => now,
        saveRecord: (r) async {
          saved.add(r);
        });
  });
  tearDown(() => controller.dispose());

  test('initial immutable projection rejects frames before camera starts', () {
    expect(controller.state.phase, WorkoutUiPhase.positioning);
    expect(controller.hasStarted, isFalse);
    expect(controller.acceptRep(observation(2), const Duration(seconds: 2)),
        isFalse);
    frame(controller);
    expect(controller.state.reps, 0);
    expect(controller.state.placementReady, isFalse);
    expect(controller.state.goalProgress, 0);
  });

  test('goal is emitted once and UI reads the legacy session count', () {
    controller.cameraStarted();
    frame(controller);
    expect(controller.state.phase, WorkoutUiPhase.ready);
    final initial = controller.state;
    for (var i = 1; i <= 5; i++) {
      clock.advance(2);
      expect(controller.acceptRep(observation(i * 2), clock.elapsed), i == 3);
    }
    expect(controller.state.reps, 5);
    expect(initial.reps, 0);
    expect(controller.state.goalProgress, 1);
    expect(controller.state.goalReachedOnce, isTrue);
    expect(controller.state.phase, WorkoutUiPhase.active);
  });

  test('camera restart keeps start time and excludes background time',
      () async {
    controller.cameraStarted();
    clock.advance(8);
    controller.pause();
    clock.advance(120);
    now = now.add(const Duration(minutes: 2));
    expect(controller.state.phase, WorkoutUiPhase.paused);
    expect(controller.acceptRep(observation(10), clock.elapsed), isFalse);
    controller.cameraStarted();
    clock.advance(4);
    final r = await controller.finish(calibration: calibration);
    expect(r.startedAt, DateTime(2026, 9, 27, 10));
    expect(r.durationSeconds, 12);
    expect(clock.isRunning, isFalse);
  });

  test('calibration projection reports actual sample count without countdown',
      () {
    controller.cameraStarted();
    controller.calibrationChanged(
        collecting: true, calibrated: false, samples: 0);
    expect(controller.state.phase, WorkoutUiPhase.calibrating);
    frame(controller);
    expect(controller.state.calibrationSamples, 12);
    controller.calibrationChanged(
        collecting: false, calibrated: true, samples: 95);
    expect(controller.state.calibrated, isTrue);
    expect(controller.state.isCalibrating, isFalse);
    expect(controller.state.calibrationSamples, 95);
  });

  test('concurrent finish saves once and rejects frames while saving/done',
      () async {
    final release = Completer<void>();
    final c = WorkoutController(
        requireCountdown: false,
        profile: pushUp,
        clock: clock,
        saveRecord: (r) async {
          saved.add(r);
          await release.future;
        });
    addTearDown(c.dispose);
    c.cameraStarted();
    frame(c);
    clock.advance(5);
    final a = c.finish(calibration: calibration);
    final b = c.finish(calibration: calibration);
    expect(identical(a, b), isTrue);
    expect(c.state.phase, WorkoutUiPhase.saving);
    expect(c.acceptRep(observation(6), const Duration(seconds: 6)), isFalse);
    frame(c, found: false, ready: false);
    clock.advance(60);
    release.complete();
    final result = await a;
    expect(saved.length, 1);
    expect(result.poseFrames, 1);
    expect(result.lostFrames, 0);
    expect(result.durationSeconds, 5);
    expect(c.state.phase, WorkoutUiPhase.done);
    expect(await c.finish(calibration: calibration), same(result));
  });

  test('failed save unlocks retry and resumes active time without data loss',
      () async {
    var attempts = 0;
    final c = WorkoutController(
        requireCountdown: false,
        profile: pushUp,
        clock: clock,
        now: () => now,
        saveRecord: (r) async {
          if (++attempts == 1) throw StateError('disk failure');
          saved.add(r);
        });
    addTearDown(c.dispose);
    c.cameraStarted();
    for (var i = 1; i <= 3; i++) {
      clock.advance(2);
      c.acceptRep(observation(i * 2), clock.elapsed);
    }
    await expectLater(c.finish(calibration: calibration), throwsStateError);
    expect(c.state.saveError, contains('disk failure'));
    expect(c.state.isFinishing, isFalse);
    expect(c.acceptsFrames, isTrue);
    expect(clock.isRunning, isTrue);
    final result = await c.finish(calibration: calibration);
    expect(result.reps, 3);
    expect(saved.length, 1);
    expect(c.state.saveError, isNull);
  });

  test('backgrounding during a failed save cannot restart the clock', () async {
    final release = Completer<void>();
    final c = WorkoutController(
        requireCountdown: false,
        profile: pushUp,
        clock: clock,
        saveRecord: (_) => release.future);
    addTearDown(c.dispose);
    c.cameraStarted();
    final saving = c.finish(calibration: calibration);
    final failure = expectLater(saving, throwsStateError);
    c.pause();
    release.completeError(StateError('disk failure'));
    await failure;
    expect(clock.isRunning, isFalse);
    expect(c.state.phase, WorkoutUiPhase.paused);
  });

  test('abort freezes input and does not save', () async {
    controller.cameraStarted();
    controller.abort();
    expect(controller.state.phase, WorkoutUiPhase.aborted);
    expect(controller.acceptsFrames, isFalse);
    expect(clock.isRunning, isFalse);
    await expectLater(
        controller.finish(calibration: calibration), throwsStateError);
    expect(saved, isEmpty);
  });

  test('pending save may complete safely after controller disposal', () async {
    final release = Completer<void>();
    final c = WorkoutController(
        requireCountdown: false,
        profile: pushUp,
        clock: clock,
        saveRecord: (_) => release.future);
    var notifications = 0;
    c.addListener(() => notifications++);
    c.cameraStarted();
    final saving = c.finish(calibration: calibration);
    c.dispose();
    final before = notifications;
    release.complete();
    await saving;
    expect(notifications, before);
    expect(clock.isRunning, isFalse);
  });

  for (final profile in allExercises) {
    test(
        '${profile.id}: session and saved record match the legacy orchestration',
        () async {
      final c = WorkoutController(
          requireCountdown: false,
          profile: profile,
          clock: clock,
          now: () => now,
          saveRecord: (r) async {
            saved.add(r);
          });
      addTearDown(c.dispose);
      final legacySession = SessionTracker(minReps: profile.minRepsPerSet);
      final metrics = <RepMetric>[];
      c.cameraStarted();
      for (final second in [2, 4, 6, 16, 18]) {
        clock.elapsed = Duration(seconds: second);
        final o = observation(second);
        metrics.add(RepMetric(
            index: metrics.length + 1,
            setIndex: 1,
            observation: o,
            flags: const RepQualityAnalyzer().analyze(o)));
        legacySession.onRep(clock.elapsed);
        c.acceptRep(o, clock.elapsed);
        legacySession.tick(clock.elapsed);
        frame(c);
        expect(c.state.reps, legacySession.totalReps);
        expect(c.state.repsInCurrentSet, legacySession.repsInCurrentSet);
      }
      clock.advance(7);
      legacySession.tick(clock.elapsed);
      frame(c, found: false, ready: false);
      expect(c.state.reps, legacySession.totalReps);
      expect(c.state.completedSets, legacySession.sets.length);
      expect(c.state.sessionState, legacySession.state);
      final summary =
          WorkoutAggregator(minRepsPerSet: math.min(2, profile.minRepsPerSet))
              .build(
                  id: now.microsecondsSinceEpoch.toString(),
                  exerciseId: profile.id,
                  startedAt: now,
                  endedAt: now,
                  reps: metrics,
                  calibration: calibration,
                  poseStats: const PoseQualityStats(
                      totalProcessedFrames: 6,
                      countableFrames: 5,
                      poseLostFrames: 1));
      final expected = WorkoutRecord.fromSummary(
          summary: summary,
          exerciseName: profile.name,
          durationSeconds: 25,
          poseFrames: 6,
          readyFrames: 5,
          lostFrames: 1);
      expect((await c.finish(calibration: calibration)).toJson(),
          expected.toJson());
    });
  }
}
