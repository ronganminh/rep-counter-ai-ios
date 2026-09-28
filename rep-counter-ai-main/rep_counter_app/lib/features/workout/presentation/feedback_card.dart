/// Thẻ nhận xét ngoại tuyến trên trang kết quả.
///
/// Dịch kết luận của [RuleBasedFeedback] (là enum) sang câu chữ theo ngôn ngữ
/// đang chọn. Domain không biết gì về `S`, nên chỗ nối duy nhất là ở đây.
library;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';

import '../../../core/i18n/app_strings.dart';
import '../../../core/i18n/locale_controller.dart';
import '../data/workout_record.dart';
import '../domain/rule_based_feedback.dart';

String feedbackNoteText(FeedbackNote n, S s) => switch (n) {
      FeedbackNote.goalReached => s.fbGoalReached,
      FeedbackNote.steadyCadence => s.fbSteadyCadence,
      FeedbackNote.goodRange => s.fbGoodRange,
      FeedbackNote.balancedSides => s.fbBalancedSides,
      FeedbackNote.goodCameraSetup => s.fbGoodCameraSetup,
      FeedbackNote.poseLostOften => s.fbPoseLostOften,
      FeedbackNote.amplitudeDropped => s.fbAmplitudeDropped,
      FeedbackNote.leftRightUneven => s.fbLeftRightUneven,
      FeedbackNote.repsTooFast => s.fbRepsTooFast,
      FeedbackNote.shortSession => s.fbShortSession,
    };

class FeedbackCard extends StatelessWidget {
  const FeedbackCard({super.key, required this.record, this.embedded = false});

  final WorkoutRecord record;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final f = const RuleBasedFeedback().analyze(record);

    final content = Padding(
      padding: EdgeInsets.all(embedded ? 0 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!embedded)
            Row(children: [
              const Icon(LucideIcons.chartNoAxesCombined,
                  color: AppColors.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(s.fbTitle, style: AppTypography.title20),
              ),
            ]),
          if (!embedded) const SizedBox(height: 4),
          if (!embedded)
            Text(s.fbSourceRules,
                style: const TextStyle(color: AppColors.text3, fontSize: 11)),
          if (!embedded) const SizedBox(height: 14),

          // Không đủ dữ liệu thì nói thẳng, đừng hiện điểm số suy đoán.
          if (!f.hasEnoughData)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(s.fbNotEnoughData,
                  style: const TextStyle(
                      color: AppColors.warningText, height: 1.45)),
            ),

          if (f.strengths.isNotEmpty)
            _section(s.fbStrengths, f.strengths, s, LucideIcons.circleCheck,
                AppColors.success),
          if (f.improvements.isNotEmpty)
            _section(s.fbImprovements, f.improvements, s,
                LucideIcons.trendingUp, AppColors.warning),
          if (f.isEmpty && f.hasEnoughData)
            Text(s.fbNothingYet,
                style: const TextStyle(color: AppColors.text2)),

          if (f.nextGoalReps != null) ...[
            const SizedBox(height: 6),
            Container(
                padding: EdgeInsets.all(embedded ? 14 : 0),
                decoration: embedded
                    ? BoxDecoration(
                        color: AppColors.accentTintSoft,
                        border: Border.all(color: AppColors.accentBorder),
                        borderRadius: BorderRadius.circular(12))
                    : null,
                child: Row(children: [
                  const Icon(LucideIcons.flag,
                      size: 18, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        '${s.fbNextGoal}: ${f.nextGoalReps} ${s.repsShort}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ])),
          ],
        ],
      ),
    );
    return embedded ? content : Card(child: content);
  }

  Widget _section(String title, List<FeedbackNote> notes, S s, IconData icon,
          Color color) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            for (final n in notes)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(icon, size: 16, color: color),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(feedbackNoteText(n, s),
                            style: const TextStyle(height: 1.4)),
                      ),
                    ]),
              ),
          ],
        ),
      );
}
