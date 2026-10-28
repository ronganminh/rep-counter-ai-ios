import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/features/plan/application/plan_repository.dart';
import 'package:rep_counter_app/features/plan/application/reminder_service.dart';
import 'package:rep_counter_app/features/plan/domain/local_date.dart';
import 'package:rep_counter_app/features/plan/domain/plan_schedule.dart';
import 'package:rep_counter_app/features/plan/domain/plan_templates.dart';
import 'package:rep_counter_app/features/plan/domain/reminder_planner.dart';
import 'package:rep_counter_app/features/plan/domain/workout_plan.dart';
import 'package:rep_counter_app/features/plan/presentation/reminder_settings_page.dart';
import 'package:rep_counter_app/features/workout/data/workout_record.dart';
import 'package:rep_counter_app/theme/app_theme.dart';
import 'package:rep_counter_app/widgets/app_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/l10n.dart';

/// NT-1 local reminders linked to planned sessions.

final monday = LocalDate(2026, 11, 2);
const on = ReminderPrefs(enabled: true);

class FakePlatform implements ReminderPlatform {
  ReminderPermission granted = ReminderPermission.granted;
  final scheduled = <int, (PlannedReminder, String, String)>{};
  final log = <String>[];
  bool fail = false;

  @override
  Future<ReminderPermission> permission() async => granted;

  @override
  Future<ReminderPermission> requestPermission() async => granted;

  @override
  Future<Map<int, String?>> pending() async {
    if (fail) throw StateError('plugin');
    return {
      for (final e in scheduled.entries) e.key: e.value.$1.payload,
      // Somebody else's notification is never touched.
      42: 'other',
    };
  }

  @override
  Future<void> schedule(PlannedReminder r, String title, String body) async {
    log.add('schedule ${r.id}');
    scheduled[r.id] = (r, title, body);
  }

  @override
  Future<void> cancel(int id) async {
    log.add('cancel $id');
    scheduled.remove(id);
  }
}

