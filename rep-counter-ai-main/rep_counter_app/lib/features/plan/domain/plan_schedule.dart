import 'package:flutter/foundation.dart';

import '../../workout/data/workout_record.dart';
import 'local_date.dart';
import 'workout_plan.dart';

/// PL-1 scheduling rules, as pure functions over a plan and its sessions.
/// Nothing here reads a clock or storage: callers pass `today` (the device's
/// local calendar day) and `now`, which keeps every rule unit-testable,
/// including time-zone and day-boundary changes.

/// The read-only facts of a saved WorkoutRecord that sessions need. Totals
/// always come from what was recorded, never from plan targets.
@immutable
class PlanWorkout {
  const PlanWorkout({
    required this.id,
    required this.exerciseId,
    required this.date,
    required this.reps,
    required this.durationSeconds,
    this.partial = false,
    this.manual = false,
  });

  factory PlanWorkout.fromRecord(WorkoutRecord r) => PlanWorkout(
        id: r.id,
        exerciseId: r.exerciseId,
        date: LocalDate.of(r.startedAt),
        reps: r.reps,
        durationSeconds: r.durationSeconds,
        partial: r.partial,
        manual: r.manual,
      );

  final String id, exerciseId;
  final LocalDate date;
  final int reps, durationSeconds;
  final bool partial;

  /// Entered by hand: counts toward the session, never as camera-verified.
  final bool manual;
}

/// One day of a calendar view.
@immutable
class PlanDay {
  const PlanDay(this.date, this.kind, this.session);

  final LocalDate date;
  final DayKind kind;
  final PlannedSession? session;

  bool get isRecovery => kind == DayKind.recovery && session == null;
}

/// Progress on one target, from linked records.
@immutable
class TargetProgress {
  const TargetProgress(this.target, this.reps, this.seconds, this.manual);

  final ExerciseTarget target;
  final int reps, seconds;
  final bool manual;

  bool get met => target.isDuration
      ? seconds >= target.seconds! * target.sets
      : reps >= target.totalReps;
}

sealed class ScheduleResult {
  const ScheduleResult();
}

/// Applied: the new plan and sessions to save.
class ScheduleApplied extends ScheduleResult {
  const ScheduleApplied(this.plan, this.sessions, this.session);
  final WorkoutPlan plan;
  final List<PlannedSession> sessions;
  final PlannedSession session;
}

enum ScheduleConflictKind {
  /// Another session already holds that day; nothing is overwritten.
  occupied,

  /// The day is a recovery day: ask, then retry with `confirmRecovery`.
  recoveryDay,

  /// The day has already ended.
  past,

  /// Only scheduled or missed sessions can be moved.
  notMovable,

  unknownSession,
}

/// Not applied; [alternatives] are free training or open days nearby.
class ScheduleConflict extends ScheduleResult {
  const ScheduleConflict(this.kind, {this.alternatives = const []});
  final ScheduleConflictKind kind;
  final List<LocalDate> alternatives;
}

class PlanSchedule {
  const PlanSchedule._();

  /// Plan creation previews this many days.
  static const previewDays = 28;

  /// The training day's place in the A/B/C rotation: how many training
  /// weekdays came before it since the plan started. Depends only on the
  /// calendar, so it is the same however often sessions are generated.
  static int rotationIndex(WorkoutPlan plan, LocalDate date) {
    final days =
        date.isBefore(plan.startDate) ? 0 : plan.startDate.daysUntil(date);
    final weeks = days ~/ 7;
    var count = weeks * plan.weeklyFrequency;
    for (var d = plan.startDate.addDays(weeks * 7);
        d.isBefore(date);
        d = d.addDays(1)) {
      if (plan.selectedWeekdays.contains(d.weekday)) count++;
    }
    return count;
  }

  static WorkoutTemplate templateFor(WorkoutPlan plan, LocalDate date) =>
      plan.templates[rotationIndex(plan, date) % plan.templates.length];

  static PlannedSession? sessionOn(
      List<PlannedSession> sessions, LocalDate date) {
    for (final s in sessions) {
      if (s.scheduledLocalDate == date && s.occupiesDay) return s;
    }
    return null;
  }

