import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/i18n/locale_controller.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/product_ui.dart';

class CameraPermissionView extends StatelessWidget {
  const CameraPermissionView(
      {super.key,
      required this.title,
      required this.body,
      required this.denied,
      required this.loading,
      required this.actionLabel,
      required this.onAction,
      required this.onExit,
      this.onRetry});
  final String title, body, actionLabel;
  final bool denied, loading;
  final VoidCallback onAction, onExit;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            leading: IconButton(
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
                                    child: Icon(
                                        denied
                                            ? LucideIcons.cameraOff
                                            : LucideIcons.camera,
                                        size: 60,
                                        color: denied
                                            ? AppColors.text2
                                            : AppColors.accent)),
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
                                          if (denied) ...[
                                            _Line(
                                                LucideIcons.settings,
                                                context.tr('1. Mở Cài đặt',
                                                    '1. Open Settings')),
                                            _Line(
                                                LucideIcons.smartphone,
                                                context.tr(
                                                    '2. Chọn RepCoach AI',
                                                    '2. Select RepCoach AI')),
                                            _Line(
                                                LucideIcons.camera,
                                                context.tr('3. Bật Camera',
                                                    '3. Enable Camera')),
                                          ] else ...[
                                            _Line(LucideIcons.shieldCheck,
                                                context.s.cameraOnDeviceNote),
                                            _Line(
                                                LucideIcons.eye,
                                                context.tr(
                                                    'Camera chỉ dùng trong buổi tập',
                                                    'Camera is used during workouts')),
                                          ],
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
                                        if (onRetry != null)
                                          TextButton(
                                              onPressed: onRetry,
                                              child: Text(context
                                                  .s.cameraGrantedRetry)),
                                        TextButton(
                                            onPressed: onExit,
                                            child: Text(
                                                context.tr('Để sau', 'Not now'),
                                                style: const TextStyle(
                                                    color: AppColors.text2))),
                                      ])),
                            ]))))),
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
