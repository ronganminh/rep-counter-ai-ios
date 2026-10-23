import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/features/legal/onboarding_page.dart';
import 'package:rep_counter_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Owner decision (decision log L-D15): the app opens in English on a fresh
/// install; Vietnamese is chosen in Settings and then remembered.
void main() {
  Future<AppLanguage> loaded(Map<String, Object> prefs, String system) async {
    SharedPreferences.setMockInitialValues(prefs);
    final controller = LocaleController();
    addTearDown(controller.dispose);
    await controller.load(system);
    return controller.value;
  }

  test('fresh install defaults to English whatever the system language',
      () async {
    for (final system in ['vi', 'en', 'fr', 'ja']) {
      expect(await loaded({}, system), AppLanguage.en, reason: system);
    }
  });

  test('a saved choice always wins', () async {
    expect(await loaded({'app_language': 'vi'}, 'en'), AppLanguage.vi);
    expect(await loaded({'app_language': 'en'}, 'vi'), AppLanguage.en);
  });

  test('existing installs without a saved choice keep their old language',
      () async {
    // Before this change: system English -> EN, anything else -> VI.
    expect(await loaded({'onboarding_v1': true}, 'vi'), AppLanguage.vi);
    expect(await loaded({'onboarding_v1': true}, 'en'), AppLanguage.en);
  });

  test('switching to Vietnamese is persisted for the next launch', () async {
    SharedPreferences.setMockInitialValues({});
    final first = LocaleController();
    addTearDown(first.dispose);
    await first.load('en');
    await first.set(AppLanguage.vi);
    final next = LocaleController();
    addTearDown(next.dispose);
    await next.load('en');
    expect(next.value, AppLanguage.vi);
  });

  testWidgets('first launch shows onboarding in English', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const RepCounterApp());
    await tester.pump();
    await tester.pump();
    final context = tester.element(find.byType(OnboardingPage));
    expect(Localizations.localeOf(context), const Locale('en'));
    expect(LocaleScope.controllerOf(context).value, AppLanguage.en);
  });
}
