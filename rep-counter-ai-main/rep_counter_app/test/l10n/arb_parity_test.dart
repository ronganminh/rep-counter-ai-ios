import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/features/legal/onboarding_page.dart';
import 'package:rep_counter_app/l10n/app_localizations.dart';
import 'package:rep_counter_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _arb(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

Iterable<String> _keys(Map<String, dynamic> arb) =>
    arb.keys.where((k) => !k.startsWith('@'));

/// Top-level ICU argument names, e.g. `{count, plural, …}` → `count`.
Set<String> _arguments(String message) {
  final names = <String>{};
  var depth = 0;
  for (var i = 0; i < message.length; i++) {
    final c = message[i];
    if (c == '{') {
      if (depth == 0) {
        final m = RegExp(r'\{\s*(\w+)').matchAsPrefix(message, i);
        if (m != null) names.add(m.group(1)!);
      }
      depth++;
    } else if (c == '}') {
      depth--;
    }
  }
  return names;
}

void main() {
  final en = _arb('lib/l10n/app_en.arb');
  final vi = _arb('lib/l10n/app_vi.arb');

  test('EN and VI ARB files have identical key sets', () {
    expect(_keys(vi).toSet(), _keys(en).toSet());
    expect(en['@@locale'], 'en');
    expect(vi['@@locale'], 'vi');
  });

  test('EN and VI messages use the same ICU arguments', () {
    final mismatched = [
      for (final key in _keys(en))
        if (!setEquals(
            _arguments(en[key] as String), _arguments(vi[key] as String)))
          key,
    ];
    expect(mismatched, isEmpty);
  });

  test('app ARB files are byte-identical to the Final C handoff', () {
    for (final name in ['app_en.arb', 'app_vi.arb']) {
      final app = File('lib/l10n/$name').readAsBytesSync();
      final handoff = File('../../docs/design/v2-final-c/handoff/l10n/$name')
          .readAsBytesSync();
      expect(app, handoff, reason: name);
    }
  });

  test('generated lookups follow the glossary for the tab names', () {
    final enL = lookupAppLocalizations(const Locale('en'));
    final viL = lookupAppLocalizations(const Locale('vi'));
    expect([enL.navHome, enL.navProgress, enL.navProfile],
        ['Home', 'Progress', 'Profile']);
    expect([viL.navHome, viL.navProgress, viL.navProfile],
        ['Trang chủ', 'Tiến bộ', 'Hồ sơ']);
  });

  testWidgets('persisted language drives AppLocalizations and Material',
      (tester) async {
    SharedPreferences.setMockInitialValues({'app_language': 'vi'});
    await tester.pumpWidget(const RepCounterApp());
    await tester.pump();
    await tester.pump();

    BuildContext ctx() => tester.element(find.byType(OnboardingPage));
    expect(Localizations.localeOf(ctx()), const Locale('vi'));
    expect(AppLocalizations.of(ctx()).navProgress, 'Tiến bộ');
    expect(MaterialLocalizations.of(ctx()).backButtonTooltip, 'Quay lại');

    await LocaleScope.controllerOf(ctx()).set(AppLanguage.en);
    await tester.pump();
    expect(Localizations.localeOf(ctx()), const Locale('en'));
    expect(AppLocalizations.of(ctx()).navProgress, 'Progress');
    expect(MaterialLocalizations.of(ctx()).backButtonTooltip, 'Back');
  });
}
