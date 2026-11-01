import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/metric_widgets.dart';
import '../../../widgets/product_ui.dart';
import '../../achievements/presentation/achievement_earned_card.dart';
import '../xp.dart';
import '../xp_controller.dart';

/// Level and XP from the account (Home and Progress). Nothing when XP is
/// off, signed out, or not loaded yet; a failed read keeps the last value.
class XpLevelCard extends StatefulWidget {
  const XpLevelCard({super.key});

  @override
  State<XpLevelCard> createState() => _XpLevelCardState();
}

class _XpLevelCardState extends State<XpLevelCard> {
  @override
  void initState() {
    super.initState();
    // Fresh numbers whenever Home or Progress opens (not during build).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) XpScope.maybeOf(context)?.refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final xp = XpScope.maybeOf(context);
    final p = xp?.progress;
    if (xp == null || !xp.signedIn || p == null) return const SizedBox.shrink();
    final l = context.l10n;
    final next = XpRules.xpForLevel(p.level + 1);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: ChallengeMeter(
        key: const Key('xp-level-card'),
        title: l.xpLevelTitle(p.level),
        value: p.intoLevel,
        target: p.levelSize,
        valueLabel: l.unitLevelXp(p.level, p.xpTotal, next),
        pace: l.xpToLevel(next - p.xpTotal, p.level + 1),
      ),
    );
  }
}

/// Progress: the account's achievements (unlocked on the server).
class XpAchievementsSection extends StatelessWidget {
  const XpAchievementsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final xp = XpScope.maybeOf(context);
    if (xp == null || !xp.signedIn || xp.progress == null) {
      return const SizedBox.shrink();
    }
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(l.fbAchievements),
          if (xp.achievements.isNotEmpty)
            Wrap(
              key: const Key('xp-achievements'),
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a in xp.achievements)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(AppRadius.r8),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(LucideIcons.award,
                          size: 14, color: AppColors.success),
                      const SizedBox(width: 6),
                      Text(achievementTitle(context, a),
                          style: AppTypography.body14.copyWith(fontSize: 13)),
                    ]),
                  ),
              ],
            ),
          const SizedBox(height: 8),
          Text(l.xpFromSyncedWorkouts,
              style: AppTypography.body14
                  .copyWith(color: AppColors.text2, fontSize: 12)),
        ],
      ),
    );
  }
}
