import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'workout_database.dart';
import 'workout_record.dart';

/// Carries the exact removed JSON so Undo also preserves optional/future fields.
class DeletedWorkout {
  const DeletedWorkout._(this.record, this._raw);
  final WorkoutRecord record;
  final String _raw;
}

/// Workout history. Since F-3 the records live in [WorkoutDatabase] (SQLite,
/// no 100-record cap, a `client_id` per record). The legacy
/// SharedPreferences list is the rollback copy: it is imported on every open
/// and, if the database cannot be opened, this store keeps working on that list
/// exactly as before F-3, so nothing is lost either way.
class WorkoutHistoryStore {
  static const _key = WorkoutDatabase.legacyKey;
  // One queue across store instances: save/AI/delete/clear cannot overwrite each
  // other's read-modify-write snapshots in this app isolate.
  static Future<void>? _pending;
  static Future<T> _serial<T>(Future<T> Function() operation) {
    final next =
        _pending == null ? operation() : _pending!.then((_) => operation());
    final barrier =
        next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    _pending = barrier;
    return next.whenComplete(() {
      if (identical(_pending, barrier)) _pending = null;
    });
  }

  /// Drops a queue left behind by an earlier test's fake-async zone.
  @visibleForTesting
  static void resetForTest() => _pending = null;

  /// The database, or null when it cannot be opened (legacy fallback).
  Future<WorkoutDatabase?> _database() async {
    try {
      return await WorkoutDatabase.instance();
    } catch (_) {
      return null;
    }
  }

  Future<List<WorkoutRecord>> load() => _serial(() async {
        final db = await _database();
        if (db == null) return _LegacyHistory.load();
        return (await db.allRaw())
            .map((raw) => parseWorkoutJson(raw)?.record)
            .whereType<WorkoutRecord>()
            .toList()
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
      });

  Future<void> save(WorkoutRecord record) => _serial(() async {
        final db = await _database();
        if (db == null) return _LegacyHistory.save(record);
        await db.db.transaction((txn) async {
          await WorkoutDatabase.insert(txn, record.toJson(), record,
              clientId: await WorkoutDatabase.clientIdFor(txn, record.id),
              replace: true);
        });
      });

  /// Deletes all history, including the legacy rollback copy, so a cleared
  /// history cannot come back.
  Future<void> clear() => _serial(() async {
        final db = await _database();
        await db?.db.transaction((txn) async {
          await txn.delete('workouts');
          await txn.delete('unreadable_workouts');
        });
        await _LegacyHistory.clear();
      });

  /// Change only feedback. Preserve metrics and unknown fields verbatim.
  Future<void> saveFeedback(String id, String feedback) => _serial(() async {
        final db = await _database();
        if (db == null) return _LegacyHistory.saveFeedback(id, feedback);
        await db.db.transaction((txn) async {
          final raw = await WorkoutDatabase.rawFor(txn, id);
          if (raw == null) throw StateError('Workout no longer exists');
          final json = jsonDecode(raw) as Map<String, dynamic>;
          json['ai_feedback'] = feedback;
          await txn.update('workouts', {'raw': jsonEncode(json)},
              where: 'id = ?', whereArgs: [id]);
        });
      });

  /// Deletes one workout. It is also removed from the legacy copy so the next
  /// import cannot bring it back.
  Future<DeletedWorkout?> delete(String id) => _serial(() async {
        final db = await _database();
        if (db == null) return _LegacyHistory.delete(id);
        final removed = await db.db.transaction((txn) async {
          final raw = await WorkoutDatabase.rawFor(txn, id);
          if (raw != null) {
            await txn.delete('workouts', where: 'id = ?', whereArgs: [id]);
          }
          return raw;
        });
        if (removed == null) return null;
        await _LegacyHistory.delete(id);
        final parsed = parseWorkoutJson(removed);
        return parsed == null ? null : DeletedWorkout._(parsed.record, removed);
      });

  Future<void> restore(DeletedWorkout deleted) => _serial(() async {
        final db = await _database();
        if (db == null) return _LegacyHistory.restore(deleted);
        final parsed = parseWorkoutJson(deleted._raw);
        if (parsed == null) return;
        // Do not overwrite a newer copy if an ID has already been restored.
        await WorkoutDatabase.insert(db.db, parsed.json, parsed.record,
            clientId: parsed.json['client_id'] as String?, replace: false);
      });
}

/// The pre-F-3 SharedPreferences implementation, kept as the fallback when the
/// database is unavailable and as the rollback copy's writer.
abstract final class _LegacyHistory {
  static const _key = WorkoutHistoryStore._key;

  static List<_Entry> _read(SharedPreferences prefs) =>
      (prefs.getStringList(_key) ?? const []).map(_Entry.parse).toList();

  static Future<void> _write(
      SharedPreferences prefs, List<_Entry> entries) async {
    try {
      if (!await prefs.setStringList(
          _key, entries.map((e) => e.raw).toList())) {
        throw StateError('Cannot write workout history');
      }
    } catch (_) {
      // SharedPreferences updates its memory cache before the platform write.
      // Read disk back after failure so a subsequent load does not claim success.
      try {
        await prefs.reload();
      } catch (_) {}
      rethrow;
    }
  }

  static Future<List<WorkoutRecord>> load() async {
    final entries = _read(await SharedPreferences.getInstance());
    return entries.map((e) => e.record).whereType<WorkoutRecord>().toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  }

  static Future<void> save(WorkoutRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = _read(prefs)..removeWhere((e) => e.record?.id == record.id);
    entries.add(_Entry(jsonEncode(record.toJson()), record));
    await _write(prefs, _limit(entries));
  }

  // The legacy list keeps its 100-workout limit. Unreadable entries are
  // retained as raw JSON during mutations instead of being silently erased.
  static List<_Entry> _limit(List<_Entry> entries) {
    final valid = entries.where((e) => e.record != null).toList()
      ..sort((a, b) => b.record!.startedAt.compareTo(a.record!.startedAt));
    return [...valid.take(100), ...entries.where((e) => e.record == null)];
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      if (!await prefs.remove(_key)) {
        throw StateError('Cannot clear history');
      }
    } catch (_) {
      try {
        await prefs.reload();
      } catch (_) {}
      rethrow;
    }
  }

  static Future<void> saveFeedback(String id, String feedback) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = _read(prefs);
    final index = entries.indexWhere((e) => e.record?.id == id);
    if (index < 0) throw StateError('Workout no longer exists');
    final json = jsonDecode(entries[index].raw) as Map<String, dynamic>;
    json['ai_feedback'] = feedback;
    entries[index] = _Entry.parse(jsonEncode(json));
    await _write(prefs, entries);
  }

  static Future<DeletedWorkout?> delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = _read(prefs);
    final index = entries.indexWhere((e) => e.record?.id == id);
    if (index < 0) return null;
    final removed = entries.removeAt(index);
    await _write(prefs, entries);
    return DeletedWorkout._(removed.record!, removed.raw);
  }

  static Future<void> restore(DeletedWorkout deleted) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = _read(prefs);
    // Do not overwrite a newer copy if an ID has already been restored.
    if (entries.any((e) => e.record?.id == deleted.record.id)) return;
    entries.add(_Entry(deleted._raw, deleted.record));
    await _write(prefs, _limit(entries));
  }
}

class _Entry {
  const _Entry(this.raw, this.record);
  final String raw;
  final WorkoutRecord? record;
  static _Entry parse(String raw) => _Entry(raw, parseWorkoutJson(raw)?.record);
}
