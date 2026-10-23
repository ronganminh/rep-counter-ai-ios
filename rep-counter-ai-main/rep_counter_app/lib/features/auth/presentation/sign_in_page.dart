import 'package:flutter/material.dart';

import '../../../core/i18n/l10n.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_feedback.dart';
import '../application/auth_controller.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_validation.dart';
import 'auth_widgets.dart';
import 'password_reset_pages.dart';
import 'sign_up_page.dart';

/// Phase 9 sign-in: providers, then email + password. Pops `true` when
/// signed in. An expired session pre-fills its email.
class SignInPage extends StatefulWidget {
  const SignInPage({super.key, required this.controller});
  final AuthController controller;

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  late final _email = TextEditingController(
      text: switch (widget.controller.state) {
    AuthExpired(:final user) => user.email ?? '',
    _ => '',
  });
  final _password = TextEditingController();
  String? _emailError, _passwordError;
  AuthFailure? _failure;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = context.l10n;
    setState(() {
      _failure = null;
      _emailError = AuthValidation.isEmail(_email.text)
          ? null
          : l.authEnterFullEmailAddress;
      _passwordError = _password.text.isEmpty ? l.authEnterPassword : null;
    });
    if (_emailError != null || _passwordError != null) return;
    try {
      await widget.controller.signInWithEmail(_email.text, _password.text);
      if (mounted) Navigator.of(context).pop(true);
    } on AuthFailure catch (f) {
      if (mounted) setState(() => _failure = f);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n, c = widget.controller;
    final email = c.repository.providers.contains(AuthProvider.email);
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => AuthScaffold(
        title: l.authSignIn,
        children: [
          if (c.state is AuthExpired) ...[
            AppBanner(
                key: const Key('auth-expired'),
                title: l.authSessionExpired,
                tone: AppBannerTone.warn),
            const SizedBox(height: 16),
          ],
          if (_failure != null) AuthFailureBanner(_failure!),
          AuthProviderButtons(
              controller: c, onFailure: (f) => setState(() => _failure = f)),
          if (email) ...[
            if (c.repository.providers.length > 1) const AuthOrDivider(),
            TextField(
              key: const Key('auth-email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                  labelText: l.authEnterEmail, errorText: _emailError),
            ),
            const SizedBox(height: 12),
            AuthPasswordField(
                controller: _password,
                label: l.authEnterPassword,
                errorText: _passwordError,
                onSubmitted: _submit),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                  key: const Key('auth-forgot-password'),
                  onPressed: c.busy
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) => ForgotPasswordPage(
                                  controller: c, initialEmail: _email.text))),
                  child: Text(l.authForgotPassword)),
            ),
            const SizedBox(height: 8),
            AppButton(
                key: const Key('auth-submit'),
                label: c.busy ? l.authSigning : l.authSignIn,
                loading: c.busy,
                onPressed: c.busy ? null : _submit),
            const SizedBox(height: 8),
            TextButton(
                onPressed: c.busy
                    ? null
                    : () => pushAuthStep(context, SignUpPage(controller: c)),
                child: Text(l.authCreateAccount)),
          ],
        ],
      ),
    );
  }
}
