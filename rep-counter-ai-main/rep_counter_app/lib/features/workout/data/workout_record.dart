import '../domain/workout_summary.dart';

class WorkoutRecord {
  const WorkoutRecord({
    required this.id,
    required this.exerciseId,
    required this.exerciseName,
    required this.startedAt,
    required this.durationSeconds,
    required this.reps,
    required this.sets,
    required this.targetReps,
    required this.poseFrames,
    required this.readyFrames,
    required this.lostFrames,
    this.aiFeedback,
    this.quality,
    this.repDetails,
  });

  /// Số liệu chất lượng lấy từ `WorkoutSummary`.
  ///
  /// Tách riêng và cho phép null vì bản ghi cũ lưu trước khi có phần này vẫn
  /// phải đọc lại được — đó là lý do `fromJson` không bắt buộc trường này.
  factory WorkoutRecord.fromSummary({
    required WorkoutSummary summary,
    required String exerciseName,
    required int durationSeconds,
    int? targetReps,
    required int poseFrames,
    required int readyFrames,
    required int lostFrames,
    String? aiFeedback,
  }) =>
      WorkoutRecord(
        id: summary.id,
        exerciseId: summary.exerciseId,
        exerciseName: exerciseName,
        startedAt: summary.startedAt,
        durationSeconds: durationSeconds,
        reps: summary.totalReps,
        sets: summary.sets.length,
        targetReps: targetReps,
        poseFrames: poseFrames,
        readyFrames: readyFrames,
        lostFrames: lostFrames,
        aiFeedback: aiFeedback,
        quality: WorkoutQuality.fromSummary(summary),
        repDetails: [
          for (final set in summary.sets)
            for (final rep in set.reps)
              if (rep.valid)
                StoredRep(
                    seconds: rep.durationSeconds,
                    setIndex: set.index,
                    flagged: rep.flagged,
                    qualityFlags: rep.flags.map((flag) => flag.name).toList())
        ],
      );

  final String id;
  final String exerciseId;
  final String exerciseName;
  final DateTime startedAt;
  final int durationSeconds;
  final int reps;
  final int sets;
  final int? targetReps;
  final int poseFrames;
  final int readyFrames;
  final int lostFrames;
  final String? aiFeedback;
  final WorkoutQuality? quality;

  /// Optional local-only timing detail; legacy records remain readable.
  final List<StoredRep>? repDetails;

  bool get goalReached => targetReps != null && reps >= targetReps!;
  int get placementScore => poseFrames == 0
      ? 0
      : ((readyFrames / poseFrames) * 100).round().clamp(0, 100);

  Map<String, dynamic> toJson() => {
        'id': id,
        'exercise_id': exerciseId,
        'exercise_name': exerciseName,
        'started_at': startedAt.toUtc().toIso8601String(),
        'duration_seconds': durationSeconds,
        'reps': reps,
        'sets': sets,
        'target_reps': targetReps,
        'pose_frames': poseFrames,
        'ready_frames': readyFrames,
        'lost_frames': lostFrames,
        if (aiFeedback != null) 'ai_feedback': aiFeedback,
        if (quality != null) 'quality': quality!.toJson(),
        if (repDetails != null)
          'rep_details': repDetails!.map((r) => r.toJson()).toList(),
        if (repDetails != null) 'rep_details_version': 2,
      };

  Map<String, dynamic> toAiPayload() => {
        'schema_version': 1,
        'exercise': exerciseId,
        'duration_seconds': durationSeconds,
        'reps': reps,
        'sets': sets,
        'target_reps': targetReps,
        'goal_reached': goalReached,
        'placement_score': placementScore,
        'pose_frames': poseFrames,
        'pose_lost_frames': lostFrames,
        // Nếu chưa có số liệu chất lượng thì KHÔNG gửi khoá rỗng: backend phân
        // biệt được "chưa đo" với "đo ra 0", và prompt §9.4 yêu cầu nói rõ khi
        // dữ liệu không đủ thay vì đoán.
        if (quality != null) ...quality!.toAiPayload(),
      };

