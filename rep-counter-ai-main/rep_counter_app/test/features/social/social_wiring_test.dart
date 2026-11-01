import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/app/app_link.dart';
import 'package:rep_counter_app/core/backend/backend_rpc.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/features/auth/application/auth_controller.dart';
import 'package:rep_counter_app/features/auth/application/auth_scope.dart';
import 'package:rep_counter_app/features/social/presentation/friends_page.dart';
import 'package:rep_counter_app/features/social/social.dart';
import 'package:rep_counter_app/features/social/supabase_social_api.dart';
import 'package:rep_counter_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/contract_rpc.dart';
import '../../support/l10n.dart';
import '../../support/sync_fixtures.dart';

/// A SocialApi that fails like staging offline.
class _OfflineSocial implements SocialApi {
  Never _fail() => throw const BackendException('network');
  @override
  Future<String> createInvite() async => _fail();
  @override
  Future<void> acceptInvite(String code) async => _fail();
  @override
  Future<void> respond(String userId, {required bool accept}) async => _fail();
  @override
  Future<FriendState> state(String userId) async => _fail();
  @override
  Future<void> block(String userId) async => _fail();
  @override
  Future<void> report(String userId, String reason) async => _fail();
  @override
  Future<List<FriendSummary>> friends() async => _fail();
  @override
  Future<List<LeaderboardRow>> leaderboard(String exerciseId) async => _fail();
  @override
  Future<void> setDisplayName(String userId, String name) async => _fail();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('links', () {
    test('friend links open Friends only when social is on', () async {
      final off = AppLinkRouter(loadWorkouts: () async => const []);
      expect(await off.resolve(const AppLink(AppLinkKind.invite, 'c1')),
          isA<LinkFallback>());
      final on = AppLinkRouter(
          loadWorkouts: () async => const [], socialEnabled: () => true);
      final invite = await on.resolve(const AppLink(AppLinkKind.invite, 'c1'));
      expect((invite as OpenFriends).inviteCode, 'c1');
      expect(await on.resolve(const AppLink(AppLinkKind.friendRequests)),
          isA<OpenFriends>());
      expect(await on.resolve(const AppLink(AppLinkKind.race, 'r')),
          isA<LinkFallback>(), reason: 'races are later (S-2)');
      expect(AppLink.parse(FriendsPage.inviteLink('abc')),
          const AppLink(AppLinkKind.invite, 'abc'));
    });
  });

