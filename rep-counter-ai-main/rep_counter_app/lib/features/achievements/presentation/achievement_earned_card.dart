import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/product_ui.dart';
import '../achievement.dart';
import '../../../core/i18n/l10n.dart';

class AchievementEarnedCard extends StatelessWidget {
  const AchievementEarnedCard({
    super.key,
    required this.achievement,
  });

  final AchievementId achievement;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      liveRegion: true,
      label: context.tr(
        'Huy hiệu mới: ${_title(context)}. ${_description(context)}',
        'New achievement: ${_title(context)}. ${_description(context)}',
      ),
      child: ExcludeSemantics(
        child: Container(
          key: Key('achievement-${achievement.name}'),
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: p.accent),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: p.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 128,
                height: 128,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 128,
                      height: 128,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: p.accent, width: 2),
                      ),
                    ),
                    Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: p.accent),
                      ),
                    ),
                    Text(
                      '★',
                      textScaler: TextScaler.noScaling,
                      style: AppTypography.metric64.copyWith(
                        color: p.accent,
                        fontSize: 64,
                        height: .95,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.legacyAchievementEarnedNewAchievement,
                textAlign: TextAlign.center,
                style: AppTypography.caption12.copyWith(color: p.accent),
              ),
              const SizedBox(height: 14),
              Text(
                _title(context),
                textAlign: TextAlign.center,
                style: AppTypography.headline28,
              ),
              const SizedBox(height: 10),
              Text(
                _description(context),
                textAlign: TextAlign.center,
                style: AppTypography.body14.copyWith(color: p.text2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _title(BuildContext context) => switch (achievement) {
        AchievementId.firstWorkout =>
          context.l10n.legacyAchievementEarnedFirstWorkout,
        AchievementId.totalReps100 =>
          context.l10n.legacyAchievementEarnedTotalReps,
        AchievementId.streak7 =>
          context.l10n.legacyAchievementEarnedDayStreak,
        AchievementId.firstTimeChallenge =>
          context.l10n.legacyAchievementEarnedFirstTimeChallenge,
        AchievementId.newPersonalRecord =>
          context.l10n.legacyAchievementEarnedNewPersonalRecord,
        AchievementId.workouts10 =>
          context.l10n.legacyAchievementEarnedWorkouts,
      };

  String _description(BuildContext context) => switch (achievement) {
        AchievementId.firstWorkout => context.l10n.legacyAchievementEarnedCompletedFirstWorkout,
        AchievementId.totalReps100 => context.l10n.legacyAchievementEarnedReachedTotalReps,
        AchievementId.streak7 => context.l10n.legacyAchievementEarnedTrainedDaysRow,
        AchievementId.firstTimeChallenge => context.l10n.legacyAchievementEarnedCompletedFirstTimeChallenge,
        AchievementId.newPersonalRecord => context.l10n.legacyAchievementEarnedJustSetNewPersonal,
        AchievementId.workouts10 => context.l10n.legacyAchievementEarnedSavedWorkoutsDevice,
      };
}
