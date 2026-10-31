import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/backend/backend_rpc.dart';
import '../plan/data/plan_store.dart';
import '../plan/domain/workout_plan.dart';
import 'cloud_sync.dart';

/// Plans in the account (A-2): one row per plan, `doc` = the plan and its
/// sessions, through `sync_push_plans` / `sync_pull_plans`
/// (`supabase/contracts/sync.json`). Rows travel as [SyncWorkout] so the
/// same [SyncEngine] and last-writer-wins rules serve plans and workouts:
/// [SyncWorkout.clientId] is the plan id and [SyncWorkout.raw] the doc.
class SupabasePlanSyncApi implements CloudSyncApi {
  SupabasePlanSyncApi(this._rpc);

  final BackendRpc _rpc;

  @override
  Future<SyncPage> pull({required int after, int limit = 500}) async {
    final res =
        await _rpc.rpc('sync_pull_plans', {'p_after': after, 'p_limit': limit});
    if (res is! Map || res['cursor'] is! num || res['rows'] is! List) {
      throw const BackendException('invalid_response');
    }
    return SyncPage(
      [for (final row in res['rows'] as List) _row(row)],
      (res['cursor'] as num).toInt(),
      hasMore: res['has_more'] == true,
    );
  }

  @override
  Future<List<SyncWorkout>> push(List<SyncWorkout> plans) async {
    final stored = <SyncWorkout>[];
    for (var i = 0; i < plans.length; i += 500) {
      final res = await _rpc.rpc('sync_push_plans', {
        'p_rows': [
          for (final p in plans.skip(i).take(500))
            {
              'plan_id': p.clientId,
              'doc': p.raw,
              'client_updated_at': p.clientUpdatedAt.toUtc().toIso8601String(),
              'deleted_at': p.deletedAt?.toUtc().toIso8601String(),
            }
        ],
      });
      if (res is! List) throw const BackendException('invalid_response');
      stored.addAll(res.map(_row));
    }
    return stored;
  }

  /// No server list of plan ids; the merge preview counts workouts only.
  @override
  Future<Set<String>> clientIds() async => const {};

  static SyncWorkout _row(Object? row) {
    try {
      final m = (row as Map).cast<String, Object?>();
      return SyncWorkout(
        clientId: m['plan_id'] as String,
        raw: (m['doc'] as Map).cast<String, Object?>(),
        clientUpdatedAt: DateTime.parse(m['client_updated_at'] as String),
        deletedAt: m['deleted_at'] == null
            ? null
            : DateTime.parse(m['deleted_at'] as String),
        serverSeq: (m['server_seq'] as num).toInt(),
      );
    } on TypeError {
      throw const BackendException('invalid_response');
    } on FormatException {
      throw const BackendException('invalid_response');
    }
  }
}

/// [LocalSyncSource] over [PlanStore]. The store keeps no sync columns:
/// a plan is pending when its doc differs from the last one synced (a hash
/// per plan in `plan_sync_v1`), so every plan edit, wherever it is made,
/// is picked up without touching the plan screens.
class PlanSyncSource implements LocalSyncSource {
  PlanSyncSource({PlanStore? store, DateTime Function()? now})
      : _store = store ?? PlanStore(),
        _now = now ?? DateTime.now;

  static const key = 'plan_sync_v1';

  final PlanStore _store;
  final DateTime Function() _now;

  static Map<String, Object?> docOf(
          WorkoutPlan plan, List<PlannedSession> sessions) =>
      {
        'plan': plan.toJson(),
        'sessions': [for (final s in sessions) s.toJson()],
      };

  static String _hash(Map<String, Object?> doc) =>
      sha1.convert(utf8.encode(jsonEncode(doc))).toString();

  Future<_State> _state() async {
    final raw = (await SharedPreferences.getInstance()).getString(key);
    return raw == null ? _State() : _State.fromJson(jsonDecode(raw) as Map);
  }

  Future<void> _save(_State s) async {
    await (await SharedPreferences.getInstance())
        .setString(key, jsonEncode(s.toJson()));
  }

  @override
  Future<List<SyncWorkout>> pending() async {
    final snap = await _store.load();
    final state = await _state();
    final out = <SyncWorkout>[];
    var changed = false;
    for (final plan in snap.plans) {
      final doc = docOf(plan, snap.sessionsOf(plan.id));
      final hash = _hash(doc);
      if (state.synced[plan.id] == hash) continue;
      // First time this edit is seen: that is its time for last-writer-wins.
      final seen = state.changed[plan.id];
      final at = seen?.hash == hash ? seen!.at : _now().toUtc();
      if (seen?.hash != hash) {
        state.changed[plan.id] = (hash: hash, at: at);
        changed = true;
      }
      out.add(SyncWorkout(clientId: plan.id, raw: doc, clientUpdatedAt: at));
    }
    if (changed) await _save(state);
    return out;
  }

