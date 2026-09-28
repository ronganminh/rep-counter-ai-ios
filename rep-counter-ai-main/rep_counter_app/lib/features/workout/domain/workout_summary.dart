/// Tổng hợp buổi tập — đầu vào duy nhất mà AI được nhìn thấy (ADR 0001).
library;

import 'quality_thresholds.dart';
import 'rep_metric.dart';
import 'set_metric.dart';

/// Thống kê chất lượng pose của buổi tập.
///
/// §5.2: `poseLostPercent` tính trên **frame đã xử lý**, không phải FPS danh nghĩa
/// của camera. Máy yếu bỏ frame là chuyện bình thường và không có nghĩa là mất pose.
class PoseQualityStats {
  const PoseQualityStats({
    this.totalProcessedFrames = 0,
    this.countableFrames = 0,
    this.poseLostFrames = 0,
    this.partiallyOutFrames = 0,
    this.wrongPoseFrames = 0,
  });

  final int totalProcessedFrames;
  final int countableFrames;
  final int poseLostFrames;
  final int partiallyOutFrames;
  final int wrongPoseFrames;

  double get poseLostPercent =>
      totalProcessedFrames == 0 ? 0 : poseLostFrames / totalProcessedFrames * 100;

  double get countablePercent =>
      totalProcessedFrames == 0 ? 0 : countableFrames / totalProcessedFrames * 100;

  Map<String, dynamic> toJson() => {
        'total_processed_frames': totalProcessedFrames,
        'countable_frames': countableFrames,
        'pose_lost_frames': poseLostFrames,
        'partially_out_frames': partiallyOutFrames,
        'wrong_pose_frames': wrongPoseFrames,
      };

  static PoseQualityStats fromJson(Map<String, dynamic> j) => PoseQualityStats(
        totalProcessedFrames: (j['total_processed_frames'] as num?)?.toInt() ?? 0,
        countableFrames: (j['countable_frames'] as num?)?.toInt() ?? 0,
        poseLostFrames: (j['pose_lost_frames'] as num?)?.toInt() ?? 0,
        partiallyOutFrames: (j['partially_out_frames'] as num?)?.toInt() ?? 0,
        wrongPoseFrames: (j['wrong_pose_frames'] as num?)?.toInt() ?? 0,
      );
}

/// Điểm chất lượng tách theo thành phần.
///
/// Lưu từng thành phần chứ không chỉ tổng: điểm 70 vì biên độ kém và điểm 70 vì
/// nhịp thất thường cần hai lời khuyên khác hẳn nhau.
class QualityScore {
  const QualityScore({
    required this.rangeOfMotion,
    required this.cadenceConsistency,
    required this.leftRightBalance,
    required this.poseAlignment,
    required this.overall,
    this.hasEnoughData = true,
  });

  final int rangeOfMotion;
  final int cadenceConsistency;
  final int leftRightBalance;
  final int poseAlignment;
  final int overall;

  /// false khi quá ít rep để kết luận. UI phải nói rõ thay vì hiện một con số.
  final bool hasEnoughData;

  Map<String, dynamic> toJson() => {
        'range_of_motion': rangeOfMotion,
        'cadence_consistency': cadenceConsistency,
        'left_right_balance': leftRightBalance,
        'pose_alignment': poseAlignment,
        'overall': overall,
        'has_enough_data': hasEnoughData,
      };

  static QualityScore fromJson(Map<String, dynamic> j) => QualityScore(
        rangeOfMotion: (j['range_of_motion'] as num).toInt(),
        cadenceConsistency: (j['cadence_consistency'] as num).toInt(),
        leftRightBalance: (j['left_right_balance'] as num).toInt(),
        poseAlignment: (j['pose_alignment'] as num).toInt(),
        overall: (j['overall'] as num).toInt(),
        hasEnoughData: j['has_enough_data'] as bool? ?? true,
      );
}

class WorkoutSummary {
  const WorkoutSummary({
    required this.id,
    required this.exerciseId,
    required this.startedAt,
    required this.endedAt,
    required this.sets,
    required this.score,
    required this.poseStats,
    required this.calibration,
    this.amplitudeDropPercent = 0,
    this.leftRightDifferencePercent = 0,
  });

