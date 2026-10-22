import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/app/app_shell.dart';
import 'package:rep_counter_app/app/app_tab_bar.dart';
import 'package:rep_counter_app/app/route_observer.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/features/exercises/presentation/exercise_picker_screen.dart';
import 'package:rep_counter_app/features/home/presentation/home_screen.dart';
import 'package:rep_counter_app/features/legal/settings_page.dart';
import 'package:rep_counter_app/features/profile/presentation/profile_page.dart';
import 'package:rep_counter_app/features/workout/presentation/goal_setup_page.dart';
import 'package:rep_counter_app/features/workout/presentation/history_page.dart';
import 'package:rep_counter_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/l10n.dart';

Future<void> _pump(WidgetTester tester,
    {AppLanguage language = AppLanguage.vi,
    Size size = const Size(393, 852),
    double scale = 1}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final locale = LocaleController(language);
  addTearDown(locale.dispose);
  await tester.pumpWidget(LocaleScope(
    controller: locale,
    child: MaterialApp(
      theme: RepCoachTheme.dark(),
      locale: language.locale,
      supportedLocales: testSupportedLocales,
      localizationsDelegates: testLocalizationsDelegates,
      navigatorObservers: [appRouteObserver],
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!),
      home: const AppShell(),
    ),
  ));
  await tester.pumpAndSettle();
}

Finder _tab(String label) =>
    find.descendant(of: find.byType(AppTabBar), matching: find.text(label));

void main() {
  testWidgets('five tabs in the approved order with glossary labels',
      (tester) async {
    await _pump(tester);
    final labels = tester
        .widgetList<Text>(find.descendant(
            of: find.byType(AppTabBar), matching: find.byType(Text)))
        .map((t) => t.data)
        .toList();
    expect(labels, ['Trang chủ', 'Bài tập', 'Tập', 'Tiến bộ', 'Hồ sơ']);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.bySemanticsLabel('Điều hướng chính'), findsOneWidget);
  });

  testWidgets('English labels follow the persisted language', (tester) async {
    await _pump(tester, language: AppLanguage.en);
    for (final label in ['Home', 'Exercises', 'Train', 'Progress', 'Profile']) {
      expect(_tab(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('each tab opens its existing screen', (tester) async {
    await _pump(tester);
    await tester.tap(_tab('Bài tập'));
    await tester.pumpAndSettle();
    expect(find.byType(ExercisePickerScreen), findsOneWidget);
    await tester.tap(_tab('Tiến bộ'));
    await tester.pumpAndSettle();
    expect(find.byType(HistoryPage), findsOneWidget);
    await tester.tap(_tab('Hồ sơ'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfilePage), findsOneWidget);
    await tester.tap(_tab('Trang chủ'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selected tab is exposed to screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);
    await tester.tap(_tab('Tiến bộ'));
    await tester.pumpAndSettle();
    expect(
        tester.getSemantics(find
            .ancestor(of: _tab('Tiến bộ'), matching: find.byType(Semantics))
            .first),
        matchesSemantics(
            label: 'Tiến bộ',
            isButton: true,
            isSelected: true,
            hasSelectedState: true,
            hasTapAction: true));
    handle.dispose();
  });

  testWidgets('Train opens the start sheet over the current tab',
      (tester) async {
    await _pump(tester);
    await tester.tap(_tab('Tiến bộ'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tab-train')));
    await tester.pumpAndSettle();
    expect(find.byType(GoalSetupContent), findsOneWidget);
    // Closing the sheet leaves the user where they were.
    Navigator.of(tester.element(find.byType(GoalSetupContent))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(GoalSetupContent), findsNothing);
    expect(find.byType(HistoryPage), findsOneWidget);
  });

  testWidgets('Settings is reachable from Profile, full screen, with Back',
      (tester) async {
    await _pump(tester);
    await tester.tap(_tab('Hồ sơ'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-settings')));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
    // Pushed routes cover the shell: no tab bar (D-02).
    expect(find.byType(AppTabBar), findsNothing);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(ProfilePage), findsOneWidget);
    expect(find.byType(AppTabBar), findsOneWidget);
  });

  testWidgets('guest profile states data stays on this phone', (tester) async {
    await _pump(tester);
    await tester.tap(_tab('Hồ sơ'));
    await tester.pumpAndSettle();
    expect(find.text('Chỉ trên máy này'), findsOneWidget);
    expect(find.text('Tập, lịch sử và đếm hoạt động không cần tài khoản.'),
        findsOneWidget);
    // No sign-in entry until a real auth provider exists (A-1 blocked).
    expect(find.text('Đăng nhập'), findsNothing);
  });

  testWidgets('tab bar meets tap-target guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    handle.dispose();
  });

  for (final language in AppLanguage.values) {
    testWidgets('no overflow on a small phone at 2.0x · ${language.code}',
        (tester) async {
      await _pump(tester,
          language: language, size: const Size(375, 667), scale: 2);
      for (final tab in AppTab.values.where((t) => t != AppTab.train)) {
        final index = AppTab.values.indexOf(tab);
        await tester.tap(find
            .descendant(of: find.byType(AppTabBar), matching: find.byType(Text))
            .at(index));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: tab.name);
      }
    });
  }
}
