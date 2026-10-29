import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../core/config/feature_flags.dart';

/// G-1 XP seam (06_SUPABASE_SCHEMA_PROPOSAL §4, D-05/D-09/D-18). The
/// server computes XP from synced workouts; the app only reads progress.
/// Rules and an in-memory server only: no backend, flag off. The local
/// achievements (`AchievementService`) are unchanged and award no XP.
class Xp {
  const Xp._();

  static const bool enabled = FeatureFlags.enableAccounts &&
      bool.fromEnvironment('ENABLE_XP', defaultValue: false);
}

/// What the server knows about a workout when it awards XP. Built from the
/// stored workout, never from a number the client sends.
@immutable
class XpWorkout {
  const XpWorkout(
      {required this.clientId,
      required this.reps,
      required this.durationSeconds,
      this.manual = false});

  final String clientId;
  final int reps, durationSeconds;
  final bool manual;
}

/// Award rules accepted by the owner (06 Q4, L-D30). The database applies
/// the same rules (`xp_for_workout`); `supabase/contracts/xp.json` holds the
/// examples both sides are tested against.
class XpRules {
  const XpRules._();

  static const perWorkout = 10, maxPerWorkout = 150;

  /// Manual and guided-timer workouts earn half (Q4); they never count for
  /// challenges, races or leaderboards (D-18), which is separate.
  static int forWorkout(XpWorkout w) {
    if (w.reps <= 0 && w.durationSeconds <= 0) return 0;
    final effort = w.reps > 0 ? w.reps : w.durationSeconds ~/ 6;
    final full = math.min(perWorkout + effort, maxPerWorkout);
    return w.manual ? full ~/ 2 : full;
  }

  /// Level n starts at 50·(n−1)² XP: 1 → 0, 2 → 50, 3 → 200, 4 → 450.
  static int levelFor(int xp) => math.sqrt(math.max(xp, 0) / 50).floor() + 1;

  static int xpForLevel(int level) => 50 * (level - 1) * (level - 1);
}

@immutable
class XpProgress {
  const XpProgress(this.xpTotal);
  final int xpTotal;

  int get level => XpRules.levelFor(xpTotal);
  int get intoLevel => xpTotal - XpRules.xpForLevel(level);
  int get levelSize =>
      XpRules.xpForLevel(level + 1) - XpRules.xpForLevel(level);
}

/// The account side. The client reads; awards happen on the server when a
/// workout is synced (`award-xp`), so the client has no award call.
abstract interface class XpApi {
  Future<XpProgress> progress();
}

/// Server rules for tests and UI work: one award per (source type, source
/// id) (D-09); deleting a workout does not revoke XP (D-05); corrections
/// are separate negative events.
class InMemoryXpServer implements XpApi {
  final events = <({String type, String id, int amount})>[];

  int get _total => events.fold(0, (sum, e) => sum + e.amount);

  /// Called by the sync push on the server. Returns the XP awarded now
  /// (0 when this workout was already awarded).
  int onWorkoutSynced(XpWorkout w) {
    if (events.any((e) => e.type == 'workout' && e.id == w.clientId)) {
      return 0;
    }
    final amount = XpRules.forWorkout(w);
    events.add((type: 'workout', id: w.clientId, amount: amount));
    return amount;
  }

  /// D-05: a deleted workout keeps its XP.
  void onWorkoutDeleted(String clientId) {}

  /// Server-side correction of an invalid or duplicate award.
  void correct(String id, int amount) =>
      events.add((type: 'correction', id: id, amount: -amount.abs()));

  @override
  Future<XpProgress> progress() async => XpProgress(math.max(_total, 0));
}
