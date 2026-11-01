import 'dart:convert';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'workout_record.dart';

/// Local SQLite database for workout history (roadmap F-3, decision D-16,
/// decision log L-D16).
///
/// The SharedPreferences list `workout_history_v1` stays on the device as the
/// rollback copy. Every open imports it again with `INSERT OR IGNORE` keyed by
/// workout id, then verifies that every readable legacy id is present, so the
/// import is automatic, idempotent and never duplicates or drops a record.
/// Unreadable legacy entries are kept verbatim in their own table.
class WorkoutDatabase {
  WorkoutDatabase._(this.db);

  final Database db;

  static const fileName = 'repcoach.db';
  static const legacyKey = 'workout_history_v1';
  /// 2 adds the cloud-sync bookkeeping tables (A-2), see [createSyncTables].
  static const schemaVersion = 2;

  /// Meta key written once the first import has been verified.
  static const importedKey = 'legacy_import_v1';

  /// Tests point this at `inMemoryDatabasePath`.
  static String? pathOverride;

  static Future<WorkoutDatabase>? _opening;
  static WorkoutDatabase? _current;

  static Future<WorkoutDatabase> instance() =>
      _opening ??= _open().then((db) => _current = db,
          onError: (Object error, StackTrace stack) {
        _opening = null;
        return Future<WorkoutDatabase>.error(error, stack);
      });

  /// Forgets the shared connection so the next [instance] opens a fresh one.
  /// Synchronous on purpose: tests call it between widget tests, whose
  /// fake-async zones never resume a future created inside them.
  static void close() {
    final current = _current;
    _current = null;
    _opening = null;
    current?.db.close().ignore();
  }

  static Future<WorkoutDatabase> _open() async {
    final path = pathOverride ??
        p.join(await getDatabasesPath(), WorkoutDatabase.fileName);
    final db = await openDatabase(path,
        version: schemaVersion,
        onCreate: (db, _) => _create(db),
        onUpgrade: (db, from, _) async {
          if (from < 2) await createSyncTables(db);
        },
        // In-memory test databases must not be shared between tests.
        singleInstance: pathOverride == null);
    final store = WorkoutDatabase._(db);
    try {
      await store.importLegacy(await SharedPreferences.getInstance());
    } catch (_) {
      await db.close();
      rethrow;
    }
    return store;
  }

