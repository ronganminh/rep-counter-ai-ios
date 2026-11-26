import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../core/i18n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_feedback.dart';
import '../application/auth_controller.dart';
import '../domain/auth_repository.dart';
import 'auth_failure_text.dart';

/// Pushes [page]; when it reports a finished sign-in (`true`), this route
/// closes with `true` too, so the flow returns to whoever opened it.
Future<void> pushAuthStep(BuildContext context, Widget page) async {
  final done = await Navigator.of(context)
      .push<bool>(MaterialPageRoute(builder: (_) => page));
  if (done == true && context.mounted) Navigator.of(context).pop(true);
}

class AuthScaffold extends StatelessWidget {
  const AuthScaffold(
      {super.key, required this.title, this.body, required this.children});

  final String title;
  final String? body;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Semantics(
                  header: true,
                  child: Text(title, style: AppTypography.title22)),
              if (body != null) ...[
                const SizedBox(height: 8),
                Text(body!,
                    style:
                        AppTypography.body14.copyWith(color: AppColors.text2)),
              ],
              const SizedBox(height: 24),
              ...children,
            ],
          ),
        ),
      );
}

class AuthFailureBanner extends StatelessWidget {
  const AuthFailureBanner(this.failure, {super.key, this.signUp = false});
  final AuthFailure failure;
  final bool signUp;

  @override
  Widget build(BuildContext context) {
    final (title, body) = authFailureText(context, failure, signUp: signUp);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppBanner(
          key: const Key('auth-error'),
          title: title,
          body: body,
          tone: failure.kind == AuthFailureKind.cancelled
              ? AppBannerTone.neutral
              : AppBannerTone.err),
    );
  }
}

/// Apple first (App Store guideline 4.8 equal prominence), then Google,
/// both full width and the same height. Only providers the repository
/// supports are shown.
class AuthProviderButtons extends StatelessWidget {
  const AuthProviderButtons(
      {super.key, required this.controller, required this.onFailure});

  final AuthController controller;
  final ValueChanged<AuthFailure?> onFailure;

  Future<void> _run(BuildContext context, AuthProvider p) async {
    onFailure(null);
    try {
      await (p == AuthProvider.apple
          ? controller.signInWithApple()
          : controller.signInWithGoogle());
      if (context.mounted) Navigator.of(context).pop(true);
    } on AuthFailure catch (f) {
      onFailure(f.provider == null && f.kind == AuthFailureKind.providerFailed
          ? AuthFailure(f.kind, p)
          : f);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final providers = controller.repository.providers;
    final busy = controller.busy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (providers.contains(AuthProvider.apple)) ...[
          AppleSignInButton(
              key: const Key('auth-apple'),
              label: l.authContinueApple,
              matchLabel: providers.contains(AuthProvider.google)
                  ? l.authContinueGoogle
                  : null,
              onPressed: busy ? null : () => _run(context, AuthProvider.apple)),
          const SizedBox(height: 12),
        ],
        if (providers.contains(AuthProvider.google)) ...[
          AppButton(
              key: const Key('auth-google'),
              label: l.authContinueGoogle,
              icon: LucideIcons.globe,
              variant: AppButtonVariant.secondary,
              onPressed:
                  busy ? null : () => _run(context, AuthProvider.google)),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

/// Sign in with Apple in Apple's HIG style: the Apple logo and "Continue
/// with Apple", white on the dark theme (black on light), a pill like the
/// other buttons. Laid out exactly like an [AppButton] (same padding, text
/// style, 20 dp icon slot and minimum height), and [matchLabel] (the Google
/// button's label) is laid out invisibly under its own, so it is never
/// smaller than "Continue with Google", even when large text wraps it.
class AppleSignInButton extends StatelessWidget {
  const AppleSignInButton(
      {super.key,
      required this.label,
      required this.onPressed,
      this.matchLabel});

  final String label;
  final String? matchLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final enabled = onPressed != null;
    final bg = dark ? Colors.white : Colors.black;
    final fg = dark ? Colors.black : Colors.white;
    final style = AppTypography.label16.copyWith(color: fg, height: 1.2);
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
              minHeight: AppSpacing.buttonHeightSmall,
              minWidth: AppSpacing.minTouch),
          child: Material(
            key: const Key('auth-apple-surface'),
            color: bg,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox.square(
                      dimension: 20,
                      child: Center(
                        child: SizedBox(
                          width: 16,
                          height: 20,
                          child:
                              CustomPaint(painter: AppleLogoPainter(color: fg)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (matchLabel != null)
                            Visibility(
                              visible: false,
                              maintainSize: true,
                              maintainAnimation: true,
                              maintainState: true,
                              child: Text(matchLabel!,
                                  textAlign: TextAlign.center, style: style),
                            ),
                          Text(label,
                              textAlign: TextAlign.center, style: style),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown when this build has no sign-in method configured (the production
/// default until the backend exists).
class AuthUnavailableBanner extends StatelessWidget {
  const AuthUnavailableBanner({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: AppBanner(
            key: const Key('auth-unavailable'),
            title: context.l10n.authSignIsnTAvailable,
            body: context.l10n.authTrainWithoutAccount),
      );
}

class AuthOrDivider extends StatelessWidget {
  const AuthOrDivider({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          const Expanded(child: Divider()),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(context.l10n.authText,
                  style:
                      AppTypography.body14.copyWith(color: AppColors.text2))),
          const Expanded(child: Divider()),
        ]),
      );
}

class AuthPasswordField extends StatefulWidget {
  const AuthPasswordField(
      {super.key,
      required this.controller,
      required this.label,
      this.errorText,
      this.helperText,
      this.newPassword = false,
      this.onSubmitted});

  final TextEditingController controller;
  final String label;
  final String? errorText, helperText;
  final bool newPassword;
  final VoidCallback? onSubmitted;

  @override
  State<AuthPasswordField> createState() => _AuthPasswordFieldState();
}

class _AuthPasswordFieldState extends State<AuthPasswordField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return TextField(
      key: const Key('auth-password'),
      controller: widget.controller,
      obscureText: !_visible,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: [
        widget.newPassword ? AutofillHints.newPassword : AutofillHints.password
      ],
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => widget.onSubmitted?.call(),
      decoration: InputDecoration(
        labelText: widget.label,
        errorText: widget.errorText,
        helperText: widget.helperText,
        helperMaxLines: 2,
        errorMaxLines: 2,
        suffixIcon: IconButton(
          tooltip: _visible ? l.authHidePassword : l.commonAccountShowPassword,
          onPressed: () => setState(() => _visible = !_visible),
          icon: Icon(_visible ? LucideIcons.eyeOff : LucideIcons.eye),
        ),
      ),
    );
  }
}
