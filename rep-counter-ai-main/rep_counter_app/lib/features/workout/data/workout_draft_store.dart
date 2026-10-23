import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/workout_mode.dart';
import 'workout_history_store.dart';
import 'workout_record.dart';

/// What is known about an unfinished workout (roadmap F-4). Built only from
/// [WorkoutUiState], the read-only projection of the engine, so recording a
/// draft never touches counting.
@immutable
class WorkoutDraft {
  const WorkoutDraft({
    required this.startedAt,
    required this.updatedAt,
    required this.exerciseId,
    required this.exerciseName,
    required this.reps,
    required this.sets,
    required this.durationSeconds,
    required this.mode,
    this.targetReps,
    this.challengeSeconds,
  });

  final DateTime startedAt, updatedAt;
  final String exerciseId, exerciseName;
  final int reps, sets, durationSeconds;
  final WorkoutMode mode;
  final int? targetReps, challengeSeconds;

  /// D-06 (PROPOSED, decision log L-D17): 12 h, configurable.
  static const recoveryWindow = Duration(hours: 12);

  bool isExpired(DateTime now, {Duration window = recoveryWindow}) =>
      now.difference(updatedAt) > window;

  /// The single partial record "Save as partial" writes. Same id every time,
  /// so saving twice still leaves one record.
  WorkoutRecord toPartialRecord() => WorkoutRecord(
        id: 'draft-${startedAt.toUtc().microsecondsSinceEpoch}',
        exerciseId: exerciseId,
        exerciseName: exerciseName,
        startedAt: startedAt,
        durationSeconds: durationSeconds,
        reps: reps,
        sets: sets,
        targetReps: targetReps,
        poseFrames: 0,
        readyFrames: 0,
        lostFrames: 0,
        mode: mode,
        challengeSeconds: challengeSeconds,
        partial: true,
      );

  Map<String, dynamic> toJson() => {
        'started_at': startedAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'exercise_id': exerciseId,
        'exercise_name': exerciseName,
        'reps': reps,
        'sets': sets,
        'duration_seconds': durationSeconds,
        'mode': mode.name,
        if (targetReps != null) 'target_reps': targetReps,
        if (challengeSeconds != null) 'challenge_seconds': challengeSeconds,
      };

  static WorkoutDraft? fromJson(Map<String, dynamic> j) {
    try {
      return WorkoutDraft(
        startedAt: DateTime.parse(j['started_at'] as String).toLocal(),
        updatedAt: DateTime.parse(j['updated_at'] as String).toLocal(),
        exerciseId: j['exercise_id'] as String,
        exerciseName: j['exercise_name'] as String,
        reps: (j['reps'] as num).toInt(),
        sets: (j['sets'] as num).toInt(),
        durationSeconds: (j['duration_seconds'] as num).toInt(),
        mode: WorkoutMode.values.firstWhere((m) => m.name == j['mode'],
            orElse: () => WorkoutMode.free),
        targetReps: (j['target_reps'] as num?)?.toInt(),
        challengeSeconds: (j['challenge_seconds'] as num?)?.toInt(),
      );
    } catch (_) {
      return null;
    }
  }
}

/// One draft at a time, in SharedPreferences: a few bytes written only when
/// the rep or set count changes.
class WorkoutDraftStore {
  static const key = 'workout_draft_v1';

  Future<WorkoutDraft?> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(key);
    if (raw == null) return null;
    try {
      return WorkoutDraft.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(WorkoutDraft draft) async {
    await (await SharedPreferences.getInstance())
        .setString(key, jsonEncode(draft.toJson()));
  }

  Future<void> clear() async {
    await (await SharedPreferences.getInstance()).remove(key);
  }

  /// The draft to offer for recovery, or null. A draft whose workout was
  /// already saved (the app closed between saving and clearing it) is
  /// cleared instead, so recovery never creates a second record.
  Future<WorkoutDraft?> pendingRecovery({WorkoutHistoryStore? history}) async {
    final draft = await load();
    if (draft == null) return null;
    final saved = await (history ?? WorkoutHistoryStore()).load();
    final alreadySaved = saved.any((r) =>
        r.id == draft.toPartialRecord().id ||
        (r.exerciseId == draft.exerciseId &&
            r.reps >= draft.reps &&
            r.startedAt.difference(draft.startedAt).abs() <
                const Duration(minutes: 10)));
    if (alreadySaved) {
      await clear();
      return null;
    }
    return draft;
  }

  /// "Save as partial": one record, then the draft is gone.
  Future<WorkoutRecord> savePartial(WorkoutDraft draft,
      {WorkoutHistoryStore? history}) async {
    final record = draft.toPartialRecord();
    await (history ?? WorkoutHistoryStore()).save(record);
    await clear();
    return record;
  }
}
