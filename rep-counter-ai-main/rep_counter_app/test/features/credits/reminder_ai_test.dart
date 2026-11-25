import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/backend/backend_rpc.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/features/credits/ai_credits.dart';
import 'package:rep_counter_app/features/credits/credits_controller.dart';
import 'package:rep_counter_app/features/credits/reminder_ai.dart';
import 'package:rep_counter_app/features/plan/application/plan_repository.dart';
import 'package:rep_counter_app/features/plan/application/reminder_service.dart';
import 'package:rep_counter_app/features/plan/domain/local_date.dart';
import 'package:rep_counter_app/features/plan/domain/plan_templates.dart';
import 'package:rep_counter_app/features/plan/domain/reminder_copy.dart';
import 'package:rep_counter_app/features/plan/domain/reminder_planner.dart';
import 'package:rep_counter_app/features/plan/presentation/reminder_settings_page.dart';
import 'package:rep_counter_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/l10n.dart';
import '../../support/sync_fixtures.dart';
import '../plan/reminder_test.dart' show FakePlatform;

/// NT-2 layer 2 (L-D44): AI-written reminder lines, at most one AI request a
/// week, numbers only, filtered, and layer 1 whenever anything fails.

class BatchAi implements CreditedAiApi {
  final calls = <({CreditedRequest kind, int version, Map<String, Object?>? context})>[];
  Object? fail;
  List<Map<String, Object?>> Function(List<String> ids)? lines;

  @override
  Future<CreditBalance> balance() async => CreditBalance(
      balance: 10, weeklyAllowance: 10, weekStart: DateTime.utc(2026, 11, 2), pro: false);

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
    calls.add((kind: kind, version: version, context: context));
    final f = fail;
    if (f != null) throw f;
    final ids = [
      for (final s in (context!['sessions'] as List)) (s as Map)['session_id'] as String
    ];
    return CreditedAnswer(
        requestId: requestId,
        text: 't',
        balance: 9,
        data: {'lines': (lines ?? (ids) => [for (final id in ids) {'session_id': id, 'text': 'AI line for $id'}])(ids)});
  }
}

