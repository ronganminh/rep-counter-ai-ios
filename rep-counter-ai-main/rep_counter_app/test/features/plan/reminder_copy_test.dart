import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/features/plan/application/plan_repository.dart';
import 'package:rep_counter_app/features/plan/application/reminder_service.dart';
import 'package:rep_counter_app/features/plan/domain/local_date.dart';
import 'package:rep_counter_app/features/plan/domain/plan_templates.dart';
import 'package:rep_counter_app/features/plan/domain/reminder_copy.dart';
import 'package:rep_counter_app/features/plan/domain/reminder_planner.dart';
import 'package:rep_counter_app/features/plan/domain/workout_plan.dart';
import 'package:rep_counter_app/features/plan/presentation/reminder_settings_page.dart';
import 'package:rep_counter_app/features/workout/data/workout_record.dart';
import 'package:rep_counter_app/l10n/app_localizations.dart';
import 'package:rep_counter_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/l10n.dart';
import 'reminder_test.dart' show FakePlatform;

/// NT-2 layer 1 (L-D44): friendly reminder lines from the ARB catalog,
/// chosen by situation, never repeated within 14 days, offline.

final en = lookupAppLocalizations(const Locale('en'));
final vi = lookupAppLocalizations(const Locale('vi'));
const vars = ReminderVars(
    name: 'Minh', exercise: 'Push-up', time: '5:30 PM', streak: '9', sets: '6');

final _emoji = RegExp(
    r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{1F000}-\u{1F2FF}]',
    unicode: true);

