import 'package:flutter/material.dart';

import '../../../core/i18n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_button.dart';
import '../../legal/legal_page.dart';
import '../application/auth_controller.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_validation.dart';
import 'auth_widgets.dart';
import 'sign_in_page.dart';
import 'verify_email_page.dart';

/// Phase 9 sign-up: email + password (≥ 10 characters) + Terms. On success
/// shows email verification, then pops `true`. Only an email and a password
/// are asked for.
class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key, required this.controller});
  final AuthController controller;

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _terms = false;
  String? _emailError, _passwordError, _termsError;
  AuthFailure? _failure;

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
  }

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
      _passwordError = AuthValidation.isPasswordLongEnough(_password.text)
          ? null
          : l.authUseLeastCharacters;
      _termsError = _terms ? null : l.authTickBoxAcceptTerms;
    });
    if (_emailError != null || _passwordError != null || _termsError != null) {
      return;
    }
    try {
      await widget.controller.signUpWithEmail(_email.text, _password.text);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => VerifyEmailPage(controller: widget.controller)));
      if (mounted) Navigator.of(context).pop(true);
    } on AuthFailure catch (f) {
      if (mounted) setState(() => _failure = f);
    }
  }

  void _legal(LegalKind kind) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => LegalPage(kind: kind)));

  @override
  Widget build(BuildContext context) {
    final l = context.l10n, c = widget.controller;
    final short = _password.text.isNotEmpty &&
        !AuthValidation.isPasswordLongEnough(_password.text);
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => AuthScaffold(
        title: l.authCreateAccount2,
        body: l.authJustEmailPasswordNo,
        children: [
          if (_failure != null) AuthFailureBanner(_failure!, signUp: true),
          if (_failure?.kind == AuthFailureKind.accountExists)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: AppButton(
                  key: const Key('auth-sign-in-instead'),
                  label: l.authSignInstead,
                  variant: AppButtonVariant.secondary,
                  onPressed: () =>
                      pushAuthStep(context, SignInPage(controller: c))),
            ),
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
              label: l.authCreatePassword,
              newPassword: true,
              errorText: _passwordError,
              helperText: short
                  ? l.authStrengthTooShort
                  : '${l.authUseLeastCharacters} · ${l.authCheckedAgainstLeakedPasswords}'),
          const SizedBox(height: 12),
          CheckboxListTile(
            key: const Key('auth-terms'),
            value: _terms,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: (v) => setState(() {
              _terms = v ?? false;
              if (_terms) _termsError = null;
            }),
            title: Text(l.authIAgreeTermsService, style: AppTypography.body14),
            subtitle: _termsError == null
                ? null
                : Text(_termsError!,
                    style: AppTypography.body14
                        .copyWith(color: AppColors.warningText)),
          ),
          Wrap(spacing: 8, children: [
            TextButton(
                onPressed: () => _legal(LegalKind.terms),
                child: Text(l.authReadTerms)),
            TextButton(
                onPressed: () => _legal(LegalKind.privacy),
                child: Text(l.authReadPrivacyPolicy)),
          ]),
          const SizedBox(height: 16),
          AppButton(
              key: const Key('auth-submit'),
              label: c.busy ? l.authCreatingAccount : l.authCreateAccount,
              loading: c.busy,
              onPressed: c.busy ? null : _submit),
          const SizedBox(height: 8),
          TextButton(
              onPressed: c.busy
                  ? null
                  : () => pushAuthStep(context, SignInPage(controller: c)),
              child: Text(l.authAlreadyHaveAccountSign)),
        ],
      ),
    );
  }
}
