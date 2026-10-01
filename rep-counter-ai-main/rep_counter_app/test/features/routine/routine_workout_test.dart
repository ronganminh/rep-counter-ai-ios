import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/exercise.dart';
import 'package:rep_counter_app/features/routine/domain/routine_preset.dart';
import 'package:rep_counter_app/features/workout/application/workout_controller.dart';
import 'package:rep_counter_app/features/workout/data/workout_record.dart';
import 'package:rep_counter_app/features/workout/domain/quality_thresholds.dart';
import 'package:rep_counter_app/features/workout/domain/rep_metric.dart';

class FakeRoutineClock implements WorkoutClock {
  @override
  Duration elapsed = Duration.zero;
  @override
  bool isRunning = false;

  @override
  void start() => isRunning = true;
  @override
  void stop() => isRunning = false;

  void advance(Duration value) {
    if (isRunning) elapsed += value;
  }
}

RepObservation repAt(int second) => RepObservation(
      startedAt: Duration(milliseconds: second * 1000 - 800),
      bottomAt: Duration(milliseconds: second * 1000 - 400),
      completedAt: Duration(seconds: second),
      bottomAngle: 90,
      topAngle: 160,
      leftBottomAngle: 90,
      rightBottomAngle: 92,
      sampleCount: 12,
      averagePoseConfidence: .9,
    );

const calibration =
    CalibrationSnapshot(repHi: 140, repLo: 100, minAmplitude: 40);

const routine = RoutineSnapshot(
  id: 'morning',
  name: 'Hít đất buổi sáng',
  exerciseId: 'push_up',
  targetReps: 2,
  targetSets: 2,
  restSeconds: 5,
  voiceCoachEnabled: true,
);

void main() {
  test('routine reuses SessionTracker and preserves skipped-rest set boundaries',
      () async {
    final tracking = FakeRoutineClock();
    final session = FakeRoutineClock();
    WorkoutRecord? saved;
    final controller = WorkoutController(
      profile: pushUp,
      requireCountdown: false,
      routine: routine,
      trackingClock: tracking,
      clock: session,
      saveRecord: (record) async => saved = record,
    );
    addTearDown(controller.dispose);

    controller.cameraStarted();
    tracking.advance(const Duration(seconds: 1));
    session.advance(const Duration(seconds: 1));
    expect(controller.acceptRep(repAt(1), tracking.elapsed), isFalse);
    tracking.advance(const Duration(seconds: 1));
    session.advance(const Duration(seconds: 1));
    expect(controller.acceptRep(repAt(2), tracking.elapsed), isFalse);

    expect(controller.state.reps, 2);
    expect(controller.state.completedSets, 1);
    expect(controller.state.routineCompletedSetReps, 2);
    expect(controller.state.isRoutineResting, isTrue);
    expect(controller.acceptRep(repAt(3), tracking.elapsed), isFalse,
        reason: 'rest must block new accepted reps');

    controller.skipRoutineRest();
    expect(controller.state.isRoutineResting, isFalse);

    tracking.advance(const Duration(seconds: 1));
    session.advance(const Duration(seconds: 1));
    controller.acceptRep(repAt(3), tracking.elapsed);
    tracking.advance(const Duration(seconds: 1));
    session.advance(const Duration(seconds: 1));
    controller.acceptRep(repAt(4), tracking.elapsed);

    expect(controller.state.reps, 4);
    expect(controller.state.completedSets, 2);
    expect(controller.state.routineComplete, isTrue);

    final record = await controller.finish(calibration: calibration);
    expect(saved, same(record));
    expect(record.reps, 4);
    expect(record.sets, 2,
        reason: 'Skip rest must not merge intentional routine sets');
    expect(record.routine?.id, 'morning');
    expect(record.routine?.targetSets, 2);
    expect(record.repDetails?.map((rep) => rep.setIndex).toList(),
        <int>[1, 1, 2, 2]);
  });

  testWidgets('rest countdown expires from the workout tracking clock',
      (tester) async {
    final tracking = FakeRoutineClock();
    final session = FakeRoutineClock();
    final controller = WorkoutController(
      profile: pushUp,
      requireCountdown: false,
      routine: routine,
      trackingClock: tracking,
      clock: session,
      saveRecord: (_) async {},
    );
    addTearDown(controller.dispose);

    controller.cameraStarted();
    tracking.advance(const Duration(seconds: 1));
    controller.acceptRep(repAt(1), tracking.elapsed);
    tracking.advance(const Duration(seconds: 1));
    controller.acceptRep(repAt(2), tracking.elapsed);
    expect(controller.isRoutineResting, isTrue);

    tracking.advance(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 300));

    expect(controller.isRoutineResting, isFalse);
    expect(controller.state.reps, 2);
    expect(controller.state.completedSets, 1);
  });

  test('ending during rest saves normally with immutable routine snapshot',
      () async {
    final tracking = FakeRoutineClock();
    final session = FakeRoutineClock();
    final saved = <WorkoutRecord>[];
    final controller = WorkoutController(
      profile: pushUp,
      requireCountdown: false,
      routine: routine,
      trackingClock: tracking,
      clock: session,
      saveRecord: (record) async => saved.add(record),
    );
    addTearDown(controller.dispose);

    controller.cameraStarted();
    tracking.advance(const Duration(seconds: 1));
    session.advance(const Duration(seconds: 1));
    controller.acceptRep(repAt(1), tracking.elapsed);
    tracking.advance(const Duration(seconds: 1));
    session.advance(const Duration(seconds: 1));
    controller.acceptRep(repAt(2), tracking.elapsed);
    expect(controller.state.isRoutineResting, isTrue);

    final record = await controller.finish(calibration: calibration);

    expect(saved, hasLength(1));
    expect(record.reps, 2);
    expect(record.sets, 1);
    expect(record.routine?.name, 'Hít đất buổi sáng');
    expect(controller.state.isFinishing, isTrue);
  });
}
