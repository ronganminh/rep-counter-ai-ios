import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/features/plan/domain/local_date.dart';
import 'package:rep_counter_app/features/plan/domain/plan_schedule.dart';
import 'package:rep_counter_app/features/plan/domain/plan_templates.dart';
import 'package:rep_counter_app/features/plan/domain/workout_plan.dart';

/// PL-1 business rules (owner decision, 2026-10-26) on pure functions.

final monday = LocalDate(2026, 11, 2);
final now = DateTime(2026, 11, 2, 9);

String Function() ids() {
  var n = 0;
  return () => 's${++n}';
}

WorkoutPlan plan({List<int> days = PlanTemplates.defaultWeekdays}) =>
    PlanTemplates.beginnerPlan(
            id: 'p1',
            startDate: monday,
            timezone: 'Asia/Ho_Chi_Minh',
            now: now,
            weekdays: days)
        .copyWith(status: PlanStatus.active);

List<PlannedSession> fourWeeks(WorkoutPlan p, {LocalDate? from}) =>
    PlanSchedule.generate(p, const [],
        from: from ?? monday,
        to: (from ?? monday).addDays(27),
        now: now,
        newId: ids());

PlanWorkout workout(String id, LocalDate date, String exercise,
        {int reps = 0,
        int seconds = 30,
        bool partial = false,
        bool manual = false}) =>
    PlanWorkout(
        id: id,
        exerciseId: exercise,
        date: date,
        reps: reps,
        durationSeconds: seconds,
        partial: partial,
        manual: manual);

