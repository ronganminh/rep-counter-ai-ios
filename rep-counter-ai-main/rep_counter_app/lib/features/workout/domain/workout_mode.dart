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
  const WorkoutStartConfig._({
    required this.mode,
    this.targetReps,
    this.timedChallenge,
    this.previousBestReps,
  });

  const WorkoutStartConfig.free()
      : this._(mode: WorkoutMode.free);

  const WorkoutStartConfig.target(int reps)
      : assert(reps > 0),
        this._(
          mode: WorkoutMode.targetReps,
          targetReps: reps,
        );

  const WorkoutStartConfig.timed(
    int seconds, {
    int? previousBestReps,
  })  : assert(seconds > 0),
        this._(
          mode: WorkoutMode.timed,
          timedChallenge: TimedChallengeConfig(durationSeconds: seconds),
          previousBestReps: previousBestReps,
        );

  final WorkoutMode mode;
  final int? targetReps;
  final TimedChallengeConfig? timedChallenge;

  /// Presentation-only snapshot used by the active HUD. Personal records are
  /// always recomputed from local history for results.
  final int? previousBestReps;
}
