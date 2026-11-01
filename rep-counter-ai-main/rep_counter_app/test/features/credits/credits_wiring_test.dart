import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/backend/backend_rpc.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/features/auth/application/auth_controller.dart';
import 'package:rep_counter_app/features/auth/application/auth_scope.dart';
import 'package:rep_counter_app/features/credits/ai_credits.dart';
import 'package:rep_counter_app/features/credits/credits_controller.dart';
import 'package:rep_counter_app/features/credits/presentation/coach_page.dart';
import 'package:rep_counter_app/features/credits/presentation/credits_widgets.dart';
import 'package:rep_counter_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/l10n.dart';
import '../../support/sync_fixtures.dart';

/// The `ai-request` rules as the app sees them: one charge per request id,
/// refund on provider failure, 402 when empty. [next] scripts failures.
class FakeCreditedAi implements CreditedAiApi {
  FakeCreditedAi({this.balanceLeft = 10});

  int balanceLeft;
  final charged = <String>{};
  final requests = <({String id, CreditedRequest kind, int messages, Map<String, Object?>? context})>[];
  Object? next;
  Completer<void>? hang;

  @override
  Future<CreditBalance> balance() async {
    final e = next;
    if (e != null) {
      next = null;
      throw e;
    }
    return CreditBalance(
        balance: balanceLeft,
        weeklyAllowance: 10,
        weekStart: DateTime.utc(2026, 10, 26),
        pro: false);
  }

  @override
  Future<CreditedAnswer> ask({
    required String requestId,
    required CreditedRequest kind,
    required String locale,
    List<CoachMessage> messages = const [],
    Map<String, Object?>? context,
  }) async {
    requests.add((
      id: requestId,
      kind: kind,
      messages: messages.length,
      context: context
    ));
    if (hang != null) await hang!.future;
    final e = next;
    if (e != null) {
      next = null;
      if (e is _ChargeThenFail) {
        charged.add(requestId);
        balanceLeft--;
        throw const BackendException('network');
      }
      throw e;
    }
    if (charged.contains(requestId)) throw DuplicateAiRequest(balanceLeft);
    if (balanceLeft <= 0) throw InsufficientCredits(balanceLeft);
    charged.add(requestId);
    balanceLeft--;
    return CreditedAnswer(
        requestId: requestId, text: 'Answer ${requests.length}', balance: balanceLeft);
  }
}

