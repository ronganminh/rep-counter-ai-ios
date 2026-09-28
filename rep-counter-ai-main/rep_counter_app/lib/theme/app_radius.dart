import 'package:flutter/widgets.dart';

abstract final class AppRadius {
  static const r6 = 6.0;
  static const r8 = 8.0;
  static const r12 = 12.0;
  static const card = 16.0;
  static const r20 = 20.0;
  static const sheet = 28.0;
  static const guideZone = 32.0;
  static const pill = 999.0;
  static const cardBR = BorderRadius.all(Radius.circular(card));
  static const sheetBR = BorderRadius.vertical(top: Radius.circular(sheet));
  static const pillBR = BorderRadius.all(Radius.circular(pill));
}
