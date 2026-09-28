/// Màn hướng dẫn mở từ nút "?" cạnh tên bài: đặt máy thế nào và app đếm rep ra sao.
library;

import 'package:flutter/material.dart';

import '../../../core/i18n/locale_controller.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../exercise.dart';
import '../../../guide_template.dart';

/// Nút "?" — không hiện gì nếu bài chưa có nội dung hướng dẫn.
class ExerciseHelpButton extends StatelessWidget {
  const ExerciseHelpButton({super.key, required this.profile, this.color});

  final ExerciseProfile profile;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    if (!s.exerciseHelp.containsKey(profile.id)) return const SizedBox.shrink();
    return IconButton(
      tooltip: s.helpTooltip,
      icon: Icon(Icons.help_outline_rounded, color: color ?? AppColors.text2),
      onPressed: () => showExerciseHelp(context, profile),
    );
  }
}

Future<void> showExerciseHelp(BuildContext context, ExerciseProfile profile) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, scroll) =>
          _HelpBody(profile: profile, controller: scroll),
    ),
  );
}

class _HelpBody extends StatelessWidget {
  const _HelpBody({required this.profile, required this.controller});

  final ExerciseProfile profile;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final h = s.exerciseHelp[profile.id]!;
    final template = skeletonTemplateFor(profile.id);
    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
      children: [
        Text(profile.localizedName(s), style: AppTypography.display40),
        const SizedBox(height: 18),
        if (template != null) ...[
          Center(child: _PhoneMock(template: template)),
          const SizedBox(height: 20),
        ],
        _Heading(s.helpPlacement),
        for (final line in h.placement) _Bullet(line),
        const SizedBox(height: 18),
        _Heading(s.helpWatch),
        _Para(h.watchIntro),
        const SizedBox(height: 10),
        for (final (pose, look) in h.poses) _PoseRow(pose: pose, look: look),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.accent.withValues(alpha: .4)),
          ),
          child: Text(h.oneRep,
              style:
                  const TextStyle(height: 1.45, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 18),
        _Heading(s.helpNotCounted),
        for (final line in h.notCounted) _Bullet(line),
      ],
    );
  }
}

/// Khung điện thoại với mẫu khung xương đúng chỗ nó hiện trên màn hình tập.
///
/// Giữ nguyên toạ độ thật thay vì phóng mẫu cho to: với kéo xà, người NHỎ giữa
/// màn hình chính là điều cần truyền đạt — đặt máy gần hơn là tay ra khỏi khung.
class _PhoneMock extends StatelessWidget {
  const _PhoneMock({required this.template});

  final SkeletonTemplate template;

  @override
  Widget build(BuildContext context) => Container(
        width: 150,
        height: 290,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.borderStrong, width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: CustomPaint(
            painter: _TemplatePainter(template),
            child: const SizedBox.expand(),
          ),
        ),
      );
}

class _TemplatePainter extends CustomPainter {
  _TemplatePainter(this.template);

  final SkeletonTemplate template;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.surface);
    // Nét vẽ của mẫu tính cho màn hình cỡ thật; hình ở đây nhỏ ~1/3 nên vẽ ở
    // cỡ thật rồi thu lại, để độ dày nét giữ đúng tỉ lệ.
    const scale = 1 / 3;
    canvas.save();
    canvas.scale(scale);
    paintSkeletonTemplate(
        canvas, Offset.zero & (size / scale), AppColors.accent, template);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TemplatePainter old) => old.template != template;
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text.toUpperCase(),
            style: const TextStyle(
                color: AppColors.text3,
                fontSize: 12,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w800)),
      );
}

class _Para extends StatelessWidget {
  const _Para(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(height: 1.45, color: AppColors.text2));
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.only(top: 7, right: 10),
            child: Icon(Icons.circle, size: 6, color: AppColors.accent),
          ),
          Expanded(
              child: Text(text,
                  style:
                      const TextStyle(height: 1.45, color: AppColors.text2))),
        ]),
      );
}

class _PoseRow extends StatelessWidget {
  const _PoseRow({required this.pose, required this.look});
  final String pose;
  final String look;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(pose, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(look,
              style: const TextStyle(height: 1.4, color: AppColors.text2)),
        ]),
      );
}
