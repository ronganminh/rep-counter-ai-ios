import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/backend/backend_rpc.dart';
import '../auth/application/auth_controller.dart';
import '../workout/data/workout_database.dart';
import '../workout/data/workout_record.dart';
import 'ai_credits.dart';
import 'supabase_ai_credits_api.dart';

/// The signed-in user's AI credits (AI-1): the weekly balance for the
/// Profile chip and meter, and the [CoachConversation]s that spend them.
/// Basic post-workout feedback never goes through this (D-07).
class CreditsController extends ChangeNotifier {
  CreditsController({required this.auth, required this.api}) {
    auth.addListener(_onAuth);
    _onAuth();
  }

  final AuthController auth;
  final CreditedAiApi api;

  CreditBalance? _balance;
  bool _loading = false, _failed = false, _disposed = false;

  CreditBalance? get balance => _balance;
  bool get loading => _loading;

  /// The last balance read failed (offline, server); [balance] keeps the
  /// previous value if there was one.
  bool get failed => _failed;

  bool get signedIn => auth.state is AuthSignedIn;

  bool get outOfCredits => _balance != null && _balance!.balance <= 0;

  void _onAuth() {
    if (signedIn) {
      refresh();
    } else {
      _balance = null;
      _failed = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    auth.removeListener(_onAuth);
    super.dispose();
  }

  /// Reads the balance (which also grants the week's allowance on the
  /// server). Never throws.
  Future<void> refresh() async {
    if (!signedIn || _loading) return;
    _loading = true;
    _notify();
    try {
      _balance = await api.balance();
      _failed = false;
    } catch (e) {
      _failed = true;
      if (e is BackendException && e.notSignedIn) auth.markExpired();
    }
    _loading = false;
    _notify();
  }

  /// Applies the balance an answer or an error reported.
  void _update(int balance) {
    final b = _balance;
    if (b == null) return;
    _balance = CreditBalance(
        balance: balance,
        weeklyAllowance: b.weeklyAllowance,
        weekStart: b.weekStart,
        pro: b.pro);
    _notify();
  }
}

/// Provides [CreditsController] when `ENABLE_AI_CREDITS` is on and the
/// backend is configured. Without it the AI Coach entry and the credits
/// chip hide themselves.
class CreditsScope extends InheritedNotifier<CreditsController> {
  const CreditsScope(
      {super.key, required CreditsController controller, required super.child})
      : super(notifier: controller);

  static CreditsController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CreditsScope>()?.notifier;
}

CreditsController? createCreditsController(AuthController auth,
    {bool enabled = AiCredits.enabled, BackendRpc? rpc}) {
  final api = createCreditedAiApi(enabled: enabled, rpc: rpc);
  return api == null ? null : CreditsController(auth: auth, api: api);
}

enum CoachTurnState { waiting, answered, failed, outOfCredits }

/// Why a turn failed; the UI explains each without red error styling.
enum CoachFailure { offline, timeout, provider, other }

/// One question (or analysis) and its answer. [requestId] stays the same
/// across retries, so a retry is never charged twice (D-09).
class CoachTurn {
  CoachTurn(
      {required this.kind,
      required this.text,
      required this.requestId,
      this.context});

  final CreditedRequest kind;

  /// The user's message, or the action label for an analysis.
  final String text;
  final Map<String, Object?>? context;
  String requestId;
  CoachTurnState state = CoachTurnState.waiting;
  CoachFailure? failure;
  String? answer;
}

/// An AI Coach session: kept in memory on this phone only and never on the
/// server (D-21). Each question or analysis costs one credit; a failed
/// provider call is refunded by the server.
class CoachConversation extends ChangeNotifier {
  CoachConversation(this.credits,
      {this.timeout = const Duration(seconds: 30), String Function()? newId})
      : _newId = newId ?? WorkoutDatabase.newClientId;

  final CreditsController credits;
  final Duration timeout;
  final String Function() _newId;
  final turns = <CoachTurn>[];
  bool _disposed = false;

  bool get busy => turns.any((t) => t.state == CoachTurnState.waiting);

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Asks the coach. Earlier answered turns go along as the conversation
  /// (at most 20 messages, the server's limit).
  Future<void> ask(String question, {required String locale}) {
    final text = question.trim();
    if (text.isEmpty || busy) return Future.value();
    final cut = text.length > 2000 ? text.substring(0, 2000) : text;
    return _start(
        CoachTurn(
            kind: CreditedRequest.coachChat, text: cut, requestId: _newId()),
        locale);
  }

