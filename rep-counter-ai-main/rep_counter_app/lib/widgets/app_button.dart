import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Button variants from COMPONENT_REGISTRY #2 / DESIGN_SYSTEM_TOKENS
/// `components.button`.
enum AppButtonVariant {
  /// Accent fill. One per screen.
  primary,

  /// Surface fill with a strong border.
  secondary,

  /// Transparent, muted text.
  ghost,

  /// Danger tint. Destructive actions stay this tone until confirmed.
  danger,

  /// Solid danger fill. Only after a typed confirmation.
  destructiveConfirmed,
}

/// Pill button with token heights (56 / 48 / 44), a 48 dp minimum hit area,
/// a loading state and no truncation at large text scales: the label wraps
/// and the button grows in height instead.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.loading = false,
    this.expand = true,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool loading;
  final bool expand;
  final String? semanticLabel;

  bool get _enabled => onPressed != null && !loading;

  double get _height => switch (variant) {
        AppButtonVariant.primary ||
        AppButtonVariant.destructiveConfirmed =>
          AppSpacing.buttonHeight,
        AppButtonVariant.secondary ||
        AppButtonVariant.danger =>
          AppSpacing.buttonHeightSmall,
        AppButtonVariant.ghost => AppSpacing.buttonHeightCompact,
      };

  (Color bg, Color fg, Color? border) _colors() {
    if (!_enabled && !loading) {
      return (AppColors.surface3, AppColors.text3, null);
    }
    return switch (variant) {
      AppButtonVariant.primary => (AppColors.accent, AppColors.onAccent, null),
      AppButtonVariant.secondary => (
          AppColors.surface2,
          AppColors.text,
          AppColors.borderStrong
        ),
      AppButtonVariant.ghost => (Colors.transparent, AppColors.textMuted, null),
      AppButtonVariant.danger => (
          AppColors.dangerTint,
          AppColors.dangerText,
          null
        ),
      AppButtonVariant.destructiveConfirmed => (
          AppColors.danger,
          AppColors.onAccent,
          null
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = _colors();
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        else if (icon != null)
          Icon(icon, size: 20, color: fg),
        if (loading || icon != null) const SizedBox(width: 10),
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.label16.copyWith(color: fg, height: 1.2),
          ),
        ),
      ],
    );
    return Semantics(
      button: true,
      enabled: _enabled,
      label: semanticLabel ?? label,
      // excludeSemantics drops the InkWell's action, so expose it here.
      onTap: _enabled ? onPressed : null,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight:
              _height < AppSpacing.minTouch ? AppSpacing.minTouch : _height,
          minWidth: AppSpacing.minTouch,
        ),
        child: Material(
          color: bg,
          shape: StadiumBorder(
            side: border == null ? BorderSide.none : BorderSide(color: border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _enabled ? onPressed : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