  group('Friends', () {
    late InMemorySocialServer server;
    late List<String> shared;

    setUp(() {
      server = InMemorySocialServer()
        ..names.addAll({'me': 'Thanh', 'linh': 'Linh', 'sam': 'Sam'});
      shared = [];
    });

    Future<void> pump(WidgetTester tester, Widget home,
        {AppLanguage language = AppLanguage.en, AuthController? auth}) async {
      tester.view.physicalSize = const Size(393, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final locale = LocaleController(language);
      addTearDown(locale.dispose);
      Widget app = MaterialApp(
        theme: RepCoachTheme.dark(),
        locale: language.locale,
        supportedLocales: testSupportedLocales,
        localizationsDelegates: testLocalizationsDelegates,
        home: home,
      );
      app = SocialScope(api: server.as('me'), child: app);
      if (auth != null) app = AuthScope(controller: auth, child: app);
      await tester.pumpWidget(LocaleScope(controller: locale, child: app));
      await tester.pumpAndSettle();
    }

    FriendsPage page({String? code}) => FriendsPage(
        api: server.as('me'),
        inviteCode: code,
        share: (text) async => shared.add(text));

    for (final (language, invite, leaderboard, you) in [
      (AppLanguage.en, 'Invite a friend', 'LEADERBOARD', 'You'),
      (AppLanguage.vi, 'Mời một người bạn', 'BẢNG XẾP HẠNG', 'Bạn'),
    ]) {
      testWidgets('invite, share, leaderboard (${language.name})',
          (tester) async {
        // Linh is already a friend; both trained this week with the camera.
        final code = await server.as('linh').createInvite();
        await server.as('me').acceptInvite(code);
        await server.as('me').respond('linh', accept: true);
        server.cameraReps
          ..['me'] = {'push_up': 40}
          ..['linh'] = {'push_up': 55};

        await pump(tester, page(), language: language);
        expect(find.text(invite), findsWidgets);
        expect(find.text(leaderboard), findsOneWidget);
        expect(find.text(you), findsOneWidget);
        expect(find.text('55'), findsOneWidget);

        await tester.tap(find.byKey(const Key('friends-create-invite')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('friends-invite-card')), findsOneWidget);
        await tester.tap(find.byKey(const Key('friends-share-invite')));
        await tester.pumpAndSettle();
        expect(shared.single, startsWith('repcoach://invites/'));
      });
    }

    testWidgets('accept a request; decline another', (tester) async {
      // Opening Linh's and Sam's invites sends their requests to me.
      await server.as('me').acceptInvite(await server.as('linh').createInvite());
      await server.as('me').acceptInvite(await server.as('sam').createInvite());
      await pump(tester, page());
      expect(find.byKey(const Key('friend-request-linh')), findsOneWidget);
      await tester.tap(find.byKey(const Key('friend-accept-linh')));
      await tester.pumpAndSettle();
      expect(find.text('You and Linh are now friends'), findsOneWidget);
      expect(await server.as('me').state('linh'), FriendState.friends);
      await tester.tap(find.byKey(const Key('friend-decline-sam')));
      await tester.pumpAndSettle();
      expect(await server.as('me').state('sam'), FriendState.none);
    });

    testWidgets('a code from a link is prefilled; refusals are explained',
        (tester) async {
      final code = await server.as('linh').createInvite();
      await pump(tester, page(code: code), language: AppLanguage.vi);
      await tester.tap(find.byKey(const Key('friends-accept-code')));
      await tester.pumpAndSettle();
      expect(find.text('Xong. Hãy đồng ý lời mời bên dưới để trở thành bạn bè.'),
          findsOneWidget);
      expect(find.byKey(const Key('friend-request-linh')), findsOneWidget);
      expect(await server.as('me').state('linh'), FriendState.requestReceived);

      // The same code again: already used.
      await tester.enterText(find.byKey(const Key('friends-code')), code);
      await tester.tap(find.byKey(const Key('friends-accept-code')));
      await tester.pumpAndSettle();
      expect(find.text('Lời mời này đã được dùng.'), findsOneWidget);
    });

    testWidgets('block and report from the menu', (tester) async {
      final code = await server.as('linh').createInvite();
      await server.as('me').acceptInvite(code);
      await server.as('me').respond('linh', accept: true);
      await pump(tester, page());

      await tester.tap(find.byKey(const Key('friend-menu-linh')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Report').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('report-harassment')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('report-send')));
      await tester.pumpAndSettle();
      expect(server.reports.single.$3, 'harassment');
      expect(find.text('Report sent. Thank you.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('friend-menu-linh')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Block').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('friends-block-confirm')));
      await tester.pumpAndSettle();
      expect(await server.as('me').state('linh'), FriendState.blocked);
    });

    testWidgets('offline: a banner with retry, no crash', (tester) async {
      await pump(tester, FriendsPage(api: _OfflineSocial()));
      expect(find.byKey(const Key('friends-load-failed')), findsOneWidget);
      await tester.tap(find.byKey(const Key('friends-create-invite')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Nothing changed'), findsOneWidget);
    });

    testWidgets('the display name friends see', (tester) async {
      final auth =
          (await tester.runAsync(() async => (await authFor('a@x.com')).$1))!;
      await pump(tester, page(), auth: auth);
      await tester.enterText(
          find.byKey(const Key('friends-display-name')), '  Thanh N  ');
      await tester.tap(find.byKey(const Key('friends-save-name')));
      await tester.pumpAndSettle();
      expect(server.names['me'], 'Thanh N');
    });

        testWidgets('guests go through the auth gate (return-to)', (tester) async {
      final auth = (await tester.runAsync(() async => (await authFor(null)).$1))!;
      await pump(
          tester,
          Builder(
              builder: (context) => TextButton(
                  onPressed: () => openFriends(context),
                  child: const Text('open'))),
          auth: auth);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Friends need an account'), findsOneWidget);
      expect(find.text('After signing in you return to Friends.'), findsNothing);
      await tester.tap(find.byKey(const Key('gate-guest')));
      await tester.pumpAndSettle();
      expect(find.byType(FriendsPage), findsNothing);
    });
  });

  test('Supabase: the display name goes to my profiles row', () async {
    final rpc = ContractRpc(loadContract('social'), (_, __) => null);
    final api = SupabaseSocialApi(rpc, now: () => DateTime.utc(2026, 10, 31));
    await api.setDisplayName('u1', '  ${'x' * 90}  ');
    final row = rpc.upserts['profiles']!.single;
    expect(row['user_id'], 'u1');
    expect((row['display_name'] as String).length, 80);
    expect(row['updated_at'], '2026-10-31T00:00:00.000Z');
  });
}
