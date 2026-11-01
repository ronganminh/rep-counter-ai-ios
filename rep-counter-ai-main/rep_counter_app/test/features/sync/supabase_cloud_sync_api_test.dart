import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/backend/backend_rpc.dart';
import 'package:rep_counter_app/features/sync/cloud_sync.dart';
import 'package:rep_counter_app/features/sync/supabase_cloud_sync_api.dart';

import '../../support/contract_rpc.dart';

/// A-2 on Supabase: the adapter speaks `supabase/contracts/sync.json` (the
/// same file the SQL tests check against the real functions) and the sync
/// rules still hold end to end through it.

/// The SQL functions' behaviour over JSON, backed by the in-memory server.
class FakeSyncServer {
  FakeSyncServer(this.contract);
  final Map<String, Object?> contract;
  final memory = InMemoryCloudSyncApi();
  int pushes = 0;

  Map<String, Object?> _row(SyncWorkout w) {
    final row = <String, Object?>{
      'client_id': w.clientId,
      'raw': {...w.raw, 'client_id': w.clientId},
      'client_updated_at': w.clientUpdatedAt.toUtc().toIso8601String(),
      'deleted_at': w.deletedAt?.toUtc().toIso8601String(),
      'server_seq': w.serverSeq,
    };
    expect(row.keys.toSet(), contractKeys(contract, 'workout_row'));
    return row;
  }

  Future<Object?> handle(String fn, Map<String, Object?> p) async {
    switch (fn) {
      case 'sync_push_workouts':
        pushes++;
        final rows = (p['p_rows'] as List).cast<Map>();
        expect(rows.length, lessThanOrEqualTo(500));
        final input = [
          for (final r in rows)
            () {
              expect(r.keys.toSet(), contractKeys(contract, 'push_row'));
              return SyncWorkout(
                clientId: r['client_id'] as String,
                raw: (r['raw'] as Map).cast<String, Object?>(),
                clientUpdatedAt:
                    DateTime.parse(r['client_updated_at'] as String),
                deletedAt: r['deleted_at'] == null
                    ? null
                    : DateTime.parse(r['deleted_at'] as String),
              );
            }()
        ];
        return [for (final w in await memory.push(input)) _row(w)];
      case 'sync_pull_workouts':
        final page = await memory.pull(
            after: p['p_after'] as int, limit: p['p_limit'] as int);
        return {
          'rows': [for (final w in page.workouts) _row(w)],
          'cursor': page.cursor,
          'has_more': page.hasMore,
        };
      case 'sync_workout_client_ids':
        return (await memory.clientIds()).toList()..sort();
    }
    fail('unexpected $fn');
  }
}

/// [ContractRpc] with an async handler.
class AsyncContractRpc implements BackendRpc {
  AsyncContractRpc(this.contract, this.server);
  final Map<String, Object?> contract;
  final FakeSyncServer server;
  late final ContractRpc _check = ContractRpc(contract, (_, __) => null);

  @override
  Future<Object?> rpc(String function, Map<String, Object?> params) async {
    await _check.rpc(function, params); // validates names and params
    return server.handle(function, params);
  }

  @override
  Future<Object?> invoke(String function, Map<String, Object?> body) =>
      throw UnimplementedError();
}

class FakeLocal implements LocalSyncSource {
  final Map<String, SyncWorkout> workouts = {};
  final Set<String> dirty = {};
  int savedCursor = 0;

  void save(String id, DateTime at, {int reps = 10}) {
    workouts[id] = SyncWorkout(
        clientId: id,
        raw: {'id': id, 'exercise_id': 'push_up', 'reps': reps},
        clientUpdatedAt: at);
    dirty.add(id);
  }

  void delete(String id, DateTime at) {
    final w = workouts[id]!;
    workouts[id] = SyncWorkout(
        clientId: id, raw: w.raw, clientUpdatedAt: at, deletedAt: at);
    dirty.add(id);
  }

  Set<String> get visible => {
        for (final w in workouts.values)
          if (!w.isTombstone) w.clientId
      };

  @override
  Future<List<SyncWorkout>> pending() async =>
      [for (final id in dirty) workouts[id]!];

  @override
  Future<void> markPushed(List<SyncWorkout> stored) async {
    for (final w in stored) {
      dirty.remove(w.clientId);
    }
  }

