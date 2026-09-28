import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/i18n/locale_controller.dart';
import '../../../../exercise.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/product_ui.dart';
import '../../data/workout_record.dart';
import 'workout_hud.dart';

class ResultHero extends StatelessWidget {
  const ResultHero({super.key, required this.record});
  final WorkoutRecord record;
  @override
  Widget build(BuildContext context) {
    final r = record, s = context.s;
    final goal =
        r.targetReps != null && r.targetReps! > 0 ? r.targetReps : null;
    final reached = goal != null && r.reps >= goal;
    final progress = goal == null ? 1.0 : (r.reps / goal).clamp(0.0, 1.0);
    final extra = reached ? r.reps - goal : 0;
    final status = goal == null
        ? context.tr('Tập tự do', 'Free workout')
        : reached
            ? '${context.tr('Đạt mục tiêu', 'Goal reached')}${extra > 0 ? ' +$extra' : ''}'
            : '${r.reps}/$goal · ${(progress * 100).round()}%';
    final name = allExercises
            .where((e) => e.id == r.exerciseId)
            .firstOrNull
            ?.localizedName(s) ??
        r.exerciseName;
    return Column(children: [
      Semantics(
          label:
              context.tr('${r.reps} rep. $status', '${r.reps} reps. $status'),
          child: ExcludeSemantics(
              child: SizedBox.square(
                  dimension: 232,
                  child: Stack(alignment: Alignment.center, children: [
                    Positioned.fill(
                        child: CircularProgressIndicator(
                            key: const Key('result-goal-ring'),
                            value: progress,
                            strokeWidth: 16,
                            strokeCap: StrokeCap.round,
                            color: reached && extra == 0
                                ? AppColors.success
                                : AppColors.accent,
                            backgroundColor: AppColors.surface2)),
                    if (extra > 0)
                      Positioned.fill(
                          child: CircularProgressIndicator(
                              key: const Key('result-extra-ring'),
                              value: (extra / goal!).clamp(0.0, 1.0),
                              strokeWidth: 16,
                              strokeCap: StrokeCap.round,
                              color: AppColors.success,
                              backgroundColor: Colors.transparent)),
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('${r.reps}',
                                  textScaler: TextScaler.noScaling,
                                  style: AppTypography.hero
                                      .copyWith(fontSize: 112))),
                          const SizedBox(height: 8),
                          FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                  goal == null ? s.repsShort : '/ $goal',
                                  style: AppTypography.display40.copyWith(
                                      fontSize: 32, color: AppColors.text3))),
                        ])),
                  ])))),
      const SizedBox(height: 24),
      Container(
          key: const Key('result-goal-status'),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
              color: reached ? AppColors.successTint : AppColors.accentTint,
              borderRadius: BorderRadius.circular(30)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
                goal == null
                    ? LucideIcons.infinity
                    : reached
                        ? LucideIcons.circleCheck
                        : LucideIcons.trendingUp,
                size: 18,
                color: reached ? AppColors.success : AppColors.accent),
            const SizedBox(width: 8),
            Flexible(
                child: Text(status,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: reached ? AppColors.success : AppColors.accent,
                        fontWeight: FontWeight.w600))),
          ])),
      if (goal != null && !reached) ...[
        const SizedBox(height: 16),
        Text(
            context.tr(
                'Đã hoàn thành ${(progress * 100).round()}% — mỗi rep đều có giá trị',
                '${(progress * 100).round()}% complete — every rep counts'),
            textAlign: TextAlign.center,
            style: AppTypography.title20),
      ],
      const SizedBox(height: 16),
      Text(
          '$name · ${r.sets} ${context.tr('set', r.sets == 1 ? 'set' : 'sets')} · ${workoutTime(Duration(seconds: r.durationSeconds))}',
          key: const Key('result-workout-summary'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.text2)),
      const SizedBox(height: 6),
      Text(
          '${r.startedAt.day}/${r.startedAt.month}/${r.startedAt.year} · ${r.startedAt.hour.toString().padLeft(2, '0')}:${r.startedAt.minute.toString().padLeft(2, '0')}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.text3, fontSize: 12)),
    ]);
  }
}
