import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/backend/backend_rpc.dart';
import 'package:rep_counter_app/features/billing/entitlements.dart';
import 'package:rep_counter_app/features/billing/supabase_entitlement_api.dart';

import '../../support/contract_rpc.dart';

/// P-1 on Supabase: `entitlement_current` and `verify-purchase` per
/// `supabase/contracts/entitlements.json`; refusals keep the user Free.
void main() {
  final contract = loadContract('entitlements');
  final now = DateTime.utc(2026, 10, 29, 12);
  Map<String, Object?> row(String status, {String? expires}) => {
        'product_id': 'pro.monthly',
        'status': status,
        'expires_at': expires ?? '2026-11-29T00:00:00Z',
        'verified_at': '2026-10-29T11:00:00Z',
        'pro': status == 'active' || status == 'grace',
      };

  test('every server status maps to the seam', () {
    expect(contract['statuses'], [
      'active',
      'grace',
      'billing_retry',
      'expired',
      'revoked',
      'pending',
    ]);
  });

  test('current: null is Free; rows map and isPro follows the seam rules',
      () async {
    Object? answer;
    final api = SupabaseEntitlementApi(ContractRpc(contract, (fn, _) {
      expect(fn, 'entitlement_current');
      if (answer is Map) {
        final shape = ((contract['functions'] as Map)['entitlement_current']
            as Map)['returns'] as Map;
        expect(answer.keys.toSet(), shape.keys.toSet());
      }
      return answer;
    }));
    expect(await api.current(), isNull);
    for (final s in contract['statuses'] as List) {
      answer = row(s as String);
      final e = (await api.current())!;
      expect(e.status.name, isNot(isEmpty));
      expect(e.isPro(now), s == 'active' || s == 'grace', reason: s);
    }
    answer = row('billing_retry');
    expect((await api.current())!.status, EntitlementStatus.billingRetry);
  });

  test('verify sends the store proof untouched and maps the answer', () async {
    final api = SupabaseEntitlementApi(
        ContractRpc(contract, (_, __) => null, invokeHandler: (fn, body) {
      expect(fn, 'verify-purchase');
      expect(body, {
        'platform': 'app_store',
        'product_id': 'pro.monthly',
        'token': 'header.payload.sig',
      });
      return row('active');
    }));
    final e = await api.verify(const StoreProof(
        platform: 'app_store',
        productId: 'pro.monthly',
        token: 'header.payload.sig'));
    expect(e.isPro(now), isTrue);
  });

  test('refusals become VerificationFailed with the server code', () async {
    final errors = ((contract['edge_functions'] as Map)['verify-purchase']
        as Map)['errors'] as Map;
    for (final entry in errors.entries) {
      final api = SupabaseEntitlementApi(FailingRpc(BackendException(
          entry.value as String,
          status: int.parse(entry.key as String))));
      await expectLater(
          api.verify(
              const StoreProof(platform: 'play', productId: 'p', token: 't')),
          throwsA(isA<VerificationFailed>()
              .having((e) => e.reason, 'reason', entry.value)));
    }
  });

  test('flag gate: off without accounts, the flag and product ids', () {
    expect(Billing.enabled, isFalse);
    expect(createEntitlementApi(), isNull);
    final rpc = FailingRpc(const BackendException('x'));
    expect(createEntitlementApi(enabled: false, rpc: rpc), isNull);
    expect(createEntitlementApi(enabled: true, rpc: rpc),
        isA<SupabaseEntitlementApi>());
  });
}
