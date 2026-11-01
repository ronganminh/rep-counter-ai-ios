import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/features/auth/application/auth_scope.dart';
import 'package:rep_counter_app/features/home/presentation/home_screen.dart';
import 'package:rep_counter_app/features/sync/sync_controller.dart';
import 'package:rep_counter_app/features/sync/sync_scope.dart';
import 'package:rep_counter_app/features/workout/presentation/history_page.dart';
import 'package:rep_counter_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/l10n.dart';
import '../../support/sync_fixtures.dart';

/// Follow-up to A-2: Home and History reload by themselves when sync
/// writes account data into this phone; nothing changes when sync is off.
void main() {
  late TestServer server;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    server = TestServer();
  });

  test('dataRevision moves only when account data reached the phone',
      () async {
    final (auth, _) = await authFor('a@x.com');
    final c = SyncController(
        auth: auth,
        workoutsApi: server,
        debounce: const Duration(days: 1),
        retryDelays: const []);
    addTearDown(c.dispose);
    c.start();
    await pumpEventQueue();
    await c.syncNow();
    final start = c.dataRevision;
    await c.syncNow();
    expect(c.dataRevision, start, reason: 'nothing new');
    await server.seed(workout('tablet', reps: 33), clientId: 'c-t');
    await c.syncNow();
    expect(c.dataRevision, start + 1);
  });

  Future<SyncController> controller(WidgetTester tester) async =>
      (await tester.runAsync(() async {
        final (auth, _) = await authFor('a@x.com');
        final c = SyncController(
            auth: auth,
            workoutsApi: server,
            debounce: const Duration(days: 1),
            retryDelays: const []);
        c.start();
        await pumpEventQueue();
        await c.syncNow();
        return c;
      }))!;

  Future<void> pump(WidgetTester tester, SyncController c, Widget home) async {
    tester.view.physicalSize = const Size(393, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final locale = LocaleController(AppLanguage.en);
    addTearDown(locale.dispose);
    await tester.pumpWidget(LocaleScope(
      controller: locale,
      child: AuthScope(
        controller: c.auth,
        child: SyncScope(
          controller: c,
          child: MaterialApp(
            theme: RepCoachTheme.dark(),
            locale: AppLanguage.en.locale,
            supportedLocales: testSupportedLocales,
            localizationsDelegates: testLocalizationsDelegates,
            home: home,
          ),
        ),
      ),
    ));
    await settle(tester);
  }

  Future<void> pullFromTablet(WidgetTester tester, SyncController c) async {
    await tester.runAsync(() async {
      await server.seed(
          workout('tablet', reps: 33, at: DateTime.now().toUtc()),
          clientId: 'c-t');
      await c.syncNow();
    });
    await settle(tester);
  }

  testWidgets('Home shows a workout pulled from the account, no reload',
      (tester) async {
    final c = await controller(tester);
    await pump(tester, c, const HomeScreen());
    expect(find.text('Start with your first rep.'), findsOneWidget);
    await pullFromTablet(tester, c);
    expect(find.text('Start with your first rep.'), findsNothing);
    expect(find.textContaining('33 rep'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });

  testWidgets('History list updates in place when sync pulls', (tester) async {
    final c = await controller(tester);
    await pump(tester, c, const HistoryPage(sections: HistorySections.list));
    final before = find.textContaining('33').evaluate().length;
    await pullFromTablet(tester, c);
    expect(find.textContaining('33').evaluate().length, greaterThan(before));
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
}

/// Database and server futures need real time as well as frames.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)));
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pump();
}
