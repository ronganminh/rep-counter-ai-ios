import 'package:flutter/widgets.dart';

import '../../../core/i18n/l10n.dart';
import '../domain/auth_repository.dart';

String authProviderName(AuthProvider p) => switch (p) {
      AuthProvider.apple => 'Apple',
      AuthProvider.google => 'Google',
      AuthProvider.email => 'Email',
    };

/// Title and body for an [AuthFailure], from the Phase 9 error copy.
(String, String) authFailureText(BuildContext context, AuthFailure f,
    {bool signUp = false}) {
  final l = context.l10n;
  final provider = f.provider;
  return switch (f.kind) {
    AuthFailureKind.invalidCredentials => (
        l.authInvalid,
        l.authCheckBothTryAgain
      ),
    AuthFailureKind.network => signUp
        ? (l.authCanTCreateAccount, l.authCheckConnectionTryAgain2)
        : (l.authCanTConnect, l.authCheckConnectionTryAgain),
    AuthFailureKind.tooManyAttempts => (
        l.authTooManyAttempts,
        l.authSignPausedAccountDevice
      ),
    AuthFailureKind.unavailable => (
        l.authSignIsnTAvailable,
        l.authPleaseContactSupportHelp
      ),
    AuthFailureKind.cancelled => (
        l.authSignCancelled,
        l.authNothingChangedChooseAnother2
      ),
    AuthFailureKind.providerFailed => (
        l.authCouldnTSignValue(
            provider == null ? '' : authProviderName(provider)),
        l.authProviderDidnTComplete
      ),
    AuthFailureKind.accountExists => (
        l.authAlreadyHaveAccount,
        provider == null || provider == AuthProvider.email
            ? l.authAlreadyHaveAccountEmail
            : l.authValueConfirmedEmailWhich(
                authProviderName(provider), authProviderName(provider))
      ),
    AuthFailureKind.weakPassword => (
        l.authNotCommonlyUsedLeaked,
        l.authUseLeastCharacters
      ),
  };
}