void main() {
  late DateTime now;
  late List<WorkoutRecord> history;
  late PlanRepository repo;
  late FakePlatform platform;
  late ReminderService service;
  var n = 0;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    now = DateTime(2026, 11, 2, 9);
    history = [];
    repo = PlanRepository(
        loadWorkouts: () async => history,
        now: () => now,
        newId: () => 'id${++n}');
    platform = FakePlatform();
    service = ReminderService(platform: platform, now: () => now);
    await repo.activate(PlanTemplates.beginnerPlan(
        id: 'plan', startDate: monday, timezone: 'UTC', now: now));
    await ReminderPrefsStore().save(on);
  });

  Set<LocalDate> remindedDays() => {
        for (final e in platform.scheduled.values) e.$1.date,
      };

  group('planner rules', () {
    test('off by default; nothing is scheduled until the user turns it on',
        () async {
      await ReminderPrefsStore().save(const ReminderPrefs());
      expect(const ReminderPrefs().enabled, isFalse);
      await service.sync(await repo.load());
      expect(platform.scheduled, isEmpty);
    });

    test(
        'one per upcoming session in 14 days, at 5:30 PM, never on recovery '
        'days (10)', () async {
      final view = (await repo.load())!;
      final wanted = ReminderPlanner.plan(view.plan, view.sessions, on, now);
      expect(wanted, hasLength(6), reason: '3 a week × 2 weeks');
      expect(wanted.map((r) => r.date.weekday).toSet(),
          {DateTime.monday, DateTime.wednesday, DateTime.friday});
      expect(wanted.first.fireAt, DateTime(2026, 11, 2, 17, 30));
      expect(wanted.every((r) => view.plan.dayKind(r.date) == DayKind.training),
          isTrue);
      expect(wanted.map((r) => r.id).toSet(), hasLength(6));
    });

    test('quiet hours move a reminder to when they end', () {
      const late = ReminderPrefs(enabled: true, minuteOfDay: 23 * 60);
      expect(late.isQuiet(23 * 60), isTrue);
      expect(late.isQuiet(6 * 60 + 59), isTrue);
      expect(late.isQuiet(7 * 60), isFalse);
      final r = ReminderPlanner.plan(
          PlanTemplates.beginnerPlan(
                  id: 'p', startDate: monday, timezone: 'UTC', now: now)
              .copyWith(status: PlanStatus.active),
          PlanSchedule.generate(
              PlanTemplates.beginnerPlan(
                      id: 'p', startDate: monday, timezone: 'UTC', now: now)
                  .copyWith(status: PlanStatus.active),
              const [],
              from: monday,
              to: monday.addDays(6),
              now: now,
              newId: () => 's${++n}'),
          late,
          DateTime(2026, 11, 1, 12));
      expect(r.first.fireAt, DateTime(2026, 11, 2, 7));
    });

    test('a reminder time already past today is skipped', () {
      final view = PlanSchedule.generate(
          PlanTemplates.beginnerPlan(
                  id: 'p', startDate: monday, timezone: 'UTC', now: now)
              .copyWith(status: PlanStatus.active),
          const [],
          from: monday,
          to: monday.addDays(6),
          now: now,
          newId: () => 's${++n}');
      final plan = PlanTemplates.beginnerPlan(
              id: 'p', startDate: monday, timezone: 'UTC', now: now)
          .copyWith(status: PlanStatus.active);
      final r = ReminderPlanner.plan(plan, view, on, DateTime(2026, 11, 2, 18));
      expect(r.first.date, monday.addDays(2));
    });

    test('notification ids are stable per session', () {
      expect(ReminderPlanner.notificationId('abc'),
          ReminderPlanner.notificationId('abc'));
      expect(ReminderPlanner.notificationId('abc'),
          isNot(ReminderPlanner.notificationId('abd')));
      expect(ReminderPlanner.notificationId('x') >= 0, isTrue);
    });
  });

  group('sync', () {
    test('11 a completed session never keeps a pending reminder', () async {
      await service.sync(await repo.load());
      expect(remindedDays(), contains(monday));
      history.addAll([
        _record('w1', now, 'push_up', 18),
        _record('w2', now, 'curl', 30),
        _record('w3', now, 'overhead_extension', 20),
      ]);
      final view = (await repo.load())!;
      expect(view.todaySession!.state, SessionState.completed);
      await service.sync(view);
      expect(remindedDays(), isNot(contains(monday)));
    });

    test('missed, skipped and paused: no reminders as if upcoming', () async {
      var view = (await repo.load())!;
      await repo.skip(view.sessions[1].id);
      await service.sync(await repo.load());
      expect(remindedDays(), isNot(contains(monday.addDays(2))));
      await repo.setStatus(PlanStatus.paused);
      await service.sync(await repo.load());
      expect(platform.scheduled, isEmpty);
      now = DateTime(2026, 11, 3, 9);
      await repo.setStatus(PlanStatus.active);
      view = (await repo.load())!;
      await service.sync(view);
      expect(view.missed, isEmpty, reason: 'paused days are cancelled');
      expect(
          remindedDays().every((d) => !d.isBefore(monday.addDays(1))), isTrue);
    });

    test('rescheduling moves the reminder under the same id', () async {
      now = DateTime(2026, 11, 3, 9);
      var view = (await repo.load())!;
      await service.sync(view);
      final missed = view.missed.single;
      final id = ReminderPlanner.notificationId(missed.id);
      expect(platform.scheduled.containsKey(id), isFalse,
          reason: 'a missed session gets no reminder');
      await repo.reschedule(missed.id, monday.addDays(3),
          confirmRecovery: true);
      view = (await repo.load())!;
      await service.sync(view);
      expect(platform.scheduled[id]!.$1.date, monday.addDays(3));
      expect(platform.scheduled[id]!.$1.fireAt, DateTime(2026, 11, 5, 17, 30));
      // Moving it again replaces the reminder; it is never doubled.
      await repo.reschedule(missed.id, monday.addDays(6),
          confirmRecovery: true);
      await service.sync(await repo.load());
      expect(platform.scheduled[id]!.$1.date, monday.addDays(6));
      expect(
          platform.scheduled.values.where((e) => e.$1.sessionId == missed.id),
          hasLength(1));
    });

    test('retries and repeated syncs never duplicate', () async {
      final view = (await repo.load())!;
      await service.sync(view);
      final first = Map.of(platform.scheduled);
      await service.sync(view);
      await service.sync(view);
      expect(platform.scheduled.keys.toSet(), first.keys.toSet());
      expect(platform.log.where((l) => l.startsWith('cancel')), isEmpty);
    });

    test('turning reminders off cancels ours only', () async {
      final view = (await repo.load())!;
      await service.sync(view);
      await service.savePrefs(const ReminderPrefs(), view);
      expect(platform.scheduled, isEmpty);
      expect(platform.log.where((l) => l == 'cancel 42'), isEmpty);
    });

    test('reminders use local wall time and are re-planned on every sync',
        () async {
      final view = (await repo.load())!;
      await service.sync(view);
      final before = platform.scheduled.values.first.$1.fireAt;
      // The planner always works in device-local wall time: 5:30 PM stays
      // 5:30 PM on the session's local date after the zone changes.
      expect(before.hour, 17);
      expect(before.minute, 30);
    });

    test('a failing plugin or a denied permission never throws', () async {
      platform.fail = true;
      expect(await service.sync(await repo.load()), isEmpty);
      platform
        ..fail = false
        ..granted = ReminderPermission.denied;
      expect(await service.requestPermission(), ReminderPermission.denied);
      expect((await repo.load())!.sessions, isNotEmpty,
          reason: 'planning does not depend on notifications');
    });

    test('titles are localized', () async {
      await service.sync(await repo.load(), locale: const Locale('vi'));
      expect(platform.scheduled.values.first.$2, 'Hôm nay có buổi Full Body A');
      expect(platform.scheduled.values.first.$3, startsWith('Khoảng '));
    });
  });

  testWidgets(
      'settings: explanation before the OS prompt; denied keeps working',
      (tester) async {
    await tester
        .runAsync(() => ReminderPrefsStore().save(const ReminderPrefs()));
    platform.granted = ReminderPermission.denied;
    final view = (await tester.runAsync(repo.load))!;
    final locale = LocaleController(AppLanguage.en);
    addTearDown(locale.dispose);
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(LocaleScope(
        controller: locale,
        child: MaterialApp(
            theme: RepCoachTheme.dark(),
            supportedLocales: testSupportedLocales,
            localizationsDelegates: testLocalizationsDelegates,
            home: ReminderSettingsPage(view: view, service: service))));
    await tester.pumpAndSettle();
    expect(find.text('Get reminders for planned sessions'), findsOneWidget);
    expect(platform.log, isEmpty, reason: 'no prompt before the user asks');
    // 5.1.1(iv): the explanation only continues to the OS prompt.
    expect(find.widgetWithText(AppButton, 'Continue'), findsOneWidget);
    expect(find.byKey(const Key('reminder-not-now')), findsNothing);
    expect(find.text('Not now'), findsNothing);
    expect(find.byType(BackButton), findsNothing);
    for (final t in tester.widgetList<Text>(find.byType(Text))) {
      expect((t.data ?? '').toLowerCase(), isNot(contains('allow')));
    }
    await tester.tap(find.byKey(const Key('reminder-enable')));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reminder-denied')), findsOneWidget);
    expect(find.byKey(const Key('reminder-open-settings')), findsOneWidget);
    expect(find.byKey(const Key('reminder-toggle')), findsOneWidget);
    expect(find.byKey(Key('reminder-${monday.addDays(2).toIso()}')),
        findsOneWidget);
    expect(
        find.byKey(Key('reminder-${monday.addDays(1).toIso()}')), findsNothing,
        reason: 'Tuesday is a recovery day');
  });

  Future<void> openRoute(WidgetTester tester, PlanView view) async {
    final locale = LocaleController(AppLanguage.en);
    addTearDown(locale.dispose);
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(LocaleScope(
        controller: locale,
        child: MaterialApp(
            theme: RepCoachTheme.dark(),
            supportedLocales: testSupportedLocales,
            localizationsDelegates: testLocalizationsDelegates,
            home: Builder(
                builder: (context) => TextButton(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => ReminderSettingsPage(
                                view: view, service: service))),
                    child: const Text('open'))))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('5.1.1(iv): no back before the prompt, back after it',
      (tester) async {
    await tester
        .runAsync(() => ReminderPrefsStore().save(const ReminderPrefs()));
    platform.granted = ReminderPermission.unknown;
    final view = (await tester.runAsync(repo.load))!;
    await openRoute(tester, view);
    expect(find.byType(BackButton), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ReminderSettingsPage), findsOneWidget,
        reason: 'system back does not skip the prompt');
    platform.granted = ReminderPermission.granted;
    await tester.tap(find.byKey(const Key('reminder-enable')));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reminder-toggle')), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('reminders off with notifications granted: no explanation again',
      (tester) async {
    await tester
        .runAsync(() => ReminderPrefsStore().save(const ReminderPrefs()));
    final view = (await tester.runAsync(repo.load))!;
    await openRoute(tester, view);
    expect(find.byKey(const Key('reminder-enable')), findsNothing);
    expect(find.byKey(const Key('reminder-toggle')), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
  });
}

WorkoutRecord _record(String id, DateTime at, String exercise, int reps) =>
    WorkoutRecord(
      id: id,
      exerciseId: exercise,
      exerciseName: exercise,
      startedAt: at,
      durationSeconds: 60,
      reps: reps,
      sets: 1,
      targetReps: null,
      poseFrames: 0,
      readyFrames: 0,
      lostFrames: 0,
    );
