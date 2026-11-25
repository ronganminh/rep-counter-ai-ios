import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_button.dart';
import '../../credits/credits_controller.dart';
import '../../workout/data/workout_record.dart';
import '../../workout/domain/workout_mode.dart';
import '../coach_v2.dart';
import 'coach_chat_page.dart';
import 'coach_consent_page.dart';
import 'coach_review_page.dart';
import 'coach_widgets.dart';

/// Results (FA-03a) → "Coach review" (AC-02). Shown only with the flag,
/// AI credits configured and a rep workout; the free basic feedback above
/// it is unchanged (D-07). Opens the account gate and consent first.
class CoachReviewEntry extends StatelessWidget {
  const CoachReviewEntry({super.key, required this.record, this.enabled});
  final WorkoutRecord record;

  /// Overrides the flag (tests).
  final bool? enabled;

  @override
  Widget build(BuildContext context) {
    final credits = CreditsScope.maybeOf(context);
    final on = enabled ?? CoachGate.available(context);
    if (!on || credits == null || record.mode == WorkoutMode.timed) {
      return const SizedBox.shrink();
    }
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: CoachCard(
        key: const Key('coach-review-entry'),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          CoachCaption(l.ptReviewTitle, trailing: const CoachChip()),
          const SizedBox(height: 10),
          AppButton(
            key: const Key('coach-review-open'),
            label: l.ptGetReview,
            icon: LucideIcons.sparkles,
            variant: AppButtonVariant.secondary,
            onPressed: () async {
              if (!await CoachConsentPage.ensure(context) || !context.mounted) {
                return;
              }
              await Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(
                      builder: (pageContext) => CoachReviewPage(
                          record: record,
                          credits: credits,
                          onAskFollowUp: () =>
                              openCoachChat(pageContext, credits))));
            },
          ),
          const SizedBox(height: 8),
          Text(l.ptUsesOneCredit,
              textAlign: TextAlign.center,
              style: AppTypography.caption12.copyWith(color: AppColors.text2)),
        ]),
      ),
    );
  }
}
