import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/theme/app_colors.dart';
import 'package:rep_counter_app/theme/app_motion.dart';
import 'package:rep_counter_app/theme/app_radius.dart';
import 'package:rep_counter_app/theme/app_spacing.dart';
import 'package:rep_counter_app/theme/app_typography.dart';
import 'package:rep_counter_app/widgets/product_ui.dart';

/// Final C token file shipped with the design handoff (unmodified copy).
const _tokenPath =
    '../../docs/design/v2-final-c/handoff/DESIGN_SYSTEM_TOKENS.json';

Color _hex(String value) =>
    Color(int.parse('FF${value.substring(1)}', radix: 16));

double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  final tokens =
      jsonDecode(File(_tokenPath).readAsStringSync()) as Map<String, dynamic>;
  final dark = tokens['color']['dark'] as Map<String, dynamic>;

  test('solid dark colours match the Final C token file', () {
    final expected = <String, Color>{
      'bg': AppColors.bg,
      'surface': AppColors.surface,
      'surface2': AppColors.surface2,
      'surface3': AppColors.surface3,
      'surfaceHover': AppColors.surfaceHover,
      'track': AppColors.track,
      'text': AppColors.text,
      'text2': AppColors.text2,
      'text3': AppColors.text3,
      'textMuted': AppColors.textMuted,
      'textDisabled': AppColors.textDisabled,
      'accent': AppColors.accent,
      'accentHover': AppColors.accentHover,
      'onAccent': AppColors.onAccent,
      'success': AppColors.success,
      'warning': AppColors.warning,
      'warningText': AppColors.warningText,
      'danger': AppColors.danger,
      'dangerText': AppColors.dangerText,
      'info': AppColors.info,
    };
    expected.forEach((name, color) {
      expect(color, _hex(dark[name] as String), reason: name);
    });
  });

  test('scrims match token alpha values', () {
    expect(AppColors.sheetScrim.a, closeTo(0.55, 0.005));
    expect(AppColors.dialogScrim.a, closeTo(0.6, 0.005));
    expect(AppColors.scrim.a, closeTo(0.62, 0.005), reason: 'scrimStrong');
    expect(AppColors.hudGlass.a, closeTo(0.55, 0.005));
  });

  test('radius, motion and spacing match the token file', () {
    final radius = tokens['radius'] as Map<String, dynamic>;
    expect(AppRadius.r10, radius['r10']);
    expect(AppRadius.r14, radius['r14']);
    expect(AppRadius.r24, radius['r24']);
    expect(AppRadius.card, radius['card']);
    expect(AppRadius.sheet, radius['sheet']);

    final durations = tokens['motion']['durations'] as Map<String, dynamic>;
    expect(AppMotion.sheet.inMilliseconds, durations['sheet']);
    expect(AppMotion.page.inMilliseconds, durations['page']);
    expect(AppMotion.press.inMilliseconds, durations['press']);
    expect(AppMotion.holdToEnd.inMilliseconds, durations['holdToFinish']);

    final spacing = tokens['spacing'] as Map<String, dynamic>;
    expect(
        AppSpacing.screenPaddingV2.left, spacing['screenPaddingH']['design']);
    expect(AppSpacing.listRowMinHeight, spacing['listRowMinHeight']);
    expect(AppSpacing.minTouch, greaterThanOrEqualTo(48));
  });

  test('type scale additions match the token file', () {
    final scale = tokens['typography']['scale'] as Map<String, dynamic>;
    void check(TextStyle style, String key) {
      final t = scale[key] as Map<String, dynamic>;
      expect(style.fontFamily, t['family'], reason: key);
      expect(style.fontSize, (t['size'] as num).toDouble(), reason: key);
      expect(style.fontWeight!.value, t['weight'], reason: key);
    }

    check(AppTypography.hudCounter, 'hudCounter');
    check(AppTypography.metric96, 'metric96');
    check(AppTypography.stat30, 'stat30');
    check(AppTypography.title22, 'title22');
    check(AppTypography.row15, 'row15');
    check(AppTypography.tab11, 'tab11');
    // V-9: Barlow line height >= 1.0 so numerals are not clipped.
    for (final s in [
      AppTypography.hudCounter,
      AppTypography.metric96,
      AppTypography.stat30,
    ]) {
      expect(s.height, greaterThanOrEqualTo(1));
      expect(s.leadingDistribution, TextLeadingDistribution.even);
    }
  });

  test('Barlow Condensed 600, 700 and 800 are bundled (D-26)', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final (file, weight) in [
      ('BarlowCondensed-SemiBold.ttf', 600),
      ('BarlowCondensed-Bold.ttf', 700),
      ('BarlowCondensed-ExtraBold.ttf', 800),
    ]) {
      expect(File('assets/fonts/$file').existsSync(), isTrue, reason: file);
      expect(
          pubspec, contains('assets/fonts/$file\n          weight: $weight'));
    }
  });

  test('contrast: text3 fails AA body on cards, text2 passes (D-25)', () {
    expect(_contrast(AppColors.text3, AppColors.surface), lessThan(4.5));
    expect(_contrast(AppColors.text2, AppColors.surface),
        greaterThanOrEqualTo(4.5));
    expect(_contrast(AppColors.text2, AppColors.surface2),
        greaterThanOrEqualTo(4.5));
    expect(_contrast(AppColors.textMuted, AppColors.surface),
        greaterThanOrEqualTo(4.5));
    expect(_contrast(AppColors.info, AppColors.surface2),
        greaterThanOrEqualTo(4.5));
  });

  testWidgets('shared card text uses text2, not text3 (D-25)', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(extensions: const [AppPalette.dark]),
      home: const Scaffold(
        body: Column(children: [
          SettingsRow(
              icon: Icons.info, title: 'Title', subtitle: 'Subtitle text'),
          MetricCard(label: 'Reps', value: '35'),
        ]),
      ),
    ));
    final subtitle = tester.widget<Text>(find.text('Subtitle text'));
    expect(subtitle.style!.color, AppColors.text2);
    final label = tester.widget<Text>(find.text('REPS'));
    expect(label.style!.color, AppColors.text2);
  });
}
