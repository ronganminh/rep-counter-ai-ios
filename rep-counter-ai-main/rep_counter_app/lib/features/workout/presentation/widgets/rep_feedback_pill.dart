import 'package:flutter/material.dart';

import '../../../../core/i18n/locale_controller.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_typography.dart';
import '../../application/rep_feedback.dart';
import '../../domain/rep_metric.dart';

class RepFeedbackPill extends StatelessWidget {
  const RepFeedbackPill({
    super.key,
    required this.feedback,
  });

  final RepFeedback feedback;

  @override
  Widget build(BuildContext context) {
    final copy = _copy(context, feedback);
    final clean = feedback.kind == RepFeedbackKind.countedClean;
    final tone = clean ? AppColors.success : AppColors.warning;

    return Semantics(
      container: true,
      liveRegion: true,
      label: copy.status + '. ' + copy.message,
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 305,
            minHeight: 82,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: tone),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.surface2,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      clean
                          ? Icons.check_rounded
                          : Icons.priority_high_rounded,
                      color: tone,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          copy.status,
                          style: AppTypography.caption12.copyWith(color: tone),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          copy.message,
                          style: AppTypography.body16
                              .copyWith(color: AppColors.text),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RepFeedbackTransition extends StatelessWidget {
  const RepFeedbackTransition({
    super.key,
    required this.feedback,
  });

  final RepFeedback? feedback;

  @override
  Widget build(BuildContext context) {
    final reducedMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final valueKey = feedback == null
        ? const ValueKey<String>('rep-feedback-empty')
        : ValueKey<String>(
            feedback!.kind.name +
                ':' +
                (feedback!.repNumber?.toString() ?? '') +
                ':' +
                (feedback!.primaryFlag?.name ?? ''),
          );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      reverseDuration: const Duration(milliseconds: 140),
      transitionBuilder: (child, animation) {
        final fade = FadeTransition(opacity: animation, child: child);
        if (reducedMotion) return fade;
        return ScaleTransition(
          scale: Tween<double>(begin: .97, end: 1).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: fade,
        );
      },
      child: feedback == null
          ? SizedBox.shrink(key: valueKey)
          : RepFeedbackPill(key: valueKey, feedback: feedback!),
    );
  }
}

class _FeedbackCopy {
  const _FeedbackCopy(this.status, this.message);
  final String status;
  final String message;
}

_FeedbackCopy _copy(BuildContext context, RepFeedback feedback) {
  switch (feedback.kind) {
    case RepFeedbackKind.countedClean:
      return _FeedbackCopy(
        context.tr('ĐÃ TÍNH', 'COUNTED'),
        context.tr('Rep tốt', 'Good rep'),
      );
    case RepFeedbackKind.countedWarning:
      return _FeedbackCopy(
        context.tr('ĐÃ TÍNH', 'COUNTED'),
        _warningMessage(context, feedback.primaryFlag),
      );
    case RepFeedbackKind.placementInterrupted:
      return _FeedbackCopy(
        context.tr(
          'CHUYỂN ĐỘNG BỊ GIÁN ĐOẠN',
          'ATTEMPT INTERRUPTED',
        ),
        context.tr(
          'Quay lại vùng camera',
          'Move back into the camera zone',
        ),
      );
    case RepFeedbackKind.poseLost:
      return _FeedbackCopy(
        context.tr('MẤT NHẬN DIỆN TƯ THẾ', 'POSE LOST'),
        context.tr(
          'Giữ phần thân trên trong khung hình',
          'Keep your upper body visible',
        ),
      );
  }
}

String _warningMessage(BuildContext context, RepQualityFlag? flag) {
  return switch (flag) {
    RepQualityFlag.shallow =>
      context.tr('Xuống sâu hơn một chút', 'Try a deeper range'),
    RepQualityFlag.incompleteLockout =>
      context.tr('Duỗi tay đủ ở đỉnh', 'Fully extend at the top'),
    RepQualityFlag.tooFast =>
      context.tr('Chậm lại một chút', 'Slow down slightly'),
    RepQualityFlag.bodyAlignmentLost =>
      context.tr('Giữ thân người ổn định', 'Keep your torso steady'),
    RepQualityFlag.poseUnreliable =>
      context.tr('Giữ người trong khung hình', 'Keep your body in view'),
    RepQualityFlag.leftRightUneven =>
      context.tr('Kiểm tra tư thế ở rep này', 'Check your form on this rep'),
    RepQualityFlag.tooSlow =>
      context.tr('Kiểm tra tư thế ở rep này', 'Check your form on this rep'),
    null => context.tr('Kiểm tra tư thế ở rep này', 'Check your form on this rep'),
  };
}
