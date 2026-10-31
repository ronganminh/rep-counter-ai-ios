import 'package:flutter/widgets.dart';

import '../../core/backend/backend_rpc.dart';
import 'social.dart';

/// [SocialApi] on Supabase: the `social_*` SQL functions
/// (`supabase/contracts/social.json`). Refusals come back as
/// `{"error": code}` and are thrown as [SocialError].
class SupabaseSocialApi implements SocialApi {
  SupabaseSocialApi(this._rpc, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final BackendRpc _rpc;
  final DateTime Function() _now;

  static const _states = {
    'none': FriendState.none,
    'request_sent': FriendState.requestSent,
    'request_received': FriendState.requestReceived,
    'friends': FriendState.friends,
    'blocked': FriendState.blocked,
  };

  /// PROPOSED: boards cover the current week, from Monday 00:00 UTC.
  DateTime get weekStart {
    final t = _now().toUtc();
    final d = DateTime.utc(t.year, t.month, t.day);
    return d.subtract(Duration(days: d.weekday - DateTime.monday));
  }

  Future<Object?> _call(String fn, Map<String, Object?> params) async {
    final res = await _rpc.rpc(fn, params);
    if (res is Map && res['error'] is String) {
      throw SocialError(res['error'] as String);
    }
    return res;
  }

  Future<Map<String, Object?>> _map(String fn, Map<String, Object?> p) async {
    final res = await _call(fn, p);
    if (res is! Map) throw const BackendException('invalid_response');
    return res.cast<String, Object?>();
  }

  Future<List<Map<String, Object?>>> _rows(
      String fn, Map<String, Object?> p) async {
    final res = await _call(fn, p);
    if (res is! List) throw const BackendException('invalid_response');
    return [for (final r in res) (r as Map).cast<String, Object?>()];
  }

  FriendState _state(Object? s) =>
      _states[s] ?? (throw const BackendException('invalid_response'));

  @override
  Future<String> createInvite() async =>
      (await _map('social_create_invite', {}))['code'] as String;

  @override
  Future<void> acceptInvite(String code) =>
      _map('social_accept_invite', {'p_code': code});

  @override
  Future<void> respond(String userId, {required bool accept}) =>
      _map('social_respond', {'p_user': userId, 'p_accept': accept});

  @override
  Future<FriendState> state(String userId) async =>
      _state((await _map('social_state', {'p_user': userId}))['state']);

  @override
  Future<void> block(String userId) => _map('social_block', {'p_user': userId});

  @override
  Future<void> report(String userId, String reason) =>
      _map('social_report', {'p_user': userId, 'p_reason': reason});

  @override
  Future<List<FriendSummary>> friends() async => [
        for (final r in await _rows('social_friends', {}))
          FriendSummary(r['user_id'] as String,
              (r['display_name'] as String?) ?? '', _state(r['state'])),
      ];

  /// Written straight to the user's own `profiles` row (RLS: the owner can
  /// insert and update it); there is no RPC for it.
  @override
  Future<void> setDisplayName(String userId, String name) {
    final trimmed = name.trim();
    return _rpc.upsert('profiles', {
      'user_id': userId,
      'display_name': trimmed.length > 80 ? trimmed.substring(0, 80) : trimmed,
      'updated_at': _now().toUtc().toIso8601String(),
    });
  }

  @override
  Future<List<LeaderboardRow>> leaderboard(String exerciseId) async => [
        for (final r in await _rows('social_leaderboard', {
          'p_exercise_id': exerciseId,
          'p_since': weekStart.toIso8601String(),
        }))
          LeaderboardRow(
              r['display_name'] as String? ?? '', (r['reps'] as num).toInt(),
              me: r['me'] == true),
      ];
}

/// Provides the [SocialApi] when `ENABLE_SOCIAL` is on and the backend is
/// configured; without it the Friends entry and friend links hide or fall
/// back.
class SocialScope extends InheritedWidget {
  const SocialScope({super.key, required this.api, required super.child});
  final SocialApi api;

  static SocialApi? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SocialScope>()?.api;

  @override
  bool updateShouldNotify(SocialScope old) => old.api != api;
}

/// The social backend for this build: null unless `ENABLE_ACCOUNTS` and
/// `ENABLE_SOCIAL` are both on and Supabase is initialised.
SocialApi? createSocialApi({bool enabled = Social.enabled, BackendRpc? rpc}) =>
    switch (rpc ?? supabaseBackendRpc(enabled: enabled)) {
      final BackendRpc r when enabled => SupabaseSocialApi(r),
      _ => null,
    };
