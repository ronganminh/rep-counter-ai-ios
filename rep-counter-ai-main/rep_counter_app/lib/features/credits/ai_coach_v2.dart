import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../plan/application/plan_repository.dart';
import '../plan/domain/overload_advisor.dart';
import '../plan/domain/workout_plan.dart';
import 'ai_credits.dart';

/// AI-1 coach v2, the "virtual PT" (L-D43, `docs/implementation/08_AI_COACH_PLAN.md`).
/// Off by default; on in staging. Needs accounts and AI credits.
class AiCoachV2 {
  const AiCoachV2._();

  static const bool enabled = AiCredits.enabled &&
      bool.fromEnvironment('ENABLE_AI_COACH_V2', defaultValue: false);

  /// Chat keeps the last 15 turns (user + assistant), the server's v2 limit.
  static const chatTurns = 15;

  /// v2 sends more than v1 (4-week history, plan, chat memory), so the
  /// coach consent is asked again (08 §4).
  static const consentKey = 'ai_coach_consent_v2';
}

enum TargetChange { increase, maintain, decrease }

/// One exercise target the coach proposes. Mirrors the server validator
/// (`supabase/functions/ai-request/schema.ts`) and the plan model's limits.
@immutable
class CoachTarget {
  const CoachTarget({
    required this.exerciseId,
    required this.sets,
    this.reps,
    this.seconds,
    required this.restSeconds,
    required this.change,
    this.note = '',
  });

  final String exerciseId;
  final int sets;
  final int? reps, seconds;
  final int restSeconds;
  final TargetChange change;
  final String note;

  bool get isDuration => seconds != null;

  static int? _int(Object? v, int min, int max) =>
      v is int && v >= min && v <= max ? v : null;

  static CoachTarget? fromJson(Object? v) {
    if (v is! Map) return null;
    final id = v['exercise_id'];
    if (id is! String || !RegExp(r'^[a-z0-9_]{1,40}$').hasMatch(id)) {
      return null;
    }
    final sets = _int(v['sets'], 1, 10);
    final reps = v['reps'] == null ? null : _int(v['reps'], 1, 100);
    final seconds = v['seconds'] == null ? null : _int(v['seconds'], 5, 3600);
    final rest = _int(v['rest_seconds'] ?? 60, 0, 600);
    final change = switch (v['change']) {
      'increase' => TargetChange.increase,
      'maintain' => TargetChange.maintain,
      'decrease' => TargetChange.decrease,
      _ => null,
    };
    if (sets == null || rest == null || change == null) return null;
    if ((v['reps'] != null && reps == null) ||
        (v['seconds'] != null && seconds == null) ||
        (reps == null) == (seconds == null)) {
      return null;
    }
    final note = v['note'];
    return CoachTarget(
      exerciseId: id,
      sets: sets,
      reps: reps,
      seconds: seconds,
      restSeconds: rest,
      change: change,
      note: note is String ? note.trim() : '',
    );
  }

  static List<CoachTarget> listFrom(Object? v) => v is List
      ? v.map(CoachTarget.fromJson).whereType<CoachTarget>().toList()
      : const [];
}

/// A structured v2 answer (`data` in the ai-request response).
sealed class CoachAnswer {
  const CoachAnswer();

  /// Targets the user may apply to the plan (empty for chat / progress).
  List<CoachTarget> get targets => const [];

  static CoachAnswer? parse(CreditedRequest kind, Map<String, Object?>? data) {
    if (data == null) return null;
    String? str(Object? v) =>
        v is String && v.trim().isNotEmpty ? v.trim() : null;
    List<String> strs(Object? v) =>
        v is List ? v.map(str).whereType<String>().toList() : const [];
    switch (kind) {
      case CreditedRequest.workoutReview:
        final summary = str(data['summary']);
        final fixes = strs(data['fixes']);
        if (summary == null || fixes.isEmpty) return null;
        return CoachWorkoutReview(
            summary: summary,
            fixes: fixes,
            nextSession: CoachTarget.listFrom(data['next_session']));
      case CreditedRequest.planSuggestion:
        final summary = str(data['summary']);
        final horizon = data['horizon'];
        if (summary == null ||
            (horizon != 'tomorrow' && horizon != 'next_week')) {
          return null;
        }
        final sessions = <CoachSession>[];
        for (final s
            in data['sessions'] is List ? data['sessions'] as List : const []) {
          if (s is! Map) continue;
          final day = CoachTarget._int(s['day_offset'], 1, 7);
          final exercises = CoachTarget.listFrom(s['exercises']);
          if (day == null || exercises.isEmpty) continue;
          sessions.add(CoachSession(
              dayOffset: day,
              focus: str(s['focus']) ?? '',
              exercises: exercises));
        }
        return CoachPlanSuggestion(
            summary: summary,
            nextWeek: horizon == 'next_week',
            sessions: sessions);
      default:
        return null;
    }
  }
}

class CoachWorkoutReview extends CoachAnswer {
  const CoachWorkoutReview(
      {required this.summary, required this.fixes, required this.nextSession});
  final String summary;
  final List<String> fixes;
  final List<CoachTarget> nextSession;
  @override
  List<CoachTarget> get targets => nextSession;
}

