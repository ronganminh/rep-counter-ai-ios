import 'package:shared_preferences/shared_preferences.dart';

import '../history/history_statistics.dart';
import '../workout/data/workout_history_store.dart';
import '../workout/data/workout_record.dart';
import '../workout/domain/workout_mode.dart';
import '../workout/domain/workout_personal_records.dart';
import 'achievement.dart';

/// Finite, device-local achievements evaluated only after a WorkoutRecord has
/// already been saved. There is no XP, token, social, account, or cloud state.
class AchievementService {
  AchievementService({WorkoutHistoryStore? history})
      : _history = history ?? WorkoutHistoryStore();

  static const _key = 'earned_achievements_v1';
  static Future<void>? _pending;

  final WorkoutHistoryStore _history;

  static Future<T> _serial<T>(Future<T> Function() operation) {
    final next =
        _pending == null ? operation() : _pending!.then((_) => operation());
    final barrier =
        next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    _pending = barrier;
    return next.whenComplete(() {
      if (identical(_pending, barrier)) _pending = null;
    });
  }

  Future<List<AchievementId>> claimAfterResult(
    WorkoutRecord current, {
    DateTime? now,
  }) =>
      _serial(() async {
        final records = await _history.load();

        // Results are only eligible after the normal save flow completes.
        // This guard also makes it impossible for an active/unsaved workout to
        // trigger an achievement.
        if (!records.any((record) => record.id == current.id)) {
          return const <AchievementId>[];
        }

        final prefs = await SharedPreferences.getInstance();
        final earned = (prefs.getStringList(_key) ?? const <String>[])
            .map(_parse)
            .whereType<AchievementId>()
            .toSet();
        final qualifying = qualifyingAchievements(
          records: records,
          current: current,
          now: now ?? DateTime.now(),
        );
        final newlyEarned = <AchievementId>[
          for (final id in AchievementId.values)
            if (qualifying.contains(id) && !earned.contains(id)) id,
        ];
        if (newlyEarned.isEmpty) return const <AchievementId>[];

        earned.addAll(newlyEarned);
        final saved = await prefs.setStringList(
          _key,
          [for (final id in AchievementId.values) if (earned.contains(id)) id.name],
        );
        if (!saved) throw StateError('Cannot save achievements');
        return newlyEarned;
      });

  Future<Set<AchievementId>> earned() => _serial(() async {
        final prefs = await SharedPreferences.getInstance();
        return (prefs.getStringList(_key) ?? const <String>[])
            .map(_parse)
            .whereType<AchievementId>()
            .toSet();
      });

  static Future<void> clearAll() => _serial(() async {
        final prefs = await SharedPreferences.getInstance();
        if (!await prefs.remove(_key)) {
          throw StateError('Cannot clear achievements');
        }
      });

  static Set<AchievementId> qualifyingAchievements({
    required List<WorkoutRecord> records,
    required WorkoutRecord current,
    required DateTime now,
  }) {
    final out = <AchievementId>{};
    if (records.isNotEmpty) out.add(AchievementId.firstWorkout);

    final totalReps =
        records.fold<int>(0, (sum, record) => sum + record.reps);
    if (totalReps >= 100) out.add(AchievementId.totalReps100);

    if (HistoryStatistics(records, now).streak >= 7) {
      out.add(AchievementId.streak7);
    }

    if (records.any((record) => record.mode == WorkoutMode.timed)) {
      out.add(AchievementId.firstTimeChallenge);
    }

    if (_isNewPersonalRecord(records, current)) {
      out.add(AchievementId.newPersonalRecord);
    }

    if (records.length >= 10) out.add(AchievementId.workouts10);
    return out;
  }

  static bool _isNewPersonalRecord(
    List<WorkoutRecord> records,
    WorkoutRecord current,
  ) {
    switch (current.mode) {
      case WorkoutMode.timed:
        final seconds = current.challengeSeconds;
        if (seconds == null || !current.completedTimedChallenge) return false;
        final previous = WorkoutPersonalRecordStore.bestTimedRepsFrom(
          records,
          exerciseId: current.exerciseId,
          challengeSeconds: seconds,
          excludeRecordId: current.id,
        );
        return previous == null || current.reps > previous;
      case WorkoutMode.free:
        int? previous;
        for (final record in records) {
          if (record.id == current.id ||
              record.exerciseId != current.exerciseId ||
              record.mode != WorkoutMode.free) {
            continue;
          }
          if (previous == null || record.reps > previous) previous = record.reps;
        }
        return previous == null || current.reps > previous;
      case WorkoutMode.targetReps:
        return false;
    }
  }

  static AchievementId? _parse(String value) {
    for (final id in AchievementId.values) {
      if (id.name == value) return id;
    }
    return null;
  }
}
