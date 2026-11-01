import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/backend/backend_rpc.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/features/auth/application/auth_scope.dart';
import 'package:rep_counter_app/features/legal/settings_page.dart';
import 'package:rep_counter_app/features/sync/presentation/sync_widgets.dart';
import 'package:rep_counter_app/features/sync/sync_controller.dart';
import 'package:rep_counter_app/features/sync/sync_scope.dart';
import 'package:rep_counter_app/features/workout/data/workout_history_store.dart';
import 'package:rep_counter_app/theme/app_theme.dart';
import 'package:rep_counter_app/widgets/app_feedback.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/l10n.dart';
import '../../support/sync_fixtures.dart';

/// A-2 wiring on screen, EN and VI: badge, merge offer and conflict choice,
/// D-20 delete scopes. The server is the in-memory one; nothing touches
/// the network.
void main() {
  final store = WorkoutHistoryStore();
  late TestServer server;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    server = TestServer();
  });

  Future<SyncController> controller(WidgetTester tester,
      {String? email = 'a@x.com'}) async {
    late SyncController c;
    await tester.runAsync(() async {
      final (auth, _) = await authFor(email);
      c = SyncController(
          auth: auth,
          workoutsApi: server,
          // Rounds run only when a test asks: no timers left behind.
          debounce: const Duration(days: 1),
          retryDelays: const []);
      c.start();
      await pumpEventQueue();
      await c.syncNow();
    });
    return c;
  }

  Future<void> pump(WidgetTester tester, SyncController sync, Widget home,
      {AppLanguage language = AppLanguage.en}) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final locale = LocaleController(language);
    addTearDown(locale.dispose);
    await tester.pumpWidget(LocaleScope(
      controller: locale,
      child: AuthScope(
        controller: sync.auth,
        child: SyncScope(
          controller: sync,
          child: MaterialApp(
            theme: RepCoachTheme.dark(),
            locale: language.locale,
            supportedLocales: testSupportedLocales,
            localizationsDelegates: testLocalizationsDelegates,
            home: home is SettingsPage
                ? home
                : Scaffold(body: ListView(children: [home])),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// Lets database and server futures started by a tap finish: they need
  /// real time as well as frames.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
  }

  Future<void> dispose(WidgetTester tester, SyncController c) async {
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  }

  for (final (language, synced, waiting, offer) in [
    (AppLanguage.en, 'Synced', 'Offline · 2 waiting to sync',
        '1 workout on this phone isn’t in your account yet.'),
    (AppLanguage.vi, 'Đã đồng bộ', 'Ngoại tuyến · 2 chờ đồng bộ',
        '1 buổi tập trên máy này chưa có trong tài khoản.'),
  ]) {
    testWidgets('badge and merge offer (${language.name})', (tester) async {
      // Trained as a guest before signing in: offered, never uploaded.
      await tester.runAsync(() => store.save(workout('guest-1')));
      final c = await controller(tester);
      await pump(tester, c, const SyncHomeStrip(), language: language);
      expect(find.text(synced), findsOneWidget);
      expect(find.text(offer), findsOneWidget);
      expect(server.live, isEmpty);

      await tester.runAsync(() async {
        server.fail = const BackendException('network');
        await store.save(workout('w1'));
        await store.save(workout('w2'));
        await c.syncNow();
      });
      await tester.pumpAndSettle();
      expect(find.text(waiting), findsOneWidget);
      expect(await tester.runAsync(() => store.load()), hasLength(3));
      await dispose(tester, c);
    });
  }

  testWidgets('guests see no sync UI at all', (tester) async {
    final c = await controller(tester, email: null);
    await pump(tester, c, const Column(
        children: [SyncHomeStrip(), SyncAccountSection()]));
    expect(find.byType(AppBanner), findsNothing);
    expect(find.text('Sync now'), findsNothing);
    await dispose(tester, c);
  });

  testWidgets('merge flow: preview, conflict choice, phone version wins',
      (tester) async {
    await tester.runAsync(() async {
      await store.save(workout('differs', reps: 7));
      await store.save(workout('new', reps: 3));
      final id = await WorkoutHistoryStore.exclusive((db) async =>
          (await db!.db.query('workouts',
                  where: 'id = ?', whereArgs: ['differs']))
              .single['client_id'] as String);
      await server.seed(workout('differs', reps: 70), clientId: id);
    });
    final c = await controller(tester);
    await pump(tester, c, const SyncAccountSection());
    expect(find.byKey(const Key('sync-merge-banner')), findsOneWidget);

    await tester.tap(find.text('Bring my workouts'));
    await settle(tester);
    expect(find.text('1 workout differs'), findsOneWidget);
    expect(find.byKey(const Key('merge-new')), findsOneWidget);

    await tester.tap(find.byKey(const Key('merge-keep-phone')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('merge-confirm')));
    await tester.tap(find.byKey(const Key('merge-confirm')));
    await settle(tester);

    expect(server.live.length, 2);
    expect(server.rows.values.map((w) => w.raw['reps']), containsAll([7, 3]));
    expect(find.byKey(const Key('sync-merge-banner')), findsNothing);
    await dispose(tester, c);
  });

  testWidgets('merge read fails: retry offered, nothing changes',
      (tester) async {
    await tester.runAsync(() => store.save(workout('mine')));
    final c = await controller(tester);
    await pump(tester, c, const SyncAccountSection(),
        language: AppLanguage.vi);
    server.fail = const BackendException('503');
    await tester.tap(find.text('Chuyển buổi tập của tôi'));
    await settle(tester);
    expect(find.byKey(const Key('merge-load-failed')), findsOneWidget);
    expect(find.text('Thử lại ngay'), findsOneWidget);
    expect(server.live, isEmpty);
    await dispose(tester, c);
  });

  group('D-20 delete scopes in Settings', () {
    Future<void> openSheet(WidgetTester tester) async {
      final row = find.text('Delete workout history');
      await tester.scrollUntilVisible(row, 200,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(row);
      await tester.pumpAndSettle();
    }

    Future<void> confirm(WidgetTester tester, String scope) async {
      await tester.tap(find.byKey(Key('delete-scope-$scope')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'DELETE');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('delete-history-confirm')));
      await settle(tester);
    }

    testWidgets('account scope offline: nothing deleted anywhere',
        (tester) async {
      final c = await controller(tester);
      await tester.runAsync(() async {
        await store.save(workout('w'));
        await c.syncNow();
      });
      await pump(tester, c, const SettingsPage());
      await openSheet(tester);
      expect(find.text('This phone only'), findsOneWidget);
      expect(find.text('My account'), findsOneWidget);
      expect(find.text('Both'), findsOneWidget);

      server.fail = const BackendException('network');
      await confirm(tester, 'both');
      expect(find.textContaining('nothing was deleted'), findsOneWidget);
      expect(server.live.length, 1);
      expect(await tester.runAsync(() => store.load()), hasLength(1));
      await dispose(tester, c);
    });

    testWidgets('phone scope keeps the account copy; account scope keeps '
        'the phone copy', (tester) async {
      final c = await controller(tester);
      await tester.runAsync(() async {
        await store.save(workout('w'));
        await c.syncNow();
      });
      await pump(tester, c, const SettingsPage());
      await openSheet(tester);
      await confirm(tester, 'phone');
      expect(await tester.runAsync(() => store.load()), isEmpty);
      expect(server.live.length, 1);

      await tester.runAsync(() async {
        await store.save(workout('w2'));
        await c.syncNow();
      });
      await openSheet(tester);
      await confirm(tester, 'account');
      expect(server.live, isEmpty);
      expect(await tester.runAsync(() => store.load()), hasLength(1));
      expect(find.text('Workout history deleted. Your account was not deleted.'),
          findsOneWidget);
      await dispose(tester, c);
    });
  });
}
