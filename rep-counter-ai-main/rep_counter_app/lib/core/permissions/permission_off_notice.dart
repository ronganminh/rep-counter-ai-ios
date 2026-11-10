import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../i18n/locale_controller.dart';

/// The only place the app opens its page in the system Settings (App Store
/// Guideline 5.1.1(iv), L-D38). Called only from a neutral "access is off"
/// notice after the user taps its plain Open Settings button.
Future<void> openRepCoachSettings() => openAppSettings();

/// Neutral notice shown when the user starts a feature while its permission
/// is already off (never right after "Don't Allow"). One factual sentence and
/// two equal buttons: Back and Open Settings. No "denied" wording, no steps,
/// no retry, nothing that asks the user to reconsider.
class PermissionOffDialog extends StatelessWidget {
  const PermissionOffDialog({super.key, required this.message});
  final String message;

  static Future<void> show(BuildContext context, String message) async {
    final open = await showDialog<bool>(
        context: context,
        builder: (_) => PermissionOffDialog(message: message));
    if (open == true) await openRepCoachSettings();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        content: Text(message,
            key: const Key('permission-off-message'),
            textAlign: TextAlign.center),
        actions: [
          Row(children: [
            Expanded(
                child: OutlinedButton(
                    key: const Key('permission-off-back'),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(context.s.cameraBack))),
            const SizedBox(width: 12),
            Expanded(
                child: OutlinedButton(
                    key: const Key('permission-off-settings'),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(context.s.openSettings))),
          ]),
        ],
      );
}