void main() {
  test('the start date is a Monday', () {
    expect(monday.weekday, DateTime.monday);
  });

  group('1–3 plan creation and the 4-week preview', () {
    test('default: Mon/Wed/Fri, Full Body A/B/C rotating, 12 sessions', () {
      final p = plan();
      expect(p.selectedWeekdays,
          [DateTime.monday, DateTime.wednesday, DateTime.friday]);
      expect(p.weeklyFrequency, 3);
      expect(p.templates.map((t) => t.name),
          ['Full Body A', 'Full Body B', 'Full Body C']);
      expect(p.progressiveOverload, isFalse);
      expect(p.ownerId, isNull, reason: 'guest plan');

      final sessions = fourWeeks(p);
      expect(sessions, hasLength(12));
      expect(sessions.map((s) => s.scheduledLocalDate.weekday).toSet(),
          {DateTime.monday, DateTime.wednesday, DateTime.friday});
      expect(sessions.take(4).map((s) => s.workoutTemplateId), [
        PlanTemplates.fullBodyA,
        PlanTemplates.fullBodyB,
        PlanTemplates.fullBodyC,
        PlanTemplates.fullBodyA,
      ]);
      expect(sessions.every((s) => s.state == SessionState.scheduled), isTrue);
    });

    test('calendar: other days are recovery days, first-class', () {
      final p = plan();
      final days = PlanSchedule.calendar(p, fourWeeks(p), monday);
      expect(days, hasLength(28));
      final tue = days[1];
      expect(tue.kind, DayKind.recovery);
      expect(tue.isRecovery, isTrue);
      expect(tue.session, isNull);
      expect(days.where((d) => d.isRecovery), hasLength(16));
    });

    test('custom 2-day and 6-day plans', () {
      final two = plan(days: [DateTime.tuesday, DateTime.saturday]);
      two.validate();
      expect(fourWeeks(two), hasLength(8));
      final six = plan(days: [1, 2, 3, 4, 5, 6]);
      six.validate();
      final s6 = fourWeeks(six);
      expect(s6, hasLength(24));
      expect(s6.any((s) => s.scheduledLocalDate.weekday == DateTime.sunday),
          isFalse);
    });

    test('fewer than 2 or more than 6 days is rejected', () {
      expect(() => plan(days: [DateTime.monday]).validate(),
          throwsFormatException);
      expect(() => plan(days: [1, 2, 3, 4, 5, 6, 7]).validate(),
          throwsFormatException);
      expect(() => plan(days: [1, 1, 3]).validate(), throwsFormatException);
    });

    test('generating again adds nothing and keeps ids', () {
      final p = plan();
      final first = fourWeeks(p);
      final again = PlanSchedule.generate(p, first,
          from: monday, to: monday.addDays(27), now: now, newId: ids());
      expect(again.map((s) => s.id), first.map((s) => s.id));
    });

    test('the rotation is a calendar fact, independent of when generated', () {
      final p = plan();
      final late = PlanSchedule.generate(p, const [],
          from: monday.addDays(14),
          to: monday.addDays(20),
          now: now,
          newId: ids());
      final full = fourWeeks(p);
      for (final s in late) {
        expect(
            s.workoutTemplateId,
            full
                .firstWhere((f) => f.scheduledLocalDate == s.scheduledLocalDate)
                .workoutTemplateId);
      }
    });

    test('levels scale reps only; durations stay', () {
      final adv = PlanTemplates.fullBody(PlanDifficulty.advanced);
      final beg = PlanTemplates.fullBody(PlanDifficulty.beginner);
      expect(adv[0].targets[0].reps, beg[0].targets[0].reps! * 2);
      final timed = adv[2].targets.firstWhere((t) => t.isDuration);
      expect(timed.seconds, 45);
    });
  });

  group('4–5 completion from real saved workouts', () {
    late WorkoutPlan p;
    late List<PlannedSession> sessions;
    setUp(() {
      p = plan();
      sessions = fourWeeks(p);
    });

    test('all targets met by recorded reps → completed', () {
      final a = sessions.first; // Full Body A: 3×6 push, 3×10 curl, 2×10 ext
      final ws = [
        workout('w1', monday, 'push_up', reps: 18),
        workout('w2', monday, 'curl', reps: 30),
        workout('w3', monday, 'overhead_extension', reps: 21),
      ];
      final out = PlanSchedule.reconcile(sessions, ws, now);
      final done = out.first;
      expect(done.id, a.id);
      expect(done.state, SessionState.completed);
      expect(done.completedWorkoutIds, ['w1', 'w2', 'w3']);
      expect(done.completedWorkoutId, 'w1');
      final progress =
          PlanSchedule.progress(done, {for (final w in ws) w.id: w});
      expect(progress.map((x) => x.reps), [18, 30, 21],
          reason: 'totals come from the records, not the targets');
    });

    test('some targets missing → partial; finishing later → completed', () {
      var out = PlanSchedule.reconcile(
          sessions, [workout('w1', monday, 'push_up', reps: 12)], now);
      expect(out.first.state, SessionState.partial);
      out = PlanSchedule.reconcile(
          out,
          [
            workout('w1', monday, 'push_up', reps: 12),
            workout('w2', monday, 'push_up', reps: 6),
            workout('w3', monday, 'curl', reps: 30),
            workout('w4', monday, 'overhead_extension', reps: 20),
          ],
          now);
      expect(out.first.state, SessionState.completed);
    });

    test('a partial record keeps the session partial', () {
      final out = PlanSchedule.reconcile(
          sessions,
          [
            workout('w1', monday, 'push_up', reps: 18, partial: true),
            workout('w2', monday, 'curl', reps: 30),
            workout('w3', monday, 'overhead_extension', reps: 20),
          ],
          now);
      expect(out.first.state, SessionState.partial);
    });

    test('manual reps count, and stay marked manual', () {
      final ws = [workout('w1', monday, 'push_up', reps: 18, manual: true)];
      final out = PlanSchedule.reconcile(sessions, ws, now);
      final p0 = PlanSchedule.progress(out.first, {'w1': ws.first}).first;
      expect(p0.met, isTrue);
      expect(p0.manual, isTrue);
    });

    test('a duration target is met by recorded time, not by reps', () {
      final c = sessions
          .firstWhere((s) => s.workoutTemplateId == PlanTemplates.fullBodyC);
      final ws = [
        workout('t', c.scheduledLocalDate, 'push_up', reps: 4, seconds: 45),
      ];
      final out = PlanSchedule.reconcile(sessions, ws, now);
      final linked = out.firstWhere((s) => s.id == c.id);
      expect(
          PlanSchedule.progress(linked, {'t': ws.first})
              .firstWhere((x) => x.target.isDuration)
              .met,
          isTrue);
    });

    test('13 the same record saved or synced twice is counted once', () {
      final w = workout('w1', monday, 'push_up', reps: 12);
      var out = PlanSchedule.reconcile(sessions, [w], now);
      out = PlanSchedule.reconcile(out, [w, w], now);
      out = [
        for (final s in out)
          s.id == out.first.id ? PlanSchedule.link(s, w, {'w1': w}, now) : s
      ];
      expect(out.first.completedWorkoutIds, ['w1']);
      expect(PlanSchedule.progress(out.first, {'w1': w}).first.reps, 12);
      expect(out.first.history.where((e) => e.kind == SessionEventKind.partial),
          hasLength(1));
    });

    test('a workout on a day without that exercise links to nothing', () {
      final out = PlanSchedule.reconcile(
          sessions, [workout('w', monday.addDays(1), 'push_up', reps: 9)], now);
      expect(out.every((s) => s.completedWorkoutIds.isEmpty), isTrue);
    });
  });

  group('6–7 missed at the local day boundary, never moved', () {
    test('still today: scheduled; after the day ends: missed', () {
      final p = plan();
      final sessions = fourWeeks(p);
      expect(PlanSchedule.markMissed(p, sessions, monday, now).first.state,
          SessionState.scheduled);
      final out = PlanSchedule.markMissed(
          p, sessions, monday.addDays(1), now.add(const Duration(days: 1)));
      expect(out.first.state, SessionState.missed);
      expect(out.first.scheduledLocalDate, monday,
          reason: 'missed sessions are never moved automatically');
      expect(out.where((s) => s.state == SessionState.missed), hasLength(1));
      expect(out.first.history.last.kind, SessionEventKind.missed);
    });

    test('a linked workout keeps it from being missed', () {
      final p = plan();
      var s = PlanSchedule.reconcile(
          fourWeeks(p), [workout('w', monday, 'push_up', reps: 3)], now);
      s = PlanSchedule.markMissed(p, s, monday.addDays(3), now);
      expect(s.first.state, SessionState.partial);
    });

    test('a late-synced workout for the day turns missed into completed', () {
      final p = plan();
      var s = PlanSchedule.markMissed(p, fourWeeks(p), monday.addDays(1), now);
      expect(s.first.state, SessionState.missed);
      s = PlanSchedule.reconcile(
          s,
          [
            workout('w1', monday, 'push_up', reps: 18),
            workout('w2', monday, 'curl', reps: 30),
            workout('w3', monday, 'overhead_extension', reps: 20),
          ],
          now);
      expect(s.first.state, SessionState.completed);
    });

    test('paused plans miss nothing; resuming cancels the paused days', () {
      final p = plan();
      final (paused, s1) = PlanSchedule.setStatus(
          p, fourWeeks(p), PlanStatus.paused, monday, now);
      expect(
          PlanSchedule.markMissed(paused, s1, monday.addDays(5), now)
              .where((s) => s.state == SessionState.missed),
          isEmpty);
      final (active, s2) = PlanSchedule.setStatus(
          paused, s1, PlanStatus.active, monday.addDays(4), now);
      expect(active.status, PlanStatus.active);
      expect(s2.take(3).map((s) => s.state), [
        SessionState.cancelled,
        SessionState.cancelled,
        SessionState.scheduled, // Friday: still today
      ]);
    });

    test('12 the day boundary follows the local calendar of the device', () {
      // 23:30 UTC on Monday is still Monday in New York (UTC-5) but already
      // Tuesday in Ho Chi Minh City (UTC+7).
      final instant = DateTime.utc(2026, 11, 2, 23, 30);
      final ny = LocalDate.atOffset(instant, const Duration(hours: -5));
      final hcm = LocalDate.atOffset(instant, const Duration(hours: 7));
      expect(ny, monday);
      expect(hcm, monday.addDays(1));
      final p = plan();
      expect(PlanSchedule.markMissed(p, fourWeeks(p), ny, now).first.state,
          SessionState.scheduled);
      expect(PlanSchedule.markMissed(p, fourWeeks(p), hcm, now).first.state,
          SessionState.missed);
    });

    test('12 dates are calendar dates: DST and month ends do not shift', () {
      final d = LocalDate(2026, 3, 28);
      expect(d.addDays(2), LocalDate(2026, 3, 30));
      expect(LocalDate(2026, 12, 31).addDays(1), LocalDate(2027, 1, 1));
      expect(LocalDate.parse('2026-11-02'), monday);
      expect(() => LocalDate.parse('2026-02-30'), throwsFormatException);
      expect(monday.addDays(3).startOfWeek, monday);
    });
  });

  group('8–9 explicit rescheduling and conflicts', () {
    late WorkoutPlan p;
    late List<PlannedSession> missed;
    final tuesday = monday.addDays(1);
    setUp(() {
      p = plan();
      missed = PlanSchedule.markMissed(p, fourWeeks(p), tuesday, now);
    });

    test('a missed session moved to a free day keeps identity and history', () {
      final s = missed.first;
      // Saturday is a recovery day: first the warning, then confirmation.
      final saturday = monday.addDays(5);
      final warn =
          PlanSchedule.reschedule(p, missed, s.id, saturday, tuesday, now);
      expect(warn, isA<ScheduleConflict>());
      expect((warn as ScheduleConflict).kind, ScheduleConflictKind.recoveryDay);
      // Every free day of a 3-day plan is a recovery day: they are offered,
      // nearest first, and still need confirming.
      expect(warn.alternatives,
          [monday.addDays(3), monday.addDays(6), monday.addDays(8)]);
      expect(
          warn.alternatives
              .every((d) => PlanSchedule.sessionOn(missed, d) == null),
          isTrue);

      final r = PlanSchedule.reschedule(p, missed, s.id, saturday, tuesday, now,
          confirmRecovery: true) as ScheduleApplied;
      expect(r.session.id, s.id);
      expect(r.session.state, SessionState.scheduled);
      expect(r.session.scheduledLocalDate, saturday);
      expect(r.session.originalScheduledDate, monday);
      expect(r.session.rescheduledFrom, monday);
      expect(r.session.history.map((e) => e.kind), [
        SessionEventKind.created,
        SessionEventKind.missed,
        SessionEventKind.rescheduled,
      ]);
      expect(r.plan.dayKind(saturday), DayKind.training,
          reason: 'the confirmed day is a training day now');
      expect(r.sessions, hasLength(missed.length), reason: 'no new session');
    });

    test('alternatives prefer a day the user marked open', () {
      final open = p.copyWith(
          dayOverrides: {monday.addDays(6): DayKind.open}, updatedAt: now);
      final r = PlanSchedule.reschedule(
          open, missed, missed.first.id, monday.addDays(5), tuesday, now);
      expect((r as ScheduleConflict).alternatives, [monday.addDays(6)]);
    });

    test('an occupied day is refused; nothing is overwritten', () {
      final wednesday = monday.addDays(2);
      final r = PlanSchedule.reschedule(
          p, missed, missed.first.id, wednesday, tuesday, now);
      expect((r as ScheduleConflict).kind, ScheduleConflictKind.occupied);
      expect(r.alternatives, isNot(contains(wednesday)));
    });

    test('past days and finished sessions cannot be targets', () {
      expect(
          (PlanSchedule.reschedule(
                      p, missed, missed[1].id, monday, tuesday, now)
                  as ScheduleConflict)
              .kind,
          ScheduleConflictKind.past);
      final done = PlanSchedule.reconcile(
          missed,
          [
            workout('w', monday.addDays(2), 'pull_up', reps: 9),
            workout('w2', monday.addDays(2), 'push_up', reps: 12),
            workout('w3', monday.addDays(2), 'curl', reps: 20),
          ],
          now);
      expect(
          (PlanSchedule.reschedule(
                  p, done, done[1].id, monday.addDays(3), tuesday, now,
                  confirmRecovery: true) as ScheduleConflict)
              .kind,
          ScheduleConflictKind.notMovable);
    });

    test('the vacated day is not refilled when sessions are generated', () {
      final r = PlanSchedule.reschedule(
          p, missed, missed.first.id, monday.addDays(5), tuesday, now,
          confirmRecovery: true) as ScheduleApplied;
      final again = PlanSchedule.generate(r.plan, r.sessions,
          from: monday, to: monday.addDays(27), now: now, newId: ids());
      expect(again, hasLength(r.sessions.length));
      expect(PlanSchedule.sessionOn(again, monday), isNull);
    });

    test('adding a workout on a recovery day needs confirmation', () {
      final thursday = monday.addDays(3);
      final t = p.templates.first;
      final warn =
          PlanSchedule.addSession(p, missed, thursday, t, tuesday, now, ids());
      expect((warn as ScheduleConflict).kind, ScheduleConflictKind.recoveryDay);
      final ok = PlanSchedule.addSession(
          p, missed, thursday, t, tuesday, now, () => 'extra',
          confirmRecovery: true) as ScheduleApplied;
      expect(PlanSchedule.sessionOn(ok.sessions, thursday)!.id, 'extra');
      final twice = PlanSchedule.addSession(
          ok.plan, ok.sessions, thursday, t, tuesday, now, ids(),
          confirmRecovery: true);
      expect((twice as ScheduleConflict).kind, ScheduleConflictKind.occupied);
    });

    test('skipped and cancelled are distinct from completed and missed', () {
      final skipped = PlanSchedule.close(
          missed, missed.first.id, SessionState.skipped, now);
      expect(skipped.first.state, SessionState.skipped);
      expect(skipped.first.occupiesDay, isFalse);
      final cancelled = PlanSchedule.close(
          skipped, skipped[1].id, SessionState.cancelled, now);
      expect(cancelled[1].state, SessionState.cancelled);
      // A finished session cannot be skipped.
      expect(
          PlanSchedule.close(
                  cancelled, cancelled[1].id, SessionState.skipped, now)[1]
              .state,
          SessionState.cancelled);
    });
  });

  group('editing never rewrites history', () {
    test('new weekdays replan only untouched future sessions', () {
      final p = plan();
      final wednesday = monday.addDays(2);
      var s = fourWeeks(p);
      s = PlanSchedule.reconcile(
          s, [workout('w', monday, 'push_up', reps: 18)], now);
      s = PlanSchedule.markMissed(p, s, wednesday, now);
      final edited = p.copyWith(selectedWeekdays: [
        DateTime.tuesday,
        DateTime.thursday,
        DateTime.saturday,
      ]);
      final (plan2, s2) =
          PlanSchedule.applyEdit(p, edited, s, wednesday, now, ids());
      expect(plan2.version, p.version + 1);
      // Monday (done/partial) and Wednesday (today) are kept as they were.
      expect(s2.firstWhere((x) => x.scheduledLocalDate == monday).state,
          SessionState.partial);
      expect(PlanSchedule.sessionOn(s2, wednesday), isNotNull);
      // Future sessions follow the new days.
      final future = s2.where((x) => x.scheduledLocalDate.isAfter(wednesday));
      expect(future.map((x) => x.scheduledLocalDate.weekday).toSet(),
          {DateTime.tuesday, DateTime.thursday, DateTime.saturday});
      expect(future.every((x) => x.planVersion == plan2.version), isTrue);
    });

    test('editing one session changes only that session', () {
      final p = plan();
      final s = fourWeeks(p);
      final targets = [
        const ExerciseTarget(exerciseId: 'push_up', sets: 2, reps: 5)
      ];
      final out = PlanSchedule.editTargets(s, s[1].id, targets, now);
      expect(out[1].exerciseTargets, targets);
      expect(out[0].exerciseTargets, s[0].exerciseTargets);
      expect(out[4].exerciseTargets, s[4].exerciseTargets);
      expect(
          () => PlanSchedule.editTargets(
              s,
              s[1].id,
              [const ExerciseTarget(exerciseId: 'push_up', sets: 0, reps: 5)],
              now),
          throwsFormatException);
    });
  });

  test('plans and sessions survive a JSON round trip', () {
    final p = plan().copyWith(
        dayOverrides: {monday.addDays(1): DayKind.open}, updatedAt: now);
    final back = WorkoutPlan.fromJson(p.toJson());
    expect(back.toJson(), p.toJson());
    final s = fourWeeks(p).first;
    expect(PlannedSession.fromJson(s.toJson()).toJson(), s.toJson());
    expect(back.dayKind(monday.addDays(1)), DayKind.open);
  });
}
