import 'package:flutter/material.dart';
import '../../../core/config/feature_flags.dart';
import '../../../core/i18n/locale_controller.dart';
import '../../../exercise.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/product_ui.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/app_feedback.dart';
import 'exercise_detail_page.dart';
import '../../workout/presentation/exercise_icon.dart';

class ExercisePickerScreen extends StatefulWidget {
  const ExercisePickerScreen({super.key});

  @override
  State<ExercisePickerScreen> createState() => _ExercisePickerScreenState();
}

class _ExercisePickerScreenState extends State<ExercisePickerScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final available = allExercises
        .where((profile) => FeatureFlags.enableAllExercises ||
            FeatureFlags.visibleExerciseIds.contains(profile.id))
        .map((profile) => profile.id)
        .toSet();
    final items = [
      for (final profile in allExercises)
        (profile.id, profile.localizedName(context.s)),
      ('squat', 'Squat'),
      ('situp', context.tr('Gập bụng', 'Sit-up')),
      ('jumping_jack', 'Jumping jack'),
      ('lunge', context.tr('Chùng chân', 'Lunge')),
    ].where((item) => matchesExerciseQuery(item.$2, _query)).toList();
    final l = AppLocalizations.of(context);
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
              child: Column(children: [
              TextField(
                key: const Key('exercise-search'),
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: l.homeSearchExercises,
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 16),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 48),
                  child: StatusHero(
                      icon: Icons.search_off_rounded,
                      title: l.emptySearch(_query.trim())),
                ),
              Wrap(spacing: 12, runSpacing: 12, children: [
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
                          if (profile != null && available.contains(profile.id)) {
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) =>
                                    ExerciseDetailPage(profile: profile)));
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
                                      available.contains(item.$1)
                                          ? context.tr('CÓ SẴN', 'AVAILABLE')
                                          : context.tr(
                                              'SẮP RA MẮT', 'COMING SOON'),
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: available.contains(item.$1)
                                              ? AppColors.success
                                              : AppColors.text3)),
                                  const SizedBox(height: 20),
                                  Center(
                                      child: ExerciseIcon(
                                          exerciseId: item.$1,
                                          color: available.contains(item.$1)
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
                                      available.contains(item.$1)
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
              ]),
              ]));
        }));
  }
}

/// Case-insensitive match that also ignores Vietnamese diacritics, so
/// "hit dat" finds "Hít đất".
bool matchesExerciseQuery(String name, String query) {
  final q = foldVietnamese(query.trim());
  return q.isEmpty || foldVietnamese(name).contains(q);
}

String foldVietnamese(String input) {
  const groups = {
    'a': 'àáạảãâầấậẩẫăằắặẳẵ',
    'e': 'èéẹẻẽêềếệểễ',
    'i': 'ìíịỉĩ',
    'o': 'òóọỏõôồốộổỗơờớợởỡ',
    'u': 'ùúụủũưừứựửữ',
    'y': 'ỳýỵỷỹ',
    'd': 'đ',
  };
  final buffer = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    final base =
        groups.entries.where((e) => e.value.contains(char)).firstOrNull?.key;
    buffer.write(base ?? char);
  }
  return buffer.toString();
}
