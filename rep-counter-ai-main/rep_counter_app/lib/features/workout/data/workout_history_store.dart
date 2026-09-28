import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'workout_record.dart';

/// Carries the exact removed JSON so Undo also preserves optional/future fields.
class DeletedWorkout {
  const DeletedWorkout._(this.record, this._raw);
  final WorkoutRecord record;
  final String _raw;
}

class WorkoutHistoryStore {
  static const _key = 'workout_history_v1';
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

  List<_Entry> _read(SharedPreferences prefs) =>
      (prefs.getStringList(_key) ?? const []).map(_Entry.parse).toList();

  Future<void> _write(SharedPreferences prefs, List<_Entry> entries) async {
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

  Future<List<WorkoutRecord>> load() => _serial(() async {
        final entries = _read(await SharedPreferences.getInstance());
        final records = entries
            .map((e) => e.record)
            .whereType<WorkoutRecord>()
            .toList()
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
        return records;
      });

  Future<void> save(WorkoutRecord record) => _serial(() async {
        final prefs = await SharedPreferences.getInstance();
        final entries = _read(prefs)
          ..removeWhere((e) => e.record?.id == record.id);
        entries.add(_Entry(jsonEncode(record.toJson()), record));
        await _write(prefs, _limit(entries));
      });

  // Keep the existing 100-workout limit. Unreadable entries are retained as raw
  // JSON during mutations instead of being silently erased by an unrelated save.
  List<_Entry> _limit(List<_Entry> entries) {
    final valid = entries.where((e) => e.record != null).toList()
      ..sort((a, b) => b.record!.startedAt.compareTo(a.record!.startedAt));
    return [...valid.take(100), ...entries.where((e) => e.record == null)];
  }

  Future<void> clear() => _serial(() async {
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
      });

  /// Change only feedback. Preserve metrics and unknown fields verbatim.
  Future<void> saveFeedback(String id, String feedback) => _serial(() async {
        final prefs = await SharedPreferences.getInstance();
        final entries = _read(prefs);
        final index = entries.indexWhere((e) => e.record?.id == id);
        if (index < 0) throw StateError('Workout no longer exists');
        final json = jsonDecode(entries[index].raw) as Map<String, dynamic>;
        json['ai_feedback'] = feedback;
        entries[index] = _Entry.parse(jsonEncode(json));
        await _write(prefs, entries);
      });

  Future<DeletedWorkout?> delete(String id) => _serial(() async {
        final prefs = await SharedPreferences.getInstance();
        final entries = _read(prefs);
        final index = entries.indexWhere((e) => e.record?.id == id);
        if (index < 0) return null;
        final removed = entries.removeAt(index);
        await _write(prefs, entries);
        return DeletedWorkout._(removed.record!, removed.raw);
      });

  Future<void> restore(DeletedWorkout deleted) => _serial(() async {
        final prefs = await SharedPreferences.getInstance();
        final entries = _read(prefs);
        // Do not overwrite a newer copy if an ID has already been restored.
        if (entries.any((e) => e.record?.id == deleted.record.id)) return;
        entries.add(_Entry(deleted._raw, deleted.record));
        await _write(prefs, _limit(entries));
      });
}

class _Entry {
  const _Entry(this.raw, this.record);
  final String raw;
  final WorkoutRecord? record;
  static _Entry parse(String raw) {
    try {
      return _Entry(
          raw, WorkoutRecord.fromJson(jsonDecode(raw) as Map<String, dynamic>));
    } catch (_) {
      return _Entry(raw, null);
    }
  }
}
