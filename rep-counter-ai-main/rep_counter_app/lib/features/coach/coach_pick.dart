import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/application/auth_controller.dart';
import '../credits/ai_coach_v2.dart';
import '../credits/ai_credits.dart';
import '../credits/credits_controller.dart';
import '../plan/application/plan_repository.dart';
import '../plan/domain/local_date.dart';
import '../plan/domain/workout_plan.dart';
import '../workout/data/workout_record.dart';
import 'coach_apply.dart';
import 'coach_v2.dart';

/// AC-01 Coach's pick for today: one planned session, the coach's numbers
/// for it, and why.
///
/// Backend gap (docs/implementation/10 §stubs 1): `ai-request` charges one
/// credit for every request, so the free once-a-day pick (D-29, D-31) is
/// made **on the phone** from today's planned session (no AI request, no
/// reason sentence). "New suggestion" is a real AI request
/// (`plan_suggestion`, 1 credit) and its summary becomes the reason.
@immutable
class CoachPick {
  const CoachPick({
    required this.madeOn,
    required this.sessionId,
    required this.templateId,
    required this.planned,
    required this.suggested,
    this.reason,
    this.rest = const {},
    this.ai = false,
    this.skipped = false,
    this.useSuggestion = true,
  });

  final LocalDate madeOn;
  final String sessionId, templateId;

  /// The session's targets when the pick was made, and the coach's.
  final List<ExerciseTarget> planned, suggested;

  /// The AI's one-sentence reason (null for the free pick made on the phone).
  final String? reason;

  /// Rest seconds per exercise id, when the AI gave them.
  final Map<String, int> rest;
  final bool ai, skipped;

  /// AC-01f: "Use the suggestion" (true) or "Keep as planned".
  final bool useSuggestion;

  bool get adjusted => CoachApply.changed(planned, suggested).isNotEmpty;

  /// What Start trains.
  List<ExerciseTarget> get targets =>
      useSuggestion && adjusted ? suggested : planned;

  CoachPick copyWith({bool? skipped, bool? useSuggestion}) => CoachPick(
        madeOn: madeOn,
        sessionId: sessionId,
        templateId: templateId,
        planned: planned,
        suggested: suggested,
        reason: reason,
        rest: rest,
        ai: ai,
        skipped: skipped ?? this.skipped,
        useSuggestion: useSuggestion ?? this.useSuggestion,
      );

  Map<String, dynamic> toJson() => {
        'made_on': madeOn.toIso(),
        'session_id': sessionId,
        'template_id': templateId,
        'planned': [for (final t in planned) t.toJson()],
        'suggested': [for (final t in suggested) t.toJson()],
        if (reason != null) 'reason': reason,
        'rest': rest,
        'ai': ai,
        'skipped': skipped,
        'use_suggestion': useSuggestion,
      };

  static CoachPick? fromJson(Object? j) {
    if (j is! Map) return null;
    try {
      List<ExerciseTarget> list(Object? v) => [
            for (final t in v as List)
              ExerciseTarget.fromJson(Map<String, dynamic>.from(t as Map)),
          ];
      return CoachPick(
        madeOn: LocalDate.parse(j['made_on'] as String),
        sessionId: j['session_id'] as String,
        templateId: j['template_id'] as String,
        planned: list(j['planned']),
        suggested: list(j['suggested']),
        reason: j['reason'] as String?,
        rest: {
          for (final e in ((j['rest'] as Map?) ?? const {}).entries)
            if (e.value is int) '${e.key}': e.value as int,
        },
        ai: j['ai'] == true,
        skipped: j['skipped'] == true,
        useSuggestion: j['use_suggestion'] != false,
      );
    } catch (_) {
      return null;
    }
  }
}

/// The pick kept for its day only (D-31: cached for that day). Per account.
class CoachPickStore {
  static const prefix = 'coach_pick_v1:';

  Future<CoachPick?> load(String userId) async {
    final raw = (await SharedPreferences.getInstance()).getString(
      '$prefix$userId',
    );
    if (raw == null) return null;
    try {
      return CoachPick.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String userId, CoachPick pick) async =>
      (await SharedPreferences.getInstance()).setString(
        '$prefix$userId',
        jsonEncode(pick.toJson()),
      );
}

enum CoachPickPhase {
  /// Nothing to show: flag/consent/account missing, no active plan, or no
  /// planned session today. Home stays as it is (D-30).
  hidden,

  /// Fewer than [CoachMinimum.pickWorkouts] saved workouts (AC-01b).
  noData,

  /// Reading (first frame only; the free pick is made on the phone).
  loading,
  ready,

  /// Skipped for today (AC-01g).
  skipped,
}

/// Why the last "New suggestion" did not replace the pick. The current
/// pick always stays usable.
enum CoachRegenIssue { noCredits, offline, failed, limit }

class CoachPickController extends ChangeNotifier {
  CoachPickController({
    required this.credits,
    required this.plans,
    required this.loadWorkouts,
    CoachPickStore? store,
    CoachConsentStore consent = const CoachConsentStore(),
    String Function()? newId,
  })  : _store = store ?? CoachPickStore(),
        _consent = consent,
        _newId = newId;

  final CreditsController credits;
  final PlanRepository plans;
  final Future<List<WorkoutRecord>> Function() loadWorkouts;
  final CoachPickStore _store;
  final CoachConsentStore _consent;
  final String Function()? _newId;

  CoachPickPhase phase = CoachPickPhase.loading;
  CoachPick? pick;
  PlanView? view;
  int workouts = 0;

