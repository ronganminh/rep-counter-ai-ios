import 'package:flutter/foundation.dart';

import '../../core/config/feature_flags.dart';
import '../auth/domain/merge_preview.dart';

/// A-2 cloud sync seam (06_SUPABASE_SCHEMA_PROPOSAL §2). Interfaces, the
/// sync rules and an in-memory server only: there is no backend yet, so
/// nothing here talks to the network and the flag stays off.
class CloudSync {
  const CloudSync._();

  /// Needs accounts too; both are off in every shipped build.
  static const bool enabled = FeatureFlags.enableAccounts &&
      bool.fromEnvironment('ENABLE_CLOUD_SYNC', defaultValue: false);
}

/// One workout as it travels between the phone and the account. `raw` is
/// the app's WorkoutRecord JSON; a deleted workout is a tombstone
/// ([deletedAt] set) so the deletion reaches other devices.
@immutable
class SyncWorkout {
  const SyncWorkout({
    required this.clientId,
    required this.raw,
    required this.clientUpdatedAt,
    this.deletedAt,
    this.serverSeq = 0,
  });

  final String clientId;
  final Map<String, Object?> raw;
  final DateTime clientUpdatedAt;
  final DateTime? deletedAt;

  /// Set by the server; 0 until the workout has been pushed.
  final int serverSeq;

  bool get isTombstone => deletedAt != null;

  SyncWorkout withSeq(int seq) => SyncWorkout(
      clientId: clientId,
      raw: raw,
      clientUpdatedAt: clientUpdatedAt,
      deletedAt: deletedAt,
      serverSeq: seq);
}

@immutable
class SyncPage {
  const SyncPage(this.workouts, this.cursor, {this.hasMore = false});
  final List<SyncWorkout> workouts;

  /// The highest server_seq in this page; the next pull starts after it.
  final int cursor;
  final bool hasMore;
}

/// The account side (a Supabase Edge Function or PostgREST once approved).
abstract interface class CloudSyncApi {
  Future<SyncPage> pull({required int after, int limit = 500});

  /// Upserts by client id; the newer [SyncWorkout.clientUpdatedAt] wins.
  /// Returns the stored rows (with their server_seq).
  Future<List<SyncWorkout>> push(List<SyncWorkout> workouts);

  /// Client ids already in the account, for the merge preview.
  Future<Set<String>> clientIds();
}

/// The phone side, implemented by the local workout database once sync
/// ships (it then needs `client_updated_at` and `deleted_at` columns).
abstract interface class LocalSyncSource {
  /// Workouts and tombstones changed on this phone and not pushed yet.
  Future<List<SyncWorkout>> pending();

  Future<void> markPushed(List<SyncWorkout> stored);

  /// Applies a server row: upsert, or remove the workout for a tombstone.
  Future<void> apply(SyncWorkout workout);

  Future<Set<String>> clientIds();
  Future<int> cursor();
  Future<void> saveCursor(int cursor);
}

@immutable
class SyncResult {
  const SyncResult({required this.pulled, required this.pushed});
  final int pulled, pushed;
}

/// One sync round: pull everything after the cursor, apply it, then push
/// this phone's changes. Pulling first means a workout edited on two
/// devices ends with the newer edit everywhere (the server keeps the newer
/// one and the next pull brings it back).
class SyncEngine {
  SyncEngine({required this.api, required this.local});

  final CloudSyncApi api;
  final LocalSyncSource local;

  Future<SyncResult> run() async {
    var pulled = 0;
    var cursor = await local.cursor();
    while (true) {
      final page = await api.pull(after: cursor);
      for (final w in page.workouts) {
        await local.apply(w);
      }
      pulled += page.workouts.length;
      if (page.cursor > cursor) {
        cursor = page.cursor;
        await local.saveCursor(cursor);
      }
      if (!page.hasMore) break;
    }
    final pending = await local.pending();
    if (pending.isEmpty) return SyncResult(pulled: pulled, pushed: 0);
    final stored = await api.push(pending);
    await local.markPushed(stored);
    return SyncResult(pulled: pulled, pushed: stored.length);
  }

  /// The guest → account dry run (`/auth/merge`): nothing is uploaded.
  Future<MergePreview> preview() async => MergePreview.compute(
      local: await local.clientIds(), remote: await api.clientIds());
}

/// Server semantics for tests and for building the UI before the backend
/// exists: last writer by client time wins, every write gets a new
/// server_seq, tombstones are kept.
class InMemoryCloudSyncApi implements CloudSyncApi {
  final Map<String, SyncWorkout> rows = {};
  int _seq = 0;

  @override
  Future<SyncPage> pull({required int after, int limit = 500}) async {
    final newer = rows.values.where((w) => w.serverSeq > after).toList()
      ..sort((a, b) => a.serverSeq.compareTo(b.serverSeq));
    final page = newer.take(limit).toList();
    return SyncPage(page, page.isEmpty ? after : page.last.serverSeq,
        hasMore: newer.length > limit);
  }

  @override
  Future<List<SyncWorkout>> push(List<SyncWorkout> workouts) async {
    final stored = <SyncWorkout>[];
    for (final w in workouts) {
      final current = rows[w.clientId];
      if (current != null &&
          !w.clientUpdatedAt.isAfter(current.clientUpdatedAt)) {
        stored.add(current);
        continue;
      }
      final saved = w.withSeq(++_seq);
      rows[w.clientId] = saved;
      stored.add(saved);
    }
    return stored;
  }

  @override
  Future<Set<String>> clientIds() async => {
        for (final w in rows.values)
          if (!w.isTombstone) w.clientId
      };
}
