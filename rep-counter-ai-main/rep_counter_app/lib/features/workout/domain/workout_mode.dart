import 'package:flutter/foundation.dart';

enum WorkoutMode {
  free,
  targetReps,
  timed,
}

@immutable
class TimedChallengeConfig {
  const TimedChallengeConfig({required this.durationSeconds})
      : assert(durationSeconds > 0);

  final int durationSeconds;
}

@immutable
class WorkoutStartConfig {
  const WorkoutStartConfig.free()
      : mode = WorkoutMode.free,
        targetReps = null,
        timedChallenge = null,
        previousBestReps = null;

  const WorkoutStartConfig.target(int reps)
      : assert(reps > 0),
        mode = WorkoutMode.targetReps,
        targetReps = reps,
        timedChallenge = null,
        previousBestReps = null;

  const WorkoutStartConfig.timed(
    int seconds, {
    int? previousBestReps,
  })  : assert(seconds > 0),
        mode = WorkoutMode.timed,
        targetReps = null,
        timedChallenge = TimedChallengeConfig(durationSeconds: seconds),
        previousBestReps = previousBestReps;

  final WorkoutMode mode;
  final int? targetReps;
  final TimedChallengeConfig? timedChallenge;

  /// Presentation-only snapshot used by the active HUD. Personal records are
  /// always recomputed from local history for results.
  final int? previousBestReps;
}
