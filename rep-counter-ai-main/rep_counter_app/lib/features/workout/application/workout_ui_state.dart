import 'package:flutter/foundation.dart';

import '../../../placement.dart';
import '../../../rep_counter.dart';

/// Presentation phases, not a replacement for the legacy rep/set state machine.
/// Preparation/countdown never owns a second rep counter.
enum WorkoutUiPhase {
  positioning,
  ready,
  calibrating,
  countdown,
  active,
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
    this.countdown,
    this.sessionStarted = true,
    this.startRequested = false,
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
  final int? countdown;
  final bool sessionStarted, startRequested;

  bool get isCalibrating => phase == WorkoutUiPhase.calibrating;
  bool get isFinishing =>
      phase == WorkoutUiPhase.ending ||
      phase == WorkoutUiPhase.saving ||
      phase == WorkoutUiPhase.done;
  double? get goalProgress =>
      goal == null || goal! <= 0 ? null : (reps / goal!).clamp(0.0, 1.0);
}