  /// Adds the missing sessions for training days in [from]..[to]. A day
  /// keeps the session it had: generation never fills a day a session was
  /// moved away from, and never adds a second session to a day.
  static List<PlannedSession> generate(
    WorkoutPlan plan,
    List<PlannedSession> sessions, {
    required LocalDate from,
    required LocalDate to,
    required DateTime now,
    required String Function() newId,
  }) {
    final out = [...sessions];
    final start = from.isBefore(plan.startDate) ? plan.startDate : from;
    final used = <LocalDate>{
      for (final s in sessions) ...[
        s.originalScheduledDate,
        s.scheduledLocalDate
      ]
    };
    for (var d = start; !d.isAfter(to); d = d.addDays(1)) {
      if (plan.dayKind(d) != DayKind.training ||
          !plan.selectedWeekdays.contains(d.weekday) ||
          used.contains(d)) {
        continue;
      }
      final template = templateFor(plan, d);
      out.add(PlannedSession(
        id: newId(),
        planId: plan.id,
        planVersion: plan.version,
        scheduledLocalDate: d,
        workoutTemplateId: template.id,
        exerciseTargets: template.targets,
        originalScheduledDate: d,
        history: [SessionEvent(SessionEventKind.created, now, to: d)],
        createdAt: now,
        updatedAt: now,
      ));
    }
    out.sort((a, b) => a.scheduledLocalDate.compareTo(b.scheduledLocalDate));
    return out;
  }

  /// The calendar for [days] days from [from]: each day's kind and session.
  static List<PlanDay> calendar(
      WorkoutPlan plan, List<PlannedSession> sessions, LocalDate from,
      {int days = previewDays}) {
    return [
      for (var i = 0; i < days; i++)
        PlanDay(from.addDays(i), plan.dayKind(from.addDays(i)),
            sessionOn(sessions, from.addDays(i))),
    ];
  }

  /// A scheduled session becomes missed once its local day has ended
  /// (`date < today`) with no linked workout. Missed sessions are never
  /// moved automatically. Only active plans miss sessions.
  static List<PlannedSession> markMissed(WorkoutPlan plan,
      List<PlannedSession> sessions, LocalDate today, DateTime now) {
    if (plan.status != PlanStatus.active) return sessions;
    return [
      for (final s in sessions)
        if (s.state == SessionState.scheduled &&
            s.scheduledLocalDate.isBefore(today) &&
            s.completedWorkoutIds.isEmpty)
          s.copyWith(
              state: SessionState.missed,
              event: SessionEvent(SessionEventKind.missed, now,
                  from: s.scheduledLocalDate),
              updatedAt: now)
        else
          s
    ];
  }

  /// Progress per target from the linked workouts that are available.
  static List<TargetProgress> progress(
      PlannedSession session, Map<String, PlanWorkout> workouts) {
    final linked = [
      for (final id in session.completedWorkoutIds)
        if (workouts[id] != null) workouts[id]!
    ];
    return [
      for (final t in session.exerciseTargets)
        () {
          final mine = linked.where((w) => w.exerciseId == t.exerciseId);
          return TargetProgress(
            t,
            mine.fold(0, (sum, w) => sum + w.reps),
            mine.fold(0, (sum, w) => sum + w.durationSeconds),
            mine.any((w) => w.manual),
          );
        }()
    ];
  }

  /// Links [workout] to [session] (once, by record id) and re-evaluates it:
  /// completed when every target is met by recorded activity, otherwise
  /// partial. A partial record keeps the session partial.
  static PlannedSession link(PlannedSession session, PlanWorkout workout,
      Map<String, PlanWorkout> workouts, DateTime now) {
    if (session.state == SessionState.cancelled ||
        session.state == SessionState.skipped) {
      return session;
    }
    final ids = session.completedWorkoutIds.contains(workout.id)
        ? session.completedWorkoutIds
        : [...session.completedWorkoutIds, workout.id];
    final all = {...workouts, workout.id: workout};
    final linked = [
      for (final id in ids)
        if (all[id] != null) all[id]!
    ];
    final done = progress(
            session.copyWith(completedWorkoutIds: ids, updatedAt: now), all)
        .every((p) => p.met);
    final state = done && !linked.any((w) => w.partial)
        ? SessionState.completed
        : SessionState.partial;
    if (identical(ids, session.completedWorkoutIds) && state == session.state) {
      return session;
    }
    return session.copyWith(
      completedWorkoutIds: ids,
      state: state,
      event: state == session.state
          ? null
          : SessionEvent(
              state == SessionState.completed
                  ? SessionEventKind.completed
                  : SessionEventKind.partial,
              now),
      updatedAt: now,
    );
  }

