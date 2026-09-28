import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';

class RepCoachWordmark extends StatelessWidget {
  const RepCoachWordmark({super.key});
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(
            width: 28, height: 28, child: CustomPaint(painter: _MarkPainter())),
        const SizedBox(width: 7),
        Flexible(
            child: Text.rich(
                const TextSpan(text: 'REPCOACH ', children: [
                  TextSpan(
                      text: 'AI', style: TextStyle(color: AppColors.accent))
                ]),
                style: AppTypography.display40.copyWith(fontSize: 20),
                maxLines: 1)),
      ]);
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100, size.height / 100);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(0, 0, 100, 100), const Radius.circular(22)),
        Paint()..color = AppColors.surface);
    canvas.drawArc(
        const Rect.fromLTWH(20, 20, 60, 60),
        -math.pi / 2,
        math.pi * 1.67,
        false,
        Paint()
          ..color = AppColors.accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round);
    canvas.drawCircle(
        const Offset(24, 35), 9, Paint()..color = AppColors.accent);
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => false;
}

class PrivacyArt extends StatelessWidget {
  const PrivacyArt({super.key});
  @override
  Widget build(BuildContext context) => Center(
      child: SizedBox.square(
          dimension: 236,
          child: Stack(alignment: Alignment.center, children: [
            for (final size in [236.0, 176.0, 120.0])
              Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: size == 120 ? AppColors.successTint : null,
                      border: Border.all(
                          color: AppColors.success
                              .withValues(alpha: size == 236 ? .10 : .18)))),
            const Icon(LucideIcons.shieldCheck,
                size: 64, color: AppColors.success),
          ])));
}

/// Vector artwork from the supplied HTML; never uses camera frames.
class OnboardingArt extends StatelessWidget {
  const OnboardingArt({super.key, this.side = false});
  final bool side;
  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _PersonPainter(side), size: Size.infinite);
}

class _PersonPainter extends CustomPainter {
  const _PersonPainter(this.side);
  final bool side;
  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / 345, size.height / (side ? 284 : 240));
    canvas.translate((size.width - 345 * scale) / 2,
        (size.height - (side ? 284 : 240) * scale) / 2);
    canvas.scale(scale);
    void line(List<Offset> points, Color color, double width) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final p in points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
          path,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = width
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round);
    }

    void joint(Offset point) {
      canvas.drawCircle(point, 6, Paint()..color = AppColors.bg);
      canvas.drawCircle(point, 4, Paint()..color = AppColors.accent);
    }

    const body = Color(0xFF26262A);
    if (side) {
      final cone = Path()
        ..moveTo(43, 170)
        ..lineTo(345, 82)
        ..lineTo(345, 242)
        ..close();
      canvas.drawPath(cone, Paint()..color = AppColors.accentTintSoft);
      line([const Offset(43, 170), const Offset(345, 82)],
          AppColors.accentBorder, 1);
      line([const Offset(0, 242), const Offset(345, 242)],
          AppColors.borderStrong, 2);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTWH(32, 160, 9, 82), const Radius.circular(3)),
          Paint()
            ..color = AppColors.accent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
      const torso = [Offset(160, 190), Offset(252, 212)];
      const arm = [Offset(160, 190), Offset(150, 216), Offset(160, 242)];
      line(torso, body, 30);
      line([
        const Offset(252, 212),
        const Offset(290, 222),
        const Offset(320, 230),
        const Offset(330, 242)
      ], body, 18);
      line(arm, body, 14);
      canvas.drawCircle(
          const Offset(132, 180), 14, Paint()..color = AppColors.surface3);
      line(torso, AppColors.accent, 2.5);
      line(arm, AppColors.accent, 2.5);
      for (final p in {...torso, ...arm}) {
        joint(p);
      }
      line([const Offset(41, 260), const Offset(132, 260)], AppColors.text3, 1);
    } else {
      line([const Offset(10, 232), const Offset(335, 232)],
          AppColors.borderStrong, 1);
      line([const Offset(152, 92), const Offset(162, 60)], body, 14);
      line([const Offset(193, 92), const Offset(183, 60)], body, 14);
      canvas.drawPath(
          Path()
            ..moveTo(122, 125)
            ..lineTo(223, 125)
            ..lineTo(193, 92)
            ..lineTo(152, 92)
            ..close(),
          Paint()..color = body);
      const left = [Offset(122, 125), Offset(88, 175), Offset(95, 228)];
      const right = [Offset(223, 125), Offset(257, 175), Offset(250, 228)];
      line(left, body, 24);
      line(right, body, 24);
      canvas.drawCircle(
          const Offset(172, 120), 27, Paint()..color = AppColors.surface3);
      line(left, AppColors.accent, 3);
      line(right, AppColors.accent, 3);
      line([
        const Offset(122, 125),
        const Offset(223, 125),
        const Offset(193, 92),
        const Offset(152, 92),
        const Offset(122, 125)
      ], AppColors.accent, 3);
      for (final p in [
        ...left,
        ...right,
        const Offset(152, 92),
        const Offset(193, 92)
      ]) {
        joint(p);
      }
    }
  }

  @override
  bool shouldRepaint(_PersonPainter oldDelegate) => side != oldDelegate.side;
}
