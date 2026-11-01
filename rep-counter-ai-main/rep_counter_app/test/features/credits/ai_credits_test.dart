import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/features/credits/ai_credits.dart';

/// AI-1 seam: the credit rules against the in-memory ledger.

void main() {
  var now = DateTime.utc(2026, 11, 4, 12); // a Wednesday
  late InMemoryAiCreditsApi api;

  setUp(() {
    now = DateTime.utc(2026, 11, 4, 12);
    api = InMemoryAiCreditsApi(now: () => now);
  });

  test('off by default; D-08 placeholder allowance', () {
    expect(AiCredits.enabled, isFalse);
    expect(AiCredits.weeklyAllowance(pro: false), 10);
    expect(AiCredits.weeklyAllowance(pro: true), 60);
    expect(AiCredits.weekStart(now), DateTime.utc(2026, 11, 2));
  });

  test('one charge per request id (D-09)', () async {
    expect(await api.balance(), 10);
    final first = await api.consume('r1', CreditedRequest.coachChat);
    expect(first.alreadyCharged, isFalse);
    expect(first.balance, 9);
    final retry = await api.consume('r1', CreditedRequest.coachChat);
    expect(retry.alreadyCharged, isTrue);
    expect(retry.balance, 9);
  });

  test('no credits left: refused, balance never negative', () async {
    for (var i = 0; i < 10; i++) {
      await api.consume('r$i', CreditedRequest.advancedAnalysis);
    }
    expect(() => api.consume('r10', CreditedRequest.advancedAnalysis),
        throwsA(isA<InsufficientCredits>()));
    expect(await api.balance(), 0);
  });

  test('a new week tops up to the allowance, it does not stack', () async {
    await api.consume('r1', CreditedRequest.coachChat);
    now = DateTime.utc(2026, 11, 9, 1); // next Monday
    expect(await api.balance(), 10);
    now = DateTime.utc(2026, 11, 16, 1);
    expect(await api.balance(), 10);
  });

  test('Pro gets the Pro allowance', () async {
    api.pro = true;
    expect(await api.balance(), 60);
  });

  test('a failed provider call is refunded once; success keeps the charge',
      () async {
    final runner = CreditedAiRunner(api);
    expect(
        () => runner.run<String>('r1', CreditedRequest.coachChat,
            () async => throw StateError('provider down')),
        throwsStateError);
    await Future<void>.delayed(Duration.zero);
    expect(await api.balance(), 10);
    expect(await api.refund('r1'), 10, reason: 'refund is idempotent');
    final answer = await runner.run(
        'r2', CreditedRequest.progressReview, () async => 'ok');
    expect(answer, 'ok');
    expect(await api.balance(), 9);
  });
}
