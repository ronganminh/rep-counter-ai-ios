import 'package:flutter/foundation.dart';

import '../../core/config/feature_flags.dart';

/// AI-1 credits seam (06_SUPABASE_SCHEMA_PROPOSAL §3, D-07/D-08/D-09).
/// Interfaces, rules and an in-memory ledger only: there is no backend, the
/// flag stays off, and basic post-workout feedback stays free (D-07) and
/// never goes through this.
class AiCredits {
  const AiCredits._();

  static const bool enabled = FeatureFlags.enableAccounts &&
      bool.fromEnvironment('ENABLE_AI_CREDITS', defaultValue: false);

  /// D-08 weekly allowance: placeholder values accepted for staging (06 Q5,
  /// L-D30). On the backend `ai_credit_weekly_allowance` decides.
  static const freeWeekly = 10, proWeekly = 60;

  static int weeklyAllowance({required bool pro}) =>
      pro ? proWeekly : freeWeekly;

  /// Weeks start on Monday 00:00 UTC on the server.
  static DateTime weekStart(DateTime t) {
    final d = DateTime.utc(t.toUtc().year, t.toUtc().month, t.toUtc().day);
    return d.subtract(Duration(days: d.weekday - DateTime.monday));
  }
}

/// What an AI request costs credits for (D-07: basic feedback is free).
enum CreditedRequest { coachChat, advancedAnalysis, progressReview }

@immutable
class CreditCharge {
  const CreditCharge(
      {required this.requestId,
      required this.balance,
      required this.alreadyCharged});

  final String requestId;
  final int balance;

  /// True when this request id had been charged before: no second charge.
  final bool alreadyCharged;
}

class InsufficientCredits implements Exception {
  const InsufficientCredits(this.balance);
  final int balance;
}

/// The server side (`ai-request` Edge Function once approved). The client
/// never writes the ledger itself.
abstract interface class AiCreditsApi {
  Future<int> balance();

  /// Charges one credit for [requestId] exactly once (D-09). Throws
  /// [InsufficientCredits] when the balance would go below zero.
  Future<CreditCharge> consume(String requestId, CreditedRequest kind);

  /// Gives the credit back when the provider failed. Idempotent.
  Future<int> refund(String requestId);
}

/// Runs a credited AI call: charge, call, refund if the call fails.
class CreditedAiRunner {
  CreditedAiRunner(this.api);
  final AiCreditsApi api;

  Future<T> run<T>(
      String requestId, CreditedRequest kind, Future<T> Function() call) async {
    await api.consume(requestId, kind);
    try {
      return await call();
    } catch (_) {
      await api.refund(requestId);
      rethrow;
    }
  }
}

/// Ledger semantics for tests and UI work: weekly allowance granted once
/// per week, one charge per request id, one refund per charge.
class InMemoryAiCreditsApi implements AiCreditsApi {
  InMemoryAiCreditsApi({this.pro = false, DateTime Function()? now})
      : _now = now ?? DateTime.now;

  bool pro;
  final DateTime Function() _now;
  final ledger = <({String kind, int amount, String? key})>[];

  int get _balance => ledger.fold(0, (sum, e) => sum + e.amount);

  bool _has(String kind, String key) =>
      ledger.any((e) => e.kind == kind && e.key == key);

  void _grantWeek() {
    final week = AiCredits.weekStart(_now()).toIso8601String();
    if (_has('weekly_allowance', week)) return;
    // A new week tops the balance up to the allowance; it does not stack.
    final top = AiCredits.weeklyAllowance(pro: pro) - _balance;
    ledger
        .add((kind: 'weekly_allowance', amount: top > 0 ? top : 0, key: week));
  }

  @override
  Future<int> balance() async {
    _grantWeek();
    return _balance;
  }

  @override
  Future<CreditCharge> consume(String requestId, CreditedRequest kind) async {
    _grantWeek();
    if (_has('consume', requestId)) {
      return CreditCharge(
          requestId: requestId, balance: _balance, alreadyCharged: true);
    }
    if (_balance < 1) throw InsufficientCredits(_balance);
    ledger.add((kind: 'consume', amount: -1, key: requestId));
    return CreditCharge(
        requestId: requestId, balance: _balance, alreadyCharged: false);
  }

  @override
  Future<int> refund(String requestId) async {
    if (_has('consume', requestId) && !_has('refund', requestId)) {
      ledger.add((kind: 'refund', amount: 1, key: requestId));
    }
    return _balance;
  }
}

extension CreditedRequestWire on CreditedRequest {
  /// The `kind` the backend uses (`supabase/contracts/credits.json`).
  String get wireName => switch (this) {
        CreditedRequest.coachChat => 'coach_chat',
        CreditedRequest.advancedAnalysis => 'advanced_analysis',
        CreditedRequest.progressReview => 'progress_review',
      };
}

@immutable
class CreditBalance {
  const CreditBalance(
      {required this.balance,
      required this.weeklyAllowance,
      required this.weekStart,
      required this.pro});
  final int balance, weeklyAllowance;
  final DateTime weekStart;
  final bool pro;
}

@immutable
class CoachMessage {
  const CoachMessage.user(this.content) : fromUser = true;
  const CoachMessage.assistant(this.content) : fromUser = false;
  final String content;
  final bool fromUser;
}

@immutable
class CreditedAnswer {
  const CreditedAnswer(
      {required this.requestId, required this.text, required this.balance});
  final String requestId, text;
  final int balance;
}

/// This request id was already charged; the app asks again with a new id
/// (the server never charges twice and keeps no copy of the answer, D-21).
class DuplicateAiRequest implements Exception {
  const DuplicateAiRequest(this.balance);
  final int balance;
}

/// The provider failed; the credit was given back.
class AiProviderFailed implements Exception {
  const AiProviderFailed(this.balance);
  final int balance;
}

/// What the app calls for credited AI. On the backend one request does
/// charge → provider → refund-on-failure (`ai-request`), so the client never
/// charges or refunds itself; [CreditedAiRunner] and [AiCreditsApi] above
/// are the same rules for the in-memory ledger.
abstract interface class CreditedAiApi {
  Future<CreditBalance> balance();

  /// Throws [InsufficientCredits], [DuplicateAiRequest] or [AiProviderFailed].
  Future<CreditedAnswer> ask({
    required String requestId,
    required CreditedRequest kind,
    required String locale,
    List<CoachMessage> messages = const [],
    Map<String, Object?>? context,
  });
}
