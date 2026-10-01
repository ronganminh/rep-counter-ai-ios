import '../data/workout_history_store.dart';
import '../data/workout_record.dart';
import 'workout_mode.dart';

class WorkoutPersonalRecordStore {
  WorkoutPersonalRecordStore({WorkoutHistoryStore? history})
      : _history = history ?? WorkoutHistoryStore();

  final WorkoutHistoryStore _history;

  Future<int?> bestTimedReps({
    required String exerciseId,
    required int challengeSeconds,
    String? excludeRecordId,
  }) async {
    final records = await _history.load();
    return bestTimedRepsFrom(
      records,
      exerciseId: exerciseId,
      challengeSeconds: challengeSeconds,
      excludeRecordId: excludeRecordId,
    );
  }

  static int? bestTimedRepsFrom(
    Iterable<WorkoutRecord> records, {
    required String exerciseId,
    required int challengeSeconds,
    String? excludeRecordId,
  }) {
    int? best;
    for (final record in records) {
      if (record.id == excludeRecordId ||
          record.exerciseId != exerciseId ||
          record.mode != WorkoutMode.timed ||
          record.challengeSeconds != challengeSeconds ||
          !record.completedTimedChallenge) {
        continue;
      }
      if (best == null || record.reps > best) best = record.reps;
    }
    return best;
  }
}
