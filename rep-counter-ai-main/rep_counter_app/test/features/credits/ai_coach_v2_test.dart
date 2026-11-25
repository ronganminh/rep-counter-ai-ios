import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/backend/backend_rpc.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/features/auth/application/auth_scope.dart';
import 'package:rep_counter_app/features/credits/ai_coach_v2.dart';
import 'package:rep_counter_app/features/credits/ai_credits.dart';
import 'package:rep_counter_app/features/credits/credits_controller.dart';
import 'package:rep_counter_app/features/credits/presentation/coach_page.dart';
import 'package:rep_counter_app/features/credits/supabase_ai_credits_api.dart';
import 'package:rep_counter_app/features/plan/application/plan_repository.dart';
import 'package:rep_counter_app/features/plan/domain/local_date.dart';
import 'package:rep_counter_app/features/plan/domain/plan_templates.dart';
import 'package:rep_counter_app/features/plan/presentation/overload_page.dart';
import 'package:rep_counter_app/features/workout/data/workout_record.dart';
import 'package:rep_counter_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/contract_rpc.dart';
import '../../support/l10n.dart';
import '../../support/sync_fixtures.dart';

/// AI-1 coach v2, the virtual PT (L-D43): structured answers, the plan
/// context, "Apply to plan" through the PL-1c review, chat memory on the
/// phone, the v2 wire format and the usage limit.

const review = {
  'summary': 'Solid set; the last reps slowed down.',
  'fixes': ['Keep elbows at 45 degrees', 'Breathe out on the push'],
  'next_session': [
    {
      'exercise_id': 'push_up',
      'sets': 3,
      'reps': 7,
      'seconds': null,
      'rest_seconds': 90,
      'change': 'increase',
      'note': 'One more rep per set.',
    },
    {
      'exercise_id': 'burpee',
      'sets': 2,
      'reps': 5,
      'seconds': null,
      'rest_seconds': 60,
      'change': 'maintain',
      'note': '',
    },
  ],
};

/// Scripted `ai-request`: answers with [data] and records what was sent.
class ScriptedAi implements CreditedAiApi {
  Map<String, Object?>? data = review;
  String? memoryOut;
  Object? fail;
  final sent = <({CreditedRequest kind, int version, String? memory, int messages, Map<String, Object?>? context})>[];
  var _balance = 10;

  @override
  Future<CreditBalance> balance() async => CreditBalance(
      balance: _balance,
      weeklyAllowance: 10,
      weekStart: DateTime.utc(2026, 11, 23),
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
    sent.add((
      kind: kind,
      version: version,
      memory: memory,
      messages: messages.length,
      context: context
    ));
    final f = fail;
    if (f != null) throw f;
    return CreditedAnswer(
        requestId: requestId,
        text: 'Plain text',
        balance: --_balance,
        data: data,
        memory: memoryOut);
  }
}

final monday = LocalDate(2026, 11, 2);

WorkoutRecord workout() => WorkoutRecord(
      id: 'w1',
      exerciseId: 'push_up',
      exerciseName: 'Push-up',
      startedAt: DateTime(2026, 11, 1, 9),
      durationSeconds: 120,
      reps: 18,
      sets: 3,
      targetReps: 6,
      poseFrames: 100,
      readyFrames: 90,
      lostFrames: 2,
    );

