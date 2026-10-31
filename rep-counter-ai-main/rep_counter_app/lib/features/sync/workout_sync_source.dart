import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../workout/data/workout_database.dart';
import '../workout/data/workout_history_store.dart';
import 'cloud_sync.dart';

/// [LocalSyncSource] over the workout database (A-2). Every read and write
/// goes through [WorkoutHistoryStore.exclusive], the same queue as saves,
/// deletes and Undo, so sync never races a change made on the phone.
///
/// Bookkeeping lives in `sync_rows` / `sync_deletions`
/// ([WorkoutDatabase.createSyncTables]); `workouts` rows are never altered
/// except to apply the account's copy.
class WorkoutSyncSource implements LocalSyncSource {
  const WorkoutSyncSource();

  static const _cursorKey = 'sync_cursor_workouts';

  /// The account the cursor and states belong to, kept after sign-out so
  /// signing in again to the same account continues where it stopped.
  static const _lastUserKey = 'sync_last_user';

  static int _now() => DateTime.now().toUtc().millisecondsSinceEpoch;

  static Future<T> _db<T>(Future<T> Function(Database db) run) =>
      WorkoutHistoryStore.exclusive((store) {
        if (store == null) throw StateError('workout database unavailable');
        return run(store.db);
      });

  @override
  Future<List<SyncWorkout>> pending() => _db((db) async {
        final rows = await db.rawQuery('''
          SELECT w.client_id, w.raw, s.updated_at FROM workouts w
          JOIN sync_rows s ON s.client_id = w.client_id
          WHERE s.state = 'pending' ''');
        final deletions = await db.query('sync_deletions');
        return [
          for (final r in rows)
            SyncWorkout(
              clientId: r['client_id'] as String,
              raw: _decode(r['raw'] as String),
              clientUpdatedAt: _time(r['updated_at']),
            ),
          for (final d in deletions)
            SyncWorkout(
              clientId: d['client_id'] as String,
              raw: _decode(d['raw'] as String),
              clientUpdatedAt: _time(d['deleted_at']),
              deletedAt: _time(d['deleted_at']),
            ),
        ];
      });

  /// Workouts and deletions waiting for upload (the badge count).
  Future<int> pendingCount() => _db((db) async {
        final n = Sqflite.firstIntValue(await db.rawQuery(
            "SELECT COUNT(*) FROM sync_rows WHERE state = 'pending'"));
        final d = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM sync_deletions'));
        return (n ?? 0) + (d ?? 0);
      });

  @override
  Future<void> markPushed(List<SyncWorkout> stored) => _db((db) async {
        await db.transaction((txn) async {
          for (final w in stored) {
            final at = w.clientUpdatedAt.toUtc().millisecondsSinceEpoch;
            if (w.isTombstone) {
              await txn.delete('sync_deletions',
                  where: 'client_id = ? AND deleted_at <= ?',
                  whereArgs: [w.clientId, at]);
              continue;
            }
            // The server kept a live copy newer than this phone's deletion
            // (restored on another phone): drop the deletion, take the copy.
            final overruled = await txn.delete('sync_deletions',
                where: 'client_id = ? AND deleted_at <= ?',
                whereArgs: [w.clientId, at]);
            // A change made while the push ran stays pending.
            await txn.update('sync_rows', {'state': 'synced'},
                where: "client_id = ? AND state = 'pending' AND updated_at <= ?",
                whereArgs: [w.clientId, at]);
            // The server kept a newer copy from another phone: take it.
            await _applyRow(txn, w, onlyIfNewer: overruled == 0);
          }
        });
      });

  @override
  Future<void> apply(SyncWorkout w) => _db((db) async {
        await db.transaction((txn) => _applyRow(txn, w));
        final id = w.raw['id'];
        if (w.isTombstone && id is String) {
          // A workout from before F-3 also lives in the rollback copy.
          final gone = await db.query('workouts',
              columns: ['id'], where: 'id = ?', whereArgs: [id], limit: 1);
          if (gone.isEmpty) await WorkoutHistoryStore.forgetLegacyCopy(id);
        }
      });

  /// Writes the account's copy unless this phone has a newer change for the
  /// same workout, or the workout is local and waits for the merge choice.
  static Future<void> _applyRow(Transaction txn, SyncWorkout w,
      {bool onlyIfNewer = false}) async {
    final at = w.clientUpdatedAt.toUtc().millisecondsSinceEpoch;
    final local = await txn.query('sync_rows',
        where: 'client_id = ?', whereArgs: [w.clientId], limit: 1);
    final present = await txn.query('workouts',
        columns: ['id'],
        where: 'client_id = ?',
        whereArgs: [w.clientId],
        limit: 1);
    if (local.isEmpty && present.isNotEmpty) return; // undecided local copy
    if (local.isNotEmpty) {
      final state = local.single['state'] as String;
      if (state == 'kept') return;
      final mine = local.single['updated_at'] as int;
      if ((state == 'pending' || onlyIfNewer) && mine >= at) return;
      if (mine > at) return; // this phone already has a newer version
    }
    final deleted = await txn.query('sync_deletions',
        columns: ['deleted_at'],
        where: 'client_id = ?',
        whereArgs: [w.clientId],
        limit: 1);
    if (deleted.isNotEmpty && (deleted.single['deleted_at'] as int) >= at) {
      return; // deleted here after that edit; the tombstone goes up next
    }
    if (onlyIfNewer && local.isEmpty) return;

    if (w.isTombstone) {
      await txn.delete('workouts',
          where: 'client_id = ?', whereArgs: [w.clientId]);
      await txn.delete('sync_rows',
          where: 'client_id = ?', whereArgs: [w.clientId]);
      await txn.delete('sync_deletions',
          where: 'client_id = ?', whereArgs: [w.clientId]);
      return;
    }
    final raw = jsonEncode({...w.raw, 'client_id': w.clientId});
    final parsed = parseWorkoutJson(raw);
    if (parsed == null) return; // a newer app version's row; skip it
    // Another local row may hold the same workout id under a different
    // client id (never expected); the account copy wins.
    await txn.delete('workouts',
        where: 'id = ? AND client_id <> ?',
        whereArgs: [parsed.record.id, w.clientId]);
    await txn.delete('workouts',
        where: 'client_id = ? AND id <> ?',
        whereArgs: [w.clientId, parsed.record.id]);
    await WorkoutDatabase.insert(txn, parsed.json, parsed.record,
        clientId: w.clientId, replace: true);
    await txn.insert(
        'sync_rows', {'client_id': w.clientId, 'state': 'synced', 'updated_at': at},
        conflictAlgorithm: ConflictAlgorithm.replace);
    await txn.delete('sync_deletions',
        where: 'client_id = ?', whereArgs: [w.clientId]);
  }