  /// Links saved workouts to the plan's sessions: a workout belongs to the
  /// session on its own local day whose targets include its exercise.
  /// Idempotent: a record already linked anywhere is skipped, so saving or
  /// syncing the same workout twice never counts twice.
  static List<PlannedSession> reconcile(
      List<PlannedSession> sessions, List<PlanWorkout> workouts, DateTime now) {
    final byId = {for (final w in workouts) w.id: w};
    final linked = {for (final s in sessions) ...s.completedWorkoutIds};
    final out = [...sessions];
    for (final w in workouts) {
      if (linked.contains(w.id)) continue;
      final i = out.indexWhere((s) =>
          s.scheduledLocalDate == w.date &&
          s.occupiesDay &&
          s.exerciseTargets.any((t) => t.exerciseId == w.exerciseId));
      if (i < 0) continue;
      out[i] = link(out[i], w, byId, now);
      linked.add(w.id);
    }
    return out;
  }

  /// Free days near [around] (not past, not taken by another session),
  /// nearest first: training and open days, then — when the week has none —
  /// recovery days, which the UI labels and which still need confirming.
  static List<LocalDate> alternatives(WorkoutPlan plan,
      List<PlannedSession> sessions, LocalDate around, LocalDate today,
      {int limit = 3, String? exceptSessionId}) {
    final free = <LocalDate>[];
    for (var i = 1; i <= 7; i++) {
      for (final d in [around.addDays(i), around.addDays(-i)]) {
        if (d.isBefore(today)) continue;
        final other = sessionOn(sessions, d);
        if (other != null && other.id != exceptSessionId) continue;
        free.add(d);
      }
    }
    final preferred = [
      for (final d in free)
        if (plan.dayKind(d) != DayKind.recovery) d
    ];
    final picked =
        (preferred.isNotEmpty ? preferred : free).take(limit).toList()..sort();
    return picked;
  }

  /// Checks [to] for a session; returns null when it is free.
  static ScheduleConflict? _check(WorkoutPlan plan,
      List<PlannedSession> sessions, LocalDate to, LocalDate today,
      {required bool confirmRecovery, String? movingId}) {
    if (to.isBefore(today)) {
      return ScheduleConflict(ScheduleConflictKind.past,
          alternatives: alternatives(plan, sessions, today, today,
              exceptSessionId: movingId));
    }
    final other = sessionOn(sessions, to);
    if (other != null && other.id != movingId) {
      return ScheduleConflict(ScheduleConflictKind.occupied,
          alternatives: alternatives(plan, sessions, to, today,
              exceptSessionId: movingId));
    }
    if (plan.dayKind(to) == DayKind.recovery && !confirmRecovery) {
      return ScheduleConflict(ScheduleConflictKind.recoveryDay,
          alternatives: alternatives(plan, sessions, to, today,
              exceptSessionId: movingId));
    }
    return null;
  }

  static WorkoutPlan _claimDay(WorkoutPlan plan, LocalDate to, DateTime now) =>
      plan.dayKind(to) == DayKind.recovery
          ? plan.copyWith(
              dayOverrides: {...plan.dayOverrides, to: DayKind.training},
              updatedAt: now)
          : plan;

  /// Moves a scheduled or missed session to [to] only when the user asked
  /// for it. Keeps its id, its original date and its history; a recovery day
  /// needs `confirmRecovery`; an occupied day is refused.
  static ScheduleResult reschedule(
    WorkoutPlan plan,
    List<PlannedSession> sessions,
    String sessionId,
    LocalDate to,
    LocalDate today,
    DateTime now, {
    bool confirmRecovery = false,
  }) {
    final i = sessions.indexWhere((s) => s.id == sessionId);
    if (i < 0) {
      return const ScheduleConflict(ScheduleConflictKind.unknownSession);
    }
    final s = sessions[i];
    if (s.state != SessionState.scheduled && s.state != SessionState.missed) {
      return const ScheduleConflict(ScheduleConflictKind.notMovable);
    }
    if (to == s.scheduledLocalDate && s.state == SessionState.scheduled) {
      return ScheduleApplied(plan, sessions, s);
    }
    final conflict = _check(plan, sessions, to, today,
        confirmRecovery: confirmRecovery, movingId: s.id);
    if (conflict != null) return conflict;
    final moved = s.copyWith(
      scheduledLocalDate: to,
      state: SessionState.scheduled,
      rescheduledFrom: s.scheduledLocalDate,
      event: SessionEvent(SessionEventKind.rescheduled, now,
          from: s.scheduledLocalDate, to: to),
      updatedAt: now,
    );
    final out = [...sessions]..[i] = moved;
    return ScheduleApplied(_claimDay(plan, to, now), out, moved);
  }

