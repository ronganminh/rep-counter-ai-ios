import 'package:flutter/material.dart';

abstract final class AppColors {
  static const bg = Color(0xFF0B0B0C);
  static const surface = Color(0xFF161618);
  static const surface2 = Color(0xFF202023);
  static const surface3 = Color(0xFF2A2A2E);
  static const surfaceHover = Color(0xFF1B1B1E);
  static const track = Color(0xFF3A3A3F);
  static const border = Color(0x14FFFFFF);
  static const borderStrong = Color(0x24FFFFFF);
  static const text = Color(0xFFF4F4F0);
  static const text2 = Color(0xFFA1A1A6);
  static const text3 = Color(0xFF7C7C82);
  static const textDisabled = Color(0xFF5C5C62);
  static const accent = Color(0xFFC8FF2E);
  static const accentHover = Color(0xFFD6FF5C);
  static const onAccent = Color(0xFF0B0B0C);
  static const accentTint = Color(0x1FC8FF2E);
  static const accentTintSoft = Color(0x14C8FF2E);
  static const accentBorder = Color(0x52C8FF2E);
  static const success = Color(0xFF3DDC97);
  static const successTint = Color(0x1F3DDC97);
  static const warning = Color(0xFFFF8A3D);
  static const warningText = Color(0xFFFFB27F);
  static const warningTint = Color(0x1FFF8A3D);
  static const danger = Color(0xFFFF5A5F);
  static const dangerText = Color(0xFFFF6B70);
  static const dangerTint = Color(0x1FFF5A5F);
  static const scrim = Color(0x9E000000);

  static const lightBg = Color(0xFFF6F6F3);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurface2 = Color(0xFFEDEDEA);
  static const lightText = Color(0xFF111112);
  static const lightText2 = Color(0xFF5C5C62);
  static const lightText3 = Color(0xFF7C7C82);
  static const lightAccentInk = Color(0xFF4A6B00);
}

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.surface3,
    required this.surfaceHover,
    required this.track,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.text2,
    required this.text3,
    required this.textDisabled,
    required this.accent,
    required this.accentInk,
    required this.onAccent,
    required this.accentTint,
    required this.accentTintSoft,
    required this.accentBorder,
    required this.success,
    required this.successTint,
    required this.warning,
    required this.warningText,
    required this.warningTint,
    required this.danger,
    required this.dangerText,
    required this.dangerTint,
    required this.scrim,
  });

  final Color bg, surface, surface2, surface3, surfaceHover, track;
  final Color border, borderStrong, text, text2, text3, textDisabled;
  final Color accent,
      accentInk,
      onAccent,
      accentTint,
      accentTintSoft,
      accentBorder;
  final Color success, successTint, warning, warningText, warningTint;
  final Color danger, dangerText, dangerTint, scrim;

  static const dark = AppPalette(
    bg: AppColors.bg,
    surface: AppColors.surface,
    surface2: AppColors.surface2,
    surface3: AppColors.surface3,
    surfaceHover: AppColors.surfaceHover,
    track: AppColors.track,
    border: AppColors.border,
    borderStrong: AppColors.borderStrong,
    text: AppColors.text,
    text2: AppColors.text2,
    text3: AppColors.text3,
    textDisabled: AppColors.textDisabled,
    accent: AppColors.accent,
    accentInk: AppColors.accent,
    onAccent: AppColors.onAccent,
    accentTint: AppColors.accentTint,
    accentTintSoft: AppColors.accentTintSoft,
    accentBorder: AppColors.accentBorder,
    success: AppColors.success,
    successTint: AppColors.successTint,
    warning: AppColors.warning,
    warningText: AppColors.warningText,
    warningTint: AppColors.warningTint,
    danger: AppColors.danger,
    dangerText: AppColors.dangerText,
    dangerTint: AppColors.dangerTint,
    scrim: AppColors.scrim,
  );

  static const light = AppPalette(
    bg: AppColors.lightBg,
    surface: AppColors.lightSurface,
    surface2: AppColors.lightSurface2,
    surface3: Color(0xFFE2E2DE),
    surfaceHover: Color(0xFFF1F1EE),
    track: Color(0xFFD4D4D0),
    border: Color(0x14000000),
    borderStrong: Color(0x1F000000),
    text: AppColors.lightText,
    text2: AppColors.lightText2,
    text3: AppColors.lightText3,
    textDisabled: Color(0xFFA1A1A6),
    accent: AppColors.accent,
    accentInk: AppColors.lightAccentInk,
    onAccent: AppColors.onAccent,
    accentTint: Color(0x1A4A6B00),
    accentTintSoft: Color(0x0F4A6B00),
    accentBorder: Color(0x404A6B00),
    success: Color(0xFF0F7A4F),
    successTint: Color(0x1A0F7A4F),
    warning: Color(0xFFB24A00),
    warningText: Color(0xFFB24A00),
    warningTint: Color(0x1AB24A00),
    danger: Color(0xFFC8323A),
    dangerText: Color(0xFFC8323A),
    dangerTint: Color(0x14C8323A),
    scrim: Color(0x66000000),
  );

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color lerp(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      bg: lerp(bg, other.bg),
      surface: lerp(surface, other.surface),
      surface2: lerp(surface2, other.surface2),
      surface3: lerp(surface3, other.surface3),
      surfaceHover: lerp(surfaceHover, other.surfaceHover),
      track: lerp(track, other.track),
      border: lerp(border, other.border),
      borderStrong: lerp(borderStrong, other.borderStrong),
      text: lerp(text, other.text),
      text2: lerp(text2, other.text2),
      text3: lerp(text3, other.text3),
      textDisabled: lerp(textDisabled, other.textDisabled),
      accent: lerp(accent, other.accent),
      accentInk: lerp(accentInk, other.accentInk),
      onAccent: lerp(onAccent, other.onAccent),
      accentTint: lerp(accentTint, other.accentTint),
      accentTintSoft: lerp(accentTintSoft, other.accentTintSoft),
      accentBorder: lerp(accentBorder, other.accentBorder),
      success: lerp(success, other.success),
      successTint: lerp(successTint, other.successTint),
      warning: lerp(warning, other.warning),
      warningText: lerp(warningText, other.warningText),
      warningTint: lerp(warningTint, other.warningTint),
      danger: lerp(danger, other.danger),
      dangerText: lerp(dangerText, other.dangerText),
      dangerTint: lerp(dangerTint, other.dangerTint),
      scrim: lerp(scrim, other.scrim),
    );
  }
}

extension AppPaletteX on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}
