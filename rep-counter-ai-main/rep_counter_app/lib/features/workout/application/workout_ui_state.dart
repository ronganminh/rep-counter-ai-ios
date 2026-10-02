import 'package:flutter/foundation.dart';

import '../../../placement.dart';
import '../../../rep_counter.dart';
import '../domain/workout_mode.dart';
import '../../routine/domain/routine_preset.dart';
import 'rep_feedback.dart';

/// Presentation phases, not a replacement for the legacy rep/set state machine.
/// Preparation/countdown never owns a second rep counter.
enum WorkoutUiPhase {
  positioning,
  ready,
  calibrating,
  countdown,
  active,
  resting,
  paused,
  ending,
  saving,
  done,
  aborted,
}

/// Read-only projection of the existing engine. Never contains camera images,
/// ML Kit poses, landmarks or a second, independently incremented rep count.
@immutable
class WorkoutUiState {
  const WorkoutUiState({
    required this.phase,
    required this.exerciseId,
    required this.exerciseName,
    required this.reps,
    required this.repsInCurrentSet,
    required this.completedSets,
    required this.sessionState,
    required this.goal,
    required this.elapsed,
    required this.placementReady,
    required this.placementStatus,
    required this.placementMessage,
    required this.calibrated,
    required this.calibrationSamples,
    required this.goalReachedOnce,
    required this.saveError,
    this.repFeedback,
    this.countdown,
    this.sessionStarted = true,
    this.startRequested = false,
    this.mode = WorkoutMode.free,
    this.challengeSeconds,
    this.challengeRemaining,
    this.challengeExpired = false,
    this.routine,
    this.routineRestRemaining,
    this.routineCompletedSetReps = 0,
    this.routineComplete = false,
  });

  final WorkoutUiPhase phase;
  final String exerciseId, exerciseName;
  final int reps, repsInCurrentSet, completedSets;
  final SessionState sessionState;
  final int? goal;
  final Duration elapsed;
  final bool placementReady;
  final PlacementStatus placementStatus;
  final String placementMessage;
  final bool calibrated;
  // Samples actually collected by Calibrator, not fabricated rep progress.
  final int calibrationSamples;
  final bool goalReachedOnce;
  final String? saveError;
  final RepFeedback? repFeedback;
  final int? countdown;
  final bool sessionStarted, startRequested;
  final WorkoutMode mode;
  final int? challengeSeconds;
  final Duration? challengeRemaining;
  final bool challengeExpired;
  final RoutineSnapshot? routine;
  final Duration? routineRestRemaining;
  final int routineCompletedSetReps;
  final bool routineComplete;

  bool get isTimedChallenge => mode == WorkoutMode.timed;
  bool get isRoutine => routine != null;
  bool get isRoutineResting => phase == WorkoutUiPhase.resting;
  int? get routineRestRemainingSeconds {
    final remaining = routineRestRemaining;
    if (remaining == null) return null;
    if (remaining <= Duration.zero) return 0;
    return (remaining.inMilliseconds + 999) ~/ 1000;
  }
  bool get isFinalTenSeconds =>
      isTimedChallenge &&
      sessionStarted &&
      !challengeExpired &&
      challengeRemaining != null &&
      challengeRemaining! > Duration.zero &&
      challengeRemaining! <= const Duration(seconds: 10);

  int? get challengeRemainingSeconds {
    final remaining = challengeRemaining;
    if (remaining == null) return null;
    if (remaining <= Duration.zero) return 0;
    return (remaining.inMilliseconds + 999) ~/ 1000;
  }

  bool get isCalibrating => phase == WorkoutUiPhase.calibrating;
  bool get isFinishing =>
      phase == WorkoutUiPhase.ending ||
      phase == WorkoutUiPhase.saving ||
      phase == WorkoutUiPhase.done;
  double? get goalProgress =>
      goal == null || goal! <= 0 ? null : (reps / goal!).clamp(0.0, 1.0);
}
