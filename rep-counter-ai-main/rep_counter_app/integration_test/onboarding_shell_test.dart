// QA v2 · J-01 onboarding → shell, language persistence, Android back.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/app/app_shell.dart';
import 'package:rep_counter_app/app/app_tab_bar.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/features/legal/onboarding_page.dart';
import 'package:rep_counter_app/features/legal/settings_page.dart';
import 'package:rep_counter_app/features/profile/presentation/profile_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_harness.dart';

void main() {
  final binding = ensureQaBinding();
  late PluginFakes fakes;

  setUp(() {
    fakes = PluginFakes(binding.defaultBinaryMessenger)..install();
  });
  tearDown(() => fakes.uninstall());

  Finder tab(String label) =>
      find.descendant(of: find.byType(AppTabBar), matching: find.text(label));

  testWidgets('fresh install: English onboarding, 3 pages, then the 5-tab shell',
      (tester) async {
    await pumpApp(tester);
    expect(find.byType(OnboardingPage), findsOneWidget);
    expect(find.text('Your phone counts.\nAI coaches.'), findsOneWidget,
        reason: 'L-D15: a fresh install opens in English');
    // No permission is asked at launch (Apple HIG, Play prominent disclosure).
    expect(fakes.permissionCalls, isEmpty);
    expect(fakes.notificationCalls.where((c) => c.contains('request')),
        isEmpty);

    // Next through the three pages; Privacy and Terms links are reachable.
    await tapText(tester, 'Continue');
    await tapText(tester, 'Continue');
    expect(find.text('Your data.\nYour control.'), findsOneWidget);
    expect(find.text('Privacy'), findsOneWidget);
    expect(find.text('Terms'), findsOneWidget);
    await tapText(tester, 'Start training');

    expect(find.byType(AppShell), findsOneWidget);
    for (final label in ['Home', 'Exercises', 'Train', 'Progress', 'Profile']) {
      expect(tab(label), findsOneWidget, reason: label);
    }
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_v1'), isTrue);
    await closeApp(tester);
  });

  testWidgets('Skip on the first page also finishes onboarding',
      (tester) async {
    await pumpApp(tester);
    await tapText(tester, 'Skip');
    expect(find.byType(AppShell), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getBool('onboarding_v1'),
        isTrue);
    await closeApp(tester);
  });

  testWidgets('second launch skips onboarding; Android back on Home is safe',
      (tester) async {
    await pumpApp(tester, prefs: {'onboarding_v1': true, 'app_language': 'en'});
    expect(find.byType(OnboardingPage), findsNothing);
    expect(find.byType(AppShell), findsOneWidget);
    // System back on the shell root: no crash, no exception, shell stays
    // (the OS decides whether the app goes to background).
    await systemBack(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(AppShell), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets('language switch in Settings relabels the tabs and persists',
      (tester) async {
    await pumpApp(tester, prefs: {'onboarding_v1': true, 'app_language': 'en'});
    await tester.tap(tab('Profile'));
    await settle(tester);
    expect(find.byType(ProfilePage), findsOneWidget);
    await tapKey(tester, 'profile-settings');
    expect(find.byType(SettingsPage), findsOneWidget);

    final dropdown = find.byType(DropdownButton<AppLanguage>);
    expect(dropdown, findsOneWidget);
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await settle(tester);
    await tester.tap(find.text(AppLanguage.vi.label).last);
    await settle(tester);

    expect((await SharedPreferences.getInstance()).getString('app_language'),
        'vi');
    await systemBack(tester); // Settings → Profile
    for (final label in ['Trang chủ', 'Bài tập', 'Tập', 'Tiến bộ', 'Hồ sơ']) {
      expect(tab(label), findsOneWidget, reason: label);
    }
    await closeApp(tester);

    // Relaunch: the saved choice wins over the system language.
    await pumpApp(tester, prefs: {'onboarding_v1': true, 'app_language': 'vi'});
    expect(tab('Hồ sơ'), findsOneWidget);
    await closeApp(tester);
  });
}