void main() {
  late DateTime now;
  late PlanRepository repo;
  late BatchAi api;
  late CreditsController credits;
  var n = 0;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ReminderService.installedAiWriter = null;
    now = DateTime(2026, 11, 2, 9); // Monday
    repo = PlanRepository(
        loadWorkouts: () async => const [], now: () => now, newId: () => 'id${++n}');
    await repo.activate(PlanTemplates.beginnerPlan(
        id: 'plan', startDate: LocalDate(2026, 11, 2), timezone: 'UTC', now: now));
    final (auth, _) = await authFor('a@x.com');
    api = BatchAi();
    credits = CreditsController(auth: auth, api: api);
    await pumpEventQueue();
  });

  const on = ReminderPrefs(enabled: true, aiCopy: true);
  ReminderAiWriterImpl writer() => ReminderAiWriterImpl(credits, now: () => now);

  test('filter: short, one line, ≤ 1 emoji, no blame, diet or promotion', () {
    expect(ReminderCopy.cleanAi('  Easy   pace today. '), 'Easy pace today.');
    for (final bad in [
      'Don\'t be lazy!',
      'Burn fat with today\'s session',
      'Buy premium now',
      'Lười quá rồi',
      'Tập để giảm cân nhé',
      'See https://x.y',
      'Two 🔥🔥',
      'x' * 121,
      '',
      42,
    ]) {
      expect(ReminderCopy.cleanAi(bad), isNull, reason: '$bad');
    }
    expect(ReminderCopy.cleanAi('Steady reps 💪'), isNotNull);
  });

  test('asks once a week with numbers only, stores lines for upcoming sessions', () async {
    final view = (await repo.load())!;
    expect(await writer()(view, on, const Locale('vi')), isTrue);
    final call = api.calls.single;
    expect(call.kind, CreditedRequest.reminderBatch);
    expect(call.version, 2);
    final sessions = call.context!['sessions'] as List;
    expect(sessions.length, inInclusiveRange(1, 7));
    expect((sessions.first as Map).keys.toSet(),
        {'session_id', 'in_days', 'weekday', 'time', 'targets'});
    expect(call.context.toString(), isNot(contains(view.plan.name)), reason: 'no names');
    final saved = await ReminderAiStore().load();
    expect(saved.lines, hasLength(sessions.length));
    expect(saved.requested, LocalDate(2026, 11, 2));

    // Same week: no second request.
    now = DateTime(2026, 11, 6, 9);
    expect(await writer()((await repo.load())!, on, const Locale('vi')), isFalse);
    expect(api.calls, hasLength(1));
    // Next week: asks again.
    now = DateTime(2026, 11, 9, 9);
    expect(await writer()((await repo.load())!, on, const Locale('vi')), isTrue);
    expect(api.calls, hasLength(2));
  });

  test('off, guest or no upcoming session: nothing is asked', () async {
    final view = (await repo.load())!;
    expect(await writer()(view, const ReminderPrefs(enabled: true), const Locale('en')), isFalse);
    expect(await writer()(view, const ReminderPrefs(aiCopy: true), const Locale('en')), isFalse);
    await credits.auth.signOut();
    expect(await writer()(view, on, const Locale('en')), isFalse);
    expect(api.calls, isEmpty);
  });

  test('failures keep layer 1 and retry the next day, not the same day', () async {
    final view = (await repo.load())!;
    for (final e in [
      const AiProviderFailed(9),
      const AiLimitReached('user_daily'),
      const InsufficientCredits(0),
      const BackendException('network'),
    ]) {
      api.fail = e;
      expect(await writer()(view, on, const Locale('en')), isFalse);
      expect(await writer()(view, on, const Locale('en')), isFalse);
      now = now.add(const Duration(days: 1));
    }
    expect(api.calls, hasLength(4), reason: 'one try per day');
    expect((await ReminderAiStore().load()).lines, isEmpty);
  });

  test('unsafe or unknown lines are dropped', () async {
    final view = (await repo.load())!;
    api.lines = (ids) => [
          {'session_id': ids.first, 'text': 'Burn fat today!'},
          {'session_id': 'not-upcoming', 'text': 'Fine line'},
          if (ids.length > 1) {'session_id': ids[1], 'text': 'Steady reps, easy pace.'},
        ];
    await writer()(view, on, const Locale('en'));
    final lines = (await ReminderAiStore().load()).lines;
    expect(lines.values, everyElement(isNot(contains('fat'))));
    expect(lines.keys, isNot(contains('not-upcoming')));
  });

  test('service: AI lines when present, layer 1 when the AI fails', () async {
    await ReminderPrefsStore().save(on);
    final platform = FakePlatform();
    final view = (await repo.load())!;
    final service = ReminderService(
        platform: platform, now: () => now, aiWriter: writer().call);
    final wanted = await service.sync(view);
    expect(platform.scheduled[wanted.first.id]!.$3, startsWith('AI line for '));

    // A new week, the AI fails: friendly layer-1 lines are scheduled.
    SharedPreferences.setMockInitialValues({});
    await ReminderPrefsStore().save(on);
    api.fail = const AiProviderFailed(9);
    final p2 = FakePlatform();
    final w2 = await ReminderService(platform: p2, now: () => now, aiWriter: writer().call)
        .sync(view);
    final body = p2.scheduled[w2.first.id]!.$3;
    expect(body, isNot(startsWith('AI line')));
    expect(body, isNot(startsWith('About ')), reason: 'layer 1, not the neutral line');
  });

  test('install: only with credits and the v2 flag', () {
    installReminderAiWriter(credits, enabled: false);
    expect(ReminderService.installedAiWriter, isNull);
    installReminderAiWriter(null, enabled: true);
    expect(ReminderService.installedAiWriter, isNull);
    installReminderAiWriter(credits, enabled: true);
    expect(ReminderService.installedAiWriter, isNotNull);
    ReminderService.installedAiWriter = null;
  });

  for (final available in [false, true]) {
    testWidgets('settings: AI switch ${available ? 'shown, off by default' : 'hidden'}',
        (tester) async {
      final view = (await tester.runAsync(() async {
        await ReminderPrefsStore().save(const ReminderPrefs(enabled: true));
        return repo.load();
      }))!;
      tester.view.physicalSize = const Size(393, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final locale = LocaleController(AppLanguage.en);
      addTearDown(locale.dispose);
      await tester.pumpWidget(LocaleScope(
          controller: locale,
          child: MaterialApp(
              theme: RepCoachTheme.dark(),
              supportedLocales: testSupportedLocales,
              localizationsDelegates: testLocalizationsDelegates,
              home: ReminderSettingsPage(
                  view: view,
                  aiAvailable: available,
                  service: ReminderService(platform: FakePlatform(), now: () => now)))));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
      final sw = find.byKey(const Key('reminder-ai'));
      if (!available) {
        expect(sw, findsNothing);
        return;
      }
      expect(tester.widget<SwitchListTile>(sw).value, isFalse);
      await tester.tap(sw);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
      expect((await tester.runAsync(ReminderPrefsStore().load))!.aiCopy, isTrue);
    });
  }
}
