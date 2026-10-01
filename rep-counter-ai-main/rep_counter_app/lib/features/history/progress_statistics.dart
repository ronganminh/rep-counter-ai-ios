import '../workout/data/workout_record.dart';
import '../workout/domain/workout_mode.dart';
import '../workout/domain/workout_personal_records.dart';

enum ProgressRange {
  days7,
  days30,
  days90,
  all,
}

extension ProgressRangeX on ProgressRange {
  int? get days => switch (this) {
        ProgressRange.days7 => 7,
        ProgressRange.days30 => 30,
        ProgressRange.days90 => 90,
        ProgressRange.all => null,
      };

  String get label => switch (this) {
        ProgressRange.days7 => '7D',
        ProgressRange.days30 => '30D',
        ProgressRange.days90 => '90D',
        ProgressRange.all => 'ALL',
      };
}

enum ProgressTrendMetric {
  reps,
  sessions,
  duration,
  form,
}

/// Read-only analytics over locally saved workout records.
///
/// This class never recalculates reps or form scores. It only aggregates values
/// already persisted by the deterministic workout pipeline.
class ProgressStatistics {
  ProgressStatistics({
    required List<WorkoutRecord> records,
    required this.now,
    required this.range,
    this.exerciseId,
  }) : source = List.unmodifiable(records);

  final List<WorkoutRecord> source;
  final DateTime now;
  final ProgressRange range;
  final String? exerciseId;

  static DateTime day(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  DateTime get today => day(now);

  DateTime? get startDay {
    final days = range.days;
    return days == null ? null : today.subtract(Duration(days: days - 1));
  }

  late final List<WorkoutRecord> exerciseRecords = source
      .where((record) =>
          exerciseId == null || record.exerciseId == exerciseId)
      .toList();

  late final List<WorkoutRecord> records = exerciseRecords.where((record) {
    final recordDay = day(record.startedAt);
    if (recordDay.isAfter(today)) return false;
    final start = startDay;
    return start == null || !recordDay.isBefore(start);
  }).toList();

  int get totalReps => records.fold(0, (sum, record) => sum + record.reps);
  int get sessions => records.length;

  double? get averageForm {
    final scores = records
        .where((record) => record.quality?.hasEnoughData == true)
        .map((record) => record.quality!.qualityScore)
        .toList();
    if (scores.isEmpty) return null;
    return scores.fold<int>(0, (sum, score) => sum + score) / scores.length;
  }

  int get goalsReached => records
      .where((record) => record.targetReps != null && record.goalReached)
      .length;

  Map<DateTime, int> get dailyReps => _aggregateInt((record) => record.reps);

  Map<DateTime, int> get dailySessions => _aggregateInt((_) => 1);

  Map<DateTime, int> get dailyDurationSeconds =>
      _aggregateInt((record) => record.durationSeconds);

  Map<DateTime, double> get dailyForm {
    final totals = <DateTime, ({int sum, int count})>{};
    for (final record in records) {
      final quality = record.quality;
      if (quality?.hasEnoughData != true) continue;
      final key = day(record.startedAt);
      final current = totals[key] ?? (sum: 0, count: 0);
      totals[key] = (
        sum: current.sum + quality!.qualityScore,
        count: current.count + 1,
      );
    }
    return {
      for (final entry in totals.entries)
        entry.key: entry.value.sum / entry.value.count,
    };
  }

  Map<DateTime, int> _aggregateInt(int Function(WorkoutRecord) valueOf) {
    final result = <DateTime, int>{};
    for (final record in records) {
      final key = day(record.startedAt);
      result.update(
        key,
        (value) => value + valueOf(record),
        ifAbsent: () => valueOf(record),
      );
    }
    return result;
  }

  int? get personalBestFree {
    final exercise = exerciseId;
    if (exercise == null) return null;
    int? best;
    for (final record in exerciseRecords) {
      if (record.exerciseId != exercise || record.mode != WorkoutMode.free) {
        continue;
      }
      if (best == null || record.reps > best) best = record.reps;
    }
    return best;
  }

  int? personalBestTimed(int challengeSeconds) {
    final exercise = exerciseId;
    if (exercise == null) return null;
    return WorkoutPersonalRecordStore.bestTimedRepsFrom(
      exerciseRecords,
      exerciseId: exercise,
      challengeSeconds: challengeSeconds,
    );
  }
}
