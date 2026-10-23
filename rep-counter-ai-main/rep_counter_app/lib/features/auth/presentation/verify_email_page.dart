import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_feedback.dart';
import '../application/auth_controller.dart';
import '../domain/auth_repository.dart';
import 'auth_widgets.dart';

/// Phase 9 email verification. Never blocking: the account exists and the
/// user can train right away; account features unlock once confirmed.
/// [onBringWorkouts] opens the merge preview once sync (A-2) exists.
class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage(
      {super.key, required this.controller, this.onBringWorkouts});
  final AuthController controller;
  final VoidCallback? onBringWorkouts;

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  AuthFailure? _failure;
  bool _resent = false;

  Future<void> _guard(Future<void> Function() call) async {
    setState(() => _failure = null);
    try {
      await call();
    } on AuthFailure catch (f) {
      if (mounted) setState(() => _failure = f);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n, c = widget.controller;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final state = c.state;
        final user = state is AuthSignedIn ? state.user : null;
        if (user != null && user.emailVerified) {
          return AuthScaffold(
            title: l.authEmailConfirmed,
            body: l.authAccountReadyIfTrained,
            children: [
              if (widget.onBringWorkouts != null) ...[
                AppButton(
                    key: const Key('verify-bring-workouts'),
                    label: l.authBringMyWorkouts,
                    onPressed: widget.onBringWorkouts),
                const SizedBox(height: 12),
              ],
              AppButton(
                  key: const Key('verify-done'),
                  label: l.authGoProfile,
                  variant: widget.onBringWorkouts == null
                      ? AppButtonVariant.primary
                      : AppButtonVariant.secondary,
                  onPressed: () => Navigator.of(context).pop()),
            ],
          );
        }
        return AuthScaffold(
          title: l.authConfirmEmail,
          body: l.authCanStartTrainingNow,
          children: [
            if (user?.email != null) ...[
              Row(children: [
                const Icon(LucideIcons.mail, size: 18, color: AppColors.text2),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(user!.email!,
                        key: const Key('verify-email'),
                        style: AppTypography.body16)),
              ]),
              const SizedBox(height: 12),
            ],
            Text(l.authWaitingOpenLink,
                style: AppTypography.body14.copyWith(color: AppColors.text2)),
            const SizedBox(height: 16),
            if (_failure != null) AuthFailureBanner(_failure!),
            if (_resent && _failure == null) ...[
              AppBanner(
                  key: const Key('verify-resent'),
                  title: l.authCheckInbox,
                  tone: AppBannerTone.ok),
              const SizedBox(height: 16),
            ],
            AppButton(
                key: const Key('verify-check'),
                label: l.authContinueVerification,
                loading: c.busy,
                onPressed: c.busy ? null : () => _guard(c.reload)),
            const SizedBox(height: 12),
            AppButton(
                key: const Key('verify-resend'),
                label: l.authResendEmail,
                variant: AppButtonVariant.secondary,
                onPressed: c.busy
                    ? null
                    : () => _guard(() async {
                          await c.resendVerification();
                          if (mounted) setState(() => _resent = true);
                        })),
            const SizedBox(height: 12),
            AppButton(
                key: const Key('verify-later'),
                label: l.authTrainOffline,
                variant: AppButtonVariant.ghost,
                onPressed: () => Navigator.of(context).pop()),
          ],
        );
      },
    );
  }
}
