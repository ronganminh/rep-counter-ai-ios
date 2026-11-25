import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/application/auth_controller.dart';
import '../credits/ai_coach_v2.dart';
import '../credits/ai_credits.dart';
import '../credits/credits_controller.dart';
import '../plan/application/plan_repository.dart';
import '../plan/domain/local_date.dart';
import '../plan/domain/plan_schedule.dart';
import '../plan/domain/workout_plan.dart';
import '../workout/data/workout_record.dart';
import 'coach_apply.dart';
import 'coach_v2.dart';

/// AC-04 "Coach · next week" in My plan (`/home/plan`, D-36), 2 credits
/// (D-29).
///
/// Backend gap (10 §stubs 5): `plan_suggestion` (horizon `next_week`)
/// proposes exercise targets per day offset; it cannot move sessions or
/// rest days and has no per-day reason, and the server charges 1 credit
/// per request. The card shows next week's planned sessions with the
/// targets the coach changed; applying a day writes that session only.
@immutable
class CoachWeek {
  const CoachWeek({
    required this.weekStart,
    required this.madeOn,
    required this.proposed,
    this.notes = const {},
    this.summary = '',
    this.previous = const {},
    this.dismissed = false,
  });

  /// Monday of the suggested week.
  final LocalDate weekStart, madeOn;

  /// Session id → the coach's targets for it (changed sessions only).
  final Map<String, List<ExerciseTarget>> proposed;

  /// Session id → the coach's note for the change.
  final Map<String, String> notes;
  final String summary;

  /// Session id → targets before "Apply" (for Undo).
  final Map<String, List<ExerciseTarget>> previous;

  /// "Keep my plan" for this week.
  final bool dismissed;

  CoachWeek copyWith(
          {Map<String, List<ExerciseTarget>>? previous, bool? dismissed}) =>
      CoachWeek(
          weekStart: weekStart,
          madeOn: madeOn,
          proposed: proposed,
          notes: notes,
          summary: summary,
          previous: previous ?? this.previous,
          dismissed: dismissed ?? this.dismissed);

  static Map<String, dynamic> _targets(Map<String, List<ExerciseTarget>> m) => {
        for (final e in m.entries) e.key: [for (final t in e.value) t.toJson()]
      };

  static Map<String, List<ExerciseTarget>> _read(Object? v) => {
        for (final e in ((v as Map?) ?? const {}).entries)
          '${e.key}': [
            for (final t in e.value as List)
              ExerciseTarget.fromJson(Map<String, dynamic>.from(t as Map))
          ]
      };

  Map<String, dynamic> toJson() => {
        'week_start': weekStart.toIso(),
        'made_on': madeOn.toIso(),
        'proposed': _targets(proposed),
        'notes': notes,
        'summary': summary,
        'previous': _targets(previous),
        'dismissed': dismissed,
      };

  static CoachWeek? fromJson(Object? j) {
    if (j is! Map) return null;
    try {
      return CoachWeek(
        weekStart: LocalDate.parse(j['week_start'] as String),
        madeOn: LocalDate.parse(j['made_on'] as String),
        proposed: _read(j['proposed']),
        notes: {
          for (final e in ((j['notes'] as Map?) ?? const {}).entries)
            '${e.key}': '${e.value}'
        },
        summary: (j['summary'] as String?) ?? '',
        previous: _read(j['previous']),
        dismissed: j['dismissed'] == true,
      );
    } catch (_) {
      return null;
    }
  }
}

class CoachWeekStore {
  static const prefix = 'coach_week_v1:';

  Future<CoachWeek?> load(String userId) async {
    final raw =
        (await SharedPreferences.getInstance()).getString('$prefix$userId');
    if (raw == null) return null;
    try {
      return CoachWeek.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String userId, CoachWeek w) async =>
      (await SharedPreferences.getInstance())
          .setString('$prefix$userId', jsonEncode(w.toJson()));
}

enum CoachWeekPhase { hidden, noData, idle, generating, ready, dismissed }

enum CoachWeekIssue { noCredits, offline, failed, limit, nothing }

class CoachWeekController extends ChangeNotifier {
  CoachWeekController({
    required this.credits,
    required this.plans,
    required this.loadWorkouts,
    CoachWeekStore? store,
    CoachConsentStore consent = const CoachConsentStore(),
    this.newId,
  })  : _store = store ?? CoachWeekStore(),
        _consent = consent;

