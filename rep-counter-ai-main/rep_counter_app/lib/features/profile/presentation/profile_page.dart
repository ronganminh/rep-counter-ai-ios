import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/services/app_links.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/product_ui.dart';
import '../../../widgets/status_badges.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_feedback.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_scope.dart';
import '../../auth/presentation/auth_welcome_page.dart';
import '../../auth/presentation/password_reset_pages.dart';
import '../../auth/presentation/sign_in_page.dart';
import '../../auth/presentation/verify_email_page.dart';
import '../../legal/settings_page.dart';
import '../../sync/presentation/sync_widgets.dart';

/// Profile tab root (P9-07, N-1).
///
/// Without accounts (no [AuthScope]: `FeatureFlags.enableAccounts` is off,
/// the production default) this is the guest variant: data stays on this
/// phone, plus the existing Settings and support. With accounts on it adds
/// sign-in, the signed-in account and the expired-session banner (A-1).
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final auth = AuthScope.maybeOf(context);
    final state = auth?.state;
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
            if (auth != null && state is AuthExpired) ...[
              AppBanner(
                key: const Key('profile-session-expired'),
                title: l.authSessionExpired,
                tone: AppBannerTone.warn,
                actionLabel: l.authSignIn,
                onAction: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => SignInPage(controller: auth))),
              ),
              const SizedBox(height: 16),
            ],
            if (auth != null && state is AuthSignedIn) ...[
              const SyncAccountSection(),
              _AccountCard(controller: auth, state: state),
            ]
            else
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
                  if (auth != null && state is AuthGuest) ...[
                    const SizedBox(height: 16),
                    AppButton(
                      key: const Key('profile-sign-in'),
                      label: l.authSignIn,
                      icon: LucideIcons.logIn,
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<bool>(
                              builder: (_) =>
                                  AuthWelcomePage(controller: auth))),
                    ),
                  ],
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

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.controller, required this.state});
  final AuthController controller;
  final AuthSignedIn state;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Card(
      key: const Key('profile-account-card'),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        SettingsRow(
          icon: LucideIcons.circleUser,
          title: state.user.email ?? l.authSignedPhone,
          subtitle: l.authSignedPhone,
        ),
        if (state.needsVerification) ...[
          const Divider(indent: 52, endIndent: 16),
          SettingsRow(
            key: const Key('profile-verify-email'),
            icon: LucideIcons.mailWarning,
            title: l.authVerifyEmail,
            subtitle: l.authCanStartTrainingNow,
            trailing: const Icon(LucideIcons.chevronRight,
                size: 18, color: AppColors.text2),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => VerifyEmailPage(controller: controller))),
          ),
        ],
        const Divider(indent: 52, endIndent: 16),
        SettingsRow(
          key: const Key('profile-sign-out'),
          icon: LucideIcons.logOut,
          title: l.authSignOut,
          onTap: controller.signOut,
        ),
        const Divider(indent: 52, endIndent: 16),
        SettingsRow(
          key: const Key('profile-delete-account'),
          icon: LucideIcons.userX,
          title: l.commonPremiumDeleteAccount,
          trailing: const Icon(LucideIcons.chevronRight,
              size: 18, color: AppColors.text2),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => DeleteAccountPage(controller: controller))),
        ),
      ]),
    );
  }
}
