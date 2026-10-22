import 'package:flutter/widgets.dart';

abstract final class AppSpacing {
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 20.0;
  static const s6 = 24.0;
  static const s8 = 32.0;
  static const s10 = 40.0;
  static const s12 = 48.0;
  static const s14 = 56.0;
  static const minTouch = 48.0;
  static const buttonHeight = 56.0;
  static const buttonHeightSmall = 48.0;
  static const screenPadding = EdgeInsets.symmetric(horizontal: 24);
  static const listPadding = EdgeInsets.symmetric(horizontal: 16);
  static const cardPadding = EdgeInsets.all(20);

  // v2 (Final C) layout; existing screens keep the values above until restyled.
  static const screenPaddingV2 = EdgeInsets.symmetric(horizontal: 20);
  static const cardPaddingV2 = EdgeInsets.all(16);
  static const listRowMinHeight = 56.0;
  static const sectionGap = 12.0;
  static const buttonHeightCompact = 44.0;
}
