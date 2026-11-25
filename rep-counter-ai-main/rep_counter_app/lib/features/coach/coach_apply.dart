import '../credits/ai_coach_v2.dart';
import '../plan/application/plan_repository.dart';
import '../plan/domain/local_date.dart';
import '../plan/domain/workout_plan.dart';

/// D-35 "Apply to plan": the coach's targets for one planned session.
/// Only a session that is still scheduled can change; logged workouts and
/// past sessions never do. Undo puts the previous targets back.
abstract final class CoachApply {
  /// The coach's numbers laid onto [planned], in the plan's order. Only
  /// exercises the session already has change (same exercise and the same
  /// kind, reps or seconds): the coach never adds or removes exercises.
  /// Invalid numbers keep the planned target.
  static List<ExerciseTarget> merge(
    List<ExerciseTarget> planned,
    List<CoachTarget> coach,
  ) {
    final used = <int>{};
    return [
      for (final p in planned)
        () {
          for (var i = 0; i < coach.length; i++) {
            final c = coach[i];
            if (used.contains(i) ||
                c.exerciseId != p.exerciseId ||
                c.isDuration != p.isDuration) {
              continue;
            }
            used.add(i);
            final next = ExerciseTarget(
              exerciseId: p.exerciseId,
              sets: c.sets,
              reps: c.reps,
              seconds: c.seconds,
              tracking: p.tracking,
            );
            try {
              next.validate();
              return next;
            } catch (_) {
              return p;
            }
          }
          return p;
        }(),
    ];
  }

  /// Indexes of [proposed] that differ from [current] (same length).
  static List<int> changed(
    List<ExerciseTarget> current,
    List<ExerciseTarget> proposed,
  ) =>
      [
        for (var i = 0; i < current.length && i < proposed.length; i++)
          if (current[i] != proposed[i]) i,
      ];

  /// The next session still to come, today included.
  static PlannedSession? nextSession(PlanView view, {bool todayOnly = false}) {
    final next = view.sessions
        .where(
          (s) =>
              s.isUpcoming &&
              (todayOnly
                  ? s.scheduledLocalDate == view.today
                  : !s.scheduledLocalDate.isBefore(view.today)),
        )
        .toList()
      ..sort(
        (a, b) => a.scheduledLocalDate.compareTo(b.scheduledLocalDate),
      );
    return next.isEmpty ? null : next.first;
  }
}

/// One applied change, kept for Undo.
class CoachApplied {
  const CoachApplied(this.sessionId, this.date, this.previous);
  final String sessionId;
  final LocalDate date;
  final List<ExerciseTarget> previous;
}

/// Writes targets to scheduled sessions through [PlanRepository.editTargets]
/// (the same write as editing a session by hand).
class CoachApplier {
  CoachApplier(this.repository);
  final PlanRepository repository;

  /// Applies [targets] to [sessionId] if it is still scheduled. Returns
  /// what Undo needs, or null when nothing changed.
  Future<CoachApplied?> apply(
    String sessionId,
    List<ExerciseTarget> targets,
  ) async {
    final view = await repository.load();
    final session = view?.sessions.where((s) => s.id == sessionId).firstOrNull;
    if (session == null || !session.isUpcoming) return null;
    if (_same(session.exerciseTargets, targets)) return null;
    await repository.editTargets(sessionId, targets);
    return CoachApplied(
      sessionId,
      session.scheduledLocalDate,
      session.exerciseTargets,
    );
  }

  Future<void> undo(CoachApplied applied) =>
      repository.editTargets(applied.sessionId, applied.previous);

  static bool _same(List<ExerciseTarget> a, List<ExerciseTarget> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