  /// Local workouts not yet decided for the account (the merge candidates).
  @override
  Future<Set<String>> clientIds() => _db((db) async => {
        for (final r in await db.rawQuery('''
          SELECT client_id FROM workouts
          WHERE client_id NOT IN (SELECT client_id FROM sync_rows)'''))
          r['client_id'] as String
      });

  /// Raw JSON of the undecided local workouts, by client id.
  Future<Map<String, Map<String, Object?>>> undecided() =>
      _db((db) async => {
            for (final r in await db.rawQuery('''
              SELECT client_id, raw FROM workouts
              WHERE client_id NOT IN (SELECT client_id FROM sync_rows)'''))
              r['client_id'] as String: _decode(r['raw'] as String)
          });

  @override
  Future<int> cursor() => _db((db) async =>
      int.tryParse(await WorkoutDatabase.metaValue(db, _cursorKey) ?? '') ?? 0);

  @override
  Future<void> saveCursor(int cursor) =>
      _db((db) => WorkoutDatabase.setMeta(db, _cursorKey, '$cursor'));

  /// Links this phone's sync state to [userId]. Signing in again to the same
  /// account keeps everything; a different account starts over: every
  /// workout becomes local and undecided (offered in the merge), queued
  /// deletions of the old account are dropped and the cursor restarts.
  /// Returns true when the account changed.
  Future<bool> link(String userId) => _db((db) => db.transaction((txn) async {
        final last = await WorkoutDatabase.metaValue(txn, _lastUserKey);
        final changed = last != null && last != userId;
        if (changed) {
          await txn.delete('sync_rows');
          await txn.delete('sync_deletions');
          await WorkoutDatabase.setMeta(txn, _cursorKey, null);
        }
        await WorkoutDatabase.setMeta(txn, WorkoutDatabase.syncUserKey, userId);
        await WorkoutDatabase.setMeta(txn, _lastUserKey, userId);
        return changed;
      }));

  /// Signed out: new workouts stay on the phone (and are offered in the
  /// merge at the next sign-in); account workouts keep their state.
  Future<void> unlink() => _db(
      (db) => WorkoutDatabase.setMeta(db, WorkoutDatabase.syncUserKey, null));

  /// Applies the merge choice for the undecided workouts: [upload] become
  /// pending (now, so they win on the server), [same] are already in the
  /// account, [takeAccount] are replaced by the account's copy, [keep] stay
  /// on this phone only.
  Future<void> resolve({
    Set<String> upload = const {},
    Set<String> same = const {},
    Map<String, SyncWorkout> takeAccount = const {},
    Set<String> keep = const {},
  }) =>
      _db((db) => db.transaction((txn) async {
            final now = _now();
            Future<void> mark(String id, String state, int at) => txn.insert(
                'sync_rows', {'client_id': id, 'state': state, 'updated_at': at},
                conflictAlgorithm: ConflictAlgorithm.replace);
            for (final id in upload) {
              await mark(id, 'pending', now);
            }
            for (final id in same) {
              await mark(id, 'synced', now);
            }
            for (final id in keep) {
              await mark(id, 'kept', now);
            }
            for (final w in takeAccount.values) {
              // Make it an account row first so _applyRow overwrites it.
              await mark(w.clientId, 'synced', 0);
              await _applyRow(txn, w);
            }
          }));

  /// "Delete from my account" (D-20): this phone keeps its copies, which
  /// are never uploaded again; queued deletions are no longer needed.
  Future<void> keepAllOnPhone() => _db((db) => db.transaction((txn) async {
        await txn.rawUpdate("UPDATE sync_rows SET state = 'kept'");
        await txn.rawInsert('''
          INSERT OR IGNORE INTO sync_rows (client_id, state, updated_at)
          SELECT client_id, 'kept', ? FROM workouts''', [_now()]);
        await txn.delete('sync_deletions');
      }));

  static Map<String, Object?> _decode(String raw) {
    final v = jsonDecode(raw);
    return v is Map ? v.cast<String, Object?>() : const {};
  }

  static DateTime _time(Object? ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms as int, isUtc: true);
}
