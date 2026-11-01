import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/features/sync/cloud_sync.dart';
import 'package:rep_counter_app/features/sync/workout_sync_source.dart';
import 'package:rep_counter_app/features/workout/data/workout_database.dart';
import 'package:rep_counter_app/features/workout/data/workout_history_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../support/sync_fixtures.dart';

/// A-2 wiring: the local bookkeeping that decides what is uploaded.
void main() {
  const source = WorkoutSyncSource();
  final store = WorkoutHistoryStore();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<String> clientIdOf(String id) async {
    final db = await WorkoutDatabase.instance();
    return (await WorkoutDatabase.clientIdFor(db.db, id))!;
  }

  group('schema v1 → v2 migration', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('repcoach-db'));
    tearDown(() {
      WorkoutDatabase.close();
      WorkoutDatabase.pathOverride = inMemoryDatabasePath;
      dir.deleteSync(recursive: true);
    });

    test('adds the sync tables, keeps every workout, idempotent', () async {
      final path = '${dir.path}/repcoach.db';
      // A database written by the previous app version.
      final v1 = await databaseFactory.openDatabase(path,
          options: OpenDatabaseOptions(
              version: 1,
              onCreate: (db, _) async {
                await db.execute('CREATE TABLE workouts (id TEXT PRIMARY KEY, '
                    'client_id TEXT NOT NULL UNIQUE, started_at INTEGER NOT '
                    'NULL, raw TEXT NOT NULL)');
                await db.execute(
                    'CREATE TABLE unreadable_workouts (raw TEXT PRIMARY KEY)');
                await db.execute('CREATE TABLE meta (key TEXT PRIMARY KEY, '
                    'value TEXT NOT NULL)');
              }));
      final r = workout('old-1', reps: 7);
      await v1.insert('workouts', {
        'id': r.id,
        'client_id': 'c-old-1',
        'started_at': 0,
        'raw': jsonEncode({...r.toJson(), 'client_id': 'c-old-1'}),
      });
      await v1.close();

      WorkoutDatabase.close();
      WorkoutDatabase.pathOverride = path;
      final db = await WorkoutDatabase.instance();
      expect(await db.db.getVersion(), WorkoutDatabase.schemaVersion);
      final tables = (await db.db.rawQuery(
              "SELECT name FROM sqlite_master WHERE type = 'table'"))
          .map((t) => t['name'])
          .toSet();
      expect(tables, containsAll(['sync_rows', 'sync_deletions']));
      expect((await store.load()).single.reps, 7);
      // An existing workout is local and undecided: not uploaded by itself.
      expect(await source.pending(), isEmpty);
      expect(await source.clientIds(), {'c-old-1'});

      // Running the creation again changes nothing.
      await WorkoutDatabase.createSyncTables(db.db);
      WorkoutDatabase.close();
      final again = await WorkoutDatabase.instance();
      expect((await again.allRaw()).length, 1);
    });
  });

  test('a guest workout stays local; after linking new ones are pending',
      () async {
    await store.save(workout('guest'));
    expect(await source.pending(), isEmpty);
    expect(await source.pendingCount(), 0);

    expect(await source.link('u1'), isFalse);
    await store.save(workout('mine'));
    final pending = await source.pending();
    expect(pending.single.clientId, await clientIdOf('mine'));
    expect(pending.single.raw['reps'], 20);
    expect(await source.clientIds(), {await clientIdOf('guest')});

    await source.markPushed(pending);
    expect(await source.pendingCount(), 0);

    // An edit (AI feedback) of an account workout goes up again.
    await store.saveFeedback('mine', 'Nice');
    expect((await source.pending()).single.raw['ai_feedback'], 'Nice');
    // An edit of the undecided guest workout does not.
    await store.saveFeedback('guest', 'Nice');
    expect((await source.pending()).length, 1);
  });

  test('deleting an account workout queues a tombstone; Undo uploads it again',
      () async {
    await source.link('u1');
    await store.save(workout('w'));
    final id = await clientIdOf('w');
    await source.markPushed(await source.pending());

    final deleted = await store.delete('w');
    expect(deleted!.inAccount, isTrue);
    final tomb = (await source.pending()).single;
    expect(tomb.clientId, id);
    expect(tomb.isTombstone, isTrue);
    expect(tomb.raw['exercise_id'], 'push_up', reason: 'full row for the server');

    await store.restore(deleted);
    final again = (await source.pending()).single;
    expect(again.isTombstone, isFalse);
    expect(again.clientId, id);

    // A local-only workout is deleted without a tombstone.
    await source.unlink();
    await store.save(workout('local'));
    expect((await store.delete('local'))!.inAccount, isFalse);
    expect((await source.pending()).length, 1);
  });

  test('applying the account copy', () async {
    await source.link('u1');
    final t0 = DateTime.utc(2026, 10, 30, 9);
    SyncWorkout remote(String clientId, String id,
            {int reps = 30, DateTime? at, bool deleted = false}) =>
        SyncWorkout(
            clientId: clientId,
            raw: {...workout(id, reps: reps).toJson(), 'client_id': clientId},
            clientUpdatedAt: at ?? t0,
            deletedAt: deleted ? (at ?? t0) : null);

    // New from another phone.
    await source.apply(remote('c-a', 'a'));
    expect((await store.load()).single.reps, 30);
    expect(await source.pending(), isEmpty);

    // A newer edit replaces it; an older one does not.
    await source.apply(remote('c-a', 'a', reps: 31, at: t0.add(
        const Duration(minutes: 1))));
    await source.apply(remote('c-a', 'a', reps: 1, at: t0));
    expect((await store.load()).single.reps, 31);

    // An undecided local workout is never overwritten before the merge.
    await source.unlink();
    await store.save(workout('g', reps: 5));
    await source.link('u1');
    final g = await clientIdOf('g');
    await source.apply(remote(g, 'g', reps: 99));
    expect((await store.load()).firstWhere((r) => r.id == 'g').reps, 5);

    // A pending local edit newer than the account copy is kept.
    await store.save(workout('p', reps: 8));
    final p = await clientIdOf('p');
    await source.apply(remote(p, 'p', reps: 99, at: t0));
    expect((await store.load()).firstWhere((r) => r.id == 'p').reps, 8);

    // A tombstone removes an account workout.
    await source.apply(remote('c-a', 'a',
        at: t0.add(const Duration(hours: 1)), deleted: true));
    expect((await store.load()).map((r) => r.id), isNot(contains('a')));
  });

  test('signing in to another account starts over', () async {
    await source.link('u1');
    await store.save(workout('w'));
    await source.saveCursor(42);
    expect(await source.link('u1'), isFalse);
    expect(await source.cursor(), 42);

    expect(await source.link('u2'), isTrue);
    expect(await source.cursor(), 0);
    expect(await source.pending(), isEmpty);
    expect(await source.clientIds(), {await clientIdOf('w')},
        reason: 'offered to the new account in the merge');
  });

  test('merge choices and "delete from my account"', () async {
    await store.save(workout('up'));
    await store.save(workout('same'));
    await store.save(workout('keep'));
    await source.link('u1');
    await source.resolve(
        upload: {await clientIdOf('up')},
        same: {await clientIdOf('same')},
        keep: {await clientIdOf('keep')});
    expect((await source.pending()).single.clientId, await clientIdOf('up'));
    expect(await source.clientIds(), isEmpty);

    await source.keepAllOnPhone();
    expect(await source.pending(), isEmpty);
    expect((await store.load()).length, 3, reason: 'the phone keeps its copy');
    // Kept workouts never go up again, even when edited.
    await store.saveFeedback('up', 'x');
    expect(await source.pending(), isEmpty);
  });

  test('"this phone only" clear: the account copy never comes back here',
      () async {
    await source.link('u1');
    await store.save(workout('w'));
    final id = await clientIdOf('w');
    final pushed = await source.pending();
    await source.markPushed(pushed);
    await store.clear();
    expect(await store.load(), isEmpty);
    // The next pull still returns the row this phone pushed.
    await source.apply(pushed.single);
    expect(await store.load(), isEmpty);
    expect(await source.pending(), isEmpty);
    expect(await source.clientIds(), isNot(contains(id)));
  });

  test('a deletion from the account also removes the pre-F-3 copy',
      () async {
    final legacy = workout('legacy-1');
    SharedPreferences.setMockInitialValues({
      WorkoutDatabase.legacyKey: [jsonEncode(legacy.toJson())],
    });
    WorkoutDatabase.close();
    await source.link('u1');
    final id = await clientIdOf('legacy-1');
    await source.resolve(upload: {id});
    await source.markPushed(await source.pending());
    await source.apply(SyncWorkout(
        clientId: id,
        raw: {...legacy.toJson(), 'client_id': id},
        clientUpdatedAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        deletedAt: DateTime.now().toUtc()));
    expect(await store.load(), isEmpty);
    // Reopening imports the rollback copy again: it must not come back.
    WorkoutDatabase.close();
    expect(await store.load(), isEmpty);
  });
}