  final CreditsController credits;
  final PlanRepository plans;
  final Future<List<WorkoutRecord>> Function() loadWorkouts;
  final CoachWeekStore _store;
  final CoachConsentStore _consent;
  final String Function()? newId;

  CoachWeekPhase phase = CoachWeekPhase.hidden;
  CoachWeekIssue? issue;
  PlanView? view;
  CoachWeek? week;

  /// Days of history (first saved workout to today), for D-32.
  int historyDays = 0;
  String? _pendingId;
  bool _disposed = false;

  String? get _userId => switch (credits.auth.state) {
        AuthSignedIn(:final user) => user.id,
        _ => null,
      };

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  LocalDate get weekStart => view!.today.startOfWeek.addDays(7);

  /// The plan's week number of [weekStart] (1-based).
  int get weekNumber {
    final v = view!;
    final d = v.plan.startDate.startOfWeek.daysUntil(weekStart);
    return d < 0 ? 1 : d ~/ 7 + 1;
  }

  List<PlanDay> get days => view!.calendar(weekStart, days: 7);

  Future<void> load() async {
    final user = _userId;
    if (user == null || !await _consent.given()) {
      phase = CoachWeekPhase.hidden;
      return _notify();
    }
    try {
      view = await plans.load();
    } catch (_) {
      view = null;
    }
    final v = view;
    if (v == null || v.plan.status != PlanStatus.active) {
      phase = CoachWeekPhase.hidden;
      return _notify();
    }
    List<WorkoutRecord> records;
    try {
      records = await loadWorkouts();
    } catch (_) {
      records = const [];
    }
    if (records.isEmpty) {
      historyDays = 0;
    } else {
      final first = records
          .map((r) => r.startedAt)
          .reduce((a, b) => a.isBefore(b) ? a : b);
      historyDays = LocalDate.of(first).daysUntil(v.today) + 1;
    }
    if (historyDays < CoachMinimum.weekHistoryDays) {
      phase = CoachWeekPhase.noData;
      return _notify();
    }
    final cached = await _store.load(user);
    week = cached != null && cached.weekStart == weekStart ? cached : null;
    phase = week == null
        ? CoachWeekPhase.idle
        : week!.dismissed
            ? CoachWeekPhase.dismissed
            : CoachWeekPhase.ready;
    _notify();
  }

  Future<void> _save(CoachWeek w) async {
    week = w;
    final user = _userId;
    if (user != null) await _store.save(user, w);
  }

  /// Asks the coach (2 credits shown, D-29). Nothing is sent at 0 credits.
  Future<void> generate({required String locale}) async {
    final v = view;
    if (v == null || phase == CoachWeekPhase.generating) return;
    final b = credits.balance;
    if (b != null && b.balance < 1) {
      issue = CoachWeekIssue.noCredits;
      return _notify();
    }
    phase = CoachWeekPhase.generating;
    issue = null;
    _notify();
    final pending = _pendingId;
    final conversation = CoachConversation(credits,
        v2: true, newId: pending == null ? newId : () => pending);
    try {
      await conversation.analyze(CreditedRequest.planSuggestion, 'week_plan',
          {'horizon': 'next_week', ...CoachPlan.context(v, upcoming: 14)},
          locale: locale);
      final turn = conversation.turns.single;
      final answer = CoachAnswer.parse(turn.kind, turn.data);
      switch (turn.state) {
        case CoachTurnState.answered when answer is CoachPlanSuggestion:
          _pendingId = null;
          final w = _map(v, answer);
          if (w.proposed.isEmpty) issue = CoachWeekIssue.nothing;
          await _save(w);
          phase = CoachWeekPhase.ready;
        case CoachTurnState.outOfCredits:
          _pendingId = null;
          issue = CoachWeekIssue.noCredits;
          phase = CoachWeekPhase.idle;
        case CoachTurnState.failed:
          _pendingId = turn.requestId;
          issue = switch (turn.failure) {
            CoachFailure.offline => CoachWeekIssue.offline,
            CoachFailure.limit => CoachWeekIssue.limit,
            _ => CoachWeekIssue.failed,
          };
          phase = CoachWeekPhase.idle;
        default:
          _pendingId = null;
          issue = CoachWeekIssue.failed;
          phase = CoachWeekPhase.idle;
      }
    } finally {
      conversation.dispose();
      _notify();
    }
  }

