import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/features/sync/cloud_sync.dart';

/// A-2 seam: sync rules against the in-memory server, two phones.

class FakeLocal implements LocalSyncSource {
  final Map<String, SyncWorkout> workouts = {};
  final Set<String> dirty = {};
  int savedCursor = 0;

  void save(String id, DateTime at, {int reps = 10}) {
    workouts[id] = SyncWorkout(
        clientId: id, raw: {'id': id, 'reps': reps}, clientUpdatedAt: at);
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
      return; // keep the newer local edit; it is pushed next
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
  final t0 = DateTime.utc(2026, 11, 2, 9);
  late InMemoryCloudSyncApi server;
  late FakeLocal phoneA, phoneB;
  late SyncEngine a, b;

  setUp(() {
    server = InMemoryCloudSyncApi();
    phoneA = FakeLocal();
    phoneB = FakeLocal();
    a = SyncEngine(api: server, local: phoneA);
    b = SyncEngine(api: server, local: phoneB);
  });

  test('off by default (accounts and sync flags)', () {
    expect(CloudSync.enabled, isFalse);
  });

  test('a workout saved on one phone reaches the other once', () async {
    phoneA.save('w1', t0);
    expect((await a.run()).pushed, 1);
    expect((await b.run()).pulled, 1);
    expect(phoneB.visible, {'w1'});
    // Running again is a no-op: same client id, nothing new.
    expect((await a.run()).pushed, 0);
    expect((await b.run()).pulled, 0);
    expect(server.rows, hasLength(1));
  });

  test('a deletion travels as a tombstone', () async {
    phoneA.save('w1', t0);
    await a.run();
    await b.run();
    phoneB.delete('w1', t0.add(const Duration(minutes: 5)));
    await b.run();
    await a.run();
    expect(phoneA.visible, isEmpty);
    expect(server.rows['w1']!.isTombstone, isTrue,
        reason: 'kept on the server so later devices learn about it');
    expect(await server.clientIds(), isEmpty);
  });

  test('the newer edit wins on every device', () async {
    phoneA.save('w1', t0, reps: 10);
    await a.run();
    await b.run();
    phoneA.save('w1', t0.add(const Duration(minutes: 1)), reps: 11);
    phoneB.save('w1', t0.add(const Duration(minutes: 2)), reps: 12);
    await a.run();
    await b.run();
    await a.run();
    expect(phoneA.workouts['w1']!.raw['reps'], 12);
    expect(phoneB.workouts['w1']!.raw['reps'], 12);
    // An older push never overwrites a newer row.
    await server.push([
      SyncWorkout(clientId: 'w1', raw: const {'reps': 1}, clientUpdatedAt: t0)
    ]);
    expect(server.rows['w1']!.raw['reps'], 12);
  });

  test('pull pages until the end and keeps the cursor', () async {
    for (var i = 0; i < 1200; i++) {
      phoneA.save('w$i', t0);
    }
    await a.run();
    final r = await b.run();
    expect(r.pulled, 1200);
    expect(phoneB.savedCursor, 1200);
    expect((await b.run()).pulled, 0);
  });

  test('guest merge preview uploads nothing and counts by client id', () async {
    phoneA.save('shared', t0);
    await a.run();
    phoneB.save('shared', t0);
    phoneB.save('guest-only', t0);
    final p = await b.preview();
    expect(p.alreadyInAccount, 1);
    expect(p.toUpload, 1);
    expect(server.rows.keys, ['shared']);
  });
}
