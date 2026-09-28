/// Vẽ khung hướng dẫn, khung xương và bảng số lên trên preview camera.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'core/i18n/app_strings.dart';
import 'exercise.dart';
import 'guide_template.dart';
import 'placement.dart';
import 'theme/app_colors.dart';

const _skeleton = <(PoseLandmarkType, PoseLandmarkType)>[
  (PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder),
  (PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow),
  (PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist),
  (PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow),
  (PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist),
  (PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip),
  (PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip),
  (PoseLandmarkType.leftHip, PoseLandmarkType.rightHip),
  (PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee),
  (PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle),
  (PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee),
  (PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle),
];

class PoseOverlayPainter extends CustomPainter {
  PoseOverlayPainter({
    required this.profile,
    required this.guide,
    required this.status,
    required this.landmarks,
    this.trace = const [],
    this.traceRange = (min: 0, max: 1),
    required this.repFlash,
    required this.repHi,
    required this.repLo,
    required this.strings,
    required this.showGuide,
  });

  final ExerciseProfile profile;
  final GuideZone guide;
  final PlacementStatus status;
  final Landmarks? landmarks;

  /// Lịch sử tín hiệu để vẽ đồ thị chạy (giá trị cũ nhất đứng đầu).
  ///
  /// Chỉ trang thử bằng video (bản debug) truyền vào. Màn hình tập bỏ đồ thị:
  /// người tập đọc không hiểu, và ô nền tối của nó ở góc trên bên phải trông
  /// như khung bao quanh nút bên cạnh.
  final List<double> trace;
  final ({double min, double max}) traceRange;

  /// 0..1, vừa đếm được rep thì bằng 1 rồi tắt dần.
  final double repFlash;
  final double repHi;
  final double repLo;
  final S strings;

  /// Còn vẽ hình hướng dẫn không.
  ///
  /// Vào đúng tư thế rồi thì mẫu khung xương chỉ còn làm rối: nó nằm đè lên
  /// đúng chỗ người tập đang ở, và người ta không cần hướng dẫn nữa.
  final bool showGuide;

  @override
  void paint(Canvas canvas, Size size) {
    if (showGuide) _paintGuide(canvas, size);
    _paintSkeleton(canvas, size);
    _paintTrace(canvas, size);
    if (repFlash > 0) _paintFlash(canvas, size);
  }

  void _paintGuide(Canvas canvas, Size size) {
    final rect = guide.scaled(size);
    final color = status.canCount ? AppColors.success : AppColors.text2;

    // Chon hinh ve theo BAI TAP, khong suy ra tu `orientation`.
    //
    // Truoc day: `orientation == horizontal` -> ve mau khung xuong, nguoc lai
    // -> ve hinh chu nhat. Hit dat khai `vertical` (vi truc than trong anh dung
    // dung khi quay truc dien) nen luon roi vao nhanh hinh chu nhat, va mau
    // khung xuong dung tu trung vi 48 khung that thanh MA CHET, chua bao gio
    // hien ra.
    final template = skeletonTemplateFor(profile.id) ??
        (profile.orientation == BodyOrientation.horizontal
            ? pushUpTemplate
            : null);
    if (template != null) {
      paintSkeletonTemplate(canvas, Offset.zero & size, color, template);
    } else if (rect != null) {
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = status.canCount ? 5 : 3
        ..color = color;
      final rr = RRect.fromRectAndRadius(rect, const Radius.circular(28));
      status.canCount
          ? canvas.drawRRect(rr, stroke)
          : _drawDashedRRect(canvas, rr, stroke);
    }

    // Vị trí đặt tay
    for (final h in guide.handsScaled(size)) {
      canvas.drawCircle(h, 18, Paint()..color = color.withValues(alpha: 0.25));
      canvas.drawCircle(
          h,
          18,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = color);
    }

    // Chu huong dan va chu trang thai KHONG ve o day nua.
    //
    // Truoc day ve bang canvas o `rect.top - 26` va `rect.bottom + 10`. Khung
    // huong dan cua bai dung chiem 10%..95% chieu cao, nen hai doan chu do roi
    // dung vao thanh tieu de o tren va the so lieu o duoi — da xac nhan bi de
    // chu tren ca NoxPlayer lan LG V60 that.
    //
    // Gio hai doan do la widget trong `_hud()`, de Flutter dan bo cuc: khong
    // the de nhau nua, va khong phai canh offset theo tung ti le man hinh.
  }

  void _paintSkeleton(Canvas canvas, Size size) {
    final lm = landmarks;
    if (lm == null) return;
    final ml = profile.minLikelihood;
    final line = Paint()
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = status.canCount ? AppColors.accent : AppColors.warning;

    for (final (a, b) in _skeleton) {
      final pa = lm.pt(a, minLikelihood: ml), pb = lm.pt(b, minLikelihood: ml);
      if (pa != null && pb != null) canvas.drawLine(pa, pb, line);
    }
    for (final t in profile.requiredLandmarks) {
      final p = lm.pt(t, minLikelihood: ml);
      if (p != null) canvas.drawCircle(p, 6, Paint()..color = status.canCount ? AppColors.accent : AppColors.warning);
    }
  }

  void _paintTrace(Canvas canvas, Size size) {
    if (trace.length < 2) return;
    final box = Rect.fromLTWH(size.width - 190, 16, 174, 84);
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(10)),
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );

    double toY(double v) {
      final t = ((v - traceRange.min) / (traceRange.max - traceRange.min))
          .clamp(0.0, 1.0);
      return box.bottom - t * box.height;
    }

    for (final (lvl, col) in [
      (repHi, Colors.redAccent),
      (repLo, Colors.lightBlueAccent)
    ]) {
      final y = toY(lvl);
      canvas.drawLine(
          Offset(box.left, y),
          Offset(box.right, y),
          Paint()
            ..color = col.withValues(alpha: 0.8)
            ..strokeWidth = 1);
    }

    final path = Path();
    var started = false;
    for (var i = 0; i < trace.length; i++) {
      final v = trace[i];
      if (v.isNaN) {
        started = false;
        continue;
      }
      final x = box.left + box.width * i / (trace.length - 1);
      final p = Offset(x, toY(v));
      started ? path.lineTo(p.dx, p.dy) : path.moveTo(p.dx, p.dy);
      started = true;
    }
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFF00DCFF));
  }

  void _paintFlash(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14 * repFlash
        ..color = AppColors.accent.withValues(alpha: repFlash),
    );
  }

  void _drawDashedRRect(Canvas canvas, RRect rr, Paint p) {
    final path = Path()..addRRect(rr);
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final next = math.min(d + 14, metric.length);
        canvas.drawPath(metric.extractPath(d, next), p);
        d = next + 10;
      }
    }
  }

  @override
  bool shouldRepaint(covariant PoseOverlayPainter old) =>
      old.showGuide != showGuide ||
      old.status != status ||
      old.landmarks != landmarks ||
      old.repFlash != repFlash ||
      !identical(old.trace, trace);
}
