import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/features/coach/coach_safety.dart';
import 'package:rep_counter_app/features/coach/presentation/coach_chat_page.dart';
import 'package:rep_counter_app/features/coach/presentation/coach_week_card.dart';
import 'package:rep_counter_app/features/credits/ai_coach_v2.dart';
import 'package:rep_counter_app/features/credits/ai_credits.dart';
import 'package:rep_counter_app/features/credits/credits_controller.dart';
import 'package:rep_counter_app/features/plan/application/plan_repository.dart';
import 'package:rep_counter_app/features/plan/domain/local_date.dart';
import 'package:rep_counter_app/features/plan/domain/plan_templates.dart';
import 'package:rep_counter_app/features/workout/data/workout_record.dart';
import 'package:rep_counter_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/l10n.dart';
import '../../support/sync_fixtures.dart';
import 'coach_pick_review_test.dart' show FakeCoachAi, rec;

/// AC-03 consent + chat and AC-04 next week in My plan (L-D45).
void main() {
  late DateTime now;
  late PlanRepository plans;
  late FakeCoachAi api;
  late CreditsController credits;
  late List<WorkoutRecord> workouts;
  var n = 0;

  setUp(() async {
    SharedPreferences.setMockInitialValues({AiCoachV2.consentKey: true});
    now = DateTime.now();
    final monday = LocalDate.of(now).startOfWeek;
    workouts = [
      for (var i = 0; i < 6; i++)
        rec('w$i', now.subtract(Duration(days: 3 + i * 3)), 10 + i),
    ];
    plans = PlanRepository(
        loadWorkouts: () async => const [],
        now: () => now,
        newId: () => 'id${++n}');
    await plans.activate(PlanTemplates.beginnerPlan(
        id: 'plan', startDate: monday, timezone: 'UTC', now: now));
    final (auth, _) = await authFor('a@x.com');
    api = FakeCoachAi();
    credits = CreditsController(auth: auth, api: api);
    await pumpEventQueue();
  });

  Future<void> settle(WidgetTester tester) async {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
  }

  Future<void> pump(WidgetTester tester, Widget home,
      {AppLanguage lang = AppLanguage.en, double width = 393}) async {
    tester.view.physicalSize = Size(width, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(LocaleScope(
        controller: LocaleController(lang),
        child: MaterialApp(
            theme: RepCoachTheme.dark(),
            locale: Locale(lang.code),
            supportedLocales: testSupportedLocales,
            localizationsDelegates: testLocalizationsDelegates,
            home: home)));
    await settle(tester);
  }

  test('pain intent is detected EN and VI, ordinary questions are not', () {
    for (final q in [
      'My shoulder hurts',
      'knee pain after squats',
      'I think I injured my wrist',
      'Tôi đau vai',
      'bị chấn thương cổ tay',
    ]) {
      expect(CoachSafety.isPain(q), isTrue, reason: q);
    }
    for (final q in [
      'What should I train today?',
      'How was my last workout?',
      'Tuần sau tăng thế nào?',
      'painting the wall',
    ]) {
      expect(CoachSafety.isPain(q), isFalse, reason: q);
    }
  });

  group('AC-03 chat', () {
    Widget page() => CoachChatPage(credits: credits);

    testWidgets('empty: chips ≥ 48 dp, credits chip, composer note',
        (tester) async {
      await pump(tester, page());
      expect(find.text('Ask your coach'), findsOneWidget);
      expect(find.text('10 of 10 left'), findsOneWidget);
      expect(find.text('Each message uses 1 AI credit'), findsOneWidget);
      for (var i = 0; i < 4; i++) {
        expect(tester.getSize(find.byKey(Key('coach-chip-$i'))).height,
            greaterThanOrEqualTo(48));
      }
    });

    testWidgets('chip sends a v2 coach_chat message (1 credit)',
        (tester) async {
      api.data = (_) => {'reply': 'Full body A today.', 'memory': 'm'};
      await pump(tester, page());
      await tester.tap(find.byKey(const Key('coach-chip-0')));
      await settle(tester);
      expect(api.calls.single.kind, CreditedRequest.coachChat);
      expect(find.text('What should I train today?'), findsOneWidget);
      expect(find.byKey(const Key('coach-chat-reply')), findsOneWidget);
      expect(find.text('9 of 10 left'), findsOneWidget);
    });

    testWidgets('AC-03e pain: fixed safety reply, no request, no credit',
        (tester) async {
      await pump(tester, page());
      await tester.tap(find.byKey(const Key('coach-chip-1')));
      await settle(tester);
      expect(api.calls, isEmpty);
      expect(find.byKey(const Key('coach-chat-safety')), findsOneWidget);
      expect(find.textContaining("I can't assess pain"), findsOneWidget);
      expect(find.text('Safety replies don’t use AI credits'), findsOneWidget);
      expect(find.text('10 of 10 left'), findsOneWidget);
    });

    testWidgets('failure: retry reuses the request id', (tester) async {
      api.fail = const AiProviderFailed(10);
      await pump(tester, page());
      await tester.enterText(
          find.byKey(const Key('coach-chat-input')), 'How was my week?');
      await tester.tap(find.byKey(const Key('coach-chat-send')));
      await settle(tester);
      expect(find.byKey(const Key('coach-chat-failed')), findsOneWidget);
      api.fail = null;
      api.data = (_) => {'reply': 'Good week.', 'memory': ''};
      await tester.tap(find.byKey(const Key('coach-chat-retry')));
      await settle(tester);
      expect(api.calls, hasLength(2));
      expect(api.calls[1].requestId, api.calls[0].requestId);
      expect(find.text('Good week.'), findsOneWidget);
    });

    testWidgets('AC-03f no credits: paused with reset date, pain still free',
        (tester) async {
      api.credits = 0;
      await credits.refresh();
      await pump(tester, page());
      expect(find.byKey(const Key('coach-chat-out')), findsOneWidget);
      expect(find.textContaining('Resets '), findsOneWidget);
      expect(
          tester
              .widget<TextField>(find.byKey(const Key('coach-chat-input')))
              .enabled,
          isFalse);
      expect(
          tester
              .widget<OutlinedButton>(find.byKey(const Key('coach-chip-0')))
              .onPressed,
          isNull);
      await tester.tap(find.byKey(const Key('coach-chip-1')));
      await settle(tester);
      expect(find.byKey(const Key('coach-chat-safety')), findsOneWidget);
      expect(api.calls, isEmpty);
    });

    testWidgets('VI at 375 px: no overflow', (tester) async {
      await pump(tester, page(), lang: AppLanguage.vi, width: 375);
      expect(find.text('Hỏi Coach'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('AC-04 next week', () {
    Widget card() => Scaffold(
        body: SingleChildScrollView(
            child: CoachWeekCard(
                plans: plans,
                credits: credits,
                loadWorkouts: () async => workouts)));

    Map<String, Object?> week(CreditedRequest _) {
      final today = LocalDate.of(now);
      final nextMonday = today.startOfWeek.addDays(7);
      return {
        'summary': 'Add one push-up per set.',
        'horizon': 'next_week',
        'sessions': [
          {
            'day_offset': today.daysUntil(nextMonday).clamp(1, 7),
            'focus': 'Full body',
            // Every beginner template has one of these two.
            'exercises': [
              for (final id in ['curl', 'overhead_extension'])
                {
                  'exercise_id': id,
                  'sets': 4,
                  'reps': 10,
                  'rest_seconds': 90,
                  'change': 'increase',
                  'note': '+1 set.',
                }
            ]
          }
        ],
      };
    }

    testWidgets('< 14 days of history: no request, progress', (tester) async {
      workouts = [rec('w', now.subtract(const Duration(days: 4)), 10)];
      await pump(tester, card());
      expect(find.byKey(const Key('coach-week-no-data')), findsOneWidget);
      expect(find.text('5 of 14 days tracked'), findsOneWidget);
      expect(api.calls, isEmpty);
    });

    testWidgets('suggest → apply a day → undo; apply all; keep my plan',
        (tester) async {
      api.data = week;
      await pump(tester, card());
      expect(find.byKey(const Key('coach-week-offer')), findsOneWidget);
      await tester.tap(find.byKey(const Key('coach-week-generate')));
      await settle(tester);
      expect(api.calls.single.kind, CreditedRequest.planSuggestion);
      expect(find.byKey(const Key('coach-week')), findsOneWidget);
      expect(find.textContaining('2 AI credits used'), findsOneWidget);
      final apply = find.byWidgetPredicate((w) =>
          w.key is ValueKey<String> &&
          (w.key as ValueKey<String>).value.startsWith('coach-week-apply-') &&
          !(w.key as ValueKey<String>)
              .value
              .startsWith('coach-week-apply-all'));
      expect(apply, findsOneWidget);
      expect(tester.getSize(apply).height, greaterThanOrEqualTo(48));
      final id = (tester.widget(apply).key as ValueKey<String>)
          .value
          .substring('coach-week-apply-'.length);
      final before = (await tester.runAsync(plans.load))!
          .sessions
          .firstWhere((x) => x.id == id)
          .exerciseTargets;
      await tester.tap(apply);
      await settle(tester);
      var s = (await tester.runAsync(plans.load))!
          .sessions
          .firstWhere((x) => x.id == id);
      expect(s.exerciseTargets, isNot(before));
      expect(s.exerciseTargets.where((t) => t.sets == 4), isNotEmpty);
      expect(find.text('Applied'), findsOneWidget);
      await tester.tap(find.byKey(Key('coach-week-undo-$id')));
      await settle(tester);
      s = (await tester.runAsync(plans.load))!
          .sessions
          .firstWhere((x) => x.id == id);
      expect(s.exerciseTargets, before);
      // Apply all asks first, then writes.
      await tester.tap(find.byKey(const Key('coach-week-apply-all')));
      await settle(tester);
      expect(
          find.byKey(const Key('coach-week-apply-all-sheet')), findsOneWidget);
      expect(
          find.text(
              'Reminders move with their sessions. Logged workouts are never changed.'),
          findsOneWidget);
      await tester.tap(find.byKey(const Key('coach-week-apply-all-confirm')));
      await settle(tester);
      s = (await tester.runAsync(plans.load))!
          .sessions
          .firstWhere((x) => x.id == id);
      expect(s.exerciseTargets, isNot(before));
      await tester.ensureVisible(find.byKey(const Key('coach-week-keep')));
      await tester.tap(find.byKey(const Key('coach-week-keep')));
      await settle(tester);
      expect(find.byKey(const Key('coach-week')), findsNothing);
      expect(api.calls, hasLength(1));
    });

    testWidgets('failure: plan unchanged, no credit', (tester) async {
      api.fail = const AiProviderFailed(10);
      await pump(tester, card());
      await tester.tap(find.byKey(const Key('coach-week-generate')));
      await settle(tester);
      expect(find.byKey(const Key('coach-week-failed')), findsOneWidget);
      expect(find.byKey(const Key('coach-week-offer')), findsOneWidget);
    });

    testWidgets('hidden without consent', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pump(tester, card());
      expect(find.byKey(const Key('coach-week-offer')), findsNothing);
      expect(find.byKey(const Key('coach-week-no-data')), findsNothing);
    });
  });
}
