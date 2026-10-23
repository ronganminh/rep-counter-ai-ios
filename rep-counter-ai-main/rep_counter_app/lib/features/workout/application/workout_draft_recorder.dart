import 'package:flutter/foundation.dart';

import '../data/workout_draft_store.dart';
import 'workout_controller.dart';
import 'workout_ui_state.dart';

/// Keeps a [WorkoutDraft] in step with a running workout. Listens to the
/// controller's read-only [WorkoutUiState]; writes only when the counted reps
/// or sets change (never per frame) and clears the draft once the workout is
/// saved or discarded.
class WorkoutDraftRecorder {
  WorkoutDraftRecorder(this._controller,
      {WorkoutDraftStore? store, DateTime Function()? now})
      : _store = store ?? WorkoutDraftStore(),
        _now = now ?? DateTime.now {
    _controller.addListener(_changed);
  }

  final WorkoutController _controller;
  final WorkoutDraftStore _store;
  final DateTime Function() _now;
  DateTime? _startedAt;
  int _lastReps = 0, _lastSets = 0;
  bool _cleared = false;
  Future<void> _queue = Future.value();

  /// Number of draft writes so far (tests check it is not per frame).
  @visibleForTesting
  int writes = 0;

  void _changed() {
    final s = _controller.state;
    if (s.phase == WorkoutUiPhase.done || s.phase == WorkoutUiPhase.aborted) {
      if (!_cleared) {
        _cleared = true;
        _enqueue(_store.clear);
      }
      return;
    }
    if (!s.sessionStarted || s.reps <= 0 || s.isFinishing) return;
    final sets = s.completedSets + (s.repsInCurrentSet > 0 ? 1 : 0);
    if (s.reps == _lastReps && sets == _lastSets) return;
    _lastReps = s.reps;
    _lastSets = sets;
    final now = _now();
    _startedAt ??= now.subtract(s.elapsed);
    final draft = WorkoutDraft(
      startedAt: _startedAt!,
      updatedAt: now,
      exerciseId: s.exerciseId,
      exerciseName: s.exerciseName,
      reps: s.reps,
      sets: sets < 1 ? 1 : sets,
      durationSeconds: s.elapsed.inSeconds,
      mode: s.mode,
      targetReps: s.goal,
      challengeSeconds: s.challengeSeconds,
    );
    writes++;
    _enqueue(() => _store.save(draft));
  }

  void _enqueue(Future<void> Function() write) {
    _queue = _queue.then((_) => write()).catchError((Object _) {});
  }

  /// Waits for queued writes (tests).
  @visibleForTesting
  Future<void> flush() => _queue;

  void dispose() => _controller.removeListener(_changed);
}
