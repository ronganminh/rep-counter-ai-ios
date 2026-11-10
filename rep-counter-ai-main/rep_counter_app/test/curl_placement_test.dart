/// Cuốn tạ: khung canh theo vai, mức "quá gần" và cổng đứng thẳng (L-D39).
///
/// Bối cảnh: video cuốn tạ thật của chủ dự án (IMG_0967, 65 rep) — set 1–2
/// kẹt `partiallyOut` vì cổ tay/tạ ở mép ảnh và người đứng lệch tâm; set 3–4
/// kẹt `tooNear` (vai 42–49%); mọi rep thừa rơi vào lúc nghỉ (ngồi, quỳ).
library;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/exercise.dart';
import 'package:rep_counter_app/placement.dart';

const _view = Size(1080, 1920);

/// Người đứng cuốn tạ, toạ độ chuẩn hoá (x theo bề rộng, y theo chiều cao).
/// [cx] = điểm giữa hai vai, [sw] = bề rộng vai theo cạnh ngắn.
Map<PoseLandmarkType, Offset> _standing(
    {double cx = 0.5, double sw = 0.30, double wristOut = 0.0}) {
  final h = sw / 2;
  return {
    PoseLandmarkType.leftShoulder: Offset(cx + h, 0.22),
    PoseLandmarkType.rightShoulder: Offset(cx - h, 0.22),
    PoseLandmarkType.leftElbow: Offset(cx + h * 1.15, 0.36),
    PoseLandmarkType.rightElbow: Offset(cx - h * 1.15, 0.36),
    // Tạ ở hông: cổ tay ra sát (hoặc quá) mép ảnh.
    PoseLandmarkType.leftWrist: Offset(cx + h * 1.4 + wristOut, 0.48),
    PoseLandmarkType.rightWrist: Offset(cx - h * 1.4 - wristOut, 0.48),
    PoseLandmarkType.leftHip: Offset(cx + h * 0.6, 0.50),
    PoseLandmarkType.rightHip: Offset(cx - h * 0.6, 0.50),
    PoseLandmarkType.leftKnee: Offset(cx + h * 0.6, 0.74),
    PoseLandmarkType.rightKnee: Offset(cx - h * 0.6, 0.74),
  };
}

Landmarks _lm(Map<PoseLandmarkType, Offset> norm,
    {Set<PoseLandmarkType> hidden = const {}}) {
  return Landmarks({
    for (final e in norm.entries)
      e.key: PoseLandmark(
        type: e.key,
        x: e.value.dx * _view.width,
        y: e.value.dy * _view.height,
        z: 0,
        likelihood: hidden.contains(e.key) ? 0.1 : 0.95,
      ),
  });
}

PlacementResult _place(Landmarks lm, {GuideZone? guide}) => evaluatePlacement(
      profile: dumbbellCurl,
      lm: lm,
      viewSize: _view,
      guide: guide ?? guideFor(dumbbellCurl, S.vi),
      strings: S.vi,
    );

bool _gate(Landmarks lm) =>
    dumbbellCurl.countGate!(lm, dumbbellCurl.minLikelihood);

