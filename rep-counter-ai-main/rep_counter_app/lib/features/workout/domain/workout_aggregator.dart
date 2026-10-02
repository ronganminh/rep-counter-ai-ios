/// Gom rep thành set và tính điểm chất lượng. Hoàn toàn xác định (deterministic).
///
/// Cùng đầu vào luôn ra cùng đầu ra, không phụ thuộc đồng hồ hay Flutter binding —
/// đó là lý do AI không được phép tính lại bất kỳ con số nào ở đây (ADR 0001).
library;

import 'dart:math' as math;

import 'quality_thresholds.dart';
import 'rep_metric.dart';
import 'set_metric.dart';
import 'workout_summary.dart';

class WorkoutAggregator {
  const WorkoutAggregator({
    this.setGap = const Duration(seconds: 6),
    this.minRepsPerSet = 1,
    this.minRepsForScore = 3,
  });

  /// Hai rep cách nhau lâu hơn mức này thuộc hai set khác nhau.
  ///
  /// Dùng cùng mốc 6 giây với SessionTracker để HUD và bản ghi chia set nhất quán.
  final Duration setGap;

  /// Mặc định là 1: set grouping chỉ chia nhóm, không được xóa rep đã được
  /// production counter xác nhận. Tham số được giữ cho tương thích với các
  /// phân tích ngoại tuyến cũ.
  final int minRepsPerSet;

  /// Dưới mức này thì `QualityScore.hasEnoughData = false`.
  final int minRepsForScore;

  /// Gom rep đã hoàn tất thành set. Rep phải đã sắp xếp theo thời gian.
  List<SetMetric> groupIntoSets(List<RepMetric> reps) {
    if (reps.isEmpty) return const [];
    final groups = <List<RepMetric>>[];
    var cur = <RepMetric>[reps.first];
    for (final r in reps.skip(1)) {
      final gap = r.observation.completedAt - cur.last.observation.completedAt;
      if (gap <= setGap) {
        cur.add(r);
      } else {
        groups.add(cur);
        cur = [r];
      }
    }
    groups.add(cur);

    final out = <SetMetric>[];
    for (final g in groups) {
      if (g.length < minRepsPerSet) continue;
      final idx = out.length + 1;
      out.add(SetMetric(
        index: idx,
        reps: [
          for (final r in g)
            RepMetric(
              index: r.index,
              setIndex: idx,
              observation: r.observation,
              flags: r.flags,
              valid: r.valid,
            )
        ],
      ));
    }
    return out;
  }

  /// For structured routines, the live SessionTracker owns set boundaries.
  /// Preserve those assigned set indexes so Skip rest cannot collapse two
  /// intentional sets merely because their rep timestamps are close together.
  List<SetMetric> groupByAssignedSetIndex(List<RepMetric> reps) {
    if (reps.isEmpty) return const [];
    final groups = <List<RepMetric>>[];
    var assigned = reps.first.setIndex;
    var current = <RepMetric>[];
    for (final rep in reps) {
      if (rep.setIndex != assigned && current.isNotEmpty) {
        groups.add(current);
        current = <RepMetric>[];
        assigned = rep.setIndex;
      }
      current.add(rep);
    }
    if (current.isNotEmpty) groups.add(current);

    return [
      for (var i = 0; i < groups.length; i++)
        SetMetric(
          index: i + 1,
          reps: [
            for (final rep in groups[i])
              RepMetric(
                index: rep.index,
                setIndex: i + 1,
                observation: rep.observation,
                flags: rep.flags,
                valid: rep.valid,
              ),
          ],
        ),
    ];
  }

  /// Biên độ nửa sau giảm bao nhiêu % so với nửa đầu. Không giảm -> 0.
  double amplitudeDropPercent(List<RepMetric> reps) {
    if (reps.length < 4) return 0;
    final half = reps.length ~/ 2;
    final first = _mean(reps.take(half).map((r) => r.amplitude));
    final last = _mean(reps.skip(reps.length - half).map((r) => r.amplitude));
    if (first <= 0) return 0;
    return math.max(0, (first - last) / first * 100);
  }

