import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/backend/backend_rpc.dart';
import 'package:rep_counter_app/features/credits/ai_credits.dart';
import 'package:rep_counter_app/features/credits/supabase_ai_credits_api.dart';

import '../../support/contract_rpc.dart';

/// AI-1 on Supabase: the adapter speaks `supabase/contracts/credits.json`
/// (also checked by the SQL tests and the ai-request Deno tests) and maps
/// the function's errors to the seam's exceptions.

/// `ai-request` behaviour over JSON, backed by the in-memory ledger.
class FakeAiRequest {
  FakeAiRequest(this.contract, {bool pro = false})
      : ledger = InMemoryAiCreditsApi(
            pro: pro, now: () => DateTime.utc(2026, 10, 29, 12));
  final Map<String, Object?> contract;
  final InMemoryAiCreditsApi ledger;
  bool providerFails = false;
  final List<Map<String, Object?>> bodies = [];

  Map<String, Object?> get _edge =>
      ((contract['edge_functions'] as Map)['ai-request'] as Map)
          .cast<String, Object?>();

  Future<Object?> handle(String fn, Map<String, Object?> body) async {
    bodies.add(body);
    expect(_edge['kinds'] as List, contains(body['kind']));
    final id = body['request_id'] as String;
    final kind =
        CreditedRequest.values.firstWhere((k) => k.wireName == body['kind']);
    final CreditCharge charge;
    try {
      charge = await ledger.consume(id, kind);
    } on InsufficientCredits catch (e) {
      throw BackendException('insufficient_credits',
          status: 402,
          body: {'error': 'insufficient_credits', 'balance': e.balance});
    }
    if (charge.alreadyCharged) {
      throw BackendException('duplicate_request',
          status: 409,
          body: {'error': 'duplicate_request', 'balance': charge.balance});
    }
    if (providerFails) {
      final balance = await ledger.refund(id);
      throw BackendException('provider_error',
          status: 502, body: {'error': 'provider_error', 'balance': balance});
    }
    final res = {'request_id': id, 'text': 'Answer', 'balance': charge.balance};
    expect(res.keys.toSet(), (_edge['response'] as List).toSet());
    return res;
  }
}

class AsyncContractRpc implements BackendRpc {
  AsyncContractRpc(this.contract, this.server);
  final Map<String, Object?> contract;
  final FakeAiRequest server;
  late final ContractRpc _check =
      ContractRpc(contract, (_, __) => null, invokeHandler: (_, __) => null);

  @override
  Future<Object?> rpc(String function, Map<String, Object?> params) async {
    await _check.rpc(function, params);
    final b = await server.ledger.balance();
    final res = {
      'balance': b,
      'weekly_allowance': AiCredits.weeklyAllowance(pro: server.ledger.pro),
      'week_start': '2026-10-26',
      'pro': server.ledger.pro,
    };
    final shape = ((contract['functions'] as Map)['ai_credit_balance']
        as Map)['returns'] as Map;
    expect(res.keys.toSet(), shape.keys.toSet());
    return res;
  }

  @override
  Future<Object?> invoke(String function, Map<String, Object?> body) async {
    await _check.invoke(function, body);
    return server.handle(function, body);
  }
}

void main() {
  final contract = loadContract('credits');
  late FakeAiRequest server;
  late SupabaseAiCreditsApi api;

  setUp(() {
    server = FakeAiRequest(contract);
    api = SupabaseAiCreditsApi(AsyncContractRpc(contract, server));
  });

  test('kind names match the contract', () {
    final edge = (contract['edge_functions'] as Map)['ai-request'] as Map;
    expect([for (final k in CreditedRequest.values) k.wireName], edge['kinds']);
  });

  test('balance reads the weekly allowance (10 Free, Q5)', () async {
    final b = await api.balance();
    expect(b.balance, 10);
    expect(b.weeklyAllowance, 10);
    expect(b.weekStart, DateTime.parse('2026-10-26'));
    expect(b.pro, isFalse);
  });

  test('a coach question is charged once and answered', () async {
    final a = await api.ask(
        requestId: 'r1',
        kind: CreditedRequest.coachChat,
        locale: 'vi',
        messages: const [
          CoachMessage.user('q1'),
          CoachMessage.assistant('a1'),
          CoachMessage.user('q2'),
        ]);
    expect(a.text, 'Answer');
    expect(a.balance, 9);
    final body = server.bodies.single;
    expect(body['kind'], 'coach_chat');
    expect(body['locale'], 'vi');
    expect(body['messages'], [
      {'role': 'user', 'content': 'q1'},
      {'role': 'assistant', 'content': 'a1'},
      {'role': 'user', 'content': 'q2'},
    ]);
    expect(body['context'], isNull);
    await expectLater(
        api.ask(
            requestId: 'r1',
            kind: CreditedRequest.coachChat,
            locale: 'en',
            messages: const [CoachMessage.user('again')]),
        throwsA(
            isA<DuplicateAiRequest>().having((e) => e.balance, 'balance', 9)));
  });

  test('provider failure gives the credit back', () async {
    server.providerFails = true;
    await expectLater(
        api.ask(
            requestId: 'r2',
            kind: CreditedRequest.advancedAnalysis,
            locale: 'en',
            context: const {'reps': 20}),
        throwsA(
            isA<AiProviderFailed>().having((e) => e.balance, 'balance', 10)));
  });

  test('no credits left: InsufficientCredits with the balance', () async {
    for (var i = 0; i < 10; i++) {
      await api.ask(
          requestId: 'r$i',
          kind: CreditedRequest.progressReview,
          locale: 'en',
          context: const {'weeks': 4});
    }
    await expectLater(
        api.ask(
            requestId: 'r10',
            kind: CreditedRequest.progressReview,
            locale: 'en',
            context: const {'weeks': 4}),
        throwsA(
            isA<InsufficientCredits>().having((e) => e.balance, 'balance', 0)));
  });

  test('other errors pass through; no backend unless the flags are on',
      () async {
    final failing =
        SupabaseAiCreditsApi(FailingRpc(const BackendException('28000')));
    await expectLater(
        failing.balance(),
        throwsA(
            isA<BackendException>().having((e) => e.notSignedIn, 'x', true)));
    expect(AiCredits.enabled, isFalse);
    expect(createCreditedAiApi(), isNull);
    final rpc = FailingRpc(const BackendException('x'));
    expect(createCreditedAiApi(enabled: false, rpc: rpc), isNull);
    expect(createCreditedAiApi(enabled: true, rpc: rpc),
        isA<SupabaseAiCreditsApi>());
  });
}
