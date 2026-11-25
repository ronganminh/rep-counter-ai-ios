import '../workout/data/workout_record.dart';

enum TrendDirection { up, down, same, none }

/// One "Compared with last time" row (AC-02a), from recorded numbers only.
class TrendRow {
  const TrendRow(this.metric, this.direction, this.now, this.before,
      {this.beforeAt, this.lowerIsBetter = false});

  /// `reps`, `form` or `flagged` (reps flagged too fast or short).
  final String metric;
  final TrendDirection direction;
  final int now;
  final int? before;
  final DateTime? beforeAt;
  final bool lowerIsBetter;
}

/// Backend gap (10 §stubs 2): `workout_review` has no `trend`, so the
/// comparison is made on the phone from saved workouts: the same exercise's
/// previous workout, reps, form score and flagged reps.
abstract final class CoachTrend {
  static List<TrendRow> rows(WorkoutRecord r, List<WorkoutRecord> all) {
    final earlier = all
        .where((w) =>
            w.id != r.id &&
            w.exerciseId == r.exerciseId &&
            w.startedAt.isBefore(r.startedAt))
        .toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    if (earlier.isEmpty) {
      return [TrendRow('reps', TrendDirection.none, r.reps, null)];
    }
    final p = earlier.first;
    TrendDirection dir(int now, int before) => now > before
        ? TrendDirection.up
        : now < before
            ? TrendDirection.down
            : TrendDirection.same;
    final q = r.quality, pq = p.quality;
    final both = q != null && pq != null && q.hasEnoughData && pq.hasEnoughData;
    return [
      TrendRow('reps', dir(r.reps, p.reps), r.reps, p.reps,
          beforeAt: p.startedAt),
      if (both)
        TrendRow('form', dir(q.qualityScore, pq.qualityScore), q.qualityScore,
            pq.qualityScore,
            beforeAt: p.startedAt),
      if (both && (q.flaggedReps > 0 || pq.flaggedReps > 0))
        TrendRow('flagged', dir(q.flaggedReps, pq.flaggedReps), q.flaggedReps,
            pq.flaggedReps,
            beforeAt: p.startedAt, lowerIsBetter: true),
    ];
  }
}