/// The server charged and answered, but the answer was lost on the way.
class _ChargeThenFail {}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<(CreditsController, FakeCreditedAi)> signedIn(
      {int balance = 10}) async {
    final (auth, _) = await authFor('a@x.com');
    final api = FakeCreditedAi(balanceLeft: balance);
    final c = CreditsController(auth: auth, api: api);
    await pumpEventQueue();
    return (c, api);
  }

  group('CreditsController', () {
    test('off unless the flag is on', () async {
      expect(AiCredits.enabled, isFalse);
      final (auth, _) = await authFor('a@x.com');
      expect(createCreditsController(auth), isNull);
    });

    test('reads the balance when signed in, clears it for guests', () async {
      final (c, _) = await signedIn(balance: 7);
      expect(c.balance!.balance, 7);
      await c.auth.signOut();
      expect(c.balance, isNull);
    });

    test('a failed read keeps going and is reported', () async {
      final (auth, _) = await authFor('a@x.com');
      final api = FakeCreditedAi()..next = const BackendException('503');
      final c = CreditsController(auth: auth, api: api);
      await pumpEventQueue();
      expect(c.failed, isTrue);
      await c.refresh();
      expect(c.failed, isFalse);
      expect(c.balance!.balance, 10);
    });
  });

  group('CoachConversation', () {
    test('a question costs one credit; the balance follows', () async {
      final (c, api) = await signedIn();
      final chat = CoachConversation(c);
      await chat.ask('How deep?', locale: 'en');
      expect(chat.turns.single.state, CoachTurnState.answered);
      expect(chat.turns.single.answer, 'Answer 1');
      expect(c.balance!.balance, 9);
      await chat.ask('And tempo?', locale: 'vi');
      expect(api.requests.last.messages, 3, reason: 'previous Q+A + new Q');
    });

    test('provider failure: refunded, retry uses the same id', () async {
      final (c, api) = await signedIn();
      final chat = CoachConversation(c);
      api.next = AiProviderFailed(api.balanceLeft);
      await chat.ask('Q', locale: 'en');
      final turn = chat.turns.single;
      expect(turn.state, CoachTurnState.failed);
      expect(turn.failure, CoachFailure.provider);
      final id = turn.requestId;
      await chat.retry(turn, locale: 'en');
      expect(turn.state, CoachTurnState.answered);
      expect(api.requests.map((r) => r.id), [id, id]);
      expect(api.charged.length, 1);
    });

    test('offline and timeout: nothing charged, retry works', () async {
      final (c, api) = await signedIn();
      final chat = CoachConversation(c, timeout: const Duration(milliseconds: 50));
      api.next = const BackendException('network');
      await chat.ask('Q', locale: 'en');
      expect(chat.turns.single.failure, CoachFailure.offline);
      expect(c.balance!.balance, 10);

      api.hang = Completer<void>();
      await chat.retry(chat.turns.single, locale: 'en');
      expect(chat.turns.single.failure, CoachFailure.timeout);
      // The server finished after we stopped waiting: it charged once.
      api.hang!.complete();
      api.hang = null;
      await pumpEventQueue();
      expect(api.charged.length, 1);
      // Retrying that id is refused (409), never charged twice; the next
      // retry uses a new id.
      await chat.retry(chat.turns.single, locale: 'en');
      expect(chat.turns.single.state, CoachTurnState.failed);
      expect(api.charged.length, 1);
      await chat.retry(chat.turns.single, locale: 'en');
      expect(chat.turns.single.state, CoachTurnState.answered);
    });

    test('charged but the answer was lost: the retry gets a new id',
        () async {
      final (c, api) = await signedIn();
      final chat = CoachConversation(c);
      api.next = _ChargeThenFail();
      await chat.ask('Q', locale: 'en');
      final first = chat.turns.single.requestId;
      await chat.retry(chat.turns.single, locale: 'en');
      // The server answers 409 for that id; the app switches id.
      expect(chat.turns.single.state, CoachTurnState.failed);
      expect(chat.turns.single.requestId, isNot(first));
      await chat.retry(chat.turns.single, locale: 'en');
      expect(chat.turns.single.state, CoachTurnState.answered);
    });

    test('out of credits is its own state, not an error', () async {
      final (c, _) = await signedIn(balance: 0);
      expect(c.outOfCredits, isTrue);
      final chat = CoachConversation(c);
      await chat.ask('Q', locale: 'en');
      expect(chat.turns.single.state, CoachTurnState.outOfCredits);
    });

    test('401 marks the session expired', () async {
      final (c, api) = await signedIn();
      final chat = CoachConversation(c);
      api.next = const BackendException('http_401', status: 401);
      await chat.ask('Q', locale: 'en');
      expect(c.auth.state, isA<AuthExpired>());
    });

    test('analyses send aggregate numbers only', () async {
      final (c, api) = await signedIn();
      final chat = CoachConversation(c);
      final records = [
        workout('a', reps: 10, at: DateTime.utc(2026, 10, 27, 8)),
        workout('b', reps: 12, at: DateTime.utc(2026, 10, 29, 8)),
        workout('c', reps: 15, at: DateTime.utc(2026, 10, 30, 8)),
      ];
      await chat.analyze(CreditedRequest.progressReview, 'Review',
          CoachContext.progress(records, now: DateTime.utc(2026, 10, 31)),
          locale: 'en');
      final ctx = api.requests.single.context!;
      expect(ctx['workouts'], 3);
      expect(ctx['total_reps'], 37);
      expect((ctx['weeks'] as List).single, {
        'week_start': '2026-10-26',
        'workouts': 3,
        'reps': 37,
      });
      expect(api.requests.single.messages, 0);

      final last = CoachContext.lastWorkout(records.last);
      expect((last['workout'] as Map)['reps'], 15);
      expect(last.toString(), isNot(contains('landmark')));
    });
  });

  group('screens', () {
    Future<void> pump(WidgetTester tester, CreditsController c, Widget home,
        {AppLanguage language = AppLanguage.en}) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final locale = LocaleController(language);
      addTearDown(locale.dispose);
      await tester.pumpWidget(LocaleScope(
        controller: locale,
        child: AuthScope(
          controller: c.auth,
          child: CreditsScope(
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

    Future<(CreditsController, FakeCreditedAi)> setup(WidgetTester tester,
            {int balance = 7}) async =>
        (await tester.runAsync(() => signedIn(balance: balance)))!;

    for (final (language, chip, meter) in [
      (AppLanguage.en, '7 AI credits', '3 of 10 used'),
      (AppLanguage.vi, '7 lượt AI', 'Đã dùng 3/10'),
    ]) {
      testWidgets('Profile meter and AI Coach entry (${language.name})',
          (tester) async {
        final (c, _) = await setup(tester);
        await pump(
            tester,
            c,
            const Scaffold(
                body: SingleChildScrollView(child: CreditsProfileSection())),
            language: language);
        expect(find.text(chip), findsOneWidget);
        expect(find.textContaining(meter), findsOneWidget);
        expect(find.byKey(const Key('profile-ai-coach')), findsOneWidget);
      });
    }

    testWidgets('coach: consent once, answer, balance updates (VI)',
        (tester) async {
      final (c, api) = await setup(tester);
      await pump(tester, c,
          CoachPage(credits: c, loadWorkouts: () async => const []),
          language: AppLanguage.vi);
      expect(find.text('7 lượt AI'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('coach-input')), 'Câu hỏi');
      await tester.tap(find.byKey(const Key('coach-send')));
      await tester.pumpAndSettle();
      expect(find.text('Gửi cho HLV AI?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('coach-consent-accept')));
      await tester.pumpAndSettle();
      expect(find.text('Answer 1'), findsOneWidget);
      expect(find.text('6 lượt AI'), findsOneWidget);
      expect(api.charged.length, 1);

      // Asked only once.
      await tester.enterText(find.byKey(const Key('coach-input')), 'Again');
      await tester.tap(find.byKey(const Key('coach-send')));
      await tester.pumpAndSettle();
      expect(find.text('Gửi cho HLV AI?'), findsNothing);
      expect(find.text('Answer 2'), findsOneWidget);
    });

    testWidgets('coach: no credits left is neutral, no paywall (EN)',
        (tester) async {
      final (c, _) = await setup(tester, balance: 0);
      await pump(tester, c,
          CoachPage(credits: c, loadWorkouts: () async => const []));
      expect(find.text('No AI credits left this week'), findsOneWidget);
      expect(find.textContaining('Feedback after workouts stays free'),
          findsOneWidget);
      expect(find.textContaining('Pro'), findsNothing);
      final send = tester.widget<IconButton>(find.byKey(const Key('coach-send')));
      expect(send.onPressed, isNull);
    });

    testWidgets('coach: failure shows retry; retry is charged once',
        (tester) async {
      SharedPreferences.setMockInitialValues({CoachPage.consentKey: true});
      final (c, api) = await setup(tester);
      await pump(tester, c,
          CoachPage(credits: c, loadWorkouts: () async => const []));
      api.next = AiProviderFailed(api.balanceLeft);
      await tester.enterText(find.byKey(const Key('coach-input')), 'Q');
      await tester.tap(find.byKey(const Key('coach-send')));
      await tester.pumpAndSettle();
      expect(find.text('Message didn’t send'), findsOneWidget);
      await tester.tap(find.byKey(const Key('coach-retry')));
      await tester.pumpAndSettle();
      expect(find.text('Answer 2'), findsOneWidget);
      expect(api.charged.length, 1);
      expect(api.requests.first.id, api.requests.last.id);
    });

    testWidgets('analyses need saved workouts', (tester) async {
      SharedPreferences.setMockInitialValues({CoachPage.consentKey: true});
      final (c, api) = await setup(tester);
      await pump(
          tester,
          c,
          CoachPage(
              credits: c,
              loadWorkouts: () async => [workout('only', reps: 9)]));
      expect(find.text('Not enough history yet'), findsOneWidget);
      await tester.tap(find.byKey(const Key('coach-analyze-last')));
      await tester.pumpAndSettle();
      expect(api.requests.single.kind, CreditedRequest.advancedAnalysis);
      expect(find.text('Answer 1'), findsOneWidget);
    });
  });
}