  WorkoutRecord copyWith({String? aiFeedback}) => WorkoutRecord(
        id: id,
        exerciseId: exerciseId,
        exerciseName: exerciseName,
        startedAt: startedAt,
        durationSeconds: durationSeconds,
        reps: reps,
        sets: sets,
        targetReps: targetReps,
        poseFrames: poseFrames,
        readyFrames: readyFrames,
        lostFrames: lostFrames,
        aiFeedback: aiFeedback ?? this.aiFeedback,
        quality: quality,
        repDetails: repDetails,
      );

  factory WorkoutRecord.fromJson(Map<String, dynamic> j) => WorkoutRecord(
        id: j['id'] as String,
        exerciseId: j['exercise_id'] as String,
        exerciseName: j['exercise_name'] as String,
        startedAt: DateTime.parse(j['started_at'] as String).toLocal(),
        durationSeconds: j['duration_seconds'] as int,
        reps: j['reps'] as int,
        sets: j['sets'] as int,
        targetReps: j['target_reps'] as int?,
        poseFrames: j['pose_frames'] as int? ?? 0,
        readyFrames: j['ready_frames'] as int? ?? 0,
        lostFrames: j['lost_frames'] as int? ?? 0,
        aiFeedback: j['ai_feedback'] as String?,
        repDetails: _readRepDetails(j),
        quality: _readQuality(j['quality']),
      );

