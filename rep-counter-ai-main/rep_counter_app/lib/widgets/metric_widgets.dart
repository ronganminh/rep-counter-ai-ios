import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_radius.dart';
import '../theme/app_typography.dart';

/// Stat tile (COMPONENT_REGISTRY #15): caption label, Barlow 30 value with
/// tabular figures, optional sub line. `value == null` shows a skeleton.
///
/// Values must come from real repositories, never from design sample data.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.sub,
    this.valueColor = AppColors.accent,
  });

  final String label;
  final String? value;
  final String? sub;
  final Color valueColor;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        label: [label, value ?? '…', if (sub != null) sub].join(', '),
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label.toUpperCase(),
                  style:
                      AppTypography.caption12.copyWith(color: AppColors.text2)),
              const SizedBox(height: 8),
              if (value == null)
                Container(
                  width: 56,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(AppRadius.r8),
                  ),
                )
              else
                Text(value!,
                    style: AppTypography.stat30.copyWith(color: valueColor)),
              if (sub != null) ...[
                const SizedBox(height: 4),
                Text(sub!,
                    style: AppTypography.body14
                        .copyWith(color: AppColors.text2, fontSize: 12)),
              ],
            ],
          ),
        ),
      );
}

/// Progress meter / challenge card (COMPONENT_REGISTRY #16): 8 px pill track,
/// accent fill, value/target text and an optional pace line. The text is the
/// accessible equivalent of the bar.
class ChallengeMeter extends StatelessWidget {
  const ChallengeMeter({
    super.key,
    required this.title,
    required this.value,
    required this.target,
    required this.valueLabel,
    this.pace,
  }) : assert(target > 0);

  final String title;
  final num value;
  final num target;

  /// Localised "value / target" text, e.g. `227 / 500`.
  final String valueLabel;
  final String? pace;

  double get fraction => (value / target).clamp(0, 1).toDouble();

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      container: true,
      label: [title, valueLabel, if (pace != null) pace].join(', '),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 12,
                children: [
                  Text(title,
                      style:
                          AppTypography.row15.copyWith(color: AppColors.text)),
                  Text(valueLabel,
                      style: AppTypography.row15.copyWith(
                          color: AppColors.accent,
                          fontFeatures: const [FontFeature.tabularFigures()])),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: SizedBox(
                height: 8,
                child: Stack(children: [
                  const Positioned.fill(
                      child: ColoredBox(color: AppColors.surface2)),
                  TweenAnimationBuilder<double>(
                    tween: Tween(end: fraction),
                    duration: reduceMotion ? Duration.zero : AppMotion.progress,
                    curve: AppMotion.progressCurve,
                    builder: (_, f, __) => FractionallySizedBox(
                      widthFactor: f.clamp(0, 1),
                      heightFactor: 1,
                      child: const ColoredBox(color: AppColors.accent),
                    ),
                  ),
                ]),
              ),
            ),
            if (pace != null) ...[
              const SizedBox(height: 8),
              Text(pace!,
                  style: AppTypography.body14.copyWith(color: AppColors.text2)),
            ],
          ],
        ),
      ),
    );
  }
}