  /// Plans whose latest edit is not in the account yet.
  Future<int> pendingCount() async => (await pending()).length;

  @override
  Future<void> markPushed(List<SyncWorkout> stored) async {
    for (final row in stored) {
      final state = await _state();
      final seen = state.changed[row.clientId];
      final echo = seen != null &&
          seen.at.millisecondsSinceEpoch ==
              row.clientUpdatedAt.millisecondsSinceEpoch;
      if (!echo) {
        // The server kept a newer version from another phone.
        await apply(row);
        continue;
      }
      // Accepted as sent: the doc we hashed is the account's copy now.
      state.synced[row.clientId] = seen.hash;
      state.changed.remove(row.clientId);
      await _save(state);
    }
  }

  @override
  Future<void> apply(SyncWorkout row) async {
    final state = await _state();
    final seen = state.changed[row.clientId];
    // This phone changed the plan after that version: keep ours, it is
    // uploaded next and wins on the server.
    if (seen != null && seen.at.isAfter(row.clientUpdatedAt)) return;
    if (row.isTombstone) {
      await _store.update((snap) => PlanSnapshot(
            plans: [for (final p in snap.plans) if (p.id != row.clientId) p],
            sessions: [
              for (final s in snap.sessions)
                if (s.planId != row.clientId) s
            ],
            unreadable: snap.unreadable,
          ));
      state.synced.remove(row.clientId);
      state.changed.remove(row.clientId);
      await _save(state);
      return;
    }
    final WorkoutPlan plan;
    final List<PlannedSession> sessions;
    try {
      plan = WorkoutPlan.fromJson(
          (row.raw['plan'] as Map).cast<String, dynamic>());
      sessions = [
        for (final s in row.raw['sessions'] as List)
          PlannedSession.fromJson((s as Map).cast<String, dynamic>())
      ];
    } catch (_) {
      return; // written by a newer app version; leave the phone's copy
    }
    await _store.update((snap) {
      var next = snap.replacePlan(plan, sessions);
      // Two phones each started a plan: the newer one stays current.
      final live = {PlanStatus.active, PlanStatus.paused};
      if (live.contains(plan.status)) {
        for (final other in next.plans) {
          if (other.id == plan.id || !live.contains(other.status)) continue;
          final keepOther = other.updatedAt.isAfter(plan.updatedAt);
          final loser = keepOther ? plan : other;
          next = next.replacePlan(
              loser.copyWith(
                  status: PlanStatus.archived, updatedAt: _now()),
              next.sessionsOf(loser.id));
        }
      }
      return next;
    });
    // The account's version as this app writes it (the server reorders
    // JSON keys). If the phone just archived it above, the hashes differ
    // and that change goes up next.
    state.synced[plan.id] = _hash(docOf(plan, sessions));
    if (seen != null && !seen.at.isAfter(row.clientUpdatedAt)) {
      state.changed.remove(row.clientId);
    }
    await _save(state);
  }

  @override
  Future<Set<String>> clientIds() async =>
      {for (final p in (await _store.load()).plans) p.id};

  @override
  Future<int> cursor() async => (await _state()).cursor;

  @override
  Future<void> saveCursor(int cursor) async {
    final s = await _state();
    s.cursor = cursor;
    await _save(s);
  }

  /// A different account signed in: everything is offered to it again.
  Future<void> reset() async =>
      (await SharedPreferences.getInstance()).remove(key);
}

typedef _Seen = ({String hash, DateTime at});

class _State {
  _State();

  int cursor = 0;
  final Map<String, String> synced = {};
  final Map<String, _Seen> changed = {};

  factory _State.fromJson(Map json) {
    final s = _State()..cursor = (json['cursor'] as num?)?.toInt() ?? 0;
    (json['synced'] as Map?)?.forEach((k, v) => s.synced['$k'] = '$v');
    (json['changed'] as Map?)?.forEach((k, v) {
      final m = v as Map;
      s.changed['$k'] =
          (hash: '${m['hash']}', at: DateTime.parse('${m['at']}'));
    });
    return s;
  }

  Map<String, Object?> toJson() => {
        'cursor': cursor,
        'synced': synced,
        'changed': {
          for (final e in changed.entries)
            e.key: {'hash': e.value.hash, 'at': e.value.at.toIso8601String()}
        },
      };
}
