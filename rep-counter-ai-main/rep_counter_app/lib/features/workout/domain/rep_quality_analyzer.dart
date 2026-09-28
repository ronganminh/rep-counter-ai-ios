/// Gắn cờ chất lượng cho từng rep. Không quyết định rep có được đếm hay không.
library;

import 'quality_thresholds.dart';
import 'rep_metric.dart';

class RepQualityAnalyzer {
  const RepQualityAnalyzer({this.thresholds = const QualityThresholds()});

  final QualityThresholds thresholds;

  Set<RepQualityFlag> analyze(
    RepObservation o, {
    CalibrationSnapshot? calibration,
  }) {
    final t = thresholds;
    final flags = <RepQualityFlag>{};
    final seconds = o.duration.inMicroseconds / 1e6;

    if (seconds < t.minRepSeconds) flags.add(RepQualityFlag.tooFast);
    if (seconds > t.maxRepSeconds) flags.add(RepQualityFlag.tooSlow);

    // Chỉ kết luận hai bên lệch khi ĐO ĐƯỢC CẢ HAI. Thiếu một tay thì im lặng —
    // báo "hai bên không đều" dựa trên một tay là bịa.
    if (o.hasBothArms && o.leftRightDifference > t.leftRightUnevenDeg) {
      flags.add(RepQualityFlag.leftRightUneven);
    }

    if (o.averagePoseConfidence < t.poseUnreliableConfidence) {
      flags.add(RepQualityFlag.poseUnreliable);
    }

    // Một cú giật nhất thời không phải mất căn chỉnh; phải lệch trong phần đáng
    // kể của chu kỳ.
    if (o.maxTorsoDeviation > t.torsoDeviationDeg &&
        o.torsoDeviationFraction >= t.torsoDeviationFraction) {
      flags.add(RepQualityFlag.bodyAlignmentLost);
    }

    // `shallow` và `incompleteLockout` cần mốc tham chiếu của CHÍNH người dùng.
    // Không có calibration thì bỏ qua, chứ không rơi về hằng số toàn cục —
    // ADR 0002: tầm vận động chênh rất xa giữa người và giữa góc máy.
    if (calibration != null && calibration.hasReference) {
      final refAmp = calibration.referenceAmplitude!;
      if (o.amplitude < refAmp * t.shallowAmplitudeRatio) {
        flags.add(RepQualityFlag.shallow);
      }
      final refTop = calibration.referenceTopAngle;
      if (refTop != null && refTop > 0 && o.topAngle < refTop * t.lockoutRatio) {
        flags.add(RepQualityFlag.incompleteLockout);
      }
    }

    return flags;
  }
}
