/// Ngưỡng chấm chất lượng rep, gom về một chỗ.
///
/// IMPLEMENTATION_PLAN §6: không rải magic number trong UI hay analyzer. Mọi con số
/// ở đây đều là **điểm khởi đầu cần tinh chỉnh bằng dữ liệu thật**, không phải hằng
/// số đã kiểm chứng — trừ `minRepSeconds`, xem ghi chú bên dưới.
library;

class QualityThresholds {
  const QualityThresholds({
    this.minRepSeconds = 0.7,
    this.maxRepSeconds = 5.0,
    this.leftRightUnevenDeg = 20.0,
    this.poseUnreliableConfidence = 0.55,
    this.torsoDeviationDeg = 25.0,
    this.torsoDeviationFraction = 0.3,
    this.shallowAmplitudeRatio = 0.75,
    this.lockoutRatio = 0.85,
  });

  /// Rep nhanh hơn mức này bị gắn cờ `tooFast`.
  ///
  /// 0.7 s là con số DUY NHẤT ở đây có bằng chứng đo được: trên 7 video hít đất
  /// thật, nhịp trung vị là 1.0–1.6 s, và 0.7 s là mức chặn được nhịp ma do pose
  /// giật mà không cắt rep nhanh có thật (xem ADR 0002).
  final double minRepSeconds;

  /// Rep chậm hơn mức này bị gắn cờ `tooSlow`.
  final double maxRepSeconds;

  /// Chênh lệch góc hai tay tại đáy vượt mức này -> `leftRightUneven`.
  final double leftRightUnevenDeg;

  /// Độ tin cậy pose trung bình dưới mức này -> `poseUnreliable`.
  final double poseUnreliableConfidence;

  /// Độ lệch trục thân coi là mất căn chỉnh.
  final double torsoDeviationDeg;

  /// Phải lệch quá tỉ lệ này của chu kỳ mới gắn cờ `bodyAlignmentLost`,
  /// để một cú giật nhất thời không bị tính.
  final double torsoDeviationFraction;

  /// Biên độ dưới tỉ lệ này so với biên độ tham chiếu -> `shallow`.
  ///
  /// Tham chiếu lấy từ calibration của chính người dùng, KHÔNG phải hằng số toàn
  /// cục: 7 video cho thấy tầm vận động chênh nhau rất xa giữa người và giữa góc
  /// máy (ADR 0002).
  final double shallowAmplitudeRatio;

  /// Góc đỉnh dưới tỉ lệ này so với đỉnh tham chiếu -> `incompleteLockout`.
  final double lockoutRatio;

  QualityThresholds copyWith({
    double? minRepSeconds,
    double? maxRepSeconds,
    double? leftRightUnevenDeg,
    double? poseUnreliableConfidence,
    double? torsoDeviationDeg,
    double? torsoDeviationFraction,
    double? shallowAmplitudeRatio,
    double? lockoutRatio,
  }) =>
      QualityThresholds(
        minRepSeconds: minRepSeconds ?? this.minRepSeconds,
        maxRepSeconds: maxRepSeconds ?? this.maxRepSeconds,
        leftRightUnevenDeg: leftRightUnevenDeg ?? this.leftRightUnevenDeg,
        poseUnreliableConfidence:
            poseUnreliableConfidence ?? this.poseUnreliableConfidence,
        torsoDeviationDeg: torsoDeviationDeg ?? this.torsoDeviationDeg,
        torsoDeviationFraction:
            torsoDeviationFraction ?? this.torsoDeviationFraction,
        shallowAmplitudeRatio: shallowAmplitudeRatio ?? this.shallowAmplitudeRatio,
        lockoutRatio: lockoutRatio ?? this.lockoutRatio,
      );
}

/// Mốc tham chiếu của riêng người dùng, lấy từ calibration hoặc từ chính buổi tập.
///
/// Không có nó thì `shallow` và `incompleteLockout` vô nghĩa: không thể nói một rep
/// là "nông" nếu chưa biết tầm vận động bình thường của người đó là bao nhiêu.
class CalibrationSnapshot {
  const CalibrationSnapshot({
    required this.repHi,
    required this.repLo,
    required this.minAmplitude,
    this.referenceAmplitude,
    this.referenceTopAngle,
    this.source = CalibrationSource.defaults,
  });

  final double repHi;
  final double repLo;
  final double minAmplitude;

  /// Biên độ điển hình của người này (độ). Null nghĩa là chưa biết.
  final double? referenceAmplitude;

  /// Góc đỉnh điển hình (độ). Null nghĩa là chưa biết.
  final double? referenceTopAngle;

  final CalibrationSource source;

  bool get hasReference => referenceAmplitude != null && referenceAmplitude! > 0;

  Map<String, dynamic> toJson() => {
        'rep_hi': repHi,
        'rep_lo': repLo,
        'min_amplitude': minAmplitude,
        'reference_amplitude': referenceAmplitude,
        'reference_top_angle': referenceTopAngle,
        'source': source.name,
      };

  static CalibrationSnapshot fromJson(Map<String, dynamic> j) => CalibrationSnapshot(
        repHi: (j['rep_hi'] as num).toDouble(),
        repLo: (j['rep_lo'] as num).toDouble(),
        minAmplitude: (j['min_amplitude'] as num).toDouble(),
        referenceAmplitude: (j['reference_amplitude'] as num?)?.toDouble(),
        referenceTopAngle: (j['reference_top_angle'] as num?)?.toDouble(),
        source: CalibrationSource.values.firstWhere(
          (e) => e.name == j['source'],
          orElse: () => CalibrationSource.defaults,
        ),
      );
}

enum CalibrationSource {
  /// Ngưỡng mặc định trong profile — chưa hiệu chỉnh cho người dùng này.
  defaults,

  /// Người dùng đã chạy luồng hiệu chỉnh.
  userCalibration,

  /// Suy ra từ chính buổi tập đang chạy.
  sessionDerived,
}
