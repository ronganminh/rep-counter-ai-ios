import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/features/billing/entitlements.dart';

/// P-1 seam: Pro only after server verification (D-10), offline cache
/// at most 7 days (D-08).

void main() {
  var now = DateTime.utc(2026, 11, 2, 9);
  late InMemoryEntitlementApi api;

  setUp(() {
    now = DateTime.utc(2026, 11, 2, 9);
    api = InMemoryEntitlementApi(now: () => now);
  });

  const proof = StoreProof(
      platform: 'app_store', productId: 'pro_monthly', token: 'ok:abc');

  test('off: no flag and no product ids configured', () {
    expect(Billing.flag, isFalse);
    expect(Billing.enabled, isFalse);
  });

  test('verified purchase is Pro; failure and pending stay Free', () async {
    expect(await api.current(), isNull);
    expect(
        () => api.verify(const StoreProof(
            platform: 'play', productId: 'pro_monthly', token: 'forged')),
        throwsA(isA<VerificationFailed>()));
    final pending = await api.verify(const StoreProof(
        platform: 'app_store', productId: 'pro_monthly', token: 'pending:1'));
    expect(pending.isPro(now), isFalse, reason: 'Ask to Buy stays Free');
    final ok = await api.verify(proof);
    expect(ok.isPro(now), isTrue);
  });

  test('offline cache trusted for 7 days, then Free until re-checked',
      () async {
    final e = await api.verify(proof);
    expect(e.isPro(now.add(const Duration(days: 7))), isTrue);
    expect(e.isPro(now.add(const Duration(days: 7, minutes: 1))), isFalse);
  });

  test('expiry, refund and billing retry end Pro; grace keeps it', () async {
    final e = await api.verify(proof);
    expect(e.isPro(e.expiresAt!), isFalse);
    api.notify(EntitlementStatus.grace);
    expect((await api.current())!.isPro(now), isTrue);
    api.notify(EntitlementStatus.billingRetry);
    expect((await api.current())!.isPro(now), isFalse);
    api.notify(EntitlementStatus.revoked);
    expect((await api.current())!.isPro(now), isFalse);
  });
}
