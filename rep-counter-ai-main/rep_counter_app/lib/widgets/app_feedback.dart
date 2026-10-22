import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_typography.dart';
import 'app_button.dart';

/// Banner tones (COMPONENT_REGISTRY #12).
enum AppBannerTone { ok, warn, err, lime, neutral }

extension on AppBannerTone {
  (Color fg, Color bg, IconData icon) get style => switch (this) {
        AppBannerTone.ok => (
            AppColors.success,
            AppColors.successTint,
            LucideIcons.circleCheck
          ),
        AppBannerTone.warn => (
            AppColors.warningText,
            AppColors.warningTint,
            LucideIcons.triangleAlert
          ),
        AppBannerTone.err => (
            AppColors.dangerText,
            AppColors.dangerTint,
            LucideIcons.circleAlert
          ),
        AppBannerTone.lime => (
            AppColors.accent,
            AppColors.accentTint,
            LucideIcons.sparkles
          ),
        AppBannerTone.neutral => (
            AppColors.text2,
            AppColors.surface2,
            LucideIcons.info
          ),
      };
}

/// Inline status banner: icon, title, optional body and one optional action.
/// Announced as a live region (`role=status`).
class AppBanner extends StatelessWidget {
  const AppBanner({
    super.key,
    required this.title,
    this.body,
    this.tone = AppBannerTone.neutral,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? body;
  final AppBannerTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final (fg, bg, icon) = tone.style;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: fg),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTypography.body14.copyWith(
                          color: AppColors.text, fontWeight: FontWeight.w600)),
                  if (body != null) ...[
                    const SizedBox(height: 4),
                    Text(body!,
                        style: AppTypography.body14
                            .copyWith(color: AppColors.text2)),
                  ],
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(height: 8),
                    AppButton(
                      label: actionLabel!,
                      onPressed: onAction,
                      variant: AppButtonVariant.ghost,
                      expand: false,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom toast (COMPONENT_REGISTRY #13): surface2, strong border, radius 14,
/// auto-dismiss after 4 s (proposed) with a 48 dp close button.
///
/// Never call this while a workout HUD is visible: nothing may overlay the
/// HUD (PRODUCT_DECISIONS D-02).
abstract final class AppToast {
  static const duration = Duration(seconds: 4);

  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? show(
    BuildContext context,
    String message, {
    IconData icon = LucideIcons.circleCheck,
    Color iconColor = AppColors.success,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return null;
    final closeLabel = AppLocalizations.of(context).navClose;
    messenger.hideCurrentSnackBar();
    return messenger.showSnackBar(SnackBar(
      duration: duration,
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surface2,
      padding: const EdgeInsets.only(left: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.r14),
        side: const BorderSide(color: AppColors.borderStrong),
      ),
      content: Semantics(
        liveRegion: true,
        child: Row(children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: AppTypography.body14.copyWith(color: AppColors.text)),
          ),
          IconButton(
            tooltip: closeLabel,
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            icon: const Icon(LucideIcons.x, size: 18, color: AppColors.text2),
            onPressed: () => messenger.hideCurrentSnackBar(),
          ),
        ]),
      ),
    ));
  }
}

/// Full-state hero for empty, error, success and pending screens
/// (COMPONENT_REGISTRY #14): 96 icon disc, 26/700 title, body, one action.
class StatusHero extends StatelessWidget {
  const StatusHero({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.actionLabel,
    this.onAction,
    this.tone = AppBannerTone.neutral,
  });

  final IconData icon;
  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final AppBannerTone tone;

  @override
  Widget build(BuildContext context) {
    final (fg, bg, _) = tone.style;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: tone == AppBannerTone.neutral ? AppColors.surface2 : bg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 44, color: fg),
          ),
        ),
        const SizedBox(height: 20),
        Semantics(
          header: true,
          child: Text(title,
              textAlign: TextAlign.center,
              style: AppTypography.title20.copyWith(
                  color: AppColors.text,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  height: 1.2)),
        ),
        if (body != null) ...[
          const SizedBox(height: 8),
          Text(body!,
              textAlign: TextAlign.center,
              style: AppTypography.body16.copyWith(color: AppColors.text2)),
        ],
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 24),
          AppButton(label: actionLabel!, onPressed: onAction),
        ],
      ],
    );
  }
}
