import 'package:flutter/material.dart';
import '../../../core/i18n/locale_controller.dart';
import '../../../exercise.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/product_ui.dart';
import '../../plan/presentation/plan_today_sheet.dart';
import '../../workout/presentation/exercise_icon.dart';

class ExercisePickerScreen extends StatelessWidget {
  const ExercisePickerScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final items = [
      for (final profile in allExercises)
        (profile.id, profile.localizedName(context.s)),
      ('squat', 'Squat'),
      ('situp', context.tr('Gập bụng', 'Sit-up')),
      ('jumping_jack', 'Jumping jack'),
      ('lunge', context.tr('Chùng chân', 'Lunge')),
    ];
    return Scaffold(
        appBar: AppBar(
            title: Text(context.tr('CHỌN BÀI TẬP', 'CHOOSE EXERCISE'),
                style: AppTypography.display40.copyWith(fontSize: 28))),
        body: LayoutBuilder(builder: (context, box) {
          final large = MediaQuery.textScalerOf(context).scale(14) > 20;
          final columns = large ? 1 : 2;
          final width = (box.maxWidth - 32 - (columns - 1) * 12) / columns;
          return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Wrap(spacing: 12, runSpacing: 12, children: [
                for (final item in items)
                  SizedBox(
                      width: width,
                      child: Card(
                          child: InkWell(
                        key: Key('exercise-${item.$1}'),
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          final profile = allExercises
                              .where((p) => p.id == item.$1)
                              .firstOrNull;
                          if (profile != null) {
                            showPlanTodaySheet(context, profile);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(context.tr(
                                    'Bài tập này sắp ra mắt.',
                                    'This exercise is coming soon.'))));
                          }
                        },
                        child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      allExercises.any((p) => p.id == item.$1)
                                          ? context.tr('CÓ SẴN', 'AVAILABLE')
                                          : context.tr(
                                              'SẮP RA MẮT', 'COMING SOON'),
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: allExercises
                                                  .any((p) => p.id == item.$1)
                                              ? AppColors.success
                                              : AppColors.text3)),
                                  const SizedBox(height: 20),
                                  Center(
                                      child: ExerciseIcon(
                                          exerciseId: item.$1,
                                          color: allExercises
                                                  .any((p) => p.id == item.$1)
                                              ? AppColors.accent
                                              : AppColors.text3,
                                          size: 56)),
                                  const SizedBox(height: 20),
                                  Text(item.$2,
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 6),
                                  Text(
                                      allExercises.any((p) => p.id == item.$1)
                                          ? allExercises
                                              .firstWhere(
                                                  (p) => p.id == item.$1)
                                              .localizedHint(context.s)
                                          : context.tr('Đang phát triển',
                                              'In development'),
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.text3)),
                                ])),
                      ))),
              ]));
        }));
  }
}
