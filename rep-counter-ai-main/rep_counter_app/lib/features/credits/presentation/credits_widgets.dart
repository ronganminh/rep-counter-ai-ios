import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_feedback.dart';
import '../../../widgets/metric_widgets.dart';
import '../../../widgets/product_ui.dart';
import '../credits_controller.dart';
import 'coach_page.dart';

/// Credits chip (COMPONENT_REGISTRY, `CreditsChip`): the balance as text and
/// icon. At zero it stays neutral, never red: running out is not an error.
class CreditsChip extends StatelessWidget {
  const CreditsChip({super.key, required this.credits});
  final int credits;

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.creditsChip(credits);
    final color = credits > 0 ? AppColors.text : AppColors.text2;
    return Semantics(
      container: true,
      liveRegion: true,
      label: label,
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 26),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(AppRadius.r8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(LucideIcons.sparkles, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label,
                style: AppTypography.body14.copyWith(
                    color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }
}

/// Profile (signed in, credits on): the week's usage meter and the AI
/// Coach entry. Nothing otherwise.
class CreditsProfileSection extends StatelessWidget {
  const CreditsProfileSection({super.key});

  @override
  Widget build(BuildContext context) {
    final credits = CreditsScope.maybeOf(context);
    if (credits == null || !credits.signedIn) return const SizedBox.shrink();
    final l = context.l10n;
    final b = credits.balance;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (b != null)
            ChallengeMeter(
              key: const Key('credits-meter'),
              title: l.creditsMeterTitle,
              value: (b.weeklyAllowance - b.balance)
                  .clamp(0, b.weeklyAllowance),
              target: b.weeklyAllowance > 0 ? b.weeklyAllowance : 1,
              valueLabel: l.creditsMeterValue(
                  (b.weeklyAllowance - b.balance).clamp(0, b.weeklyAllowance),
                  b.weeklyAllowance),
              pace: l.creditsResetsMonday,
            )
          else if (credits.failed)
            AppBanner(
              key: const Key('credits-unavailable'),
              title: l.creditsUnavailable,
              actionLabel: l.commonRetryNow,
              onAction: credits.refresh,
            ),
          const SizedBox(height: 12),
          Card(
            clipBehavior: Clip.antiAlias,
            child: SettingsRow(
              key: const Key('profile-ai-coach'),
              icon: LucideIcons.messageCircle,
              title: l.aiCoach,
              subtitle: l.fbAskAboutTrainingEach,
              trailing: b == null ? null : CreditsChip(credits: b.balance),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => CoachPage(credits: credits))),
            ),
          ),
        ],
      ),
    );
  }
}
