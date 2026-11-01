import '../../core/backend/backend_rpc.dart';
import 'entitlements.dart';

/// [EntitlementApi] on Supabase: `entitlement_current` (SQL function) and
/// the `verify-purchase` Edge Function (`supabase/contracts/entitlements.json`).
/// Pro comes only from the server's answer after it asked Apple / Google
/// (D-10). Billing stays off until product ids exist (D-14).
class SupabaseEntitlementApi implements EntitlementApi {
  SupabaseEntitlementApi(this._rpc);

  final BackendRpc _rpc;

  static const _statuses = {
    'active': EntitlementStatus.active,
    'grace': EntitlementStatus.grace,
    'billing_retry': EntitlementStatus.billingRetry,
    'expired': EntitlementStatus.expired,
    'revoked': EntitlementStatus.revoked,
    'pending': EntitlementStatus.pending,
  };

  static Entitlement _entitlement(Object? res) {
    if (res is! Map || _statuses[res['status']] == null) {
      throw const BackendException('invalid_response');
    }
    return Entitlement(
      productId: res['product_id'] as String,
      status: _statuses[res['status']]!,
      expiresAt: res['expires_at'] == null
          ? null
          : DateTime.parse(res['expires_at'] as String),
      verifiedAt: DateTime.parse(res['verified_at'] as String),
    );
  }

  @override
  Future<Entitlement?> current() async {
    final res = await _rpc.rpc('entitlement_current', {});
    return res == null ? null : _entitlement(res);
  }

  @override
  Future<Entitlement> verify(StoreProof proof) async {
    try {
      return _entitlement(await _rpc.invoke('verify-purchase', {
        'platform': proof.platform,
        'product_id': proof.productId,
        'token': proof.token,
      }));
    } on BackendException catch (e) {
      // Every refusal keeps the user Free (D-10); the code says why.
      if (e.status != null) throw VerificationFailed(e.code);
      rethrow;
    }
  }
}

/// The entitlement backend for this build: null unless `ENABLE_ACCOUNTS`,
/// `ENABLE_BILLING` and both product ids are set and Supabase is
/// initialised. Off in every build today (D-14).
EntitlementApi? createEntitlementApi({bool? enabled, BackendRpc? rpc}) {
  final on = enabled ?? Billing.enabled;
  return switch (rpc ?? supabaseBackendRpc(enabled: on)) {
    final BackendRpc r when on => SupabaseEntitlementApi(r),
    _ => null,
  };
}