  /// Coach sessions land on next week's planned sessions: the session on
  /// the same day first, then the remaining ones in date order.
  CoachWeek _map(PlanView v, CoachPlanSuggestion a) {
    final sessions = [
      for (final d in days)
        if (d.session != null && d.session!.isUpcoming) d.session!
    ];
    final free = [...sessions];
    final proposed = <String, List<ExerciseTarget>>{};
    final notes = <String, String>{};
    final pending = <CoachSession>[];
    for (final s in a.sessions) {
      final date = v.today.addDays(s.dayOffset);
      final match = free.where((x) => x.scheduledLocalDate == date).firstOrNull;
      if (match == null) {
        pending.add(s);
        continue;
      }
      free.remove(match);
      _put(match, s, proposed, notes);
    }
    for (final s in pending) {
      if (free.isEmpty) break;
      _put(free.removeAt(0), s, proposed, notes);
    }
    return CoachWeek(
        weekStart: weekStart,
        madeOn: v.today,
        proposed: proposed,
        notes: notes,
        summary: a.summary);
  }

  static void _put(PlannedSession session, CoachSession s,
      Map<String, List<ExerciseTarget>> proposed, Map<String, String> notes) {
    final merged = CoachApply.merge(session.exerciseTargets, s.exercises);
    if (CoachApply.changed(session.exerciseTargets, merged).isEmpty) return;
    proposed[session.id] = merged;
    final note = s.exercises
        .map((e) => e.note)
        .firstWhere((n) => n.isNotEmpty, orElse: () => s.focus);
    if (note.isNotEmpty) notes[session.id] = note;
  }

  PlannedSession? session(String id) =>
      view?.sessions.where((s) => s.id == id).firstOrNull;

  bool applied(String sessionId) =>
      week?.previous.containsKey(sessionId) ?? false;

  /// Changed days still to apply (scheduled, not applied yet).
  List<String> get pending => [
        for (final id in week?.proposed.keys ?? const <String>[])
          if (!applied(id) && (session(id)?.isUpcoming ?? false)) id
      ];

  Future<bool> apply(String sessionId) async {
    final w = week;
    final targets = w?.proposed[sessionId];
    if (w == null || targets == null) return false;
    final done = await CoachApplier(plans).apply(sessionId, targets);
    if (done == null) return false;
    await _save(
        w.copyWith(previous: {...w.previous, sessionId: done.previous}));
    view = await plans.load();
    _notify();
    return true;
  }

  Future<void> undo(String sessionId) async {
    final w = week;
    final before = w?.previous[sessionId];
    if (w == null || before == null) return;
    await plans.editTargets(sessionId, before);
    await _save(w.copyWith(previous: {...w.previous}..remove(sessionId)));
    view = await plans.load();
    _notify();
  }

  Future<int> applyAll() async {
    var n = 0;
    for (final id in pending) {
      if (await apply(id)) n++;
    }
    return n;
  }

  /// "Keep my plan": nothing changes; hidden for this week.
  Future<void> keep() async {
    final w = week;
    if (w == null) return;
    await _save(w.copyWith(dismissed: true));
    phase = CoachWeekPhase.dismissed;
    _notify();
  }
}