  /// History span in weeks (1–4) the pick reads, for "from your last
  /// {weeks} weeks".
  int weeks = 1;
  bool regenerating = false;
  CoachRegenIssue? issue;
  bool _disposed = false;

  /// The request id of a failed "New suggestion", reused by a retry (D-09).
  String? _pendingId;

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

  Future<void> load() async {
    final user = _userId;
    if (user == null || !await _consent.given()) {
      return _set(CoachPickPhase.hidden);
    }
    List<WorkoutRecord> records;
    try {
      records = await loadWorkouts();
    } catch (_) {
      records = const [];
    }
    workouts = records.length;
    final now = DateTime.now();
    final recent = records
        .where((r) => now.difference(r.startedAt).inDays < 28)
        .map((r) => r.startedAt)
        .toList();
    weeks = recent.isEmpty
        ? 1
        : (now
                        .difference(
                          recent.reduce((a, b) => a.isBefore(b) ? a : b),
                        )
                        .inDays ~/
                    7 +
                1)
            .clamp(1, 4);
    if (workouts < CoachMinimum.pickWorkouts) {
      return _set(CoachPickPhase.noData);
    }
    PlanView? v;
    try {
      v = await plans.load();
    } catch (_) {}
    view = v;
    final session = v == null || v.plan.status != PlanStatus.active
        ? null
        : CoachApply.nextSession(v, todayOnly: true);
    if (v == null || session == null) {
      pick = null;
      return _set(CoachPickPhase.hidden);
    }
    final cached = await _store.load(user);
    if (cached != null &&
        cached.madeOn == v.today &&
        cached.sessionId == session.id &&
        _same(cached.planned, session.exerciseTargets)) {
      pick = cached;
    } else {
      // The free pick: made on the phone, no AI request, no credit.
      pick = CoachPick(
        madeOn: v.today,
        sessionId: session.id,
        templateId: session.workoutTemplateId,
        planned: session.exerciseTargets,
        suggested: session.exerciseTargets,
      );
      await _store.save(user, pick!);
    }
    _set(pick!.skipped ? CoachPickPhase.skipped : CoachPickPhase.ready);
  }

  void _set(CoachPickPhase p) {
    phase = p;
    _notify();
  }

  Future<void> _save(CoachPick p) async {
    pick = p;
    final user = _userId;
    if (user != null) await _store.save(user, p);
  }

  Future<void> skip() async {
    final p = pick;
    if (p == null) return;
    await _save(p.copyWith(skipped: true));
    _set(CoachPickPhase.skipped);
  }

  /// Undo of Skip: the same pick, no new AI call.
  Future<void> undoSkip() async {
    final p = pick;
    if (p == null) return;
    await _save(p.copyWith(skipped: false));
    _set(CoachPickPhase.ready);
  }

  Future<void> choose({required bool useSuggestion}) async {
    final p = pick;
    if (p == null) return;
    await _save(p.copyWith(useSuggestion: useSuggestion));
    _notify();
  }

  void clearIssue() {
    issue = null;
    _notify();
  }

  /// "New suggestion" (1 credit, D-29). With no credits left nothing is
  /// sent and the current pick stays (AC-01d).
  Future<void> regenerate({required String locale}) async {
    final p = pick, v = view;
    if (p == null || v == null || regenerating) return;
    final b = credits.balance;
    if (b != null && b.balance < CoachCost.newSuggestion) {
      issue = CoachRegenIssue.noCredits;
      return _notify();
    }
    regenerating = true;
    issue = null;
    _notify();
    final conversation = CoachConversation(
      credits,
      v2: true,
      newId: _pendingId == null ? _newId : () => _pendingId!,
    );
    try {
      await conversation.analyze(
          CreditedRequest.planSuggestion,
          'daily_pick',
          {
            'horizon': 'tomorrow',
            'today_pick': true,
            ...CoachPlan.context(v),
          },
          locale: locale);
      final turn = conversation.turns.single;
      final answer = CoachAnswer.parse(turn.kind, turn.data);
      switch (turn.state) {
        case CoachTurnState.answered when answer is CoachPlanSuggestion:
          _pendingId = null;
          final coach = answer.sessions.isEmpty
              ? answer.targets
              : answer.sessions.first.exercises;
          await _save(
            CoachPick(
              madeOn: p.madeOn,
              sessionId: p.sessionId,
              templateId: p.templateId,
              planned: p.planned,
              suggested: CoachApply.merge(p.planned, coach),
              reason: _cap(answer.summary),
              rest: {for (final t in coach) t.exerciseId: t.restSeconds},
              ai: true,
            ),
          );
        case CoachTurnState.outOfCredits:
          _pendingId = null;
          issue = CoachRegenIssue.noCredits;
        case CoachTurnState.failed:
          _pendingId = turn.requestId;
          issue = switch (turn.failure) {
            CoachFailure.offline => CoachRegenIssue.offline,
            CoachFailure.limit => CoachRegenIssue.limit,
            _ => CoachRegenIssue.failed,
          };
        default:
          // Text instead of JSON: invalid, not shown (D-33).
          _pendingId = null;
          issue = CoachRegenIssue.failed;
      }
    } finally {
      conversation.dispose();
      regenerating = false;
      _notify();
    }
  }

  static String _cap(String s) =>
      s.length > 160 ? '${s.substring(0, 159)}…' : s;

  static bool _same(List<ExerciseTarget> a, List<ExerciseTarget> b) =>
      a.length == b.length && CoachApply.changed(a, b).isEmpty;
}
