/// Mẫu khung xương "đặt người vào đây" cho từng bài.
///
/// Toạ độ là trung vị pose THẬT (MediaPipe, chuẩn hoá 0..1 theo khung hình),
/// không phải điểm vẽ tay — nên mẫu chỉ đúng chỗ người tập sẽ đứng/chống tay
/// khi đặt máy như hướng dẫn. Dùng chung cho màn hình tập và màn hướng dẫn.
library;

import 'dart:ui';

enum TemplateExtra {
  /// Hai vạch ngang dưới cổ tay — bàn tay úp trên sàn (hít đất).
  palms,

  /// Một vạch ngang ngay trên cổ tay — thanh xà (kéo xà).
  bar,
}

class SkeletonTemplate {
  const SkeletonTemplate({
    required this.points,
    required this.extra,
    this.headScale = 0.151,
  });

  /// head, lShoulder, rShoulder, lElbow, rElbow, lWrist, rWrist, lHip, rHip,
  /// lKnee, rKnee, lAnkle, rAnkle.
  final Map<String, Offset> points;
  final TemplateExtra extra;

  /// Bán kính đầu = [headScale] × bề rộng vai. Hít đất quay trực diện có đầu
  /// gần máy nên to so với vai; người treo xà ở xa thì đầu nhỏ hơn hẳn vai.
  final double headScale;

  /// Khung bao các điểm, chuẩn hoá — để phóng mẫu cho vừa hình minh hoạ.
  Rect get bounds {
    var l = 1.0, t = 1.0, r = 0.0, b = 0.0;
    for (final o in points.values) {
      if (o.dx < l) l = o.dx;
      if (o.dx > r) r = o.dx;
      if (o.dy < t) t = o.dy;
      if (o.dy > b) b = o.dy;
    }
    return Rect.fromLTRB(l, t, r, b);
  }
}

/// Trung vị 48 khung chống tay thật trong push_up/100pushup.mp4.
const pushUpTemplate = SkeletonTemplate(
  extra: TemplateExtra.palms,
  points: {
    'head': Offset(0.49170, 0.41923),
    'lShoulder': Offset(0.77112, 0.40498),
    'rShoulder': Offset(0.27436, 0.41471),
    'lElbow': Offset(0.91520, 0.58396),
    'rElbow': Offset(0.12559, 0.58592),
    'lWrist': Offset(0.96340, 0.76544),
    'rWrist': Offset(0.10038, 0.76021),
    'lHip': Offset(0.61316, 0.57350),
    'rHip': Offset(0.42633, 0.57535),
    'lKnee': Offset(0.58223, 0.64404),
    'rKnee': Offset(0.45865, 0.64853),
    'lAnkle': Offset(0.55556, 0.68868),
    'rAnkle': Offset(0.48766, 0.69727),
  },
);

/// Trung vị 1387 khung treo thẳng tay trong pull_up/IMG_8708.MOV (máy đặt
/// cách xà ~2–3 m), rồi lấy đối xứng qua giữa khung: trung vị thật lệch 2%
/// (máy hơi chếch) làm thanh xà chỉ chạm một tay. Người nhỏ trong khung là
/// ĐÚNG: đặt gần hơn thì tay và xà ra ngoài mép trên, app không đếm được.
const pullUpTemplate = SkeletonTemplate(
  extra: TemplateExtra.bar,
  headScale: 0.38,
  points: {
    'head': Offset(0.5, 0.41330),
    'lShoulder': Offset(0.56614, 0.45287),
    'rShoulder': Offset(0.43386, 0.45287),
    'lElbow': Offset(0.60024, 0.37918),
    'rElbow': Offset(0.39976, 0.37918),
    'lWrist': Offset(0.61960, 0.30229),
    'rWrist': Offset(0.38040, 0.30229),
    'lHip': Offset(0.54153, 0.62475),
    'rHip': Offset(0.45847, 0.62475),
    'lKnee': Offset(0.53612, 0.74879),
    'rKnee': Offset(0.46388, 0.74879),
    'lAnkle': Offset(0.52244, 0.86338),
    'rAnkle': Offset(0.47756, 0.86338),
  },
);

SkeletonTemplate? skeletonTemplateFor(String exerciseId) => switch (exerciseId) {
      'push_up' => pushUpTemplate,
      'pull_up' => pullUpTemplate,
      _ => null,
    };

/// Vẽ [t] với toạ độ chuẩn hoá ánh xạ vào [frame].
///
/// Mặc định đầu bán kính 0.151 × bề rộng vai: đúng bằng tỉ lệ của mẫu hít đất
/// cũ (0.075 × cạnh ngắn, vai rộng 0.497), để mẫu hít đất trông y như trước.
void paintSkeletonTemplate(
    Canvas canvas, Rect frame, Color color, SkeletonTemplate t) {
  Offset p(String k) => Offset(frame.left + frame.width * t.points[k]!.dx,
      frame.top + frame.height * t.points[k]!.dy);

  final glow = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 18
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = color.withValues(alpha: 0.13);
  final limb = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 8
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = color.withValues(alpha: 0.48);
  final joint = Paint()..color = color.withValues(alpha: 0.72);

  final head = p('head');
  final ls = p('lShoulder'), rs = p('rShoulder');
  final neck = Offset((ls.dx + rs.dx) / 2, (ls.dy + rs.dy) / 2);
  final le = p('lElbow'), re = p('rElbow');
  final lw = p('lWrist'), rw = p('rWrist');
  final lh = p('lHip'), rh = p('rHip');
  final lk = p('lKnee'), rk = p('rKnee');
  final la = p('lAnkle'), ra = p('rAnkle');

  // Xà vẽ TRƯỚC để thân người đè lên, giống người đang bám xà thật.
  if (t.extra == TemplateExtra.bar) {
    final y = (lw.dy < rw.dy ? lw.dy : rw.dy) - 10;
    final bar = Paint()
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.55);
    canvas.drawLine(Offset(frame.left + frame.width * 0.12, y),
        Offset(frame.left + frame.width * 0.88, y), bar);
  }

  for (final (a, b) in [
    (neck, ls),
    (neck, rs),
    (ls, rs),
    (ls, le),
    (le, lw),
    (rs, re),
    (re, rw),
    (ls, lh),
    (rs, rh),
    (lh, rh),
    (lh, lk),
    (lk, la),
    (rh, rk),
    (rk, ra),
  ]) {
    canvas.drawLine(a, b, glow);
    canvas.drawLine(a, b, limb);
  }

  final r = t.headScale * (ls - rs).distance;
  canvas.drawCircle(head, r, Paint()..color = color.withValues(alpha: 0.16));
  canvas.drawCircle(
    head,
    r,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..color = color.withValues(alpha: 0.50),
  );
  canvas.drawLine(head, neck, limb);

  for (final pt in [ls, rs, le, re, lw, rw, lh, rh, lk, rk, la, ra]) {
    canvas.drawCircle(pt, 7, joint);
  }

  if (t.extra == TemplateExtra.palms) {
    canvas.drawLine(lw.translate(-18, 7), lw.translate(18, 7), limb);
    canvas.drawLine(rw.translate(-18, 7), rw.translate(18, 7), limb);
  }
}