  static Future<void> _create(Database db) async {
    await db.execute('''
      CREATE TABLE workouts (
        id TEXT PRIMARY KEY,
        client_id TEXT NOT NULL UNIQUE,
        started_at INTEGER NOT NULL,
        raw TEXT NOT NULL
      )''');
    await db.execute(
        'CREATE INDEX workouts_started_at ON workouts (started_at DESC)');
    // Legacy entries that no longer parse, preserved byte for byte.
    await db.execute('CREATE TABLE unreadable_workouts (raw TEXT PRIMARY KEY)');
    await db.execute(
        'CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
    await createSyncTables(db);
  }

  /// Cloud-sync bookkeeping (A-2), beside `workouts` so that table and its
  /// rows never change shape. Additive and idempotent: safe on every open,
  /// on a fresh install and after an interrupted upgrade.
  ///
  /// * `sync_rows`: one row per workout that belongs to the account:
  ///   `pending` (to upload), `synced`, or `kept` (no longer synced with this
  ///   phone: kept on the phone only, or removed from the phone only). A
  ///   workout with no row here is local and undecided: it is only uploaded
  ///   after the guest → account merge.
  /// * `sync_deletions`: deletions of account workouts not uploaded yet,
  ///   with the deleted JSON (the server needs the full row for a tombstone).
  static Future<void> createSyncTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_rows (
        client_id TEXT PRIMARY KEY,
        state TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_deletions (
        client_id TEXT PRIMARY KEY,
        raw TEXT NOT NULL,
        deleted_at INTEGER NOT NULL
      )''');
  }

  /// The account this phone's synced workouts belong to, if signed in.
  static const syncUserKey = 'sync_user';

  static Future<String?> metaValue(DatabaseExecutor db, String key) async {
    final rows = await db.query('meta',
        columns: ['value'], where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.single['value'] as String;
  }

  static Future<void> setMeta(
          DatabaseExecutor db, String key, String? value) =>
      value == null
          ? db.delete('meta', where: 'key = ?', whereArgs: [key])
          : db.insert('meta', {'key': key, 'value': value},
              conflictAlgorithm: ConflictAlgorithm.replace);

  static Future<String?> syncStateOf(
      DatabaseExecutor db, String clientId) async {
    final rows = await db.query('sync_rows',
        columns: ['state'],
        where: 'client_id = ?',
        whereArgs: [clientId],
        limit: 1);
    return rows.isEmpty ? null : rows.single['state'] as String;
  }

  /// Records a local change to [clientId] for sync. A new workout belongs to
  /// the account when one is linked; an existing one keeps its side: an
  /// account workout becomes pending again, a local or kept one stays.
  static Future<void> markChanged(DatabaseExecutor db, String clientId,
      {required bool isNew}) async {
    final state = await syncStateOf(db, clientId);
    final linked = await metaValue(db, syncUserKey) != null;
    final upload =
        state == 'pending' || state == 'synced' || (isNew && linked);
    if (!upload) return;
    await db.insert(
        'sync_rows',
        {
          'client_id': clientId,
          'state': 'pending',
          'updated_at': DateTime.now().toUtc().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Imports every legacy entry not already present, then verifies that each
  /// readable legacy workout id exists in the database. Throws (and the store
  /// falls back to the SharedPreferences copy) when verification fails.
  Future<LegacyImportResult> importLegacy(SharedPreferences prefs) async {
    final legacy = prefs.getStringList(legacyKey) ?? const <String>[];
    var imported = 0, unreadable = 0;
    final legacyIds = <String>{};
    await db.transaction((txn) async {
      for (final raw in legacy) {
        final parsed = parseWorkoutJson(raw);
        if (parsed == null) {
          final id = await txn.rawInsert(
              'INSERT OR IGNORE INTO unreadable_workouts (raw) VALUES (?)',
              [raw]);
          if (id > 0) unreadable++;
          continue;
        }
        legacyIds.add(parsed.record.id);
        if (await insert(txn, parsed.json, parsed.record,
            clientId: parsed.json['client_id'] as String?, replace: false)) {
          imported++;
        }
      }
    });
    final missing = legacyIds.difference(await _presentIds(legacyIds));
    if (missing.isNotEmpty) {
      throw StateError('Legacy workouts not imported: ${missing.length}');
    }
    final firstRun = (await db.query('meta',
            where: 'key = ?', whereArgs: [importedKey], limit: 1))
        .isEmpty;
    if (firstRun) {
      await db.insert('meta', {
        'key': importedKey,
        'value': jsonEncode({
          'at': DateTime.now().toUtc().toIso8601String(),
          'legacy_entries': legacy.length,
          'workouts': legacyIds.length,
        }),
      });
    }
    return LegacyImportResult(
        imported: imported,
        unreadable: unreadable,
        legacyWorkouts: legacyIds.length,
        firstRun: firstRun);
  }

  Future<Set<String>> _presentIds(Set<String> ids) async {
    final present = <String>{};
    final list = ids.toList();
    // SQLite limits bound parameters; check in chunks.
    for (var i = 0; i < list.length; i += 500) {
      final chunk = list.sublist(i, min(i + 500, list.length));
      final rows = await db.query('workouts',
          columns: ['id'],
          where: 'id IN (${List.filled(chunk.length, '?').join(',')})',
          whereArgs: chunk);
      present.addAll(rows.map((r) => r['id'] as String));
    }
    return present;
  }

  /// Writes [json] for [record] with a stable `client_id`, which is also
  /// stored inside the JSON so exports and a later sync carry it. With
  /// [replace] false an existing row with the same id is left untouched.
  /// Returns whether a row was written.
  static Future<bool> insert(
      DatabaseExecutor db, Map<String, dynamic> json, WorkoutRecord record,
      {String? clientId, required bool replace}) async {
    final id = clientId ?? newClientId();
    final rowId = await db.insert(
        'workouts',
        {
          'id': record.id,
          'client_id': id,
          'started_at': record.startedAt.toUtc().millisecondsSinceEpoch,
          'raw': jsonEncode({...json, 'client_id': id}),
        },
        conflictAlgorithm:
            replace ? ConflictAlgorithm.replace : ConflictAlgorithm.ignore);
    return rowId > 0;
  }

  /// Stored JSON of one workout, or null.
  static Future<String?> rawFor(DatabaseExecutor db, String id) async {
    final rows = await db.query('workouts',
        columns: ['raw'], where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : rows.single['raw'] as String;
  }

  static Future<String?> clientIdFor(DatabaseExecutor db, String id) async {
    final rows = await db.query('workouts',
        columns: ['client_id'], where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : rows.single['client_id'] as String;
  }

  /// Every stored workout JSON, newest first.
  Future<List<String>> allRaw() async =>
      (await db.query('workouts', columns: ['raw'], orderBy: 'started_at DESC'))
          .map((r) => r['raw'] as String)
          .toList();

  static final _random = Random.secure();

  /// Random RFC 4122 version 4 UUID.
  static String newClientId() {
    final b = List<int>.generate(16, (_) => _random.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    String hex(int from, int to) => b
        .sublist(from, to)
        .map((x) => x.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
  }
}

class LegacyImportResult {
  const LegacyImportResult(
      {required this.imported,
      required this.unreadable,
      required this.legacyWorkouts,
      required this.firstRun});
  final int imported, unreadable, legacyWorkouts;
  final bool firstRun;
}

class ParsedWorkout {
  const ParsedWorkout(this.json, this.record);
  final Map<String, dynamic> json;
  final WorkoutRecord record;
}

ParsedWorkout? parseWorkoutJson(String raw) {
  try {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return ParsedWorkout(json, WorkoutRecord.fromJson(json));
  } catch (_) {
    return null;
  }
}
