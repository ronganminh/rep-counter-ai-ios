import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/app/app_link.dart';
import 'package:rep_counter_app/core/backend/backend_rpc.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/features/auth/application/auth_controller.dart';
import 'package:rep_counter_app/features/auth/application/auth_scope.dart';
import 'package:rep_counter_app/features/inbox/inbox_controller.dart';
import 'package:rep_counter_app/features/inbox/presentation/inbox_page.dart';
import 'package:rep_counter_app/features/inbox/push_inbox.dart';
import 'package:rep_counter_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/l10n.dart';
import '../../support/sync_fixtures.dart';

/// The in-memory inbox, able to fail like staging offline.
class FlakyInbox extends InMemoryPushInbox {
  FlakyInbox() : super(now: () => DateTime.utc(2026, 10, 31, 9));
  bool fail = false;
  int markCalls = 0;

  @override
  Future<List<InboxItem>> inbox() async {
    if (fail) throw const BackendException('network');
    return super.inbox();
  }

  @override
  Future<void> markRead(String id) async {
    markCalls++;
    if (fail) throw const BackendException('network');
    return super.markRead(id);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  FlakyInbox seeded() => FlakyInbox()
    ..send(kind: 'system', link: 'repcoach://membership', title: 'Welcome')
    ..send(
        kind: 'friend_request',
        link: 'repcoach://friends/requests',
        title: 'Linh sent you a friend request',
        body: 'Accept or decline in Friends.');

  group('InboxController', () {
    test('off unless the flag is on', () async {
      expect(PushInbox.inboxEnabled, isFalse);
      final (auth, _) = await authFor('a@x.com');
      expect(createInboxController(auth), isNull);
    });

    test('reads for the signed-in user, newest first; marks read', () async {
      final api = seeded();
      final (auth, _) = await authFor('a@x.com');
      final c = InboxController(auth: auth, api: api);
      await pumpEventQueue();
      expect(c.items.first.title, 'Linh sent you a friend request');
      expect(c.unreadCount, 2);
      await c.markRead(c.items.first);
      expect(c.unreadCount, 1);
      await c.refresh();
      expect(c.unreadCount, 1, reason: 'the server agrees');
      await c.markAllRead();
      expect(c.unreadCount, 0);
    });

    test('offline: marked read here, nothing lost, banner state', () async {
      final api = seeded();
      final (auth, _) = await authFor('a@x.com');
      final c = InboxController(auth: auth, api: api);
      await pumpEventQueue();
      api.fail = true;
      await c.markRead(c.items.first);
      expect(c.unreadCount, 1);
      await c.refresh();
      expect(c.failed, isTrue);
      expect(c.items.length, 2, reason: 'last list kept');
      api.fail = false;
      await c.refresh();
      expect(c.failed, isFalse);
    });

    test('guests have no inbox; 401 expires the session', () async {
      final (guestAuth, _) = await authFor(null);
      final g = InboxController(auth: guestAuth, api: seeded());
      await pumpEventQueue();
      expect(g.items, isEmpty);

      final api = seeded()..fail = true;
      final (auth, _) = await authFor('a@x.com');
      final c = InboxController(auth: auth, api: _Expired(api));
      await pumpEventQueue();
      expect(auth.state, isA<AuthExpired>());
      expect(c.items, isEmpty);
    });

    test('inbox links open the inbox when it exists', () async {
      final on = AppLinkRouter(
          loadWorkouts: () async => const [], inboxEnabled: () => true);
      expect(await on.resolve(const AppLink(AppLinkKind.inbox)),
          isA<OpenInbox>());
      final off = AppLinkRouter(loadWorkouts: () async => const []);
      expect(await off.resolve(const AppLink(AppLinkKind.inbox)),
          isA<LinkFallback>());
    });
  });

  group('screens', () {
    Future<InboxController> controller(WidgetTester tester,
            {FlakyInbox? api, String? email = 'a@x.com'}) async =>
        (await tester.runAsync(() async {
          final (auth, _) = await authFor(email);
          final c = InboxController(auth: auth, api: api ?? seeded());
          await pumpEventQueue();
          return c;
        }))!;

    Future<void> pump(WidgetTester tester, InboxController c, Widget home,
        AppLanguage language) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final locale = LocaleController(language);
      addTearDown(locale.dispose);
      await tester.pumpWidget(LocaleScope(
        controller: locale,
        child: AuthScope(
          controller: c.auth,
          child: InboxScope(
            controller: c,
            child: MaterialApp(
              theme: RepCoachTheme.dark(),
              locale: language.locale,
              supportedLocales: testSupportedLocales,
              localizationsDelegates: testLocalizationsDelegates,
              home: home,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    for (final (language, title, unread, bell) in [
      (AppLanguage.en, 'Notifications', '2 unread', 'Notifications, 2 unread'),
      (AppLanguage.vi, 'Thông báo', '2 chưa đọc', 'Thông báo, 2 chưa đọc'),
    ]) {
      testWidgets('bell, list, open a link (${language.name})', (tester) async {
        final c = await controller(tester);
        await pump(tester, c,
            const Scaffold(body: Center(child: InboxBell())), language);
        expect(find.byTooltip(bell), findsOneWidget);
        expect(find.text('2'), findsOneWidget);

        await tester.tap(find.byKey(const Key('home-inbox-bell')));
        await tester.pumpAndSettle();
        expect(find.text(title), findsOneWidget);
        expect(find.text(unread), findsOneWidget);
        expect(find.text('Linh sent you a friend request'), findsOneWidget);
      });
    }

    testWidgets('tapping an item marks it read and hands its link on',
        (tester) async {
      final c = await controller(tester);
      final opened = <String>[];
      await pump(
          tester,
          c,
          Builder(
              builder: (context) => TextButton(
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => InboxPage(
                              controller: c, openLink: opened.add))),
                  child: const Text('open'))),
          AppLanguage.en);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Welcome'));
      await tester.pumpAndSettle();
      expect(opened, ['repcoach://membership']);
      expect(find.byType(InboxPage), findsNothing);
      expect(c.unreadCount, 1);
    });

    testWidgets('mark all read; empty inbox', (tester) async {
      final c = await controller(tester);
      await pump(tester, c, InboxPage(controller: c), AppLanguage.en);
      await tester.tap(find.byKey(const Key('inbox-read-all')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('inbox-unread-count')), findsNothing);

      final empty = await controller(tester, api: FlakyInbox());
      await pump(tester, empty, InboxPage(controller: empty), AppLanguage.vi);
      expect(find.text('Chưa có thông báo'), findsOneWidget);
    });

    testWidgets('offline: banner with retry, no crash', (tester) async {
      final api = seeded();
      final c = await controller(tester, api: api);
      api.fail = true;
      await pump(tester, c, InboxPage(controller: c), AppLanguage.en);
      expect(find.byKey(const Key('inbox-failed')), findsOneWidget);
      expect(find.text('Welcome'), findsOneWidget, reason: 'last list kept');
    });

    testWidgets('guests see no bell', (tester) async {
      final c = await controller(tester, email: null);
      await pump(tester, c, const Scaffold(body: InboxBell()), AppLanguage.en);
      expect(find.byKey(const Key('home-inbox-bell')), findsNothing);
    });
  });
}

class _Expired implements PushInboxApi {
  _Expired(this.inner);
  final PushInboxApi inner;
  @override
  Future<List<InboxItem>> inbox() async =>
      throw const BackendException('PGRST303');
  @override
  Future<void> markRead(String id) => inner.markRead(id);
  @override
  Future<void> registerToken(PushPlatform platform, String token) =>
      inner.registerToken(platform, token);
  @override
  Future<void> unregisterToken(String token) => inner.unregisterToken(token);
}