  /// A credited analysis with [context] (aggregate workout numbers only).
  Future<void> analyze(CreditedRequest kind, String label,
          Map<String, Object?> context,
          {required String locale}) =>
      busy
          ? Future.value()
          : _start(
              CoachTurn(
                  kind: kind,
                  text: label,
                  requestId: _newId(),
                  context: context),
              locale);

  /// Retries a failed turn with the same request id.
  Future<void> retry(CoachTurn turn, {required String locale}) {
    if (turn.state != CoachTurnState.failed || busy) return Future.value();
    turn.state = CoachTurnState.waiting;
    turn.failure = null;
    _notify();
    return _send(turn, locale);
  }

  Future<void> _start(CoachTurn turn, String locale) {
    turns.add(turn);
    _notify();
    return _send(turn, locale);
  }

  List<CoachMessage> _history(CoachTurn upTo) {
    final out = <CoachMessage>[];
    for (final t in turns) {
      if (identical(t, upTo)) break;
      if (t.kind != CreditedRequest.coachChat ||
          t.state != CoachTurnState.answered) {
        continue;
      }
      out
        ..add(CoachMessage.user(t.text))
        ..add(CoachMessage.assistant(_cap(t.answer!)));
    }
    if (upTo.kind == CreditedRequest.coachChat) {
      out.add(CoachMessage.user(upTo.text));
    }
    return out.length > 20 ? out.sublist(out.length - 20) : out;
  }

  static String _cap(String s) => s.length > 2000 ? s.substring(0, 2000) : s;

  Future<void> _send(CoachTurn turn, String locale) async {
    try {
      final answer = await credits.api
          .ask(
            requestId: turn.requestId,
            kind: turn.kind,
            locale: locale,
            messages: _history(turn),
            context: turn.context,
          )
          .timeout(timeout);
      turn
        ..answer = answer.text
        ..state = CoachTurnState.answered;
      credits._update(answer.balance);
    } on InsufficientCredits catch (e) {
      turn.state = CoachTurnState.outOfCredits;
      credits._update(e.balance);
    } on AiProviderFailed catch (e) {
      _fail(turn, CoachFailure.provider);
      credits._update(e.balance);
    } on DuplicateAiRequest catch (e) {
      // Charged earlier but the answer never arrived (the server keeps no
      // copy, D-21): a retry needs a new id.
      turn.requestId = _newId();
      _fail(turn, CoachFailure.other);
      credits._update(e.balance);
    } on TimeoutException {
      _fail(turn, CoachFailure.timeout);
    } on BackendException catch (e) {
      if (e.notSignedIn) credits.auth.markExpired();
      _fail(turn, e.offline ? CoachFailure.offline : CoachFailure.other);
    } catch (_) {
      _fail(turn, CoachFailure.other);
    }
    _notify();
  }

  void _fail(CoachTurn turn, CoachFailure why) {
    turn
      ..state = CoachTurnState.failed
      ..failure = why;
  }
}

/// What the analyses send: aggregate numbers, never video, photos or body
/// keypoints (the same fields as the free feedback, `toAiPayload`).
abstract final class CoachContext {
  static Map<String, Object?> lastWorkout(WorkoutRecord r) => {
        'workout': r.toAiPayload(),
        'started_at': r.startedAt.toUtc().toIso8601String(),
        'manual': r.manual,
      };

  /// Minimum saved workouts for a progress review.
  static const reviewMinimum = 3;

  /// A summary of the last 90 days, by week (Monday) and exercise.
  static Map<String, Object?> progress(List<WorkoutRecord> records,
      {required DateTime now}) {
    final since = now.subtract(const Duration(days: 90));
    final recent = records.where((r) => r.startedAt.isAfter(since)).toList();
    final weeks = <String, ({int workouts, int reps})>{};
    final exercises = <String, int>{};
    for (final r in recent) {
      final d = DateTime.utc(
          r.startedAt.toUtc().year, r.startedAt.toUtc().month,
          r.startedAt.toUtc().day);
      final monday = d.subtract(Duration(days: d.weekday - 1));
      final key = monday.toIso8601String().substring(0, 10);
      final w = weeks[key] ?? (workouts: 0, reps: 0);
      weeks[key] = (workouts: w.workouts + 1, reps: w.reps + r.reps);
      exercises[r.exerciseId] = (exercises[r.exerciseId] ?? 0) + r.reps;
    }
    final keys = weeks.keys.toList()..sort();
    return {
      'days': 90,
      'workouts': recent.length,
      'total_reps': recent.fold<int>(0, (n, r) => n + r.reps),
      'weeks': [
        for (final k in keys)
          {'week_start': k, 'workouts': weeks[k]!.workouts, 'reps': weeks[k]!.reps}
      ],
      'reps_by_exercise': exercises,
    };
  }
}
