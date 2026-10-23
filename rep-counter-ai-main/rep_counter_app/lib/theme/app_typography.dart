import 'package:flutter/material.dart';

abstract final class AppTypography {
  static const _tabular = [FontFeature.tabularFigures()];

  static TextStyle _barlow(double size, FontWeight weight, double height,
          {double spacingEm = 0}) =>
      TextStyle(
        fontFamily: 'Barlow Condensed',
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: size * spacingEm,
        fontFeatures: _tabular,
      );

  static TextStyle _inter(double size, FontWeight weight, double height,
          {double spacingEm = 0}) =>
      TextStyle(
        fontFamily: 'Inter',
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: size * spacingEm,
      );

  static TextStyle get hero =>
      _barlow(200, FontWeight.w800, .85, spacingEm: -.02);
  static TextStyle get metric64 => _barlow(64, FontWeight.w800, .9);
  static TextStyle get metric40 => _barlow(40, FontWeight.w800, .9);
  static TextStyle get display40 => _barlow(40, FontWeight.w800, 1);
  static TextStyle get headline28 =>
      _inter(28, FontWeight.w700, 1.2, spacingEm: -.01);
  static TextStyle get title20 => _inter(20, FontWeight.w600, 1.3);
  static TextStyle get body16 => _inter(16, FontWeight.w400, 1.5);
  static TextStyle get label16 => _inter(16, FontWeight.w700, 1);
  static TextStyle get body14 => _inter(14, FontWeight.w500, 1.45);
  static TextStyle get caption12 =>
      _inter(12, FontWeight.w600, 1.4, spacingEm: .06);

  // Final C additions. Barlow Condensed uses line height >= 1.0 with even
  // leading so numerals and stacked Vietnamese diacritics are not clipped
  // (COMPONENT_REGISTRY V-9).
  static TextStyle _barlowV2(double size, FontWeight weight) =>
      _barlow(size, weight, 1)
          .copyWith(leadingDistribution: TextLeadingDistribution.even);

  static TextStyle get hudCounter => _barlowV2(120, FontWeight.w800);
  static TextStyle get metric96 => _barlowV2(96, FontWeight.w800);
  static TextStyle get stat30 => _barlowV2(30, FontWeight.w800);
  static TextStyle get title22 => _inter(22, FontWeight.w700, 1.25);
  static TextStyle get row15 => _inter(15, FontWeight.w600, 1.35);
  // The token file gives no line height for tab labels; keep the font default.
  static TextStyle get tab11 => const TextStyle(
      fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w600);

  static TextTheme textTheme(Color text, Color text2) => TextTheme(
        displayLarge: hero.copyWith(color: text),
        displayMedium: metric64.copyWith(color: text),
        displaySmall: display40.copyWith(color: text),
        headlineMedium: headline28.copyWith(color: text),
        titleLarge: title20.copyWith(color: text),
        bodyLarge: body16.copyWith(color: text),
        bodyMedium: body14.copyWith(color: text),
        labelLarge: label16.copyWith(color: text),
        labelSmall: caption12.copyWith(color: text2),
      );
}
