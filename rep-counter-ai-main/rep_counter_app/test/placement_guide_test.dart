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
};

Landmarks _landmarksFromMedians() {
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
  return Landmarks(out);
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
