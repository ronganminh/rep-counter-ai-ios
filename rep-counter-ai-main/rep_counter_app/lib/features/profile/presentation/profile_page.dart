import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/services/app_links.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/product_ui.dart';
import '../../../widgets/status_badges.dart';
import '../../legal/settings_page.dart';

/// Profile tab root (P9-07, N-1).
///
/// Accounts do not exist yet (A-1 is blocked on an auth provider, D-12), so
/// this is the guest variant: it states that data stays on this phone and
/// leads to the existing Settings and support. No sign-in entry is shown
/// until a real provider exists.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.screenPaddingV2.copyWith(top: 20, bottom: 32),
          children: [
            Semantics(
              header: true,
              child: Text(l.navProfile.toUpperCase(),
                  style: AppTypography.display40),
            ),
            const SizedBox(height: 20),
            Container(
              key: const Key('profile-guest-card'),
              padding: AppSpacing.cardPaddingV2,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SyncStatusBadge(state: SyncBadgeState.guestOnly),
                  const SizedBox(height: 12),
                  Text(l.authTrainWithoutAccount,
                      style: AppTypography.body14
                          .copyWith(color: AppColors.text2)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(children: [
                SettingsRow(
                  key: const Key('profile-settings'),
                  icon: LucideIcons.settings,
                  title: l.commonSettings,
                  trailing: const Icon(LucideIcons.chevronRight,
                      size: 18, color: AppColors.text2),
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsPage())),
                ),
                const Divider(indent: 52, endIndent: 16),
                SettingsRow(
                  icon: LucideIcons.lifeBuoy,
                  title: l.supportContact,
                  subtitle: l.supportByEmail(AppLinks.email.path),
                  onTap: AppLinks.feedback,
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
