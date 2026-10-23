import 'package:flutter/widgets.dart';

import 'auth_controller.dart';

/// Provides the [AuthController] when accounts are enabled
/// (`FeatureFlags.enableAccounts`). With accounts off there is no scope and
/// every account entry point hides itself.
class AuthScope extends InheritedNotifier<AuthController> {
  const AuthScope(
      {super.key, required AuthController controller, required super.child})
      : super(notifier: controller);

  static AuthController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AuthScope>()?.notifier;
}
