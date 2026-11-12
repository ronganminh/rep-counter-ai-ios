import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/i18n/l10n.dart';
import '../../../../core/i18n/locale_controller.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/permission_off_notice.dart';
import '../../../../widgets/product_ui.dart';

/// Camera gate shown before the system permission prompt, while the camera
/// opens, and when it cannot open for a non-permission reason.
///
/// App Store Guideline 5.1.1(iv) (L-D24): before the prompt the only action
/// is [actionLabel] ("Continue"), which always leads to the system prompt.
/// Pass `onExit: null` and no [onManual] for that state: no close, no "Not
/// now", no other way out. Exits and manual logging come after the prompt.
///
/// Camera access that is off is NOT shown here: see [CameraOffNotice].
class CameraPermissionView extends StatelessWidget {
  const CameraPermissionView(
      {super.key,
      required this.title,
      required this.body,
      required this.loading,
      required this.actionLabel,
      required this.onAction,
      required this.onExit,
      this.onManual});
  final String title, body, actionLabel;
  final bool loading;
  final VoidCallback? onAction;
  final VoidCallback? onExit;

  /// W-4: log reps by hand instead of using the camera.
  final VoidCallback? onManual;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            automaticallyImplyLeading: false,
            leading: onExit == null
                ? null
                : IconButton(
                    onPressed: onExit,
                    tooltip: context.tr('Đóng', 'Close'),
                    icon: const Icon(LucideIcons.x))),
        body: SafeArea(
            child: LayoutBuilder(
                builder: (context, box) => SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    child: ConstrainedBox(
                        constraints: BoxConstraints(
                            minHeight:
                                (box.maxHeight - 40).clamp(0, double.infinity)),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(children: [
                                Container(
                                    width: 160,
                                    height: 160,
                                    decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.surface,
                                        border: Border.all(
                                            color: AppColors.borderStrong)),
                                    child: const Icon(LucideIcons.camera,
                                        size: 60, color: AppColors.accent)),
                                const SizedBox(height: 28),
                                Text(title,
                                    textAlign: TextAlign.center,
                                    style: AppTypography.headline28),
                                const SizedBox(height: 12),
                                Text(body,
                                    textAlign: TextAlign.center,
                                    style: AppTypography.body16
                                        .copyWith(color: AppColors.text2)),
                                const SizedBox(height: 24),
                                Card(
                                    child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(children: [
                                          _Line(LucideIcons.shieldCheck,
                                              context.s.cameraOnDeviceNote),
                                          _Line(
                                              LucideIcons.eye,
                                              context.tr(
                                                  'Camera chỉ dùng trong buổi tập',
                                                  'Camera is used during workouts')),
                                        ]))),
                              ]),
                              Padding(
                                  padding: const EdgeInsets.only(top: 28),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        if (loading)
                                          const Center(
                                              child:
                                                  CircularProgressIndicator())
                                        else
                                          FilledButton(
                                              onPressed: onAction,
                                              child: Text(actionLabel)),
                                        if (onManual != null)
                                          TextButton(
                                              key: const Key(
                                                  'camera-track-manually'),
                                              onPressed: onManual,
                                              child: Text(context
                                                  .l10n.cameraTrackManually)),
                                        if (onExit != null)
                                          TextButton(
                                              onPressed: onExit,
                                              child: Text(
                                                  context.tr('Đóng', 'Close'),
                                                  style: const TextStyle(
                                                      color: AppColors.text2))),
                                      ])),
                            ]))))),
      );
}

/// Neutral notice when camera access is off (App Store Guideline 5.1.1(iv),
/// rejection of 1.0.0 (7)).
///
/// Shown ONLY when the user opens a camera feature while access is already
/// off, never right after they answer "Don't Allow" in the system prompt.
/// It states the fact once and offers two equal actions: [onBack] and a plain
/// link to the app's Settings page ([onOpenSettings]). No "denied" title or
/// icon, no step-by-step instructions, no retry, no wording that asks the
/// user to reconsider.
class CameraOffNotice extends StatelessWidget {
  const CameraOffNotice(
      {super.key, required this.onBack, required this.onOpenSettings});
  final VoidCallback onBack, onOpenSettings;
  @override
  Widget build(BuildContext context) => PermissionOffNotice(
        keyPrefix: 'camera-off',
        message: context.s.cameraOffMessage,
        backLabel: context.s.cameraBack,
        settingsLabel: context.s.openSettings,
        onBack: onBack,
        onOpenSettings: onOpenSettings,
      );
}

class _Line extends StatelessWidget {
  const _Line(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Icon(icon, size: 22, color: AppColors.success),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
      ]));
}
