import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/backend/backend_rpc.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/features/coach/coach_apply.dart';
import 'package:rep_counter_app/features/coach/coach_pick.dart';
import 'package:rep_counter_app/features/coach/coach_trend.dart';
import 'package:rep_counter_app/features/coach/presentation/coach_review_entry.dart';
import 'package:rep_counter_app/features/coach/presentation/coach_review_page.dart';
import 'package:rep_counter_app/features/coach/presentation/coach_today_card.dart';
import 'package:rep_counter_app/features/credits/ai_coach_v2.dart';
import 'package:rep_counter_app/features/credits/ai_credits.dart';
import 'package:rep_counter_app/features/credits/credits_controller.dart';
import 'package:rep_counter_app/features/plan/application/plan_repository.dart';
import 'package:rep_counter_app/features/plan/domain/local_date.dart';
import 'package:rep_counter_app/features/plan/domain/plan_templates.dart';
import 'package:rep_counter_app/features/plan/domain/workout_plan.dart';
import 'package:rep_counter_app/features/workout/data/workout_record.dart';
import 'package:rep_counter_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/l10n.dart';
import '../../support/sync_fixtures.dart';

/// AC-01 Coach's pick on Home and AC-02 Coach review (L-D45).

class FakeCoachAi implements CreditedAiApi {
  final calls = <({CreditedRequest kind, String requestId})>[];
  int credits = 10;
  Object? fail;
  Completer<void>? gate;
  Map<String, Object?> Function(CreditedRequest kind)? data;

  @override
  Future<CreditBalance> balance() async => CreditBalance(
      balance: credits,
      weeklyAllowance: 10,
      weekStart: DateTime.utc(2026, 11, 2),
      pro: false);

  @override
  Future<CreditedAnswer> ask({
    required String requestId,
    required CreditedRequest kind,
    required String locale,
    List<CoachMessage> messages = const [],
    Map<String, Object?>? context,
    int version = 1,
    String? memory,
  }) async {
    calls.add((kind: kind, requestId: requestId));
    await gate?.future;
    final f = fail;
    if (f != null) throw f;
    if (credits < 1) throw InsufficientCredits(credits);
    credits--;
    final d = (data ?? _default)(kind);
    return CreditedAnswer(
        requestId: requestId,
        // The server's `text` for chat is the reply (answerText).
        text: d['reply'] is String ? d['reply'] as String : 'text',
        balance: credits,
        data: d);
  }

  static Map<String, Object?> _default(CreditedRequest kind) => switch (kind) {
        CreditedRequest.planSuggestion => {
            'summary': 'You held 6 push-ups twice, so add one rep.',
            'horizon': 'tomorrow',
            'sessions': [
              {
                'day_offset': 1,
                'focus': 'Full body',
                'exercises': [
                  {
                    'exercise_id': 'push_up',
                    'sets': 3,
                    'reps': 7,
                    'rest_seconds': 90,
                    'change': 'increase',
                  }
                ]
              }
            ],
          },
        _ => {
            'summary': 'All sets done.',
            'fixes': ['Rest the full 90 s.', 'Keep a steady pace.'],
            'next_session': [
              {
                'exercise_id': 'push_up',
                'sets': 3,
                'reps': 8,
                'rest_seconds': 90,
                'change': 'increase',
              }
            ],
          },
      };
}

WorkoutRecord rec(String id, DateTime at, int reps) => WorkoutRecord(
      id: id,
      exerciseId: 'push_up',
      exerciseName: 'push_up',
      startedAt: at,
      durationSeconds: 75,
      reps: reps,
      sets: 1,
      targetReps: null,
      poseFrames: 0,
      readyFrames: 0,
      lostFrames: 0,
    );

