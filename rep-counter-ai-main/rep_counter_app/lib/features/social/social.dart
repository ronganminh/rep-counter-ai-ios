import 'package:flutter/foundation.dart';

import '../../core/config/feature_flags.dart';

/// S-1 / S-2 social seam (06_SUPABASE_SCHEMA_PROPOSAL §5, D-11/D-18).
/// Friends by invite link, block, report and a friends-only leaderboard.
/// Rules and an in-memory server only: no backend, flag off.
class Social {
  const Social._();

  static const bool enabled = FeatureFlags.enableAccounts &&
      bool.fromEnvironment('ENABLE_SOCIAL', defaultValue: false);

  /// PROPOSED invite lifetime.
  static const inviteLifetime = Duration(days: 7);
}

enum FriendState { none, requestSent, requestReceived, friends, blocked }

@immutable
class LeaderboardRow {
  const LeaderboardRow(this.displayName, this.reps);
  final String displayName;
  final int reps;
}

class SocialError implements Exception {
  const SocialError(this.code);

  /// `invite_expired`, `invite_used`, `blocked`, `self`, `not_found`,
  /// `too_many_invites`, `too_many_reports`.
  final String code;
}

/// Someone I am connected with (friend or request); never anyone else.
@immutable
class FriendSummary {
  const FriendSummary(this.userId, this.displayName, this.state);
  final String userId;
  final String displayName;
  final FriendState state;
}

/// The account side. Every call is on behalf of the signed-in user.
abstract interface class SocialApi {
  Future<String> createInvite();
  Future<void> acceptInvite(String code);
  Future<void> respond(String userId, {required bool accept});
  Future<FriendState> state(String userId);
  Future<void> block(String userId);
  Future<void> report(String userId, String reason);

  /// Friends and requests, without people who blocked me.
  Future<List<FriendSummary>> friends();

  /// Me and my friends, camera workouts only (D-18), best first.
  Future<List<LeaderboardRow>> leaderboard(String exerciseId);
}

/// Server rules for tests and UI work, acting as [me].
class InMemorySocialServer {
  InMemorySocialServer({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final names = <String, String>{};

  /// (requester, addressee) → accepted?
  final _friendships = <(String, String), bool>{};
  final _blocks = <(String, String)>{};
  final reports = <(String, String, String)>[];
  final _invites = <String, ({String inviter, DateTime expires, bool used})>{};

  /// Camera workouts counted for leaderboards: user → exercise → reps.
  /// Manual workouts never get here (D-18).
  final cameraReps = <String, Map<String, int>>{};
  var _n = 0;

  SocialApi as(String me) => _As(this, me);

  bool _blockedBetween(String a, String b) =>
      _blocks.contains((a, b)) || _blocks.contains((b, a));
}

class _As implements SocialApi {
  _As(this.s, this.me);
  final InMemorySocialServer s;
  final String me;

  @override
  Future<String> createInvite() async {
    final code = 'inv${++s._n}';
    s._invites[code] = (
      inviter: me,
      expires: s._now().add(Social.inviteLifetime),
      used: false
    );
    return code;
  }

  @override
  Future<void> acceptInvite(String code) async {
    final i = s._invites[code];
    if (i == null) throw const SocialError('not_found');
    if (i.inviter == me) throw const SocialError('self');
    if (i.used) throw const SocialError('invite_used');
    if (!i.expires.isAfter(s._now())) {
      throw const SocialError('invite_expired');
    }
    if (s._blockedBetween(i.inviter, me)) throw const SocialError('blocked');
    s._invites[code] = (inviter: i.inviter, expires: i.expires, used: true);
    s._friendships[(i.inviter, me)] = false;
  }

  @override
  Future<void> respond(String userId, {required bool accept}) async {
    final key = (userId, me);
    if (!s._friendships.containsKey(key)) {
      throw const SocialError('not_found');
    }
    if (accept) {
      s._friendships[key] = true;
    } else {
      s._friendships.remove(key);
    }
  }

  @override
  Future<FriendState> state(String userId) async {
    if (s._blocks.contains((me, userId))) return FriendState.blocked;
    // Someone who blocked me looks like a stranger (never "blocked you").
    if (s._blocks.contains((userId, me))) return FriendState.none;
    final sent = s._friendships[(me, userId)];
    final received = s._friendships[(userId, me)];
    if (sent == true || received == true) return FriendState.friends;
    if (sent == false) return FriendState.requestSent;
    if (received == false) return FriendState.requestReceived;
    return FriendState.none;
  }

  @override
  Future<void> block(String userId) async {
    s._blocks.add((me, userId));
    s._friendships.remove((me, userId));
    s._friendships.remove((userId, me));
  }

  @override
  Future<void> report(String userId, String reason) async {
    s.reports
        .add((me, userId, reason.substring(0, reason.length.clamp(0, 500))));
  }

  @override
  Future<List<FriendSummary>> friends() async {
    final others = {
      for (final k in s._friendships.keys)
        if (k.$1 == me) k.$2 else if (k.$2 == me) k.$1,
    };
    return [
      for (final u in others)
        if (await state(u) != FriendState.none)
          FriendSummary(u, s.names[u] ?? '', await state(u)),
    ];
  }

  @override
  Future<List<LeaderboardRow>> leaderboard(String exerciseId) async {
    final friends = {
      for (final e in s._friendships.entries)
        if (e.value && (e.key.$1 == me || e.key.$2 == me))
          e.key.$1 == me ? e.key.$2 : e.key.$1,
    }..removeWhere((u) => s._blockedBetween(me, u));
    return [
      for (final u in {me, ...friends})
        if (s.cameraReps[u]?[exerciseId] != null)
          LeaderboardRow(s.names[u] ?? '', s.cameraReps[u]![exerciseId]!),
    ]..sort((a, b) => b.reps.compareTo(a.reps));
  }
}