void main() {
  group('khung canh cuốn tạ theo giữa hai vai', () {
    const oldGuide = GuideZone(
      body: Rect.fromLTRB(0.20, 0.10, 0.80, 0.95),
      hands: null,
      label: 'khung dọc cũ',
    );

    test('đứng lệch tâm, tạ ở mép ảnh: khung cũ chặn, khung mới cho qua', () {
      final lm = _lm(_standing(cx: 0.32, sw: 0.36));
      expect(_place(lm, guide: oldGuide).status, PlacementStatus.partiallyOut);
      expect(_place(lm).status, PlacementStatus.ready);
    });

    test('cổ tay/tạ ra ngoài mép ảnh không làm hỏng khung', () {
      final lm = _lm(_standing(sw: 0.45, wristOut: 0.10));
      expect(_place(lm).status, PlacementStatus.ready);
    });

    test('khuỷu ra ngoài ảnh vẫn bị chặn', () {
      final norm = _standing(cx: 0.20, sw: 0.36)
        ..[PoseLandmarkType.rightElbow] = const Offset(-0.04, 0.36)
        ..[PoseLandmarkType.rightShoulder] = const Offset(-0.01, 0.22);
      expect(_place(_lm(norm)).status, PlacementStatus.partiallyOut);
    });

    test('khung đi theo vai và bị cắt ở mép ảnh', () {
      final guide = guideFor(dumbbellCurl, S.vi);
      final zone = guide.zoneFor(_view,
          lm: _lm(_standing(cx: 0.30)), minLikelihood: 0.5)!;
      expect(zone.center.dx, lessThan(_view.width / 2));
      expect(zone.left, 0);
      expect(zone.right, closeTo(0.75 * _view.width, 1));
      // Không thấy vai thì giữ khung giữa ảnh.
      expect(guide.zoneFor(_view), guide.scaled(_view));
    });

    test('chỉ cuốn tạ đổi khung; bài khác giữ nguyên', () {
      expect(guideFor(pushUp, S.vi).body, isNull);
      expect(guideFor(pullUp, S.vi).body, isNull);
      final oh = guideFor(overheadExtension, S.vi);
      expect(oh.body, const Rect.fromLTRB(0.20, 0.10, 0.80, 0.95));
      expect(oh.followShoulders, isFalse);
      expect(oh.zoneLandmarksFor(overheadExtension),
          overheadExtension.requiredLandmarks);
    });
  });

  group('mức "quá gần" của cuốn tạ', () {
    test('vai 42–49% (set 3–4 của video thật) không còn bị tooNear', () {
      for (final sw in [0.43, 0.46, 0.49, 0.54]) {
        expect(_place(_lm(_standing(sw: sw))).status, PlacementStatus.ready,
            reason: 'sw=$sw');
      }
    });

    test('quá 55% vẫn là tooNear', () {
      expect(_place(_lm(_standing(sw: 0.58))).status, PlacementStatus.tooNear);
    });

    test('đứng xa phía sau (vai dưới 25%) là tooFar', () {
      expect(_place(_lm(_standing(sw: 0.20))).status, PlacementStatus.tooFar);
      expect(_place(_lm(_standing(sw: 0.27))).status, PlacementStatus.ready);
    });

    test('bài khác giữ mức cũ', () {
      expect(overheadExtension.shoulderWidthFraction, (min: 0.12, max: 0.42));
      expect(pushUp.shoulderWidthFraction.max, 0.65);
      expect(pullUp.shoulderWidthFraction.max, 0.45);
    });
  });

  group('cổng đứng thẳng của cuốn tạ (chặn rep lúc nghỉ)', () {
    test('đứng thẳng, đủ điểm: mở', () {
      expect(_gate(_lm(_standing())), isTrue);
    });

    test('không thấy gối (khung chỉ tới hông): vẫn mở', () {
      final lm = _lm(_standing(), hidden: {
        PoseLandmarkType.leftKnee,
        PoseLandmarkType.rightKnee,
      });
      expect(_gate(lm), isTrue);
    });

    test('ngồi trên ghế (gối gần ngang hông): đóng', () {
      final norm = _standing()
        ..[PoseLandmarkType.leftKnee] = const Offset(0.62, 0.55)
        ..[PoseLandmarkType.rightKnee] = const Offset(0.40, 0.56);
      expect(_gate(_lm(norm)), isFalse);
    });

    test('thiếu hông: đóng', () {
      expect(
          _gate(_lm(_standing(), hidden: {PoseLandmarkType.leftHip})), isFalse);
    });

    test('thiếu khuỷu: đóng', () {
      expect(_gate(_lm(_standing(), hidden: {PoseLandmarkType.rightElbow})),
          isFalse);
    });

    test('cúi/nghiêng thân quá 25°: đóng', () {
      final norm = _standing()
        ..[PoseLandmarkType.leftHip] = const Offset(0.72, 0.42)
        ..[PoseLandmarkType.rightHip] = const Offset(0.62, 0.42);
      expect(_gate(_lm(norm)), isFalse);
    });

    test('ngồi thì placement không thành ready, nên không qua positioning', () {
      final norm = _standing()
        ..[PoseLandmarkType.leftKnee] = const Offset(0.62, 0.55)
        ..[PoseLandmarkType.rightKnee] = const Offset(0.40, 0.56);
      expect(_place(_lm(norm)).status, PlacementStatus.wrongPose);
    });

    test('chỉ cuốn tạ có cổng này', () {
      expect(overheadExtension.countGate, isNull);
      expect(dumbbellCurl.countGate, isNotNull);
    });
  });
}
