import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/l10n.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_feedback.dart';
import '../application/auth_controller.dart';
import '../application/auth_scope.dart';
import '../domain/auth_repository.dart';
import 'auth_widgets.dart';
import 'sign_in_page.dart';
import 'sign_up_page.dart';

/// Account-only destinations. Training, history and counting are never
/// gated (FA auth gate).
enum AuthGateReason { friends, coach, pro }

/// Phase 9 auth gate with return-to: [require] resolves `true` when the user
/// is (or becomes) signed in, so the caller continues to the destination it
/// asked for; `false` keeps them where they were, as a guest.
class AuthGatePage extends StatelessWidget {
  const AuthGatePage(
      {super.key, required this.controller, required this.reason});

  final AuthController controller;
  final AuthGateReason reason;

  static Future<bool> require(
      BuildContext context, AuthGateReason reason) async {
    final c = AuthScope.maybeOf(context);
    if (c == null) return false; // accounts are off
    if (c.state is AuthSignedIn) return true;
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => AuthGatePage(controller: c, reason: reason)));
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final email = controller.repository.providers.contains(AuthProvider.email);
    final expired = controller.state is AuthExpired;
    final title = switch (reason) {
      AuthGateReason.friends => l.authFriendsNeedAccount,
      AuthGateReason.coach => l.authGateCoach,
      AuthGateReason.pro => l.authGatePro,
    };
    return AuthScaffold(
      title: title,
      body: reason == AuthGateReason.friends
          ? l.authFriendsChallengesLeaderboardsStored
          : l.authTrainWithoutAccount,
      children: [
        if (expired) ...[
          AppBanner(
              key: const Key('auth-expired'),
              title: l.authSessionExpired,
              tone: AppBannerTone.warn),
          const SizedBox(height: 16),
        ],
        if (controller.repository.providers.isEmpty)
          const AuthUnavailableBanner()
        else
          AppButton(
              key: const Key('gate-sign-in'),
              label: l.authSignIn,
              icon: LucideIcons.logIn,
              onPressed: () =>
                  pushAuthStep(context, SignInPage(controller: controller))),
        if (email) ...[
          const SizedBox(height: 12),
          AppButton(
              key: const Key('gate-create-account'),
              label: l.authCreateAccount,
              variant: AppButtonVariant.secondary,
              onPressed: () =>
                  pushAuthStep(context, SignUpPage(controller: controller))),
        ],
        const SizedBox(height: 12),
        AppButton(
            key: const Key('gate-guest'),
            label: l.authContinueGuestNow,
            variant: AppButtonVariant.ghost,
            onPressed: () => Navigator.of(context).pop(false)),
      ],
    );
  }
}
