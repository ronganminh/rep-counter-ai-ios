/// Chặn hồi quy cho lỗi khiến app KHÔNG đếm được rep nào.
///
/// Bài hít đất từng dùng khung hướng dẫn dọc `Rect(0.20, 0.10, 0.80, 0.95)`.
/// `evaluatePlacement` loại khi quá 35% điểm nằm ngoài khung, và `canCount`
/// chỉ đúng khi trạng thái là `ready` — nên trạng thái mãi `partiallyOut` làm
/// bộ đếm không bao giờ nhận được tín hiệu.
///
/// Toạ độ trong test là **trung vị thật** của 48 khung chống tay lấy từ
/// `push_up/100pushup.mp4`, cùng bộ số dùng để vẽ mẫu khung xương trong
/// `overlay_painter.dart`. Đo lại trên 4 video (1031 khung) cho thấy tay vươn
/// tới x = -0,05 và 1,17, tức ra ngoài cả khung hình.
library;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/exercise.dart';
import 'package:rep_counter_app/placement.dart';
import 'package:rep_counter_app/rep_counter.dart';

const _viewSize = Size(1080, 2460);

/// Trung vị thật của một khung chống tay, toạ độ chuẩn hoá 0..1.
const _pushUpMedians = <PoseLandmarkType, Offset>{
  PoseLandmarkType.leftShoulder: Offset(0.77112, 0.40498),
  PoseLandmarkType.rightShoulder: Offset(0.27436, 0.41471),
  PoseLandmarkType.leftElbow: Offset(0.91520, 0.58396),
  PoseLandmarkType.rightElbow: Offset(0.12559, 0.58592),
  PoseLandmarkType.leftWrist: Offset(0.96340, 0.76544),
  PoseLandmarkType.rightWrist: Offset(0.10038, 0.76021),
  PoseLandmarkType.leftHip: Offset(0.61316, 0.57350),
  PoseLandmarkType.rightHip: Offset(0.42633, 0.57535),
  PoseLandmarkType.leftKnee: Offset(0.58223, 0.64404),
  PoseLandmarkType.rightKnee: Offset(0.45865, 0.64853),
};

Map<PoseLandmarkType, PoseLandmark> _landmarkMapFromMedians() {
  final out = <PoseLandmarkType, PoseLandmark>{};
  _pushUpMedians.forEach((type, norm) {
    out[type] = PoseLandmark(
      type: type,
      x: norm.dx * _viewSize.width,
      y: norm.dy * _viewSize.height,
      z: 0,
      likelihood: 0.95,
    );
  });
  return out;
}

Landmarks _landmarksFromMedians() => Landmarks(_landmarkMapFromMedians());

/// Tư thế nghỉ từng gây rep ma trong video hồi quy: thân vẫn thẳng theo ảnh,
/// nhưng hai tay đang giữ điện thoại sát người thay vì chống xuống sàn.
Landmarks _seatedHoldingPhone({double wristY = 1250}) {
  PoseLandmark point(PoseLandmarkType type, double x, double y) =>
      PoseLandmark(type: type, x: x, y: y, z: 0, likelihood: 0.95);

  return Landmarks({
    PoseLandmarkType.leftShoulder:
        point(PoseLandmarkType.leftShoulder, 700, 800),
    PoseLandmarkType.rightShoulder:
        point(PoseLandmarkType.rightShoulder, 380, 800),
    PoseLandmarkType.leftElbow: point(PoseLandmarkType.leftElbow, 650, 1080),
    PoseLandmarkType.rightElbow: point(PoseLandmarkType.rightElbow, 430, 1080),
    // Một tay chống sàn và một tay cầm điện thoại có thể làm hai cổ tay mở
    // đủ rộng; hai gối xếp bằng vẫn rộng hơn và phải đóng cổng.
    PoseLandmarkType.leftWrist: point(PoseLandmarkType.leftWrist, 668, wristY),
    PoseLandmarkType.rightWrist:
        point(PoseLandmarkType.rightWrist, 412, wristY),
    PoseLandmarkType.leftHip: point(PoseLandmarkType.leftHip, 620, 1250),
    PoseLandmarkType.rightHip: point(PoseLandmarkType.rightHip, 460, 1250),
    PoseLandmarkType.leftKnee: point(PoseLandmarkType.leftKnee, 780, 1650),
    PoseLandmarkType.rightKnee: point(PoseLandmarkType.rightKnee, 300, 1650),
  });
}

