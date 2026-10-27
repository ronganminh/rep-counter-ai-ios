import 'package:flutter/material.dart';

import '../../../core/i18n/l10n.dart';
import '../../../core/legal/legal_config.dart';
import '../../../widgets/product_ui.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_feedback.dart';
import '../../../widgets/type_to_confirm_field.dart';
import '../application/auth_controller.dart';
import '../application/auth_scope.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_validation.dart';
import 'auth_widgets.dart';

/// Phase 9 "Forgot password": sends a reset link. The answer is the same
/// whether or not the address has an account.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage(
      {super.key, required this.controller, this.initialEmail = ''});
  final AuthController controller;
  final String initialEmail;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  late final _email = TextEditingController(text: widget.initialEmail);
  String? _emailError, _sentTo;
  AuthFailure? _failure;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l = context.l10n;
    setState(() {
      _failure = null;
      _emailError = AuthValidation.isEmail(_email.text)
          ? null
          : l.authEnterFullEmailAddress;
    });
    if (_emailError != null) return;
    try {
      await widget.controller.requestPasswordReset(_email.text);
      if (mounted) setState(() => _sentTo = _email.text.trim());
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
        if (_sentTo != null) {
          return AuthScaffold(
            title: l.authCheckEmail,
            children: [
              Text(_sentTo!,
                  key: const Key('reset-sent-to'), style: AppTypography.body16),
              const SizedBox(height: 20),
              if (_failure != null) AuthFailureBanner(_failure!),
              AppButton(
                  key: const Key('reset-resend'),
                  label: l.authResend,
                  variant: AppButtonVariant.secondary,
                  loading: c.busy,
                  onPressed: c.busy ? null : _send),
              const SizedBox(height: 12),
              AppButton(
                  key: const Key('reset-back'),
                  label: l.authBackSign,
                  variant: AppButtonVariant.ghost,
                  onPressed: () => Navigator.of(context).pop()),
            ],
          );
        }
        return AuthScaffold(
          title: l.authResetPassword,
          body: l.authEnterEmailUseRepcoach,
          children: [
            if (_failure != null) AuthFailureBanner(_failure!),
            TextField(
              key: const Key('auth-email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              autofillHints: const [AutofillHints.email],
              decoration: InputDecoration(
                  labelText: l.authEnterEmail, errorText: _emailError),
            ),
            const SizedBox(height: 20),
            AppButton(
                key: const Key('reset-send'),
                label: l.authSendResetLink,
                loading: c.busy,
                onPressed: c.busy ? null : _send),
          ],
        );
      },
    );
  }
}

/// Opened by the reset link (Supabase `passwordRecovery` event).
class ChooseNewPasswordPage extends StatefulWidget {
  const ChooseNewPasswordPage({super.key, required this.controller});
  final AuthController controller;

  @override
  State<ChooseNewPasswordPage> createState() => _ChooseNewPasswordPageState();
}

class _ChooseNewPasswordPageState extends State<ChooseNewPasswordPage> {
  final _password = TextEditingController();
  String? _error;
  AuthFailure? _failure;
  bool _done = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = context.l10n;
    setState(() {
      _failure = null;
      _error = AuthValidation.isPasswordLongEnough(_password.text)
          ? null
          : l.authUseLeastCharacters;
    });
    if (_error != null) return;
    try {
      await widget.controller.updatePassword(_password.text);
      if (mounted) setState(() => _done = true);
    } on AuthFailure catch (f) {
      if (mounted) setState(() => _failure = f);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n, c = widget.controller;
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) c.dismissRecovery();
      },
      child: ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          if (_done) {
            return AuthScaffold(
              title: l.authPasswordUpdated,
              children: [
                AppButton(
                    key: const Key('reset-done'),
                    label: l.authGoProfile,
                    onPressed: () => Navigator.of(context).pop()),
              ],
            );
          }
          final invalid = _failure?.kind == AuthFailureKind.recoveryLinkInvalid;
          return AuthScaffold(
            title: l.authChooseNewPassword,
            body: l.authResettingSignsOutOther,
            children: [
              if (_failure != null) AuthFailureBanner(_failure!),
              if (invalid) ...[
                AppButton(
                    key: const Key('reset-request-new'),
                    label: l.authRequestNewLink,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => Navigator.of(context)
                        .pushReplacement(MaterialPageRoute<void>(
                            builder: (_) => ForgotPasswordPage(
                                controller: c,
                                initialEmail: switch (c.state) {
                                  AuthSignedIn(:final user) => user.email ?? '',
                                  _ => '',
                                })))),
                const SizedBox(height: 16),
              ],
              AuthPasswordField(
                  controller: _password,
                  label: l.authCreatePassword,
                  newPassword: true,
                  errorText: _error,
                  helperText: l.authUseLeastCharacters,
                  onSubmitted: _save),
              const SizedBox(height: 20),
              AppButton(
                  key: const Key('reset-save'),
                  label: l.authSavePassword,
                  loading: c.busy,
                  onPressed: c.busy ? null : _save),
            ],
          );
        },
      ),
    );
  }
}

