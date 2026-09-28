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