  final String id;
  final String exerciseId;
  final DateTime startedAt;
  final DateTime endedAt;
  final List<SetMetric> sets;
  final QualityScore score;
  final PoseQualityStats poseStats;
  final CalibrationSnapshot calibration;

  /// Biên độ nửa sau buổi giảm bao nhiêu phần trăm so với nửa đầu. 0 nếu không giảm.
  final double amplitudeDropPercent;

  /// Chênh lệch hai tay trung bình, tính theo phần trăm biên độ.
  final double leftRightDifferencePercent;

  List<RepMetric> get allReps => [for (final s in sets) ...s.reps];
  int get totalReps => allReps.where((r) => r.valid).length;
  int get flaggedReps => allReps.where((r) => r.flagged).length;
  Duration get duration => endedAt.difference(startedAt);

  double get averageRepSeconds => _mean(allReps.map((r) => r.durationSeconds));
  double get averageAmplitude => _mean(allReps.map((r) => r.amplitude));
  double get poseLostPercent => poseStats.poseLostPercent;

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

  static const int schemaVersion = 1;

  Map<String, dynamic> toJson() => {
        'schema_version': schemaVersion,
        'id': id,
        'exercise_id': exerciseId,
        'started_at': startedAt.toUtc().toIso8601String(),
        'ended_at': endedAt.toUtc().toIso8601String(),
        'sets': sets.map((s) => s.toJson()).toList(),
        'score': score.toJson(),
        'pose_stats': poseStats.toJson(),
        'calibration': calibration.toJson(),
        'amplitude_drop_percent': amplitudeDropPercent,
        'left_right_difference_percent': leftRightDifferencePercent,
      };

  static WorkoutSummary fromJson(Map<String, dynamic> j) {
    final v = (j['schema_version'] as num?)?.toInt() ?? 1;
    if (v > schemaVersion) {
      throw FormatException('WorkoutSummary schema_version $v mới hơn bản app hiểu '
          'được ($schemaVersion)');
    }
    return WorkoutSummary(
      id: j['id'] as String,
      exerciseId: j['exercise_id'] as String,
      startedAt: DateTime.parse(j['started_at'] as String),
      endedAt: DateTime.parse(j['ended_at'] as String),
      sets: ((j['sets'] as List?) ?? const [])
          .map((e) => SetMetric.fromJson(e as Map<String, dynamic>))
          .toList(),
      score: QualityScore.fromJson(j['score'] as Map<String, dynamic>),
      poseStats: PoseQualityStats.fromJson(j['pose_stats'] as Map<String, dynamic>),
      calibration:
          CalibrationSnapshot.fromJson(j['calibration'] as Map<String, dynamic>),
      amplitudeDropPercent: (j['amplitude_drop_percent'] as num?)?.toDouble() ?? 0,
      leftRightDifferencePercent:
          (j['left_right_difference_percent'] as num?)?.toDouble() ?? 0,
    );
  }

  /// Payload gửi backend cho AI. §9.2: nhỏ, đã tổng hợp, không có landmark.
  Map<String, dynamic> toAiPayload({String locale = 'vi'}) => {
        'schema_version': 1,
        'locale': locale,
        'workout_id': id,
        'workout': {
          'exercise': exerciseId,
          'total_reps': totalReps,
          'flagged_reps': flaggedReps,
          'sets': [
            for (final s in sets)
              {
                'reps': s.validReps,
                'duration_sec': _round(s.durationSeconds),
                'avg_rep_sec': _round(s.averageRepSeconds),
                'avg_amplitude': _round(s.averageAmplitude),
              }
          ],
          'avg_rep_sec': _round(averageRepSeconds),
          'avg_amplitude': _round(averageAmplitude),
          'amplitude_drop_percent': _round(amplitudeDropPercent),
          'left_right_diff_percent': _round(leftRightDifferencePercent),
          'pose_lost_percent': _round(poseLostPercent),
          'quality_score': score.overall,
        },
      };

  static double _round(double v) =>
      v.isFinite ? (v * 10).roundToDouble() / 10 : 0;
}
