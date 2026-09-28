import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// Compatibility entry point: all routes use the current product theme.
abstract final class AppTheme {
  static const green = AppColors.accent;
  static const ink = AppColors.bg;
  static ThemeData get dark => RepCoachTheme.dark();
}
