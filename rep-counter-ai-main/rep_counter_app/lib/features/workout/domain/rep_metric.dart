/// Số liệu của một rep. Dart thuần — test được không cần Flutter binding.
library;

/// Cờ chất lượng. IMPLEMENTATION_PLAN §4.2: **không** dùng cờ này để thay đổi số
/// rep ở giai đoạn đầu. Số rep vẫn do thuật toán cũ quyết định; cờ chỉ phục vụ
/// phản hồi. Chỉ cân nhắc loại rep sau khi có ground truth đủ lớn (§11.5).
enum RepQualityFlag {
  shallow,
  incompleteLockout,
  tooFast,
  tooSlow,
  leftRightUneven,
  bodyAlignmentLost,
  poseUnreliable,
}

/// Dữ liệu thô tích luỹ trong một chu kỳ rep, do `RepTracker` gom lại.
///
/// Tách khỏi [RepMetric] vì đây là thứ đo được trực tiếp; [RepMetric] là thứ đã
/// diễn giải, có cờ chất lượng.
class RepObservation {
  const RepObservation({
    required this.startedAt,
    required this.bottomAt,
    required this.completedAt,
    required this.bottomAngle,
    required this.topAngle,
    this.leftBottomAngle,
    this.rightBottomAngle,
    this.maxTorsoDeviation = 0,
    this.torsoDeviationFraction = 0,
    this.averagePoseConfidence = 1,
    this.sampleCount = 0,
  });

  /// Thời điểm bắt đầu đi xuống.
  final Duration startedAt;

  /// Thời điểm chạm đáy.
  final Duration bottomAt;

  /// Thời điểm bộ đếm ghi nhận rep (lúc vượt ngưỡng trên khi đi lên).
  final Duration completedAt;

  final double bottomAngle;
  final double topAngle;
  final double? leftBottomAngle;
  final double? rightBottomAngle;

  /// Độ lệch trục thân lớn nhất trong chu kỳ (độ).
  final double maxTorsoDeviation;

  /// Tỉ lệ thời gian trong chu kỳ mà trục thân vượt ngưỡng lệch.
  final double torsoDeviationFraction;

  final double averagePoseConfidence;
  final int sampleCount;

  double get amplitude => topAngle - bottomAngle;

  Duration get duration => completedAt - startedAt;

  /// Chênh lệch góc hai tay tại đáy. 0 nếu chỉ đo được một tay — **không phải**
  /// bằng chứng hai bên cân, nên [RepMetric.hasBothArms] ghi lại điều đó.
  double get leftRightDifference {
    final l = leftBottomAngle, r = rightBottomAngle;
    if (l == null || r == null) return 0;
    return (l - r).abs();
  }

  bool get hasBothArms => leftBottomAngle != null && rightBottomAngle != null;
}

class RepMetric {
  const RepMetric({
    required this.index,
    required this.setIndex,
    required this.observation,
    required this.flags,
    this.valid = true,
  });

  /// Số thứ tự trong toàn buổi tập, bắt đầu từ 1.
  final int index;

  /// Set chứa rep này, bắt đầu từ 1.
  final int setIndex;

  final RepObservation observation;
  final Set<RepQualityFlag> flags;

  /// Có được tính vào tổng không. Ở phase này luôn true — xem ghi chú ở
  /// [RepQualityFlag].
  final bool valid;

  Duration get startedAt => observation.startedAt;
  Duration get bottomAt => observation.bottomAt;
  Duration get completedAt => observation.completedAt;
  double get amplitude => observation.amplitude;
  double get bottomAngle => observation.bottomAngle;
  double get topAngle => observation.topAngle;
  double get durationSeconds => observation.duration.inMicroseconds / 1e6;
  double get leftRightDifference => observation.leftRightDifference;
  bool get hasBothArms => observation.hasBothArms;
  bool get flagged => flags.isNotEmpty;

  static const int schemaVersion = 1;

  Map<String, dynamic> toJson() => {
        'schema_version': schemaVersion,
        'index': index,
        'set_index': setIndex,
        'started_ms': observation.startedAt.inMilliseconds,
        'bottom_ms': observation.bottomAt.inMilliseconds,
        'completed_ms': observation.completedAt.inMilliseconds,
        'bottom_angle': observation.bottomAngle,
        'top_angle': observation.topAngle,
        'left_bottom_angle': observation.leftBottomAngle,
        'right_bottom_angle': observation.rightBottomAngle,
        'max_torso_deviation': observation.maxTorsoDeviation,
        'torso_deviation_fraction': observation.torsoDeviationFraction,
        'average_pose_confidence': observation.averagePoseConfidence,
        'sample_count': observation.sampleCount,
        'valid': valid,
        'flags': flags.map((f) => f.name).toList(),
      };

  static RepMetric fromJson(Map<String, dynamic> j) {
    final v = (j['schema_version'] as num?)?.toInt() ?? 1;
    if (v > schemaVersion) {
      throw FormatException('RepMetric schema_version $v mới hơn bản app hiểu được '
          '($schemaVersion)');
    }
    return RepMetric(
      index: (j['index'] as num).toInt(),
      setIndex: (j['set_index'] as num).toInt(),
      valid: j['valid'] as bool? ?? true,
      observation: RepObservation(
        startedAt: Duration(milliseconds: (j['started_ms'] as num).toInt()),
        bottomAt: Duration(milliseconds: (j['bottom_ms'] as num).toInt()),
        completedAt: Duration(milliseconds: (j['completed_ms'] as num).toInt()),
        bottomAngle: (j['bottom_angle'] as num).toDouble(),
        topAngle: (j['top_angle'] as num).toDouble(),
        leftBottomAngle: (j['left_bottom_angle'] as num?)?.toDouble(),
        rightBottomAngle: (j['right_bottom_angle'] as num?)?.toDouble(),
        maxTorsoDeviation: (j['max_torso_deviation'] as num?)?.toDouble() ?? 0,
        torsoDeviationFraction:
            (j['torso_deviation_fraction'] as num?)?.toDouble() ?? 0,
        averagePoseConfidence:
            (j['average_pose_confidence'] as num?)?.toDouble() ?? 1,
        sampleCount: (j['sample_count'] as num?)?.toInt() ?? 0,
      ),
      flags: ((j['flags'] as List?) ?? const [])
          .map((n) => RepQualityFlag.values.firstWhere(
                (f) => f.name == n,
                orElse: () => RepQualityFlag.poseUnreliable,
              ))
          .toSet(),
    );
  }

  @override
  String toString() => 'Rep#$index set$setIndex amp=${amplitude.toStringAsFixed(1)}°'
      ' ${durationSeconds.toStringAsFixed(2)}s flags=${flags.map((f) => f.name)}';
}