/// Shows [ChooseNewPasswordPage] when a reset link opens the app. Sits under
/// the app's Navigator, above the shell.
class AuthRecoveryListener extends StatefulWidget {
  const AuthRecoveryListener({super.key, required this.child});
  final Widget child;

  @override
  State<AuthRecoveryListener> createState() => _AuthRecoveryListenerState();
}

class _AuthRecoveryListenerState extends State<AuthRecoveryListener> {
  AuthController? _controller;
  bool _showing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final c = AuthScope.maybeOf(context);
    if (!identical(c, _controller)) {
      _controller?.removeListener(_check);
      _controller = c?..addListener(_check);
      _check();
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_check);
    super.dispose();
  }

  void _check() {
    final c = _controller;
    if (c == null || !c.recoveryPending || _showing) return;
    _showing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => ChooseNewPasswordPage(controller: c)));
      _showing = false;
      c.dismissRecovery();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Account deletion (App Store 5.1.1(v)). Typed confirmation, then the
/// server deletes the account; workouts on this phone stay.
class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key, required this.controller});
  final AuthController controller;

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  bool _confirmed = false, _failed = false, _done = false;

  Future<void> _delete() async {
    setState(() => _failed = false);
    try {
      await widget.controller.deleteAccount();
      if (mounted) setState(() => _done = true);
    } on AuthFailure {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n, c = widget.controller;
    if (_done) {
      return AuthScaffold(
        title: l.commonNotifAccountBeingDeleted,
        body: l.accountWorkoutsSavedPhoneWere,
        children: [
          AppButton(
              key: const Key('delete-done'),
              label: l.navClose,
              onPressed: () => Navigator.of(context).pop()),
        ],
      );
    }
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => AuthScaffold(
        title: l.commonPremiumDeleteAccount,
        children: [
          AppBanner(
              title: l.accountDeletesAccount,
              body: l.accountProfileFriendsCloudWorkouts,
              tone: AppBannerTone.warn),
          const SizedBox(height: 16),
          if (_failed) ...[
            AppBanner(
                key: const Key('delete-failed'),
                title: l.accountWeCouldnTStart,
                body: l.accountNothingWasDeletedRe,
                tone: AppBannerTone.err),
            const SizedBox(height: 16),
          ],
          Text(
              key: const Key('delete-help'),
              context.tr(
                  'Cần trợ giúp? ${LegalConfig.contactEmail} · ${LegalConfig.supportUrl}',
                  'Need help? ${LegalConfig.contactEmail} · ${LegalConfig.supportUrl}'),
              style: AppTypography.body14),
          const SizedBox(height: 16),
          TypeToConfirmField(
              onChanged: (ok) => setState(() => _confirmed = ok)),
          const SizedBox(height: 20),
          AppButton(
              key: const Key('delete-confirm'),
              label: l.commonPremiumDeleteAccount,
              variant: AppButtonVariant.danger,
              loading: c.busy,
              onPressed: _confirmed && !c.busy ? _delete : null),
        ],
      ),
    );
  }
}
