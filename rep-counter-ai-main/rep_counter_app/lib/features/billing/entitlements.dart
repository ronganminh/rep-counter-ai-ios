import 'package:flutter/foundation.dart';

import '../../core/config/app_config.dart';
import '../../core/config/feature_flags.dart';

/// P-1 entitlement seam (06_SUPABASE_SCHEMA_PROPOSAL §6, D-08/D-10/D-13).
/// Pro is granted only by the server after it verified the store purchase
/// (D-10); the app never decides Pro from the store receipt alone. No
/// store SDK, no backend: the flag stays off and billing UI stays hidden
/// until both product ids are configured (D-14 still open).
class Billing {
  const Billing._();

  static const bool flag = FeatureFlags.enableAccounts &&
      bool.fromEnvironment('ENABLE_BILLING', defaultValue: false);

  static bool get enabled => flag && AppConfig.billingConfigured;

  /// D-08: how long a verified Pro entitlement is trusted offline.
  static const offlineGrace = Duration(days: 7);
}

enum EntitlementStatus {
  active,
  grace,
  billingRetry,
  expired,
  revoked,

  /// Ask to Buy or a deferred payment: stays Free (D-10).
  pending,
}

@immutable
class Entitlement {
  const Entitlement(
      {required this.productId,
      required this.status,
      this.expiresAt,
      required this.verifiedAt});

  final String productId;
  final EntitlementStatus status;
  final DateTime? expiresAt;

  /// When the server last confirmed this row.
  final DateTime verifiedAt;

  /// Pro access now: active or in the store's grace period, not expired,
  /// and confirmed by the server within [Billing.offlineGrace].
  bool isPro(DateTime now) {
    if (status != EntitlementStatus.active &&
        status != EntitlementStatus.grace) {
      return false;
    }
    if (expiresAt != null && !expiresAt!.isAfter(now)) return false;
    return now.difference(verifiedAt) <= Billing.offlineGrace;
  }
}

/// What the app sends after a store purchase: the StoreKit 2 signed
/// transaction or the Play purchase token, untouched.
@immutable
class StoreProof {
  const StoreProof(
      {required this.platform, required this.productId, required this.token});
  final String platform; // 'app_store' | 'play'
  final String productId, token;
}

class VerificationFailed implements Exception {
  const VerificationFailed(this.reason);
  final String reason;
}

/// The account side (`verify-purchase` / `store-webhook` once approved).
abstract interface class EntitlementApi {
  /// The server's current view, or null for Free.
  Future<Entitlement?> current();

  /// Verifies with Apple / Google; throws [VerificationFailed] (stay Free).
  Future<Entitlement> verify(StoreProof proof);
}

/// Server rules for tests and UI work. Tokens starting with `ok:` verify,
/// `pending:` stays pending, anything else fails.
class InMemoryEntitlementApi implements EntitlementApi {
  InMemoryEntitlementApi({DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  Entitlement? row;

  @override
  Future<Entitlement?> current() async => row;

  @override
  Future<Entitlement> verify(StoreProof proof) async {
    if (proof.token.startsWith('pending:')) {
      return row = Entitlement(
          productId: proof.productId,
          status: EntitlementStatus.pending,
          verifiedAt: _now());
    }
    if (!proof.token.startsWith('ok:')) {
      throw const VerificationFailed('store rejected the purchase');
    }
    return row = Entitlement(
        productId: proof.productId,
        status: EntitlementStatus.active,
        expiresAt: _now().add(const Duration(days: 30)),
        verifiedAt: _now());
  }

  /// A store notification (renewal failure, refund…).
  void notify(EntitlementStatus status) {
    final r = row;
    if (r == null) return;
    row = Entitlement(
        productId: r.productId,
        status: status,
        expiresAt: r.expiresAt,
        verifiedAt: _now());
  }
}
