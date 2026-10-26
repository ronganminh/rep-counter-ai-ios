import 'package:flutter/foundation.dart';

import '../../workout/data/workout_database.dart';
import '../../workout/data/workout_history_store.dart';
import '../../workout/data/workout_record.dart';
import '../data/plan_store.dart';
import '../domain/local_date.dart';
import '../domain/plan_schedule.dart';
import '../domain/workout_plan.dart';

/// The current plan with its sessions, after the day's rules were applied.
@immutable
class PlanView {
  const PlanView(this.plan, this.sessions, this.workouts, this.today);

  final WorkoutPlan plan;
  final List<PlannedSession> sessions;

  /// Saved workouts by id (to show real totals for linked sessions).
  final Map<String, PlanWorkout> workouts;
  final LocalDate today;

  List<PlanDay> calendar(LocalDate from,
          {int days = PlanSchedule.previewDays}) =>
      PlanSchedule.calendar(plan, sessions, from, days: days);

  PlannedSession? get todaySession => PlanSchedule.sessionOn(sessions, today);

  List<PlannedSession> get missed => [
        for (final s in sessions)
          if (s.state == SessionState.missed) s
      ];
}

class PlanAlreadyActive implements Exception {
  const PlanAlreadyActive(this.current);
  final WorkoutPlan current;
}

/// Applies the PL-1 rules to stored plans: keeps four weeks of sessions
/// ahead, marks ended days missed (never moves them), and links saved
/// workouts to sessions. Workouts are read from the local history only;
/// a plan never writes or edits a WorkoutRecord.
class PlanRepository {
  PlanRepository({
    PlanStore? store,
    Future<List<WorkoutRecord>> Function()? loadWorkouts,
    DateTime Function()? now,
    String Function()? newId,
  })  : _store = store ?? PlanStore(),
        _loadWorkouts = loadWorkouts ?? WorkoutHistoryStore().load,
        _now = now ?? DateTime.now,
        _newId = newId ?? WorkoutDatabase.newClientId;

  final PlanStore _store;
  final Future<List<WorkoutRecord>> Function() _loadWorkouts;
  final DateTime Function() _now;
  final String Function() _newId;

  /// The device's local calendar day: decides missed and today.
  LocalDate get today => LocalDate.of(_now());

  /// The device time-zone label stored with new plans.
  String get timezone => _now().timeZoneName;

  /// Builds the 4-week preview of a draft without saving anything.
  List<PlanDay> preview(WorkoutPlan draft) {
    final now = _now();
    final from = draft.startDate.isBefore(today) ? today : draft.startDate;
    final sessions = PlanSchedule.generate(draft, const [],
        from: from,
        to: from.addDays(PlanSchedule.previewDays - 1),
        now: now,
        newId: () => 'preview');
    return PlanSchedule.calendar(draft, sessions, from);
  }

  /// Saves [draft] as the active plan. Another active or paused plan must be
  /// ended first unless [replaceCurrent], which archives it (its sessions
  /// and history are kept).
  Future<PlanView> activate(WorkoutPlan draft,
      {bool replaceCurrent = false}) async {
    draft.validate();
    final now = _now();
    await _store.update((snap) {
      final current = snap.current;
      var next = snap;
      if (current != null && current.id != draft.id) {
        if (!replaceCurrent) throw PlanAlreadyActive(current);
        next = next.replacePlan(
            current.copyWith(status: PlanStatus.archived, updatedAt: now),
            next.sessionsOf(current.id));
      }
      final plan = draft.copyWith(status: PlanStatus.active, updatedAt: now);
      return next.replacePlan(plan, next.sessionsOf(plan.id));
    });
    return (await load())!;
  }

  /// The current plan with today's rules applied (and saved when they
  /// changed something), or null when there is none.
  Future<PlanView?> load() async {
    final records = await _safeWorkouts();
    final workouts = {for (final w in records) w.id: w};
    final now = _now();
    final day = LocalDate.of(now);
    PlanView? view;
    await _store.update((snap) {
      final plan = snap.current;
      if (plan == null) return snap;
      var sessions = snap.sessionsOf(plan.id);
      if (plan.status == PlanStatus.active) {
        sessions = PlanSchedule.generate(plan, sessions,
            from: day,
            to: day.addDays(PlanSchedule.previewDays - 1),
            now: now,
            newId: _newId);
      }
      sessions = PlanSchedule.reconcile(sessions, records, now);
      sessions = PlanSchedule.markMissed(plan, sessions, day, now);
      view = PlanView(plan, sessions, workouts, day);
      return snap.replacePlan(plan, sessions);
    });
    return view;
  }