void main() {
  group('catalog', () {
    test('40-60 lines, every situation covered', () {
      final lines = ReminderCopy.lines;
      expect(lines.length, inInclusiveRange(40, 60));
      expect(lines.map((l) => l.key).toSet(), hasLength(lines.length));
      for (final s in ReminderSituation.values) {
        final pool = lines.where((l) => l.situation == s && !l.usesName);
        expect(pool.length, greaterThanOrEqualTo(6), reason: s.name);
      }
    });

    for (final (lang, l) in [('en', en), ('vi', vi)]) {
      test('every line renders in $lang: short, warm, variables filled', () {
        final blame = lang == 'en'
            ? ['lazy', 'failed', 'you missed', 'should have', 'hurry', 'no excuses', 'guilt']
            : ['lười', 'bỏ bê', 'phải tập ngay', 'đừng lười', 'tội lỗi', 'không có lý do'];
        for (final line in ReminderCopy.lines) {
          final t = ReminderCopy.text(l, line.key, vars);
          expect(t, isNot(contains('{')), reason: line.key);
          expect(t, isNot(contains('\n')), reason: '${line.key}: one line');
          expect(t.length, lessThanOrEqualTo(110), reason: '${line.key}: ≤ 2 lines');
          expect(_emoji.allMatches(t).length, lessThanOrEqualTo(1), reason: line.key);
          for (final b in blame) {
            expect(t.toLowerCase(), isNot(contains(b)), reason: '${line.key}: "$b"');
          }
          expect(t.contains('Minh'), line.usesName,
              reason: '${line.key}: usesName must match {name}');
        }
      });
    }

    test('variables are substituted', () {
      expect(ReminderCopy.text(en, 'reminderNudgeStreak01', vars),
          '9 days in a row. Nice rhythm! Keep it easy and steady.');
      expect(ReminderCopy.text(vi, 'reminderNudgeRegular01', vars),
          'Push-up đang chờ bạn lúc 5:30 PM. Vài set nhẹ nhàng là xong.');
      expect(ReminderCopy.text(en, 'reminderNudgeRegular02', vars),
          "Today's plan: 6 sets. Start whenever you're ready.");
    });

    test('VI: exercise name lower case mid-sentence, capital at the start',
        () {
      const v = ReminderVars(
          exercise: 'Hít đất', time: '17:30', streak: '9', sets: '6');
      expect(ReminderCopy.text(vi, 'reminderNudgeFirstSession08', v),
          'Hôm nay là ngày đầu. Khởi động rồi hít đất theo nhịp của bạn.');
      expect(ReminderCopy.text(vi, 'reminderNudgeRegular03', v),
          'Hôm nay có buổi tập. Khởi động rồi vào hít đất trước nhé.');
      expect(ReminderCopy.text(vi, 'reminderNudgeRegular10', v),
          'Hôm nay: hít đất và vài bài nữa. Chậm mà chắc.');
      // Start of the line, or of a sentence: capital kept.
      expect(ReminderCopy.text(vi, 'reminderNudgeRegular01', v),
          'Hít đất đang chờ bạn lúc 17:30. Vài set nhẹ nhàng là xong.');
      expect(ReminderCopy.text(vi, 'reminderNudgeEvening06', v),
          'Buổi tập tối nay đã sẵn sàng. Hít đất trước, theo nhịp của bạn.');
      // Every line: lower case unless it opens a sentence; English as is.
      final opens = RegExp(r'[.!?…]$');
      for (final line in ReminderCopy.lines) {
        final t = ReminderCopy.text(vi, line.key, v);
        for (final m in RegExp('hít đất', caseSensitive: false).allMatches(t)) {
          final before = t.substring(0, m.start).trimRight();
          final start = before.isEmpty || opens.hasMatch(before);
          expect(t[m.start], start ? 'H' : 'h', reason: '${line.key}: $t');
        }
        final e = ReminderCopy.text(en, line.key, vars);
        expect(e, isNot(contains('push-up')), reason: '${line.key}: $e');
      }
    });
  });

  group('situation', () {
    final start = LocalDate(2026, 11, 2); // Monday
    final plan = PlanTemplates.beginnerPlan(
        id: 'p', startDate: start, timezone: 'UTC', now: DateTime(2026, 11, 1));
    PlannedSession session(String id, LocalDate d, SessionState st) =>
        PlannedSession(
          id: id,
          planId: 'p',
          planVersion: 1,
          scheduledLocalDate: d,
          workoutTemplateId: PlanTemplates.fullBodyA,
          exerciseTargets: const [],
          state: st,
          originalScheduledDate: d,
          createdAt: DateTime(2026, 11, 1),
          updatedAt: DateTime(2026, 11, 1),
        );
    ReminderSituation pick(List<PlannedSession> sessions, LocalDate date,
            {int minute = 17 * 60, bool first = true, int streak = 0}) =>
        ReminderCopy.situation(
            plan: plan,
            sessions: sessions,
            today: start.addDays(7),
            date: date,
            minuteOfDay: minute,
            first: first,
            streak: streak);
    final wed = start.addDays(9);

    test('first session, after missed, streak, weekend, evening, regular', () {
      expect(pick([session('a', wed, SessionState.scheduled)], wed),
          ReminderSituation.firstSession);
      final missed = [
        session('x', start, SessionState.completed),
        session('y', start.addDays(5), SessionState.missed),
        session('a', wed, SessionState.scheduled),
      ];
      expect(pick(missed, wed), ReminderSituation.afterMissed);
      expect(pick(missed, wed, streak: 8), ReminderSituation.streak,
          reason: 'a streak beats a missed plan session');
      final done = [
        session('x', start.addDays(5), SessionState.completed),
        session('a', wed, SessionState.scheduled),
      ];
      expect(pick(done, wed, streak: 7), ReminderSituation.streak);
      expect(pick(done, wed, streak: 6), ReminderSituation.regular);
      expect(pick(done, start.addDays(12)), ReminderSituation.weekend);
      expect(pick(done, wed, minute: 18 * 60), ReminderSituation.evening);
      // Only the next reminder carries first / missed / streak.
      expect(pick(missed, wed, first: false), ReminderSituation.regular);
    });
  });

  group('rotation', () {
    test('a line never comes back within 14 days (90 days simulated)', () {
      var state = const ReminderCopyState();
      final fired = <LocalDate, String>{};
      final day0 = LocalDate(2026, 11, 2);
      // A session every other day; each day the app re-plans 14 days ahead.
      for (var t = 0; t < 90; t++) {
        final today = day0.addDays(t);
        final slots = [
          for (var d = 0; d < 14; d++)
            if ((t + d).isEven)
              ReminderSlot('s${t + d}', today.addDays(d), ReminderSituation.regular)
        ];
        final (keys, next) =
            ReminderCopy.assign(slots, state, hasName: false, today: today);
        state = next;
        if (keys['s$t'] != null) fired[today] = keys['s$t']!;
      }
      final days = fired.keys.toList()..sort();
      for (var i = 0; i < days.length; i++) {
        for (var j = i + 1; j < days.length; j++) {
          if (days[i].daysUntil(days[j]) >= ReminderCopy.noRepeatDays) break;
          expect(fired[days[i]], isNot(fired[days[j]]),
              reason: 'repeated within 14 days: ${days[i]} and ${days[j]}');
        }
      }
      expect(fired.values.toSet().length, greaterThan(6));
    });

    test('a re-sync keeps the chosen lines; a new situation re-picks', () {
      final today = LocalDate(2026, 11, 2);
      final slots = [
        ReminderSlot('a', today, ReminderSituation.regular),
        ReminderSlot('b', today.addDays(2), ReminderSituation.regular),
      ];
      final (k1, s1) = ReminderCopy.assign(slots, const ReminderCopyState(),
          hasName: false, today: today);
      final (k2, _) = ReminderCopy.assign(slots, ReminderCopyState.fromJson(s1.toJson()),
          hasName: false, today: today);
      expect(k2, k1);
      expect(k1['a'], isNot(k1['b']));
      final (k3, _) = ReminderCopy.assign(
          [ReminderSlot('a', today, ReminderSituation.afterMissed)], s1,
          hasName: false, today: today);
      expect(k3['a'], startsWith('reminderNudgeAfterMissed'));
    });

    test('name lines only when a name is known', () {
      final today = LocalDate(2026, 11, 2);
      final slots = [
        for (var d = 0; d < 7; d++)
          ReminderSlot('s$d', today.addDays(d), ReminderSituation.firstSession)
      ];
      final (noName, _) = ReminderCopy.assign(slots, const ReminderCopyState(),
          hasName: false, today: today);
      final byKey = {for (final l in ReminderCopy.lines) l.key: l};
      expect(noName.values.every((k) => !byKey[k]!.usesName), isTrue);
    });
  });

  group('service', () {
    late PlanRepository repo;
    late FakePlatform platform;
    var n = 0;
    late DateTime now;
    late List<WorkoutRecord> history;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      now = DateTime(2026, 11, 2, 9);
      history = [];
      repo = PlanRepository(
          loadWorkouts: () async => history, now: () => now, newId: () => 'id${++n}');
      await repo.activate(PlanTemplates.beginnerPlan(
          id: 'plan', startDate: LocalDate(2026, 11, 2), timezone: 'UTC', now: now));
      await ReminderPrefsStore().save(const ReminderPrefs(enabled: true));
      platform = FakePlatform();
    });

    ReminderService service() => ReminderService(platform: platform, now: () => now);

    test('friendly lines by situation, filled in, stable across syncs', () async {
      final view = await repo.load();
      final wanted = await service().sync(view);
      expect(wanted, isNotEmpty);
      final bodies = {for (final r in wanted) r.id: platform.scheduled[r.id]!.$3};
      final first = bodies[wanted.first.id]!;
      expect(
          ReminderCopy.lines
              .where((l) => l.situation == ReminderSituation.firstSession)
              .map((l) => ReminderCopy.text(en, l.key, const ReminderVars(
                  exercise: 'Push-up', time: '5:30 PM', streak: '0', sets: '9'))),
          contains(first));
      expect(bodies.values.every((b) => !b.contains('{')), isTrue);
      expect(bodies.values.toSet().length, bodies.length, reason: 'no repeats in 14 days');
      await service().sync(view);
      expect({for (final r in wanted) r.id: platform.scheduled[r.id]!.$3}, bodies);
    });

    test('a 7-day streak words the next reminder with the streak', () async {
      for (var d = 0; d < 8; d++) {
        history.add(WorkoutRecord(
            id: 'w$d',
            exerciseId: 'squat',
            exerciseName: 'Squat',
            startedAt: DateTime(2026, 11, 2 + d, 8),
            durationSeconds: 60,
            reps: 10,
            sets: 1,
            targetReps: null,
            poseFrames: 0,
            readyFrames: 0,
            lostFrames: 0));
      }
      now = DateTime(2026, 11, 9, 9);
      final view = await repo.load();
      final wanted = await service().sync(view);
      expect(platform.scheduled[wanted.first.id]!.$3, contains('8'));
    });
  });

  testWidgets('settings: the friendly switch is on by default and saves off',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final now = DateTime(2026, 11, 2, 9);
    var n = 0;
    final repo = PlanRepository(
        loadWorkouts: () async => const [], now: () => now, newId: () => 'id${++n}');
    final view = (await tester.runAsync(() async {
      await repo.activate(PlanTemplates.beginnerPlan(
          id: 'plan', startDate: LocalDate(2026, 11, 2), timezone: 'UTC', now: now));
      await ReminderPrefsStore().save(const ReminderPrefs(enabled: true));
      return repo.load();
    }))!;
    final platform = FakePlatform();
    tester.view.physicalSize = const Size(393, 1400);
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
                service: ReminderService(platform: platform, now: () => now)))));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    final sw = find.byKey(const Key('reminder-friendly'));
    expect(tester.widget<SwitchListTile>(sw).value, isTrue);
    expect(find.text('Friendly reminders'), findsOneWidget);
    await tester.tap(sw);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    final prefs = (await tester.runAsync(ReminderPrefsStore().load))!;
    expect(prefs.friendly, isFalse);
    expect(prefs.enabled, isTrue, reason: 'only the wording changes');
    expect(platform.scheduled.values.first.$3, startsWith('About '));
  });
}
