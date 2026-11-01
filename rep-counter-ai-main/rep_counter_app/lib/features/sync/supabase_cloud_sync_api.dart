import '../../core/backend/backend_rpc.dart';
import 'cloud_sync.dart';

/// [CloudSyncApi] on Supabase: the SQL functions of
/// `supabase/migrations/20261029000100_sync_workouts_plans.sql`, shapes in
/// `supabase/contracts/sync.json`. The server takes the user from the JWT,
/// keeps the newer edit by client time and numbers every write
/// (server_seq), so this adapter only maps JSON.
class SupabaseCloudSyncApi implements CloudSyncApi {
  SupabaseCloudSyncApi(this._rpc);

  final BackendRpc _rpc;

  /// The server refuses larger pushes (54000).
  static const int maxPushRows = 500;

  @override
  Future<SyncPage> pull({required int after, int limit = 500}) async {
    final res = _map(await _rpc
        .rpc('sync_pull_workouts', {'p_after': after, 'p_limit': limit}));
    final cursor = res['cursor'];
    if (cursor is! num) throw const BackendException('invalid_response');
    return SyncPage(
      [for (final row in _list(res['rows'])) _workout(_map(row))],
      cursor.toInt(),
      hasMore: res['has_more'] == true,
    );
  }

  @override
  Future<List<SyncWorkout>> push(List<SyncWorkout> workouts) async {
    final stored = <SyncWorkout>[];
    for (var i = 0; i < workouts.length; i += maxPushRows) {
      final chunk = workouts.skip(i).take(maxPushRows);
      final res = await _rpc.rpc('sync_push_workouts', {
        'p_rows': [
          for (final w in chunk)
            {
              'client_id': w.clientId,
              'raw': w.raw,
              'client_updated_at': w.clientUpdatedAt.toUtc().toIso8601String(),
              'deleted_at': w.deletedAt?.toUtc().toIso8601String(),
            }
        ],
      });
      stored.addAll([for (final row in _list(res)) _workout(_map(row))]);
    }
    return stored;
  }

  @override
  Future<Set<String>> clientIds() async => {
        for (final id in _list(await _rpc.rpc('sync_workout_client_ids', {})))
          id as String
      };

  /// A malformed row is the server's fault: it fails the round like any
  /// backend error instead of crashing the caller.
  static SyncWorkout _workout(Map<String, Object?> row) {
    try {
      return SyncWorkout(
        clientId: row['client_id'] as String,
        raw: _map(row['raw']),
        clientUpdatedAt: DateTime.parse(row['client_updated_at'] as String),
        deletedAt: row['deleted_at'] == null
            ? null
            : DateTime.parse(row['deleted_at'] as String),
        serverSeq: (row['server_seq'] as num).toInt(),
      );
    } on TypeError {
      throw const BackendException('invalid_response');
    } on FormatException {
      throw const BackendException('invalid_response');
    }
  }

  static Map<String, Object?> _map(Object? v) {
    if (v is Map) return v.cast<String, Object?>();
    throw const BackendException('invalid_response');
  }

  static List<Object?> _list(Object? v) {
    if (v is List) return v.cast<Object?>();
    throw const BackendException('invalid_response');
  }
}

/// The sync backend for this build: null unless `ENABLE_ACCOUNTS` and
/// `ENABLE_CLOUD_SYNC` are both on and Supabase is initialised.
CloudSyncApi? createCloudSyncApi(
        {bool enabled = CloudSync.enabled, BackendRpc? rpc}) =>
    switch (rpc ?? supabaseBackendRpc(enabled: enabled)) {
      final BackendRpc r when enabled => SupabaseCloudSyncApi(r),
      _ => null,
    };
