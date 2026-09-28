/// Icon riêng cho từng bài: hình người que cùng kiểu khung xương trong app.
///
/// Bộ icon Material không có hít đất hay kéo xà (`sports_gymnastics` là người
/// đá chân), nên vẽ tay. Hít đất nhìn NGHIÊNG cho dễ nhận ra, dù app quay
/// trực diện — icon cần gợi đúng bài, còn cách đặt máy đã có màn hướng dẫn.
library;

import 'package:flutter/material.dart';

class ExerciseIcon extends StatelessWidget {
  const ExerciseIcon(
      {super.key,
      required this.exerciseId,
      required this.color,
      this.size = 36});

  final String exerciseId;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final glyph = _glyphs[exerciseId];
    if (glyph == null) {
      return Icon(Icons.sports_gymnastics_rounded, color: color, size: size);
    }
    return CustomPaint(
      size: Size.square(size),
      painter: _GlyphPainter(glyph, color),
    );
  }
}

class _Glyph {
  const _Glyph({required this.lines, required this.head, this.ground});

  /// Các đoạn thẳng, toạ độ trong ô vuông 0..1.
  final List<(Offset, Offset)> lines;
  final (Offset, double) head;

  /// Sàn hoặc xà — vẽ mảnh và mờ hơn thân người.
  final (Offset, Offset)? ground;
}

const _glyphs = <String, _Glyph>{
  // Chống tay nhìn nghiêng: vai → hông → gối → mũi chân thẳng một đường.
  'push_up': _Glyph(
    ground: (Offset(0.06, 0.80), Offset(0.94, 0.80)),
    head: (Offset(0.17, 0.41), 0.075),
    lines: [
      (Offset(0.28, 0.47), Offset(0.60, 0.62)),
      (Offset(0.60, 0.62), Offset(0.75, 0.69)),
      (Offset(0.75, 0.69), Offset(0.90, 0.76)),
      (Offset(0.28, 0.47), Offset(0.30, 0.62)),
      (Offset(0.30, 0.62), Offset(0.28, 0.77)),
    ],
  ),
  // Treo xà nhìn trực diện, giống mẫu khung xương trên màn hình tập.
  'pull_up': _Glyph(
    ground: (Offset(0.10, 0.12), Offset(0.90, 0.12)),
    head: (Offset(0.50, 0.32), 0.075),
    lines: [
      (Offset(0.33, 0.13), Offset(0.30, 0.29)),
      (Offset(0.30, 0.29), Offset(0.40, 0.43)),
      (Offset(0.67, 0.13), Offset(0.70, 0.29)),
      (Offset(0.70, 0.29), Offset(0.60, 0.43)),
      (Offset(0.40, 0.43), Offset(0.60, 0.43)),
      (Offset(0.40, 0.43), Offset(0.44, 0.66)),
      (Offset(0.60, 0.43), Offset(0.56, 0.66)),
      (Offset(0.44, 0.66), Offset(0.56, 0.66)),
      (Offset(0.44, 0.66), Offset(0.45, 0.90)),
      (Offset(0.56, 0.66), Offset(0.55, 0.90)),
    ],
  ),
};

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.glyph, this.color);

  final _Glyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    Offset p(Offset o) => Offset(o.dx * s, o.dy * s);
    final body = Paint()
      ..color = color
      ..strokeWidth = s * 0.075
      ..strokeCap = StrokeCap.round;
    final g = glyph.ground;
    if (g != null) {
      canvas.drawLine(
          p(g.$1),
          p(g.$2),
          Paint()
            ..color = color.withValues(alpha: 0.55)
            ..strokeWidth = s * 0.05
            ..strokeCap = StrokeCap.round);
    }
    for (final (a, b) in glyph.lines) {
      canvas.drawLine(p(a), p(b), body);
    }
    canvas.drawCircle(p(glyph.head.$1), glyph.head.$2 * s * 1.25,
        body..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.glyph != glyph || old.color != color;
}
