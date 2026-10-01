import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/exercise.dart';
import 'package:rep_counter_app/features/workout/application/rep_feedback.dart';
import 'package:rep_counter_app/features/workout/application/workout_controller.dart';
import 'package:rep_counter_app/features/workout/domain/rep_metric.dart';
import 'package:rep_counter_app/features/workout/domain/rep_tracker.dart';

class _Clock implements WorkoutClock {
  @override
  Duration elapsed = Duration.zero;

  @override
  bool isRunning = false;

  @override
  void start() => isRunning = true;

  @override
  void stop() => isRunning = false;
}

RepObservation _observation({
  int endMs = 2000,
  double confidence = .9,
  double torsoMax = 0,
  double torsoFraction = 0,
}) =>
    RepObservation(
      startedAt: Duration.zero,
      bottomAt: Duration(milliseconds: endMs ~/ 2),
      completedAt: Duration(milliseconds: endMs),
      bottomAngle: 90,
      topAngle: 160,
      leftBottomAngle: 90,
      rightBottomAngle: 92,
      averagePoseConfidence: confidence,
      maxTorsoDeviation: torsoMax,
      torsoDeviationFraction: torsoFraction,
      sampleCount: 20,
    );

void main() {
  test('warning feedback never changes the accepted total', () {
    final controller = WorkoutController(
      profile: pushUp,
      requireCountdown: false,
      clock: _Clock(),
    );
    addTearDown(controller.dispose);
    controller.cameraStarted();

    controller.acceptRep(_observation(endMs: 500), const Duration(seconds: 1));

    expect(controller.state.reps, 1);
    expect(controller.state.repFeedback?.kind, RepFeedbackKind.countedWarning);
    expect(controller.state.repFeedback?.counted, isTrue);
    expect(controller.state.repFeedback?.primaryFlag, RepQualityFlag.tooFast);
  });

  test('aborted event never subtracts an accepted rep', () {
    final controller = WorkoutController(
      profile: pushUp,
      requireCountdown: false,
      clock: _Clock(),
    );
    addTearDown(controller.dispose);
    controller.cameraStarted();
    controller.acceptRep(_observation(), const Duration(seconds: 2));
    final accepted = controller.state.reps;

    controller.reportRepAborted(RepAbortReason.placementLost);

    expect(controller.state.reps, accepted);
    expect(
      controller.state.repFeedback?.kind,
      RepFeedbackKind.placementInterrupted,
    );
    expect(controller.state.repFeedback?.counted, isFalse);
  });

  test('latest event replaces previous feedback and counted feedback expires',
      () async {
    final controller = WorkoutController(
      profile: pushUp,
      requireCountdown: false,
      feedbackDuration: const Duration(milliseconds: 20),
      clock: _Clock(),
    );
    addTearDown(controller.dispose);
    controller.cameraStarted();

    controller.reportRepAborted(RepAbortReason.signalLost);
    expect(controller.state.repFeedback?.kind, RepFeedbackKind.poseLost);

    controller.acceptRep(_observation(), const Duration(seconds: 2));
    expect(controller.state.repFeedback?.kind, RepFeedbackKind.countedClean);
    expect(controller.state.repFeedback?.repNumber, 1);

    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(controller.state.repFeedback, isNull);
    expect(controller.state.reps, 1);
  });

  test('persistent interruption clears when a countable signal returns', () {
    final controller = WorkoutController(
      profile: pushUp,
      requireCountdown: false,
      clock: _Clock(),
    );
    addTearDown(controller.dispose);
    controller.cameraStarted();

    controller.reportRepAborted(RepAbortReason.signalLost);
    expect(controller.state.repFeedback?.kind, RepFeedbackKind.poseLost);

    controller.repSignalRestored();

    expect(controller.state.repFeedback, isNull);
    expect(controller.state.reps, 0);
  });
}
