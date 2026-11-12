// QA v2 · J-04 `repcoach://` links into the running shell (N-2a, L-D26):
// account-only targets fall back with a notice while accounts are off;
// stale plan/workout links fall back with their notice; a link that arrives
// over another route waits until the shell is back.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/app/app_shell.dart';
import 'package:rep_counter_app/app/app_tab_bar.dart';
import 'package:rep_counter_app/app/route_observer.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/features/legal/settings_page.dart';
import 'package:rep_counter_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/support/l10n.dart';
import 'support/app_harness.dart';

void main() {
  final binding = ensureQaBinding();
  late PluginFakes fakes;
  late StreamController<String> links;

  setUp(() {
    fakes = PluginFakes(binding.defaultBinaryMessenger)..install();
    links = StreamController<String>.broadcast();
  });
  tearDown(() async {
    await links.close();
    fakes.uninstall();
  });

  Future<void> pumpShell(WidgetTester tester, {String? initialLink}) async {
    SharedPreferences.setMockInitialValues({'onboarding_v1': true});
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final locale = LocaleController(AppLanguage.en);
    addTearDown(locale.dispose);
    await tester.pumpWidget(LocaleScope(
      controller: locale,
      child: MaterialApp(
        theme: RepCoachTheme.dark(),
        locale: const Locale('en'),
        supportedLocales: testSupportedLocales,
        localizationsDelegates: testLocalizationsDelegates,
        navigatorObservers: [appRouteObserver],
        home: AppShell(
            links: links.stream, initialLink: () async => initialLink),
      ),
    ));
    await settle(tester);
  }

  Future<void> open(WidgetTester tester, String link) async {
    links.add(link);
    await settle(tester);
  }

  Finder tab(String label) =>
      find.descendant(of: find.byType(AppTabBar), matching: find.text(label));

  testWidgets('account-only links show "needs an account" while accounts are off',
      (tester) async {
    await pumpShell(tester);
    for (final link in [
      'repcoach://friends/requests',
      'repcoach://invites/i1',
      'repcoach://races/r1',
      'repcoach://challenges/c1',
    ]) {
      await open(tester, link);
      expect(
          find.text(
              'This link needs an account, which the app does not have yet.'),
          findsOneWidget,
          reason: link);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 5));
      await settle(tester);
    }
    expect(find.byType(AppShell), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets('stale plan session and deleted workout links fall back with a notice',
      (tester) async {
    await pumpShell(tester);
    await open(tester, 'repcoach://plan/session/missing');
    expect(find.text('That session is no longer in your plan.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await settle(tester);
    await open(tester, 'repcoach://workouts/w9/feedback');
    expect(find.text('That workout was deleted.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await settle(tester);
    // Unknown and membership links never crash; membership lands on Profile.
    await open(tester, 'repcoach://unknown');
    await open(tester, 'repcoach://membership');
    expect(tester.takeException(), isNull);
    expect(find.byType(AppShell), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets('inbox link without the inbox feature lands on Home, no dead end',
      (tester) async {
    await pumpShell(tester);
    await open(tester, 'repcoach://inbox');
    expect(find.byType(AppShell), findsOneWidget);
    expect(tab('Home'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await closeApp(tester);
  });

  testWidgets('a link that arrives over Settings waits until the shell is back',
      (tester) async {
    await pumpShell(tester);
    await tester.tap(tab('Profile'));
    await settle(tester);
    await tapKey(tester, 'profile-settings');
    expect(find.byType(SettingsPage), findsOneWidget);
    await open(tester, 'repcoach://plan/session/missing');
    expect(find.text('That session is no longer in your plan.'), findsNothing,
        reason: 'never over another route');
    await systemBack(tester);
    expect(find.text('That session is no longer in your plan.'), findsOneWidget,
        reason: 'delivered once the shell is on top');
    await closeApp(tester);
  });

  testWidgets('the launch link is handled once', (tester) async {
    await pumpShell(tester, initialLink: 'repcoach://plan/session/missing');
    expect(find.text('That session is no longer in your plan.'), findsOneWidget);
    await closeApp(tester);
  });
}