  /// Adds a workout on a day the user picked (e.g. a recovery day, after
  /// they confirmed the recovery warning).
  static ScheduleResult addSession(
    WorkoutPlan plan,
    List<PlannedSession> sessions,
    LocalDate date,
    WorkoutTemplate template,
    LocalDate today,
    DateTime now,
    String Function() newId, {
    bool confirmRecovery = false,
  }) {
    final conflict =
        _check(plan, sessions, date, today, confirmRecovery: confirmRecovery);
    if (conflict != null) return conflict;
    final session = PlannedSession(
      id: newId(),
      planId: plan.id,
      planVersion: plan.version,
      scheduledLocalDate: date,
      workoutTemplateId: template.id,
      exerciseTargets: template.targets,
      originalScheduledDate: date,
      history: [SessionEvent(SessionEventKind.created, now, to: date)],
      createdAt: now,
      updatedAt: now,
    );
    final out = [...sessions, session]
      ..sort((a, b) => a.scheduledLocalDate.compareTo(b.scheduledLocalDate));
    return ScheduleApplied(_claimDay(plan, date, now), out, session);
  }

  /// Skipped or cancelled by the user: distinct from completed and missed.
  static List<PlannedSession> close(List<PlannedSession> sessions,
      String sessionId, SessionState to, DateTime now) {
    assert(to == SessionState.skipped || to == SessionState.cancelled);
    return [
      for (final s in sessions)
        if (s.id == sessionId &&
            (s.state == SessionState.scheduled ||
                s.state == SessionState.missed))
          s.copyWith(
              state: to,
              event: SessionEvent(
                  to == SessionState.skipped
                      ? SessionEventKind.skipped
                      : SessionEventKind.cancelled,
                  now,
                  from: s.scheduledLocalDate),
              updatedAt: now)
        else
          s
    ];
  }

  /// Edits the targets of one upcoming session only.
  static List<PlannedSession> editTargets(List<PlannedSession> sessions,
      String sessionId, List<ExerciseTarget> targets, DateTime now) {
    for (final t in targets) {
      t.validate();
    }
    return [
      for (final s in sessions)
        if (s.id == sessionId && s.state == SessionState.scheduled)
          s.copyWith(
              exerciseTargets: targets,
              event: SessionEvent(SessionEventKind.targetsEdited, now),
              updatedAt: now)
        else
          s
    ];
  }

  /// Applies an edited plan (weekdays, templates) to the future only:
  /// sessions after [today] that are still untouched (scheduled, never
  /// moved, nothing linked) are replanned; every other session — done,
  /// partial, missed, skipped, cancelled, moved by the user, today's — is
  /// kept exactly as it is.
  static (WorkoutPlan, List<PlannedSession>) applyEdit(
    WorkoutPlan current,
    WorkoutPlan edited,
    List<PlannedSession> sessions,
    LocalDate today,
    DateTime now,
    String Function() newId, {
    int horizonDays = previewDays,
  }) {
    edited.validate();
    final plan = edited.copyWith(
        version: current.version + 1,
        // Old weekday customisations no longer apply to the new pattern.
        dayOverrides: {
          for (final e in current.dayOverrides.entries)
            if (!e.key.isAfter(today) ||
                sessions.any((s) =>
                    s.scheduledLocalDate == e.key &&
                    s.occupiesDay &&
                    _keeps(s, today)))
              e.key: e.value
        },
        updatedAt: now);
    final kept = [
      for (final s in sessions)
        if (_keeps(s, today)) s
    ];
    return (
      plan,
      generate(plan, kept,
          from: today.addDays(1),
          to: today.addDays(horizonDays - 1),
          now: now,
          newId: newId)
    );
  }

  static bool _keeps(PlannedSession s, LocalDate today) =>
      !s.scheduledLocalDate.isAfter(today) ||
      s.state != SessionState.scheduled ||
      s.rescheduledFrom != null ||
      s.completedWorkoutIds.isNotEmpty ||
      s.history.length > 1;

  /// Pausing keeps every session; on resuming, sessions whose day passed
  /// during the pause are cancelled (not missed: the user paused the plan).
  static (WorkoutPlan, List<PlannedSession>) setStatus(
      WorkoutPlan plan,
      List<PlannedSession> sessions,
      PlanStatus status,
      LocalDate today,
      DateTime now) {
    final resuming =
        plan.status == PlanStatus.paused && status == PlanStatus.active;
    return (
      plan.copyWith(status: status, updatedAt: now),
      [
        for (final s in sessions)
          if (resuming &&
              s.state == SessionState.scheduled &&
              s.scheduledLocalDate.isBefore(today) &&
              s.completedWorkoutIds.isEmpty)
            s.copyWith(
                state: SessionState.cancelled,
                event: SessionEvent(SessionEventKind.cancelled, now,
                    from: s.scheduledLocalDate),
                updatedAt: now)
          else
            s
      ]
    );
  }
}