  /// Chênh lệch hai tay trung bình, tính theo % biên độ.
  ///
  /// Chỉ dùng rep đo được **cả hai tay**. Thiếu một tay không phải bằng chứng
  /// cân bằng, nên đưa vào sẽ kéo con số xuống một cách sai lệch.
  double leftRightDifferencePercent(List<RepMetric> reps) {
    final both = reps.where((r) => r.hasBothArms).toList();
    if (both.isEmpty) return 0;
    final amp = _mean(both.map((r) => r.amplitude));
    if (amp <= 0) return 0;
    return _mean(both.map((r) => r.leftRightDifference)) / amp * 100;
  }

  QualityScore score({
    required List<SetMetric> sets,
    required PoseQualityStats poseStats,
    CalibrationSnapshot? calibration,
  }) {
    final reps = [for (final s in sets) ...s.reps];
    if (reps.isEmpty) {
      return const QualityScore(
        rangeOfMotion: 0,
        cadenceConsistency: 0,
        leftRightBalance: 0,
        poseAlignment: 0,
        overall: 0,
        hasEnoughData: false,
      );
    }

    // --- Biên độ (35%) ---
    // Mốc tham chiếu ưu tiên calibration của người dùng; không có thì lấy chính
    // biên độ tốt nhất trong buổi. Cách sau chỉ đo được "đều hay không", không
    // đo được "đủ sâu hay không" — đó là lý do calibration vẫn cần.
    final amps = reps.map((r) => r.amplitude).where((a) => a.isFinite).toList();
    final ref = (calibration?.hasReference ?? false)
        ? calibration!.referenceAmplitude!
        : (amps.isEmpty ? 0.0 : _percentile(amps, 0.9));
    final rom = ref <= 0 ? 0 : _clamp100(_mean(amps) / ref * 100);

    // --- Nhịp (25%) ---
    // Hệ số biến thiên 0 -> 100 điểm; 0.5 trở lên -> 0 điểm.
    final withCadence = sets.where((s) => s.hasCadence).toList();
    final cadence = withCadence.isEmpty
        ? 0
        : _clamp100(100 - _mean(withCadence.map((s) => s.cadenceVariation)) * 200);

    // --- Cân bằng hai tay (20%) ---
    // 0% lệch -> 100 điểm; 25% biên độ trở lên -> 0 điểm.
    final both = reps.where((r) => r.hasBothArms).toList();
    final balance = both.isEmpty
        ? 0
        : _clamp100(100 - leftRightDifferencePercent(reps) * 4);

    // --- Pose và căn chỉnh thân (20%) ---
    final lost = poseStats.poseLostPercent;
    final torso = _mean(reps.map((r) => r.observation.torsoDeviationFraction));
    final align = _clamp100(100 - lost * 2 - torso * 100);

    final overall = (rom * 0.35 + cadence * 0.25 + balance * 0.20 + align * 0.20);

    return QualityScore(
      rangeOfMotion: rom.round(),
      cadenceConsistency: cadence.round(),
      leftRightBalance: balance.round(),
      poseAlignment: align.round(),
      overall: overall.round(),
      hasEnoughData: reps.length >= minRepsForScore,
    );
  }

  WorkoutSummary build({
    required String id,
    required String exerciseId,
    required DateTime startedAt,
    required DateTime endedAt,
    required List<RepMetric> reps,
    required PoseQualityStats poseStats,
    required CalibrationSnapshot calibration,
    bool preserveAssignedSetIndex = false,
  }) {
    final sets = preserveAssignedSetIndex
        ? groupByAssignedSetIndex(reps)
        : groupIntoSets(reps);
    final kept = [for (final s in sets) ...s.reps];
    return WorkoutSummary(
      id: id,
      exerciseId: exerciseId,
      startedAt: startedAt,
      endedAt: endedAt,
      sets: sets,
      poseStats: poseStats,
      calibration: calibration,
      score: score(sets: sets, poseStats: poseStats, calibration: calibration),
      amplitudeDropPercent: amplitudeDropPercent(kept),
      leftRightDifferencePercent: leftRightDifferencePercent(kept),
    );
  }

  static double _mean(Iterable<double> xs) {
    var n = 0;
    var s = 0.0;
    for (final x in xs) {
      if (x.isFinite) {
        s += x;
        n++;
      }
    }
    return n == 0 ? 0 : s / n;
  }

  static double _percentile(List<double> xs, double p) {
    final s = [...xs]..sort();
    final i = ((s.length - 1) * p).round().clamp(0, s.length - 1);
    return s[i];
  }

  static double _clamp100(double v) => v.isFinite ? v.clamp(0, 100).toDouble() : 0;
}
