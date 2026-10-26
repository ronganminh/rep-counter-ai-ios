import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/features/plan/application/plan_repository.dart';
import 'package:rep_counter_app/features/plan/data/plan_store.dart';
import 'package:rep_counter_app/features/plan/domain/local_date.dart';
import 'package:rep_counter_app/features/plan/domain/plan_schedule.dart';
import 'package:rep_counter_app/features/plan/domain/plan_templates.dart';
import 'package:rep_counter_app/features/plan/domain/workout_plan.dart';
import 'package:rep_counter_app/features/workout/data/workout_record.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// PL-1 through the repository: local store, real WorkoutRecords, guest
/// (no account, no network).

final monday = LocalDate(2026, 11, 2);

WorkoutRecord record(String id, DateTime at, String exercise, int reps,
        {bool partial = false, bool manual = false}) =>
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
      partial: partial,
      manual: manual,
    );

void main() {
  late DateTime now;
  late List<WorkoutRecord> history;
  late PlanRepository repo;
  var n = 0;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    now = DateTime(2026, 11, 2, 8);
    history = [];
    n = 0;
    repo = PlanRepository(
        loadWorkouts: () async => history,
        now: () => now,
        newId: () => 'id${++n}');
  });

  WorkoutPlan draft() => PlanTemplates.beginnerPlan(
      id: 'plan', startDate: monday, timezone: repo.timezone, now: now);

  test('16 a guest creates and follows the default plan, all local', () async {
    final preview = repo.preview(draft());
    expect(preview, hasLength(28));
    expect(preview.where((d) => d.session != null), hasLength(12));
    expect(await PlanStore().load(), isA<PlanSnapshot>());
    expect((await PlanStore().load()).plans, isEmpty,
        reason: 'previewing saves nothing');

    final view = await repo.activate(draft());
    expect(view.plan.status, PlanStatus.active);
    expect(view.plan.ownerId, isNull);
    expect(view.plan.progressiveOverload, isFalse);
    expect(view.sessions, hasLength(12));
    expect(view.todaySession!.workoutTemplateId, PlanTemplates.fullBodyA);
    final raw =
        (await SharedPreferences.getInstance()).getString(PlanStore.key)!;
    expect(jsonDecode(raw)['plans'], hasLength(1));
  });

  test('a second plan is refused unless the first is archived', () async {
    await repo.activate(draft());
    final other = PlanTemplates.beginnerPlan(
        id: 'plan2', startDate: monday, timezone: 'UTC', now: now);
    await expectLater(repo.activate(other), throwsA(isA<PlanAlreadyActive>()));
    final view = await repo.activate(other, replaceCurrent: true);
    expect(view.plan.id, 'plan2');
    final snap = await PlanStore().load();
    expect(snap.plans.firstWhere((p) => p.id == 'plan').status,
        PlanStatus.archived);
    expect(snap.sessionsOf('plan'), hasLength(12),
        reason: 'the old plan keeps its sessions and history');
  });

  test(
      '4 a saved WorkoutRecord completes the session; saving twice does not '
      'count twice', () async {
    final view = await repo.activate(draft());
    final a = view.todaySession!;
    history.addAll([
      record('w1', DateTime(2026, 11, 2, 9), 'push_up', 18),
      record('w2', DateTime(2026, 11, 2, 9, 20), 'curl', 30),
      record('w3', DateTime(2026, 11, 2, 9, 40), 'overhead_extension', 20),
    ]);
    await repo.linkWorkout(a.id, history.first);
    await repo.linkWorkout(a.id, history.first);
    final v = (await repo.load())!;
    final done = v.sessions.firstWhere((s) => s.id == a.id);
    expect(done.state, SessionState.completed);
    expect(done.completedWorkoutIds, ['w1', 'w2', 'w3']);
    expect(PlanSchedule.progress(done, v.workouts).map((p) => p.reps),
        [18, 30, 20]);
    // A sync retry delivering the same records again changes nothing.
    final again = (await repo.load())!;
    expect(again.sessions.firstWhere((s) => s.id == a.id).completedWorkoutIds,
        ['w1', 'w2', 'w3']);
  });

  test('5 a partial (recovered) workout leaves the session partial', () async {
    final view = await repo.activate(draft());
    history.add(record('draft-1', DateTime(2026, 11, 2, 9), 'push_up', 7,
        partial: true));
    final v = (await repo.load())!;
    expect(v.sessions.firstWhere((s) => s.id == view.todaySession!.id).state,
        SessionState.partial);
  });

  test('6–7 the next day it is missed, and stays on its day', () async {
    final view = await repo.activate(draft());
    now = DateTime(2026, 11, 2, 23, 59);
    expect((await repo.load())!.missed, isEmpty);
    now = DateTime(2026, 11, 3, 0, 1);
    final v = (await repo.load())!;
    expect(v.missed.single.id, view.todaySession!.id);
    expect(v.missed.single.scheduledLocalDate, monday);
    expect(v.sessions, hasLength(13), reason: 'horizon rolls forward');
  });

  test('8 rescheduling: recovery warning, then the confirmed move', () async {
    await repo.activate(draft());
    now = DateTime(2026, 11, 3, 10);
    final missed = (await repo.load())!.missed.single;
    final thursday = monday.addDays(3);
    final warn = await repo.reschedule(missed.id, thursday);
    expect((warn as ScheduleConflict).kind, ScheduleConflictKind.recoveryDay);
    expect((await repo.load())!.missed.single.id, missed.id,
        reason: 'nothing changed without confirmation');
    final ok =
        await repo.reschedule(missed.id, thursday, confirmRecovery: true);
    expect(ok, isA<ScheduleApplied>());
    final v = (await repo.load())!;
    final moved = v.sessions.firstWhere((s) => s.id == missed.id);
    expect(moved.scheduledLocalDate, thursday);
    expect(moved.originalScheduledDate, monday);
    expect(v.missed, isEmpty);
    expect(PlanSchedule.sessionOn(v.sessions, monday), isNull);
  });

  test('skip and edit go through the store', () async {
    final view = await repo.activate(draft());
    final wed = view.sessions[1];
    await repo.skip(wed.id);
    await repo.editTargets(view.sessions[2].id,
        [const ExerciseTarget(exerciseId: 'push_up', sets: 1, reps: 5)]);
    final v = (await repo.load())!;
    expect(v.sessions[1].state, SessionState.skipped);
    expect(v.sessions[2].exerciseTargets.single.reps, 5);
    final edited = await repo.edit(v.plan
        .copyWith(selectedWeekdays: [DateTime.tuesday, DateTime.thursday]));
    expect(edited!.plan.version, 2);
    expect(edited.sessions.firstWhere((s) => s.id == wed.id).state,
        SessionState.skipped,
        reason: 'history is kept');
  });

  test('history failing to load does not stop the plan', () async {
    await repo.activate(draft());
    final broken = PlanRepository(
        loadWorkouts: () async => throw StateError('db'),
        now: () => now,
        newId: () => 'x${++n}');
    expect((await broken.load())!.sessions, hasLength(12));
  });

  test('unreadable entries are kept, never dropped on the next write',
      () async {
    await repo.activate(draft());
    final prefs = await SharedPreferences.getInstance();
    final json =
        jsonDecode(prefs.getString(PlanStore.key)!) as Map<String, dynamic>;
    (json['plans'] as List).add({'id': 'future', 'weird': true});
    await prefs.setString(PlanStore.key, jsonEncode(json));
    await repo.load();
    final after =
        jsonDecode(prefs.getString(PlanStore.key)!) as Map<String, dynamic>;
    expect(after['unreadable'], [
      {
        'plan': {'id': 'future', 'weird': true}
      }
    ]);
  });

  test('a newer schema is refused rather than overwritten', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PlanStore.key, '{"schema_version": 99}');
    await expectLater(repo.load(), throwsStateError);
    expect(prefs.getString(PlanStore.key), '{"schema_version": 99}');
  });
}
