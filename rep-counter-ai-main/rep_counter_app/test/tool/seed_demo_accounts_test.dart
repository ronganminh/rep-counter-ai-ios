import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/features/coach/coach_apply.dart';
import 'package:rep_counter_app/features/coach/coach_v2.dart';
import 'package:rep_counter_app/features/plan/application/plan_repository.dart';
import 'package:rep_counter_app/features/plan/domain/local_date.dart';
import 'package:rep_counter_app/features/plan/domain/plan_templates.dart';
import 'package:rep_counter_app/features/plan/domain/workout_plan.dart';
import 'package:rep_counter_app/features/sync/cloud_sync.dart';
import 'package:rep_counter_app/features/sync/plan_sync.dart';
import 'package:rep_counter_app/features/workout/data/workout_database.dart';
import 'package:rep_counter_app/features/workout/data/workout_record.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Contract for `tool/seed_demo_accounts.py` (docs/qa/DEMO_ACCOUNTS.md): the
/// documents it pushes for the App Review accounts are read by this app's
/// own code, and give what the reviewer is told to expect (Coach's pick
/// today, next week, D-32). Also runs the script's own tests (fake
/// Supabase on localhost). Skipped where `python3` is missing.
void main() {
  final script = File('../../tool/seed_demo_accounts.py');
  final python = _python();

  Map<String, dynamic> docs(DateTime now) {
    final day = '${now.year}-${_two(now.month)}-${_two(now.day)}';
    final r = Process.runSync(
        python!, ['-I', script.path, '--print-docs', '--today', day],
        environment: {'DEMO_TIMEZONE': 'UTC'});
    expect(r.exitCode, 0, reason: '${r.stderr}');
    return jsonDecode(r.stdout as String) as Map<String, dynamic>;
  }

  test('the script\'s own tests pass (fake Supabase, no network)', () {
    final r = Process.runSync(
        python!, ['-I', '../../tool/test_seed_demo_accounts.py']);
    expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
  }, skip: python == null ? 'python3 not installed' : false);

  test('workouts parse as saved workouts: 5 push-up/curl in 2 weeks, D-32', () {
    final now = DateTime.now();
    final d = docs(now);
    final records = <WorkoutRecord>[
      for (final w in d['workouts'] as List)
        parseWorkoutJson(jsonEncode({...w as Map, 'client_id': w['id']}))!
            .record
    ];
    expect(records, hasLength(5));
    expect(records.map((r) => r.exerciseId).toSet(), {'push_up', 'curl'});
    expect(records.length, greaterThanOrEqualTo(CoachMinimum.pickWorkouts));
    for (final r in records) {
      expect(r.manual, isFalse);
      expect(r.quality!.hasEnoughData, isTrue);
      expect(r.startedAt.isBefore(now), isTrue);
      expect(now.difference(r.startedAt).inDays, lessThan(16));
    }
    final first =
        records.map((r) => r.startedAt).reduce((a, b) => a.isBefore(b) ? a : b);
    expect(LocalDate.of(first).daysUntil(LocalDate.of(now)) + 1,
        greaterThanOrEqualTo(CoachMinimum.weekHistoryDays));
  }, skip: python == null ? 'python3 not installed' : false);

  test('plan syncs in, is active and has a session today and the next 5 days',
      () async {
    SharedPreferences.setMockInitialValues({});
    final now = DateTime.now();
    final d = docs(now);
    final doc = (d['plan'] as Map).cast<String, Object?>();
    final plan = WorkoutPlan.fromJson(
        (doc['plan'] as Map).cast<String, dynamic>()); // validates
    expect(plan.status, PlanStatus.active);
    expect(plan.selectedWeekdays, hasLength(WorkoutPlan.maxDays));
    expect(
        jsonEncode([for (final t in plan.templates) t.toJson()]),
        jsonEncode([
          for (final t in PlanTemplates.fullBody(PlanDifficulty.beginner))
            t.toJson()
        ]),
        reason: 'TEMPLATES in the script must match PlanTemplates');

    await PlanSyncSource().apply(
        SyncWorkout(clientId: plan.id, raw: doc, clientUpdatedAt: now.toUtc()));
    var n = 0;
    final repo = PlanRepository(
        loadWorkouts: () async => const [],
        now: () => now,
        newId: () => 's${n++}');
    final view = (await repo.load())!;
    expect(view.plan.id, 'demo-plan');
    expect(CoachApply.nextSession(view, todayOnly: true), isNotNull,
        reason: "Coach's pick needs a session today");
    final today = LocalDate.of(now);
    for (var i = 0; i < 6; i++) {
      expect(view.sessions.any((s) => s.scheduledLocalDate == today.addDays(i)),
          isTrue,
          reason: 'day +$i');
    }
  }, skip: python == null ? 'python3 not installed' : false);
}

String _two(int v) => v.toString().padLeft(2, '0');

String? _python() {
  try {
    final r = Process.runSync('python3', ['--version']);
    return r.exitCode == 0 ? 'python3' : null;
  } catch (_) {
    return null;
  }
}
