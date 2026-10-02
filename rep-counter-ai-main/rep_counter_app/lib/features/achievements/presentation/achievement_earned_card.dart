import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/product_ui.dart';
import '../achievement.dart';

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
                context.tr('HUY HIỆU MỚI', 'NEW ACHIEVEMENT'),
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
          context.tr('Buổi tập đầu tiên', 'First Workout'),
        AchievementId.totalReps100 =>
          context.tr('100 rep tổng', '100 Total Reps'),
        AchievementId.streak7 =>
          context.tr('Streak 7 ngày', '7-Day Streak'),
        AchievementId.firstTimeChallenge =>
          context.tr('Thử thách đầu tiên', 'First Time Challenge'),
        AchievementId.newPersonalRecord =>
          context.tr('Kỷ lục cá nhân mới', 'New Personal Record'),
        AchievementId.workouts10 =>
          context.tr('10 buổi tập', '10 Workouts'),
      };

  String _description(BuildContext context) => switch (achievement) {
        AchievementId.firstWorkout => context.tr(
            'Bạn đã hoàn thành buổi tập đầu tiên.',
            'You completed your first workout.',
          ),
        AchievementId.totalReps100 => context.tr(
            'Bạn đã đạt tổng cộng 100 rep.',
            'You reached 100 total reps.',
          ),
        AchievementId.streak7 => context.tr(
            'Bạn đã tập 7 ngày liên tiếp.',
            'You trained for 7 days in a row.',
          ),
        AchievementId.firstTimeChallenge => context.tr(
            'Bạn đã hoàn thành trải nghiệm Time Challenge đầu tiên.',
            'You completed your first Time Challenge experience.',
          ),
        AchievementId.newPersonalRecord => context.tr(
            'Bạn vừa thiết lập một kỷ lục cá nhân mới.',
            'You just set a new personal record.',
          ),
        AchievementId.workouts10 => context.tr(
            'Bạn đã lưu 10 buổi tập trên thiết bị này.',
            'You saved 10 workouts on this device.',
          ),
      };
}