  static WorkoutQuality? _readQuality(Object? value) {
    try {
      return value == null
          ? null
          : WorkoutQuality.fromJson(value as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static List<StoredRep>? _readRepDetails(Map<String, dynamic> json) {
    try {
      final version = json['rep_details_version'] ?? 1;
      if (version is! int || version > 2 || version < 1) return null;
      final raw = json['rep_details'];
      if (raw == null) return null;
      final reps = (raw as List)
          .map((r) => StoredRep.fromJson(r as Map<String, dynamic>))
          .toList();
      // Reject the optional detail as a whole: skipping a bad rep would shift
      // all subsequent rep numbers. Aggregate data remains readable.
      var previousSet = 0;
      for (final rep in reps) {
        if (rep.setIndex < previousSet) return null;
        previousSet = rep.setIndex;
      }
      return reps;
    } catch (_) {
      return null;
    }
  }
}

/// Phần chất lượng của buổi tập, rút gọn từ `WorkoutSummary` để lưu và gửi AI.
class WorkoutQuality {
  const WorkoutQuality({
    required this.flaggedReps,
    required this.avgRepSeconds,
    required this.avgAmplitude,
    required this.amplitudeDropPercent,
    required this.leftRightDiffPercent,
    required this.qualityScore,
    required this.rangeOfMotion,
    required this.cadenceConsistency,
    required this.leftRightBalance,
    required this.poseAlignment,
    required this.hasEnoughData,
  });

  final int flaggedReps;
  final double avgRepSeconds;
  final double avgAmplitude;
  final double amplitudeDropPercent;
  final double leftRightDiffPercent;
  final int qualityScore;
  final int rangeOfMotion;
  final int cadenceConsistency;
  final int leftRightBalance;
  final int poseAlignment;

  /// false khi quá ít rep để kết luận. UI và AI phải nói rõ thay vì hiện số.
  final bool hasEnoughData;

  factory WorkoutQuality.fromSummary(WorkoutSummary s) => WorkoutQuality(
        flaggedReps: s.flaggedReps,
        avgRepSeconds: _r(s.averageRepSeconds),
        avgAmplitude: _r(s.averageAmplitude),
        amplitudeDropPercent: _r(s.amplitudeDropPercent),
        leftRightDiffPercent: _r(s.leftRightDifferencePercent),
        qualityScore: s.score.overall,
        rangeOfMotion: s.score.rangeOfMotion,
        cadenceConsistency: s.score.cadenceConsistency,
        leftRightBalance: s.score.leftRightBalance,
        poseAlignment: s.score.poseAlignment,
        hasEnoughData: s.score.hasEnoughData,
      );

  static double _r(double v) => v.isFinite ? (v * 10).roundToDouble() / 10 : 0;

  Map<String, dynamic> toJson() => {
        'flagged_reps': flaggedReps,
        'avg_rep_sec': avgRepSeconds,
        'avg_amplitude': avgAmplitude,
        'amplitude_drop_percent': amplitudeDropPercent,
        'left_right_diff_percent': leftRightDiffPercent,
        'quality_score': qualityScore,
        'range_of_motion': rangeOfMotion,
        'cadence_consistency': cadenceConsistency,
        'left_right_balance': leftRightBalance,
        'pose_alignment': poseAlignment,
        'has_enough_data': hasEnoughData,
      };

  /// Chỉ những trường AI thật sự cần để viết nhận xét (§9.2).
  Map<String, dynamic> toAiPayload() => {
        'flagged_reps': flaggedReps,
        'avg_rep_sec': avgRepSeconds,
        'avg_amplitude': avgAmplitude,
        'amplitude_drop_percent': amplitudeDropPercent,
        'left_right_diff_percent': leftRightDiffPercent,
        'quality_score': qualityScore,
        'has_enough_data': hasEnoughData,
      };

  factory WorkoutQuality.fromJson(Map<String, dynamic> j) => WorkoutQuality(
        flaggedReps: (j['flagged_reps'] as num?)?.toInt() ?? 0,
        avgRepSeconds: (j['avg_rep_sec'] as num?)?.toDouble() ?? 0,
        avgAmplitude: (j['avg_amplitude'] as num?)?.toDouble() ?? 0,
        amplitudeDropPercent:
            (j['amplitude_drop_percent'] as num?)?.toDouble() ?? 0,
        leftRightDiffPercent:
            (j['left_right_diff_percent'] as num?)?.toDouble() ?? 0,
        qualityScore: (j['quality_score'] as num?)?.toInt() ?? 0,
        rangeOfMotion: (j['range_of_motion'] as num?)?.toInt() ?? 0,
        cadenceConsistency: (j['cadence_consistency'] as num?)?.toInt() ?? 0,
        leftRightBalance: (j['left_right_balance'] as num?)?.toInt() ?? 0,
        poseAlignment: (j['pose_alignment'] as num?)?.toInt() ?? 0,
        hasEnoughData: j['has_enough_data'] as bool? ?? false,
      );
}

/// No image or landmark data; only measured duration and set membership.
class StoredRep {
  const StoredRep(
      {required this.seconds,
      required this.setIndex,
      required this.flagged,
      this.qualityFlags});
  final double seconds;
  final int setIndex;
  final bool flagged;

  /// Null = legacy unknown; empty = engine checked and found no flags.
  /// Preserve unknown flag names for forward compatibility.
  final List<String>? qualityFlags;
  bool get tooFast => qualityFlags?.contains('tooFast') == true;
  Map<String, dynamic> toJson() => {
        'seconds': seconds,
        'set': setIndex,
        'flagged': flagged,
        if (qualityFlags != null) 'flags': qualityFlags,
      };
  factory StoredRep.fromJson(Map<String, dynamic> j) {
    final seconds = (j['seconds'] as num).toDouble();
    final set = j['set'] as num;
    if (!seconds.isFinite ||
        seconds <= 0 ||
        !set.isFinite ||
        set < 1 ||
        set != set.toInt()) {
      throw const FormatException('Invalid rep timing or set');
    }
    final rawFlags = j['flags'];
    final flags = rawFlags is List && rawFlags.every((f) => f is String)
        ? rawFlags.cast<String>().toList()
        : null;
    return StoredRep(
        seconds: seconds,
        setIndex: set.toInt(),
        flagged:
            (j['flagged'] as bool? ?? false) || (flags?.isNotEmpty ?? false),
        qualityFlags: flags);
  }
}
