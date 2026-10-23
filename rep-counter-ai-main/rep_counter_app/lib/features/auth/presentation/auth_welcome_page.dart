import 'package:flutter/material.dart';

import '../../../core/i18n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_button.dart';
import '../application/auth_controller.dart';
import '../domain/auth_repository.dart';
import 'auth_widgets.dart';
import 'sign_in_page.dart';
import 'sign_up_page.dart';

/// Phase 9 welcome. Pops `true` once signed in, `false` for "Continue as
/// guest". Guest is always available: nothing here gates training.
class AuthWelcomePage extends StatefulWidget {
  const AuthWelcomePage({super.key, required this.controller});
  final AuthController controller;

  @override
  State<AuthWelcomePage> createState() => _AuthWelcomePageState();
}

class _AuthWelcomePageState extends State<AuthWelcomePage> {
  AuthFailure? _failure;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n, c = widget.controller;
    final email = c.repository.providers.contains(AuthProvider.email);
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => AuthScaffold(
        title: l.authTrainCountImprove,
        body: l.authCountRepsCameraGet,
        children: [
          if (c.repository.providers.isEmpty) const AuthUnavailableBanner(),
          if (_failure != null) AuthFailureBanner(_failure!),
          AuthProviderButtons(
              controller: c, onFailure: (f) => setState(() => _failure = f)),
          if (email) ...[
            AppButton(
                key: const Key('auth-create-account'),
                label: l.authCreateAccount,
                onPressed: c.busy
                    ? null
                    : () => pushAuthStep(context, SignUpPage(controller: c))),
            const SizedBox(height: 12),
            AppButton(
                key: const Key('auth-sign-in'),
                label: l.authSignIn,
                variant: AppButtonVariant.secondary,
                onPressed: c.busy
                    ? null
                    : () => pushAuthStep(context, SignInPage(controller: c))),
            const SizedBox(height: 12),
          ],
          AppButton(
              key: const Key('auth-continue-guest'),
              label: l.authContinueGuest,
              variant: AppButtonVariant.ghost,
              onPressed: () => Navigator.of(context).pop(false)),
          const SizedBox(height: 16),
          Text(l.authTrainWithoutAccount,
              textAlign: TextAlign.center,
              style: AppTypography.body14.copyWith(color: AppColors.text2)),
        ],
      ),
    );
  }
}