void main() {
  test('hít đất không được có khung chữ nhật bắt người lọt vào', () {
    final guide = guideFor(pushUp, S.vi);
    expect(
      guide.body,
      isNull,
      reason: 'Đặt lại khung cho hít đất là làm app không đếm được rep nào: '
          'cổ tay và khuỷu tay nằm ngoài mọi hình chữ nhật vẽ được.',
    );
    expect(guide.scaled(_viewSize), isNull);
  });

  test('tư thế chống tay thật phải được chấm là ĐẠT', () {
    final result = evaluatePlacement(
      profile: pushUp,
      lm: _landmarksFromMedians(),
      viewSize: _viewSize,
      guide: guideFor(pushUp, S.vi),
      strings: S.vi,
    );
    expect(
      result.status,
      PlacementStatus.ready,
      reason: 'Không ĐẠT thì canCount mãi false và bộ đếm không nhận tín hiệu. '
          'Chi tiết trả về: "${result.detail}"',
    );
    expect(result.status.canCount, isTrue);
  });

  test('ngồi nghỉ cầm điện thoại không được mở bộ đếm hít đất', () {
    final landmarks = _seatedHoldingPhone();
    final gate = pushUp.countGate;
    expect(gate, isNotNull);
    expect(gate!(landmarks, pushUp.minLikelihood), isFalse);

    final result = evaluatePlacement(
      profile: pushUp,
      lm: landmarks,
      viewSize: _viewSize,
      guide: guideFor(pushUp, S.vi),
      strings: S.vi,
    );
    expect(result.status, PlacementStatus.wrongPose);
    expect(result.detail, S.vi.pushUpSetupHint);
  });

  test('không bắt buộc thấy gối khi đang chống đẩy', () {
    final withoutKnees = Landmarks(_landmarkMapFromMedians()
      ..remove(PoseLandmarkType.leftKnee)
      ..remove(PoseLandmarkType.rightKnee));

    expect(
      pushUp.countGate!(withoutKnees, pushUp.minLikelihood),
      isTrue,
      reason: 'Mất điểm gối thoáng qua không được hủy chu kỳ rep.',
    );
  });

  test('gối mở rộng xác nhận tư thế ngồi dù hai tay đặt thấp', () {
    final handsLowerThanHips = _seatedHoldingPhone(wristY: 1320);

    expect(
      pushUp.countGate!(handsLowerThanHips, pushUp.minLikelihood),
      isFalse,
      reason: 'Hai gối xếp bằng vẫn phải chặn chuyển động tay khi ngồi.',
    );
  });

  test('cổng hít đất chịu được pose chập chờn nhưng đóng khi nghỉ lâu', () {
    final latch = CountGateLatch(pushUp.countGateGrace);

    expect(latch.update(false, Duration.zero), CountGateState.closed);
    expect(latch.update(true, const Duration(seconds: 1)), CountGateState.open);
    expect(latch.update(false, const Duration(milliseconds: 2800)),
        CountGateState.holding,
        reason: 'Một đoạn mất landmark ngắn không được hủy rep đang dở.');
    expect(latch.update(false, const Duration(milliseconds: 3001)),
        CountGateState.closed,
        reason: 'Quá thời gian ân hạn thì tư thế nghỉ phải đóng cổng.');

    latch.reset();
    expect(
        latch.update(false, const Duration(seconds: 4)), CountGateState.closed);
  });

  test('chu kỳ khuỷu tay khi ngồi vẫn phải là 0 rep', () {
    final landmarks = _seatedHoldingPhone();
    final angles = <double>[165, 130, 90, 75, 110, 150, 165];

    RepCounter counter() => RepCounter(
          hi: pushUp.repHi,
          lo: pushUp.repLo,
          minAmplitude: pushUp.minAmplitude,
          minPeriod: pushUp.minPeriod,
        );

    final withoutPostureGate = counter();
    final productionPath = counter();
    for (var i = 0; i < angles.length; i++) {
      final at = Duration(milliseconds: i * 200);
      withoutPostureGate.update(angles[i], at);
      if (pushUp.countGate!(landmarks, pushUp.minLikelihood)) {
        productionPath.update(angles[i], at);
      } else {
        productionPath.onSignalLost();
      }
    }

    expect(withoutPostureGate.count, 1,
        reason: 'Chu kỳ này chứng minh riêng góc khuỷu sẽ sinh rep ma.');
    expect(productionPath.count, 0,
        reason: 'Luồng production phải chặn chu kỳ khi không chống tay.');
  });

  test('khung dọc cũ chặn đúng tư thế đó — bằng chứng lỗi cũ là thật', () {
    // Dựng lại nguyên khung cũ để chứng minh vì sao phải bỏ nó, chứ không phải
    // vì "trông không đẹp".
    const oldGuide = GuideZone(
      body: Rect.fromLTRB(0.20, 0.10, 0.80, 0.95),
      hands: null,
      label: 'khung dọc cũ',
    );
    final result = evaluatePlacement(
      profile: pushUp,
      lm: _landmarksFromMedians(),
      viewSize: _viewSize,
      guide: oldGuide,
      strings: S.vi,
    );
    expect(result.status, PlacementStatus.partiallyOut);
    expect(result.status.canCount, isFalse);
  });

  test('bài đứng vẫn giữ khung dọc', () {
    for (final p in [dumbbellCurl, overheadExtension]) {
      expect(guideFor(p, S.vi).body, isNotNull,
          reason: '${p.id} là bài đứng, khung dọc vẫn hợp lý');
    }
  });
}
