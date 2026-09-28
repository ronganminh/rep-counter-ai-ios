import '../workout/data/workout_record.dart';

/// Presentation aggregates of saved sessions; does not recalculate rep metrics.
class HistoryStatistics {
  HistoryStatistics(this.records, this.now);
  final List<WorkoutRecord> records;
  final DateTime now;
  static DateTime day(DateTime value) =>
      DateTime(value.year, value.month, value.day);
  List<WorkoutRecord> get month => records
      .where(
          (r) => r.startedAt.year == now.year && r.startedAt.month == now.month)
      .toList();
  int get monthReps => month.fold(0, (sum, r) => sum + r.reps);
  int get best => records.fold(0, (best, r) => r.reps > best ? r.reps : best);
  Map<DateTime, int> get dailyReps {
    final result = <DateTime, int>{};
    for (final r in records) {
      result.update(day(r.startedAt), (v) => v + r.reps,
          ifAbsent: () => r.reps);
    }
    return result;
  }

  int get streak {
    final days =
        records.where((r) => r.reps > 0).map((r) => day(r.startedAt)).toSet();
    var cursor = day(now);
    if (!days.contains(cursor)) {
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    var count = 0;
    while (days.contains(cursor)) {
      count++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    return count;
  }

  List<WorkoutRecord> get recent => records
      .where((r) =>
          !day(r.startedAt)
              .isBefore(day(now).subtract(const Duration(days: 29))) &&
          !day(r.startedAt).isAfter(day(now)))
      .toList()
    ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
}
