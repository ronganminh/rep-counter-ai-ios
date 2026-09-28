import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

abstract final class RepCoachTheme {
  static ThemeData dark() => _build(Brightness.dark, AppPalette.dark);
  static ThemeData light() => _build(Brightness.light, AppPalette.light);

  static ThemeData _build(Brightness brightness, AppPalette palette) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: palette.accent,
      onPrimary: palette.onAccent,
      primaryContainer: palette.accentTint,
      onPrimaryContainer: palette.accentInk,
      secondary: palette.surface2,
      onSecondary: palette.text,
      tertiary: palette.success,
      onTertiary: palette.onAccent,
      error: palette.danger,
      onError: palette.onAccent,
      errorContainer: palette.dangerTint,
      onErrorContainer: palette.dangerText,
      surface: palette.bg,
      onSurface: palette.text,
      onSurfaceVariant: palette.text2,
      outline: palette.borderStrong,
      outlineVariant: palette.border,
      scrim: palette.scrim,
      shadow: Colors.black,
      inverseSurface: palette.text,
      onInverseSurface: palette.bg,
      inversePrimary: palette.accentInk,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.bg,
      canvasColor: palette.bg,
      fontFamily: 'Inter',
      textTheme: AppTypography.textTheme(palette.text, palette.text2),
      extensions: [palette],
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        backgroundColor: palette.bg,
        foregroundColor: palette.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardBR,
          side: BorderSide(color: palette.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
        backgroundColor: palette.accent,
        foregroundColor: palette.onAccent,
        disabledBackgroundColor: palette.surface2,
        disabledForegroundColor: palette.text3,
        minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
        shape: const StadiumBorder(),
        textStyle: AppTypography.label16,
        elevation: 0,
      )),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
        backgroundColor: palette.surface2,
        foregroundColor: palette.text,
        side: BorderSide(color: palette.borderStrong),
        minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
        shape: const StadiumBorder(),
        textStyle: AppTypography.label16,
      )),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        modalBackgroundColor: palette.surface,
        modalBarrierColor: palette.scrim,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: const Color(0x33FFFFFF),
        dragHandleSize: const Size(36, 5),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetBR),
      ),
      dividerTheme:
          DividerThemeData(color: palette.border, thickness: 1, space: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.accent,
        linearTrackColor: palette.surface2,
        circularTrackColor: palette.surface2,
      ),
    );
  }
}
