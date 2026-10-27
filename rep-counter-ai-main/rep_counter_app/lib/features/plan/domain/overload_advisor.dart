import 'package:flutter/foundation.dart';

import 'plan_schedule.dart';
import 'workout_plan.dart';

enum SuggestionKind {
  /// A small, explained step up.
  increase,

  /// Not enough complete history, or the target was not met: keep it.
  maintain,
}

/// A proposed change to one target of a plan template. Only a proposal: the
/// user accepts, edits or dismisses it; nothing is applied automatically and
/// completed sessions and records are never changed.
@immutable
class OverloadSuggestion {
  const OverloadSuggestion({
    required this.templateId,
    required this.index,
    required this.current,
    required this.proposed,
    required this.kind,
    required this.evidence,
  });

  final String templateId;

  /// Position of the target in the template.
  final int index;
  final ExerciseTarget current, proposed;
  final SuggestionKind kind;

  /// How many recent complete sessions met the target.
  final int evidence;

  /// Identifies "this suggestion for this current target": once dismissed,
  /// it stays dismissed until the target itself changes.
  String get key =>
      '$templateId|$index|${current.exerciseId}|${current.sets}|${current.reps}|${current.seconds}';
}

/// PL-1 rule 5: optional, OFF by default, conservative and explainable.
///
/// For each template target, look at the most recent sessions that used it.
/// Only complete sessions count as evidence (not partial, missed or skipped,
/// and the target met by recorded activity). After [required] consecutive
/// complete sessions that met the target, propose about 10 % more (at least
/// one rep, or 5 s for a timed target — no universal "+2 reps"). If the
/// latest session of that template missed the target, or there is too
/// little history, suggest keeping the current target. Rep and duration
/// targets are handled separately.
class OverloadAdvisor {
  const OverloadAdvisor._();

  static const required = 2;

  static List<OverloadSuggestion> suggest(
    WorkoutPlan plan,
    List<PlannedSession> sessions,
    Map<String, PlanWorkout> workouts, {
    Set<String> dismissed = const {},
  }) {
    if (!plan.progressiveOverload) return const [];
    final out = <OverloadSuggestion>[];
    for (final template in plan.templates) {
      final history = [
        for (final s in sessions)
          if (s.workoutTemplateId == template.id &&
              (s.state == SessionState.completed ||
                  s.state == SessionState.partial ||
                  s.state == SessionState.missed))
            s
      ]..sort((a, b) => b.scheduledLocalDate.compareTo(a.scheduledLocalDate));
      if (history.isEmpty) continue;
      for (var i = 0; i < template.targets.length; i++) {
        final target = template.targets[i];
        var streak = 0;
        var sawAny = false;
        for (final s in history) {
          final p = _progressFor(s, target, workouts);
          // Sessions without this exercise, or planned with an easier
          // target than today's, say nothing about the current target.
          if (p == null || !_sameTarget(p.target, target)) continue;
          sawAny = true;
          if (s.state == SessionState.completed && p.met) {
            streak++;
            if (streak >= required) break;
          } else {
            break;
          }
        }
        if (!sawAny) continue;
        final suggestion = streak >= required
            ? OverloadSuggestion(
                templateId: template.id,
                index: i,
                current: target,
                proposed: step(target),
                kind: SuggestionKind.increase,
                evidence: streak)
            : OverloadSuggestion(
                templateId: template.id,
                index: i,
                current: target,
                proposed: target,
                kind: SuggestionKind.maintain,
                evidence: streak);
        if (suggestion.kind == SuggestionKind.increase &&
            suggestion.proposed == target) {
          continue; // already at the cap
        }
        if (!dismissed.contains(suggestion.key)) out.add(suggestion);
      }
    }
    return out;
  }

  /// About 10 % more: reps +max(1, 10 %) up to 100; time +max(5 s, 10 %)
  /// rounded to 5 s, up to 600 s. Sets never change automatically.
  static ExerciseTarget step(ExerciseTarget t) {
    if (t.isDuration) {
      final s = t.seconds!;
      final up = ((s * 0.1) / 5).ceil() * 5;
      return t.copyWith(seconds: (s + (up < 5 ? 5 : up)).clamp(5, 600));
    }
    final r = t.reps!;
    final up = (r * 0.1).round();
    return t.copyWith(reps: (r + (up < 1 ? 1 : up)).clamp(1, 100));
  }

  static TargetProgress? _progressFor(PlannedSession s, ExerciseTarget target,
      Map<String, PlanWorkout> workouts) {
    for (final p in PlanSchedule.progress(s, workouts)) {
      if (p.target.exerciseId == target.exerciseId &&
          p.target.isDuration == target.isDuration) {
        return p;
      }
    }
    return null;
  }

  static bool _sameTarget(ExerciseTarget done, ExerciseTarget now) =>
      done.isDuration
          ? done.seconds! * done.sets >= now.seconds! * now.sets
          : done.totalReps >= now.totalReps;

  /// Applies an accepted (possibly edited) suggestion to the template; the
  /// repository then replans only sessions still to come.
  static WorkoutPlan apply(
      WorkoutPlan plan, OverloadSuggestion s, ExerciseTarget accepted) {
    accepted.validate();
    return plan.copyWith(templates: [
      for (final t in plan.templates)
        if (t.id == s.templateId)
          t.copyWith(targets: [
            for (var i = 0; i < t.targets.length; i++)
              i == s.index ? accepted : t.targets[i]
          ])
        else
          t
    ]);
  }
}