  @override
  Future<void> apply(SyncWorkout w) async {
    final mine = workouts[w.clientId];
    if (mine != null &&
        dirty.contains(w.clientId) &&
        mine.clientUpdatedAt.isAfter(w.clientUpdatedAt)) {
      return;
    }
    workouts[w.clientId] = w;
    dirty.remove(w.clientId);
  }

  @override
  Future<Set<String>> clientIds() async => visible;

  @override
  Future<int> cursor() async => savedCursor;

  @override
  Future<void> saveCursor(int cursor) async => savedCursor = cursor;
}

void main() {
  final contract = loadContract('sync');
  final t0 = DateTime.utc(2026, 11, 2, 9);
  late FakeSyncServer server;
  late SupabaseCloudSyncApi api;
  late FakeLocal phoneA, phoneB;
  late SyncEngine a, b;

  setUp(() {
    server = FakeSyncServer(contract);
    api = SupabaseCloudSyncApi(AsyncContractRpc(contract, server));
    phoneA = FakeLocal();
    phoneB = FakeLocal();
    a = SyncEngine(api: api, local: phoneA);
    b = SyncEngine(api: api, local: phoneB);
  });

  test('the contract lists exactly the functions the adapter calls', () {
    expect((contract['functions'] as Map).keys.toSet(), {
      'sync_pull_workouts',
      'sync_push_workouts',
      'sync_workout_client_ids',
    });
  });

  test('a workout reaches the other phone once, with its server_seq', () async {
    phoneA.save('w1', t0);
    expect((await a.run()).pushed, 1);
    expect((await b.run()).pulled, 1);
    expect(phoneB.visible, {'w1'});
    expect(phoneB.workouts['w1']!.serverSeq, greaterThan(0));
    expect(phoneB.workouts['w1']!.raw['client_id'], 'w1');
    expect((await a.run()).pushed, 0);
    expect((await b.run()).pulled, 0);
  });

  test('tombstones and the newer edit travel through the adapter', () async {
    phoneA.save('w1', t0, reps: 10);
    await a.run();
    await b.run();
    phoneA.save('w1', t0.add(const Duration(minutes: 1)), reps: 11);
    phoneB.save('w1', t0.add(const Duration(minutes: 2)), reps: 12);
    await a.run();
    await b.run();
    await a.run();
    expect(phoneA.workouts['w1']!.raw['reps'], 12);

    phoneB.delete('w1', t0.add(const Duration(minutes: 3)));
    await b.run();
    await a.run();
    expect(phoneA.visible, isEmpty);
    expect(phoneA.workouts['w1']!.deletedAt, isNotNull);
    expect(await api.clientIds(), isEmpty);
  });

  test('pages through more than one pull and pushes in chunks of 500',
      () async {
    for (var i = 0; i < 1200; i++) {
      phoneA.save('w$i', t0);
    }
    await a.run();
    expect(server.pushes, 3, reason: '500 + 500 + 200');
    final r = await b.run();
    expect(r.pulled, 1200);
    expect(phoneB.savedCursor, 1200);
  });

  test('merge preview asks the account for its client ids only', () async {
    phoneA.save('shared', t0);
    await a.run();
    phoneB.save('shared', t0);
    phoneB.save('guest-only', t0);
    final p = await b.preview();
    expect(p.alreadyInAccount, 1);
    expect(p.toUpload, 1);
    expect(server.memory.rows.keys, ['shared']);
  });

  test('backend errors surface as BackendException', () async {
    final failing =
        SupabaseCloudSyncApi(FailingRpc(const BackendException('28000')));
    await expectLater(
        failing.pull(after: 0),
        throwsA(isA<BackendException>()
            .having((e) => e.notSignedIn, 'notSignedIn', isTrue)));
    final malformed = SupabaseCloudSyncApi(
        ContractRpc(contract, (_, __) => {'unexpected': true}));
    await expectLater(malformed.clientIds(), throwsA(isA<BackendException>()));
  });

  test('no backend unless the flags are on', () {
    expect(CloudSync.enabled, isFalse);
    expect(createCloudSyncApi(), isNull);
    final rpc = ContractRpc(contract, (_, __) => null);
    expect(createCloudSyncApi(enabled: false, rpc: rpc), isNull);
    expect(createCloudSyncApi(enabled: true, rpc: rpc),
        isA<SupabaseCloudSyncApi>());
  });
}