void main() {
  late PlanRepository repo;
  var n = 0;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = PlanRepository(
        loadWorkouts: () async => const [],
        now: () => DateTime(2026, 11, 2, 8),
        newId: () => 'id${++n}');
  });

  Future<PlanView> activePlan() async {
    await repo.activate(PlanTemplates.beginnerPlan(
        id: 'plan',
        startDate: monday,
        timezone: 'UTC',
        now: DateTime(2026, 11, 2, 8)));
    return (await repo.load())!;
  }

  test('off unless ENABLE_AI_COACH_V2 (and credits) are on', () {
    expect(AiCoachV2.enabled, isFalse);
    expect(AiCoachV2.consentKey, isNot(CoachPage.consentKey));
  });

  group('answers', () {
    test('a workout review keeps only targets the plan model allows', () {
      final a = CoachAnswer.parse(CreditedRequest.workoutReview, {
        ...review,
        'next_session': [
          ...review['next_session']! as List,
          {'exercise_id': 'squat', 'sets': 11, 'reps': 5, 'rest_seconds': 60, 'change': 'increase'},
          {'exercise_id': 'plank', 'sets': 2, 'reps': 5, 'seconds': 30, 'rest_seconds': 60, 'change': 'increase'},
          {'exercise_id': 'plank', 'sets': 2, 'seconds': 30, 'rest_seconds': 60, 'change': 'maintain'},
        ],
      })! as CoachWorkoutReview;
      expect(a.fixes, hasLength(2));
      expect(a.targets.map((t) => t.exerciseId), ['push_up', 'burpee', 'plank']);
      expect(a.targets.last.isDuration, isTrue);
      expect(CoachAnswer.parse(CreditedRequest.workoutReview, {'summary': 's', 'fixes': []}), isNull);
      expect(CoachAnswer.parse(CreditedRequest.workoutReview, null), isNull);
      expect(CoachAnswer.parse(CreditedRequest.coachChat, review), isNull);
    });

    test('a plan suggestion: valid days only, first target per exercise', () {
      final t = (review['next_session']! as List).first;
      final a = CoachAnswer.parse(CreditedRequest.planSuggestion, {
        'summary': 'Two sessions and a rest day',
        'horizon': 'next_week',
        'sessions': [
          {'day_offset': 1, 'focus': 'Push', 'exercises': [t]},
          {'day_offset': 3, 'focus': 'Push again', 'exercises': [{...t as Map, 'reps': 8}]},
          {'day_offset': 9, 'focus': 'Too far', 'exercises': [t]},
        ],
      })! as CoachPlanSuggestion;
      expect(a.nextWeek, isTrue);
      expect(a.sessions.map((s) => s.dayOffset), [1, 3]);
      expect(a.targets.single.reps, 7);
    });
  });

  group('plan', () {
    test('context: numbers and ids only', () async {
      final view = await activePlan();
      final c = CoachPlan.context(view);
      final plan = c['plan']! as Map;
      expect((c['goal']! as Map).keys, ['goal', 'difficulty']);
      expect(plan['progressive_overload'], isFalse);
      expect((plan['templates'] as List).first, containsPair('id', PlanTemplates.fullBodyA));
      expect((plan['upcoming'] as List).first, {'in_days': 0, 'template_id': PlanTemplates.fullBodyA});
      expect(c.toString(), isNot(contains(view.plan.name)), reason: 'no names');
      expect(CoachPlan.context(null), {'plan': null});
    });

    test('changes: matched to the next session\'s template, never added', () async {
      final view = await activePlan();
      final a = CoachAnswer.parse(CreditedRequest.workoutReview, review)!;
      final changes = CoachPlan.changes(view, a.targets);
      expect(changes, hasLength(1), reason: 'burpee is not in the plan');
      final s = changes.single.suggestion;
      expect(s.templateId, PlanTemplates.fullBodyA);
      expect(s.index, 0);
      expect(s.current.reps, 6);
      expect(s.proposed.reps, 7);
      expect(s.proposed.tracking, s.current.tracking);
      expect(changes.single.note, 'One more rep per set.');
      // A target equal to the current one is skipped.
      final same = CoachTarget.fromJson({...(review['next_session']! as List).first as Map, 'reps': 6})!;
      final timedSame = CoachTarget.fromJson({'exercise_id': 'push_up', 'sets': 1, 'seconds': 45, 'rest_seconds': 60, 'change': 'maintain'})!;
      expect(CoachPlan.changes(view, [same, timedSame]), isEmpty);
      // A timed target only replaces a timed slot of the same exercise.
      final timed = CoachTarget.fromJson({'exercise_id': 'push_up', 'sets': 1, 'seconds': 50, 'rest_seconds': 60, 'change': 'increase'})!;
      final t = CoachPlan.changes(view, [timed]).single.suggestion;
      expect(t.current.seconds, 45);
      expect(t.proposed.seconds, 50);
      expect(t.proposed.reps, isNull);
    });
  });

  group('wire format', () {
    final contract = loadContract('credits');
    final edge = ((contract['edge_functions'] as Map)['ai-request'] as Map).cast<String, Object?>();

    test('v2 body, data and memory; v1 body unchanged', () async {
      final bodies = <Map<String, Object?>>[];
      final rpc = _Invoke((body) {
        bodies.add(body);
        return {
          'request_id': body['request_id'],
          'text': 'Text',
          'balance': 4,
          'data': {'reply': 'Hi', 'memory': 'Goal: 50 push-ups'},
          'memory': 'Goal: 50 push-ups',
        };
      });
      final api = SupabaseAiCreditsApi(rpc);
      final a = await api.ask(
          requestId: 'r1',
          kind: CreditedRequest.coachChat,
          locale: 'vi',
          messages: const [CoachMessage.user('Hi')],
          version: 2,
          memory: 'Knees hurt last month');
      expect(bodies.single.keys.toSet(), (edge['request_v2']! as List).toSet());
      expect(bodies.single['version'], 2);
      expect(a.data, {'reply': 'Hi', 'memory': 'Goal: 50 push-ups'});
      expect(a.memory, 'Goal: 50 push-ups');

      await api.ask(requestId: 'r2', kind: CreditedRequest.coachChat, locale: 'en',
          messages: const [CoachMessage.user('Hi')]);
      expect(bodies.last.keys.toSet(), (edge['request']! as List).toSet());
    });

    test('429 limit_reached → AiLimitReached', () async {
      final api = SupabaseAiCreditsApi(_Invoke((_) => throw const BackendException(
          'limit_reached', status: 429, body: {'error': 'limit_reached', 'scope': 'monthly_total'})));
      expect(edge['errors'], containsPair('429', 'limit_reached'));
      await expectLater(
          api.ask(requestId: 'r', kind: CreditedRequest.workoutReview, locale: 'en', version: 2),
          throwsA(isA<AiLimitReached>().having((e) => e.scope, 'scope', 'monthly_total')));
    });
  });

  group('conversation', () {
    Future<(CreditsController, ScriptedAi)> signedIn() async {
      final (auth, _) = await authFor('a@x.com');
      final api = ScriptedAi()..data = null;
      final c = CreditsController(auth: auth, api: api);
      await pumpEventQueue();
      return (c, api);
    }

    test('v2 chat: 15 turns, memory kept on the phone per account', () async {
      final (c, api) = await signedIn();
      final chat = CoachConversation(c, v2: true);
      api.memoryOut = 'Goal: 50 push-ups';
      for (var i = 0; i < 18; i++) {
        await chat.ask('Question $i', locale: 'en');
      }
      expect(api.sent.every((s) => s.version == 2), isTrue);
      expect(api.sent.last.messages, 30, reason: '15 turns at most');
      expect(api.sent.first.memory, isNull);
      expect(api.sent[1].memory, 'Goal: 50 push-ups');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys().where((k) => k.startsWith(CoachMemoryStore.prefix)), hasLength(1));
      await CoachMemoryStore().clearAll();
      expect(prefs.getKeys().where((k) => k.startsWith(CoachMemoryStore.prefix)), isEmpty);
    });

    test('v1 stays v1: no memory, 20 messages', () async {
      final (c, api) = await signedIn();
      final chat = CoachConversation(c);
      api.memoryOut = 'ignored';
      for (var i = 0; i < 12; i++) {
        await chat.ask('Q$i', locale: 'en');
      }
      expect(api.sent.every((s) => s.version == 1 && s.memory == null), isTrue);
      expect(api.sent.last.messages, 20);
    });

    test('a usage limit is a neutral failure, nothing charged', () async {
      final (c, api) = await signedIn();
      api.fail = const AiLimitReached('user_daily');
      final chat = CoachConversation(c, v2: true);
      await chat.ask('Q', locale: 'en');
      expect(chat.turns.single.failure, CoachFailure.limit);
    });
  });

  group('screen', () {
    Future<void> pump(WidgetTester tester, CreditsController c, Widget home) async {
      tester.view.physicalSize = const Size(393, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final locale = LocaleController(AppLanguage.en);
      addTearDown(locale.dispose);
      await tester.pumpWidget(LocaleScope(
        controller: locale,
        child: AuthScope(
          controller: c.auth,
          child: CreditsScope(
            controller: c,
            child: MaterialApp(
              theme: RepCoachTheme.dark(),
              supportedLocales: testSupportedLocales,
              localizationsDelegates: testLocalizationsDelegates,
              home: home,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
    }

    Future<(CreditsController, ScriptedAi)> setup(WidgetTester tester) async =>
        (await tester.runAsync(() async {
          final (auth, _) = await authFor('a@x.com');
          final api = ScriptedAi();
          final c = CreditsController(auth: auth, api: api);
          await pumpEventQueue();
          return (c, api);
        }))!;

    testWidgets('review card → Apply → Accept changes the upcoming sessions', (tester) async {
      await tester.runAsync(activePlan);
      final (c, api) = await setup(tester);
      await pump(tester, c,
          CoachPage(credits: c, v2: true, planRepository: repo, loadWorkouts: () async => [workout()]));
      await settle(tester);
      expect(find.byKey(const Key('coach-analyze-last')), findsNothing);
      await tester.tap(find.byKey(const Key('coach-review-last')));
      await tester.pumpAndSettle();
      // The v2 consent (history + memory) is asked under its own key.
      expect(find.textContaining('last 4 weeks'), findsOneWidget);
      await tester.tap(find.byKey(const Key('coach-consent-accept')));
      await settle(tester);

      final sent = api.sent.single;
      expect(sent.kind, CreditedRequest.workoutReview);
      expect(sent.version, 2);
      expect(sent.context!['workout'], isNotNull);
      expect(sent.context!['plan'], isNotNull);
      expect(find.byKey(const Key('coach-card')), findsOneWidget);
      expect(find.text('• Keep elbows at 45 degrees'), findsOneWidget);
      expect(find.textContaining('rest 90 s'), findsOneWidget);
      expect(find.textContaining('not medical advice'), findsOneWidget);

      await tester.tap(find.byKey(const Key('coach-apply')));
      await tester.pumpAndSettle();
      expect(find.byType(OverloadPage), findsOneWidget);
      expect(find.text('AI coach suggestions'), findsOneWidget);
      expect(find.text('One more rep per set.'), findsOneWidget);
      expect(find.byKey(const Key('overload-toggle')), findsNothing);
      await tester.tap(find.byKey(const Key('accept-${PlanTemplates.fullBodyA}-0')));
      await settle(tester);
      expect(find.byKey(const Key('coach-changes-done')), findsOneWidget);

      final view = (await tester.runAsync(repo.load))!;
      expect(view.plan.template(PlanTemplates.fullBodyA)!.targets[0].reps, 7);
      final nextA = view.sessions.firstWhere((s) =>
          s.workoutTemplateId == PlanTemplates.fullBodyA &&
          s.scheduledLocalDate.isAfter(view.today));
      expect(nextA.exerciseTargets[0].reps, 7);
    });

    testWidgets('dismiss leaves the plan unchanged', (tester) async {
      await tester.runAsync(activePlan);
      final (c, _) = await setup(tester);
      await tester.runAsync(() async =>
          (await SharedPreferences.getInstance()).setBool(AiCoachV2.consentKey, true));
      await pump(tester, c,
          CoachPage(credits: c, v2: true, planRepository: repo, loadWorkouts: () async => [workout()]));
      await settle(tester);
      await tester.tap(find.byKey(const Key('coach-review-last')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('coach-apply')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dismiss-${PlanTemplates.fullBodyA}-0')));
      await settle(tester);
      expect(find.byKey(const Key('coach-changes-done')), findsOneWidget);
      final view = (await tester.runAsync(repo.load))!;
      expect(view.plan.template(PlanTemplates.fullBodyA)!.targets[0].reps, 6);
    });

    testWidgets('no plan: Apply is disabled with a hint; plan suggestions still work', (tester) async {
      final (c, api) = await setup(tester);
      await tester.runAsync(() async =>
          (await SharedPreferences.getInstance()).setBool(AiCoachV2.consentKey, true));
      await pump(tester, c,
          CoachPage(credits: c, v2: true, planRepository: repo, loadWorkouts: () async => const []));
      await settle(tester);
      expect(
          tester.widget<ListTile>(find.descendant(
              of: find.byKey(const Key('coach-review-last')), matching: find.byType(ListTile))).enabled,
          isFalse,
          reason: 'no workouts yet');
      api.data = {
        'summary': 'Start easy',
        'horizon': 'tomorrow',
        'sessions': [
          {'day_offset': 1, 'focus': 'Full body', 'exercises': [(review['next_session']! as List).first]},
        ],
      };
      await tester.tap(find.byKey(const Key('coach-plan-tomorrow')));
      await settle(tester);
      expect(api.sent.single.kind, CreditedRequest.planSuggestion);
      expect(api.sent.single.context!['horizon'], 'tomorrow');
      expect(find.text('Tomorrow · Full body'), findsOneWidget);
      expect(find.byKey(const Key('coach-apply-unavailable')), findsOneWidget);
      expect(find.text('Create a plan in Plans to apply suggestions.'), findsOneWidget);
    });

    testWidgets('text fallback shows the plain answer; limit shows a neutral note', (tester) async {
      final (c, api) = await setup(tester);
      await tester.runAsync(() async =>
          (await SharedPreferences.getInstance()).setBool(AiCoachV2.consentKey, true));
      api.data = null;
      await pump(tester, c, CoachPage(credits: c, v2: true, planRepository: repo, loadWorkouts: () async => const []));
      await settle(tester);
      await tester.enterText(find.byKey(const Key('coach-input')), 'Hello');
      await tester.tap(find.byKey(const Key('coach-send')));
      await settle(tester);
      expect(find.byKey(const Key('coach-answer')), findsOneWidget);
      expect(find.text('Plain text'), findsOneWidget);

      api.fail = const AiLimitReached('user_daily');
      await tester.enterText(find.byKey(const Key('coach-input')), 'Again');
      await tester.tap(find.byKey(const Key('coach-send')));
      await settle(tester);
      expect(find.textContaining("today's AI coach limit"), findsOneWidget);

      await tester.tap(find.byKey(const Key('coach-forget')));
      await tester.pumpAndSettle();
      expect(find.text('The AI coach forgot its notes about you.'), findsOneWidget);
    });
  });
}

class _Invoke implements BackendRpc {
  _Invoke(this.handler);
  final Object? Function(Map<String, Object?> body) handler;

  @override
  Future<Object?> invoke(String function, Map<String, Object?> body) async {
    expect(function, 'ai-request');
    return handler(body);
  }

  @override
  Future<Object?> rpc(String function, Map<String, Object?> params) =>
      throw UnimplementedError();

  @override
  Future<void> upsert(String table, Map<String, Object?> row) =>
      throw UnimplementedError();

  @override
  Future<List<Map<String, Object?>>> select(String table, Map<String, Object> where) =>
      throw UnimplementedError();
}
