import 'package:flutter/material.dart';

import '../theme/app_typography.dart';

/// Neutral notice when a permission a feature needs is off
/// (App Store Guideline 5.1.1(iv), rejection of 1.0.0 (7); L-D24).
///
/// Shown ONLY when the user opens the feature while the permission is already
/// off, never right after they answer "Don't Allow" in the system prompt. It
/// states the fact once and offers two equal actions: back, and a plain link
/// to the app's Settings page. No "denied" title or icon, no step-by-step
/// instructions, no retry, no wording that asks the user to reconsider.
class PermissionOffNotice extends StatelessWidget {
  const PermissionOffNotice({
    super.key,
    required this.keyPrefix,
    required this.message,
    required this.backLabel,
    required this.settingsLabel,
    required this.onBack,
    required this.onOpenSettings,
  });

  /// Keys: `<prefix>-message`, `<prefix>-back`, `<prefix>-settings`.
  final String keyPrefix;
  final String message, backLabel, settingsLabel;
  final VoidCallback onBack, onOpenSettings;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(automaticallyImplyLeading: false),
        body: SafeArea(
            child: Center(
                child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(message,
                              key: Key('$keyPrefix-message'),
                              textAlign: TextAlign.center,
                              style: AppTypography.body16),
                          const SizedBox(height: 24),
                          Row(children: [
                            Expanded(
                                child: OutlinedButton(
                                    key: Key('$keyPrefix-back'),
                                    onPressed: onBack,
                                    child: Text(backLabel))),
                            const SizedBox(width: 12),
                            Expanded(
                                child: OutlinedButton(
                                    key: Key('$keyPrefix-settings'),
                                    onPressed: onOpenSettings,
                                    child: Text(settingsLabel))),
                          ]),
                        ])))),
      );
}