class CoachSession {
  const CoachSession(
      {required this.dayOffset, required this.focus, required this.exercises});
  final int dayOffset;
  final String focus;
  final List<CoachTarget> exercises;
}

class CoachPlanSuggestion extends CoachAnswer {
  const CoachPlanSuggestion(
      {required this.summary, required this.nextWeek, required this.sessions});
  final String summary;
  final bool nextWeek;
  final List<CoachSession> sessions;

  /// The first proposal per exercise, in session order.
  @override
  List<CoachTarget> get targets {
    final seen = <String>{};
    return [
      for (final s in sessions)
        for (final t in s.exercises)
          if (seen.add(t.exerciseId)) t
    ];
  }
}

abstract final class CoachPlan {
  /// What the coach gets about the active plan: numbers and ids only.
  static Map<String, Object?> context(PlanView? view, {int upcoming = 7}) {
    if (view == null) return {'plan': null};
    final p = view.plan;
    Map<String, Object?> target(ExerciseTarget t) => {
          'exercise_id': t.exerciseId,
          'sets': t.sets,
          if (t.reps != null) 'reps': t.reps,
          if (t.seconds != null) 'seconds': t.seconds,
        };
    final next = view.sessions
        .where(
            (s) => s.isUpcoming && !s.scheduledLocalDate.isBefore(view.today))
        .toList()
      ..sort((a, b) => a.scheduledLocalDate.compareTo(b.scheduledLocalDate));
    final past = view.sessions
        .where((s) =>
            s.scheduledLocalDate.isBefore(view.today) &&
            !s.scheduledLocalDate.isBefore(view.today.addDays(-28)))
        .toList();
    int count(SessionState st) => past.where((s) => s.state == st).length;
    return {
      'goal': {'goal': p.goal.name, 'difficulty': p.difficulty.name},
      'plan': {
        'status': p.status.name,
        'training_days_per_week': p.selectedWeekdays.length,
        'progressive_overload': p.progressiveOverload,
        'templates': [
          for (final t in p.templates)
            {
              'id': t.id,
              'targets': [for (final x in t.targets) target(x)]
            }
        ],
        'upcoming': [
          for (final s in next.take(upcoming))
            {
              'in_days': view.today.daysUntil(s.scheduledLocalDate),
              'template_id': s.workoutTemplateId,
            }
        ],
        'last_28_days': {
          'completed': count(SessionState.completed),
          'partial': count(SessionState.partial),
          'missed': count(SessionState.missed),
          'skipped': count(SessionState.skipped),
        },
      },
    };
  }

  /// Matches each coach target to a template target of the same exercise
  /// and kind (reps or seconds): the template of the next session first,
  /// then the others. Targets the plan has no slot for, or that equal the
  /// current target, are left out: the coach never adds exercises by itself.
  static List<ProposedChange> changes(
      PlanView view, List<CoachTarget> targets) {
    final next = view.sessions
        .where(
            (s) => s.isUpcoming && !s.scheduledLocalDate.isBefore(view.today))
        .toList()
      ..sort((a, b) => a.scheduledLocalDate.compareTo(b.scheduledLocalDate));
    final first =
        next.isEmpty ? null : view.plan.template(next.first.workoutTemplateId);
    final order = <WorkoutTemplate>[
      if (first != null) first,
      ...view.plan.templates.where((t) => first == null || t.id != first.id),
    ];
    final used = <String>{};
    final out = <ProposedChange>[];
    for (final c in targets) {
      for (final t in order) {
        final i = t.targets.indexWhere((x) =>
            x.exerciseId == c.exerciseId &&
            x.isDuration == c.isDuration &&
            !used.contains('${t.id}|${t.targets.indexOf(x)}'));
        if (i < 0) continue;
        final current = t.targets[i];
        final proposed = ExerciseTarget(
            exerciseId: current.exerciseId,
            sets: c.sets,
            reps: c.reps,
            seconds: c.seconds,
            tracking: current.tracking);
        try {
          proposed.validate();
        } catch (_) {
          break;
        }
        if (proposed.sets == current.sets &&
            proposed.reps == current.reps &&
            proposed.seconds == current.seconds) {
          break;
        }
        used.add('${t.id}|$i');
        out.add(ProposedChange(
            OverloadSuggestion(
                templateId: t.id,
                index: i,
                current: current,
                proposed: proposed,
                kind: SuggestionKind.increase,
                evidence: 0),
            c.note));
        break;
      }
    }
    return out;
  }
}

/// The coach's long-term summary of the user (goals, preferences, limits),
/// returned by the server and kept **on this phone only**, per account
/// (D-21: never stored on the server). "Forget" clears it.
class CoachMemoryStore {
  static const prefix = 'ai_coach_memory_v1:';

  Future<String?> load(String userId) async =>
      (await SharedPreferences.getInstance()).getString('$prefix$userId');

  Future<void> save(String userId, String memory) async {
    final prefs = await SharedPreferences.getInstance();
    final m = memory.trim();
    if (m.isEmpty) return;
    await prefs.setString(
        '$prefix$userId', m.length > 600 ? m.substring(0, 600) : m);
  }

  /// Removes the summaries of every account on this phone.
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    for (final k
        in prefs.getKeys().where((k) => k.startsWith(prefix)).toList()) {
      await prefs.remove(k);
    }
  }
}