  Future<List<PlanWorkout>> _safeWorkouts() async {
    try {
      return [for (final r in await _loadWorkouts()) PlanWorkout.fromRecord(r)];
    } catch (_) {
      // History unavailable: plans still load; links catch up next time.
      return const [];
    }
  }

  Future<PlanView?> _change(
      (WorkoutPlan, List<PlannedSession>)? Function(WorkoutPlan plan,
              List<PlannedSession> sessions, LocalDate today, DateTime now)
          change) async {
    final now = _now();
    await _store.update((snap) {
      final plan = snap.current;
      if (plan == null) return snap;
      final next =
          change(plan, snap.sessionsOf(plan.id), LocalDate.of(now), now);
      return next == null ? snap : snap.replacePlan(next.$1, next.$2);
    });
    return load();
  }

  /// Moves a session only on the user's explicit request; returns the
  /// conflict instead of changing anything when the day is taken, past, or
  /// a recovery day without `confirmRecovery`.
  Future<ScheduleResult> reschedule(String sessionId, LocalDate to,
      {bool confirmRecovery = false}) async {
    late ScheduleResult result;
    await _change((plan, sessions, today, now) {
      result = PlanSchedule.reschedule(
          plan, sessions, sessionId, to, today, now,
          confirmRecovery: confirmRecovery);
      final r = result;
      return r is ScheduleApplied ? (r.plan, r.sessions) : null;
    });
    return result;
  }

  Future<ScheduleResult> addSession(LocalDate date, String templateId,
      {bool confirmRecovery = false}) async {
    late ScheduleResult result;
    await _change((plan, sessions, today, now) {
      final template = plan.template(templateId);
      if (template == null) {
        result = const ScheduleConflict(ScheduleConflictKind.unknownSession);
        return null;
      }
      result = PlanSchedule.addSession(
          plan, sessions, date, template, today, now, _newId,
          confirmRecovery: confirmRecovery);
      final r = result;
      return r is ScheduleApplied ? (r.plan, r.sessions) : null;
    });
    return result;
  }

  Future<PlanView?> skip(String sessionId) =>
      _change((plan, sessions, _, now) => (
            plan,
            PlanSchedule.close(sessions, sessionId, SessionState.skipped, now)
          ));

  Future<PlanView?> cancel(String sessionId) =>
      _change((plan, sessions, _, now) => (
            plan,
            PlanSchedule.close(sessions, sessionId, SessionState.cancelled, now)
          ));

  Future<PlanView?> editTargets(
          String sessionId, List<ExerciseTarget> targets) =>
      _change((plan, sessions, _, now) =>
          (plan, PlanSchedule.editTargets(sessions, sessionId, targets, now)));

  /// Weekdays, templates or name changed: only untouched future sessions
  /// are replanned; history is never rewritten.
  Future<PlanView?> edit(WorkoutPlan edited) =>
      _change((plan, sessions, today, now) =>
          PlanSchedule.applyEdit(plan, edited, sessions, today, now, _newId));

  Future<PlanView?> setStatus(PlanStatus status) =>
      _change((plan, sessions, today, now) =>
          PlanSchedule.setStatus(plan, sessions, status, today, now));

  /// Links a just-saved workout to the session the user started it from.
  /// Linking the same record again changes nothing.
  Future<PlanView?> linkWorkout(String sessionId, WorkoutRecord record) async {
    final workout = PlanWorkout.fromRecord(record);
    final others = {for (final w in await _safeWorkouts()) w.id: w};
    return _change((plan, sessions, _, now) {
      if (sessions.any((s) =>
          s.id != sessionId && s.completedWorkoutIds.contains(record.id))) {
        return null;
      }
      return (
        plan,
        [
          for (final s in sessions)
            s.id == sessionId ? PlanSchedule.link(s, workout, others, now) : s
        ]
      );
    });
  }
}