void main() {
  late DateTime now;
  late PlanRepository plans;
  late FakeCoachAi api;
  late CreditsController credits;
  late List<WorkoutRecord> workouts;
  var n = 0;

  setUp(() async {
    SharedPreferences.setMockInitialValues({AiCoachV2.consentKey: true});
    now = DateTime(2026, 11, 2, 9); // Monday: Full Body A is planned
    workouts = [
      rec('w3', DateTime(2026, 10, 30, 18), 20),
      rec('w2', DateTime(2026, 10, 28, 18), 18),
      rec('w1', DateTime(2026, 10, 26, 18), 15),
    ];
    plans = PlanRepository(
        loadWorkouts: () async => const [],
        now: () => now,
        newId: () => 'id${++n}');
    await plans.activate(PlanTemplates.beginnerPlan(
        id: 'plan',
        startDate: LocalDate(2026, 11, 2),
        timezone: 'UTC',
        now: now));
    final (auth, _) = await authFor('a@x.com');
    api = FakeCoachAi();
    credits = CreditsController(auth: auth, api: api);
    await pumpEventQueue();
  });

  Widget app(Widget child, {AppLanguage lang = AppLanguage.en}) {
    final locale = LocaleController(lang);
    return LocaleScope(
      controller: locale,
      child: MaterialApp(
        theme: RepCoachTheme.dark(),
        locale: Locale(lang.code),
        supportedLocales: testSupportedLocales,
        localizationsDelegates: testLocalizationsDelegates,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
  }

  CoachTodayCard card({List<String>? opened}) => CoachTodayCard(
        credits: credits,
        plans: plans,
        loadWorkouts: () async => workouts,
        openSession: (_, id) async => opened?.add(id),
        onCameraWorkout: () {},
      );

  Future<void> settle(WidgetTester tester) async {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
  }

  group('CoachApply', () {
    const planned = [
      ExerciseTarget(exerciseId: 'push_up', sets: 3, reps: 6),
      ExerciseTarget(exerciseId: 'plank', sets: 2, seconds: 40),
    ];
    test('merges only matching exercises and kinds, never adds', () {
      final out = CoachApply.merge(planned, [
        const CoachTarget(
            exerciseId: 'push_up',
            sets: 3,
            reps: 7,
            restSeconds: 90,
            change: TargetChange.increase),
        const CoachTarget(
            exerciseId: 'squat',
            sets: 2,
            reps: 15,
            restSeconds: 60,
            change: TargetChange.increase),
        const CoachTarget(
            exerciseId: 'plank',
            sets: 2,
            reps: 10,
            restSeconds: 60,
            change: TargetChange.increase),
      ]);
      expect(out, hasLength(2));
      expect(out[0].reps, 7);
      expect(out[1], planned[1], reason: 'reps for a hold: kept');
      expect(CoachApply.changed(planned, out), [0]);
    });

    test('applies to a scheduled session only and undoes', () async {
      final view = (await plans.load())!;
      final s = CoachApply.nextSession(view, todayOnly: true)!;
      final next = [
        for (final t in s.exerciseTargets) t.copyWith(sets: t.sets + 1)
      ];
      final applier = CoachApplier(plans);
      final applied = (await applier.apply(s.id, next))!;
      var after =
          (await plans.load())!.sessions.firstWhere((x) => x.id == s.id);
      expect(after.exerciseTargets, next);
      await applier.undo(applied);
      after = (await plans.load())!.sessions.firstWhere((x) => x.id == s.id);
      expect(after.exerciseTargets, s.exerciseTargets);
      // A closed session never changes (logged workouts stay as they are).
      await plans.skip(s.id);
      expect(await applier.apply(s.id, next), isNull);
    });
  });

  test('trend: from recorded numbers, "none" without an earlier workout', () {
    final rows = CoachTrend.rows(workouts.first, workouts);
    expect(rows.first.direction, TrendDirection.up);
    expect(rows.first.before, 18);
    expect(CoachTrend.rows(workouts.last, workouts).single.direction,
        TrendDirection.none);
  });

  testWidgets('AC-01a: free pick on the phone, no AI request', (tester) async {
    final opened = <String>[];
    await tester.pumpWidget(app(card(opened: opened)));
    await settle(tester);
    expect(find.byKey(const Key('coach-pick')), findsOneWidget);
    expect(find.text("COACH'S PICK · TODAY"), findsOneWidget);
    expect(find.text('FULL BODY A'), findsOneWidget);
    expect(find.byKey(const Key('coach-pick-reason')), findsNothing);
    expect(api.calls, isEmpty, reason: 'D-29: free once a day');
    for (final k in [
      'coach-pick-start',
      'coach-pick-edit',
      'coach-pick-skip'
    ]) {
      expect(
          tester.getSize(find.byKey(Key(k))).height, greaterThanOrEqualTo(48));
    }
    await tester.tap(find.byKey(const Key('coach-pick-start')));
    await settle(tester);
    expect(opened, hasLength(1));
  });

  testWidgets('AC-01b: fewer than 3 workouts: no AI call, progress',
      (tester) async {
    workouts = workouts.take(2).toList();
    await tester.pumpWidget(app(card()));
    await settle(tester);
    expect(find.byKey(const Key('coach-pick-no-data')), findsOneWidget);
    expect(find.text('2 of 3 workouts saved'), findsOneWidget);
    expect(api.calls, isEmpty);
  });

  testWidgets('hidden without consent (D-30: Home unchanged)', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(app(card()));
    await settle(tester);
    expect(find.byKey(const Key('coach-pick')), findsNothing);
    expect(find.byKey(const Key('coach-pick-no-data')), findsNothing);
  });

  testWidgets('new suggestion: 1 credit, reason shown, Start applies + Undo',
      (tester) async {
    final opened = <String>[];
    await tester.pumpWidget(app(card(opened: opened)));
    await settle(tester);
    await tester.ensureVisible(find.byKey(const Key('coach-pick-regenerate')));
    await tester.tap(find.byKey(const Key('coach-pick-regenerate')));
    await settle(tester);
    expect(api.calls.single.kind, CreditedRequest.planSuggestion);
    expect(find.byKey(const Key('coach-pick-reason')), findsOneWidget);
    expect(find.textContaining('rest 90 s'), findsWidgets);
    await tester.ensureVisible(find.byKey(const Key('coach-pick-start')));
    await tester.tap(find.byKey(const Key('coach-pick-start')));
    await settle(tester);
    final view = (await tester.runAsync(plans.load))!;
    final s = view.sessions.firstWhere((x) => x.id == opened.single);
    expect(s.exerciseTargets.first.reps, 7, reason: 'written to today only');
    expect(find.text('Undo'), findsOneWidget);
  });

  testWidgets('AC-01d: no credits: nothing sent, pick stays', (tester) async {
    api.credits = 0;
    await credits.refresh();
    await tester.pumpWidget(app(card()));
    await settle(tester);
    final link = tester.widget<TextButton>(find.descendant(
        of: find.byKey(const Key('coach-pick-regenerate')),
        matching: find.byType(TextButton)));
    expect(link.onPressed, isNull);
    expect(find.byKey(const Key('coach-pick-start')), findsOneWidget);
    expect(api.calls, isEmpty);
  });

  testWidgets('failure: no charge, pick stays, retry reuses the request id',
      (tester) async {
    api.fail = const AiProviderFailed(10);
    await tester.pumpWidget(app(card()));
    await settle(tester);
    await tester.ensureVisible(find.byKey(const Key('coach-pick-regenerate')));
    await tester.tap(find.byKey(const Key('coach-pick-regenerate')));
    await settle(tester);
    expect(find.byKey(const Key('coach-pick-failed')), findsOneWidget);
    expect(find.byKey(const Key('coach-pick-start')), findsOneWidget);
    api.fail = null;
    await tester.tap(find.text('Try again'));
    await settle(tester);
    expect(api.calls, hasLength(2));
    expect(api.calls[1].requestId, api.calls[0].requestId);
    expect(find.byKey(const Key('coach-pick-reason')), findsOneWidget);
  });

  testWidgets('offline: banner, pick stays', (tester) async {
    api.fail = const BackendException('network');
    await tester.pumpWidget(app(card()));
    await settle(tester);
    await tester.ensureVisible(find.byKey(const Key('coach-pick-regenerate')));
    await tester.tap(find.byKey(const Key('coach-pick-regenerate')));
    await settle(tester);
    expect(find.byKey(const Key('coach-pick-offline')), findsOneWidget);
    expect(find.byKey(const Key('coach-pick-start')), findsOneWidget);
  });

  testWidgets('AC-01g: skip hides for today, Undo restores without AI',
      (tester) async {
    await tester.pumpWidget(app(card()));
    await settle(tester);
    await tester.ensureVisible(find.byKey(const Key('coach-pick-skip')));
    await tester.tap(find.byKey(const Key('coach-pick-skip')));
    await settle(tester);
    expect(find.byKey(const Key('coach-pick-skipped')), findsOneWidget);
    // Same day, new Home: still skipped (cached for the day, D-31).
    await tester.pumpWidget(app(const SizedBox()));
    await tester.pumpWidget(app(card()));
    await settle(tester);
    expect(find.byKey(const Key('coach-pick-skipped')), findsOneWidget);
    await tester.tap(find.byKey(const Key('coach-pick-undo')));
    await settle(tester);
    expect(find.byKey(const Key('coach-pick')), findsOneWidget);
    expect(api.calls, isEmpty);
  });

  testWidgets('AC-01f: edit sheet keeps the plan, never calls AI',
      (tester) async {
    await tester.pumpWidget(app(card()));
    await settle(tester);
    await tester.ensureVisible(find.byKey(const Key('coach-pick-regenerate')));
    await tester.tap(find.byKey(const Key('coach-pick-regenerate')));
    await settle(tester);
    await tester.ensureVisible(find.byKey(const Key('coach-pick-edit')));
    await tester.tap(find.byKey(const Key('coach-pick-edit')));
    await settle(tester);
    expect(find.text('Editing never uses AI credits.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('coach-edit-keep')));
    await tester.tap(find.byKey(const Key('coach-edit-save')));
    await settle(tester);
    final pick =
        (await tester.runAsync(() => CoachPickStore().load('u-a@x.com')));
    expect(pick?.useSuggestion ?? false, isFalse);
    expect(api.calls, hasLength(1));
  });

  group('AC-02 review', () {
    Future<void> open(WidgetTester tester, Widget child) async {
      tester.view.physicalSize = const Size(393, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final locale = LocaleController(AppLanguage.en);
      await tester.pumpWidget(LocaleScope(
          controller: locale,
          child: MaterialApp(
              theme: RepCoachTheme.dark(),
              supportedLocales: testSupportedLocales,
              localizationsDelegates: testLocalizationsDelegates,
              home: child)));
      await settle(tester);
    }

    Widget bare() => CoachReviewPage(
          record: workouts.first,
          credits: credits,
          plans: plans,
          loadWorkouts: () async => workouts,
        );

    testWidgets('ready: strengths, fixes, trend with words, apply + undo',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await open(tester, bare());
      expect(api.calls.single.kind, CreditedRequest.workoutReview);
      expect(find.byKey(const Key('coach-review-ready')), findsOneWidget);
      expect(find.text('All sets done.'), findsOneWidget);
      expect(find.text('Rest the full 90 s.'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^up\. ')), findsOneWidget);
      semantics.dispose();
      expect(find.text('1 AI credit used'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('coach-review-apply')));
      await tester.tap(find.byKey(const Key('coach-review-apply')));
      await settle(tester);
      expect(find.byKey(const Key('coach-apply-sheet')), findsOneWidget);
      expect(
          find.text(
              'Logged workouts are never changed. You can undo after applying.'),
          findsOneWidget);
      await tester.tap(find.byKey(const Key('coach-apply-accept')));
      await settle(tester);
      var s = (await tester.runAsync(plans.load))!.sessions.first;
      expect(s.exerciseTargets.first.reps, 8);
      expect(find.byKey(const Key('coach-applied-toast')), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await settle(tester);
      s = (await tester.runAsync(plans.load))!.sessions.first;
      expect(s.exerciseTargets.first.reps, 6);
    });

    testWidgets('dismiss changes nothing', (tester) async {
      await open(tester, bare());
      await tester.ensureVisible(find.byKey(const Key('coach-review-apply')));
      await tester.tap(find.byKey(const Key('coach-review-apply')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('coach-apply-dismiss')));
      await settle(tester);
      final s = (await tester.runAsync(plans.load))!.sessions.first;
      expect(s.exerciseTargets.first.reps, 6);
    });

    testWidgets('failed: no charge, retry reuses the request id',
        (tester) async {
      api.fail = const AiProviderFailed(10);
      await open(tester, bare());
      expect(find.byKey(const Key('coach-review-failed')), findsOneWidget);
      expect(find.text('Your workout is saved. No AI credit was used.'),
          findsOneWidget);
      api.fail = null;
      await tester.tap(find.byKey(const Key('coach-review-retry')));
      await settle(tester);
      expect(api.calls, hasLength(2));
      expect(api.calls[1].requestId, api.calls[0].requestId);
      expect(find.byKey(const Key('coach-review-ready')), findsOneWidget);
    });

    testWidgets('invalid JSON is an error, not shown (D-33)', (tester) async {
      api.data = (_) => {'nope': true};
      await open(tester, bare());
      expect(find.byKey(const Key('coach-review-failed')), findsOneWidget);
    });

    testWidgets('AC-02e no credits: no request, disabled button readable',
        (tester) async {
      api.credits = 0;
      await credits.refresh();
      await open(tester, bare());
      expect(api.calls, isEmpty);
      expect(find.byKey(const Key('coach-review-no-credits')), findsOneWidget);
      expect(find.text('Get Coach review'), findsOneWidget);
    });

    testWidgets('busy then ready (generating state is shown)', (tester) async {
      api.gate = Completer<void>();
      tester.view.physicalSize = const Size(393, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(LocaleScope(
          controller: LocaleController(AppLanguage.en),
          child: MaterialApp(
              theme: RepCoachTheme.dark(),
              supportedLocales: testSupportedLocales,
              localizationsDelegates: testLocalizationsDelegates,
              home: bare())));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      expect(find.byKey(const Key('coach-review-busy')), findsOneWidget);
      api.gate!.complete();
      await settle(tester);
      expect(find.byKey(const Key('coach-review-ready')), findsOneWidget);
    });
  });

  testWidgets('Results entry hidden with the flag off', (tester) async {
    await tester.pumpWidget(app(CoachReviewEntry(record: workouts.first)));
    expect(find.byKey(const Key('coach-review-entry')), findsNothing);
    expect(AiCoachV2.enabled, isFalse);
  });
}
