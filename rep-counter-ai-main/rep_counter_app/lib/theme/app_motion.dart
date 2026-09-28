import 'package:flutter/animation.dart';

abstract final class AppMotion {
  static const repPulseDuration = Duration(milliseconds: 240);
  static const repPulseCurve = Cubic(0.34, 1.56, 0.64, 1);
  static const repPulseScale = 1.08;
  static const repFlashDuration = Duration(milliseconds: 400);
  static const fade = Duration(milliseconds: 160);
  static const press = Duration(milliseconds: 120);
  static const progress = Duration(milliseconds: 320);
  static const progressCurve = Cubic(0.34, 1.3, 0.64, 1);
  static const holdToEnd = Duration(seconds: 1);
  static const readyHold = Duration(milliseconds: 1500);
}
