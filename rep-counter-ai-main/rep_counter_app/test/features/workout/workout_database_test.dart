import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/features/workout/data/workout_database.dart';
import 'package:rep_counter_app/features/workout/data/workout_history_store.dart';
import 'package:rep_counter_app/features/workout/data/workout_record.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// F-3 / D-16: SharedPreferences `workout_history_v1` → SQLite.
///
/// The global test config uses an in-memory database; tests that need the
/// data to survive a reopen use a real file instead.

Map<String, dynamic> _current(String id, {int day = 1, int reps = 20}) =>
    WorkoutRecord(
      id: id,
      exerciseId: 'push_up',
      exerciseName: 'Hít đất',
      startedAt: DateTime.utc(2026, 1, day, 8),
      durationSeconds: 120,
      reps: reps,
      sets: 2,
      targetReps: 20,
      poseFrames: 100,
      readyFrames: 90,
      lostFrames: 10,
    ).toJson();

/// A v1-era record: no mode, no quality, no rep details, offset timestamp.
Map<String, dynamic> _oldFormat(String id) => {
      'id': id,
      'exercise_id': 'push_up',
      'exercise_name': 'Push-up',
      'started_at': '2025-06-01T07:30:00+07:00',
      'duration_seconds': 95,
      'reps': 15,
      'sets': 1,
      'target_reps': null,
    };

final _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');

Future<List<Map<String, dynamic>>> _rows() async {
  final db = (await WorkoutDatabase.instance()).db;
  return [
    for (final row in await db.query('workouts', orderBy: 'id'))
      {
        ...row,
        'json': jsonDecode(row['raw'] as String),
      }
  ];
}

void main() {
  group('legacy import', () {
    test('imports current and old-format records, keeps unreadable ones',
        () async {
      final legacy = [
        jsonEncode(_current('a', day: 2)),
        jsonEncode(_oldFormat('old-1')),
        'not json',
        jsonEncode({'id': 'missing-fields'}),
        jsonEncode(_current('a', day: 2)), // duplicate id
      ];
      SharedPreferences.setMockInitialValues({'workout_history_v1': legacy});

      final loaded = await WorkoutHistoryStore().load();
      expect(loaded.map((r) => r.id), ['a', 'old-1']);
      final old = loaded.last;
      expect(old.reps, 15);
      expect(old.startedAt.toUtc(), DateTime.utc(2025, 6, 1, 0, 30));
      expect(old.targetReps, isNull);

      final db = (await WorkoutDatabase.instance()).db;
      expect(
          (await db.query('unreadable_workouts')).map((r) => r['raw']).toSet(),
          {
            'not json',
            jsonEncode({'id': 'missing-fields'})
          });
      final marker =
          jsonDecode((await db.query('meta')).single['value'] as String)
              as Map<String, dynamic>;
      expect(marker['legacy_entries'], 5);
      expect(marker['workouts'], 2);

      // The rollback copy is left exactly as it was.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('workout_history_v1'), legacy);
    });

    test('an empty or missing legacy list imports nothing', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await WorkoutHistoryStore().load(), isEmpty);
      WorkoutDatabase.close();
      SharedPreferences.setMockInitialValues(
          {'workout_history_v1': <String>[]});
      expect(await WorkoutHistoryStore().load(), isEmpty);
      final db = (await WorkoutDatabase.instance()).db;
      expect(await db.query('workouts'), isEmpty);
      expect(
          jsonDecode(
              (await db.query('meta')).single['value'] as String)['workouts'],
          0);
    });

    test('more than 100 records all survive (cap removed)', () async {
      SharedPreferences.setMockInitialValues({
        'workout_history_v1': [
          for (var i = 0; i < 150; i++)
            jsonEncode(_current('w$i', day: 1 + i % 28, reps: i)),
        ],
      });
      final loaded = await WorkoutHistoryStore().load();
      expect(loaded, hasLength(150));
      expect(loaded.map((r) => r.id).toSet(),
          {for (var i = 0; i < 150; i++) 'w$i'});
      await WorkoutHistoryStore().save(WorkoutRecord.fromJson(_current('new')));
      expect(await WorkoutHistoryStore().load(), hasLength(151));
    });

    test('running the import twice changes nothing', () async {
      SharedPreferences.setMockInitialValues({
        'workout_history_v1': [
          jsonEncode(_current('a')),
          jsonEncode(_oldFormat('b')),
          'broken',
        ],
      });
      final db = await WorkoutDatabase.instance();
      final before = await _rows();
      final prefs = await SharedPreferences.getInstance();
      final second = await db.importLegacy(prefs);
      final third = await db.importLegacy(prefs);
      expect(second.imported, 0);
      expect(second.unreadable, 0);
      expect(second.firstRun, isFalse);
      expect(third.imported, 0);
      expect(await _rows(), before);
      expect(await db.db.query('unreadable_workouts'), hasLength(1));
      expect(await db.db.query('meta'), hasLength(1));
    });

    test('a file database keeps records and ids across reopen', () async {
      final dir = await Directory.systemTemp.createTemp('repcoach_db');
      addTearDown(() => dir.delete(recursive: true));
      final previous = WorkoutDatabase.pathOverride;
      WorkoutDatabase.pathOverride = '${dir.path}/repcoach.db';
      addTearDown(() => WorkoutDatabase.pathOverride = previous);

      SharedPreferences.setMockInitialValues({
        'workout_history_v1': [
          jsonEncode(_current('a')),
          jsonEncode(_oldFormat('b'))
        ],
      });
      final first = await _rows();
      WorkoutDatabase.close();
      final reopened = await _rows();
      expect(reopened, first);
      expect(reopened.map((r) => r['id']), ['a', 'b']);
    });
  });

  group('client ids', () {
    test('every record gets a stable UUID that is also in its JSON', () async {
      SharedPreferences.setMockInitialValues({
        'workout_history_v1': [jsonEncode(_oldFormat('old'))],
      });
      final store = WorkoutHistoryStore();
      await store.save(WorkoutRecord.fromJson(_current('new')));
      var rows = await _rows();
      final ids = {for (final r in rows) r['id']: r['client_id'] as String};
      for (final r in rows) {
        expect(r['client_id'], matches(_uuid));
        expect((r['json'] as Map)['client_id'], r['client_id']);
      }
      expect(ids['old'], isNot(ids['new']));

      // Saving again (e.g. after AI feedback) keeps the same id.
      await store.save(WorkoutRecord.fromJson(_current('new', reps: 21)));
      await store.saveFeedback('old', 'Nice');
      rows = await _rows();
      expect({for (final r in rows) r['id']: r['client_id']}, ids);
    });

    test('undo restores the original client id', () async {
      SharedPreferences.setMockInitialValues({});
      final store = WorkoutHistoryStore();
      await store.save(WorkoutRecord.fromJson(_current('x')));
      final id = (await _rows()).single['client_id'];
      final deleted = (await store.delete('x'))!;
      expect(await _rows(), isEmpty);
      await store.restore(deleted);
      expect((await _rows()).single['client_id'], id);
    });
  });

  group('rollback copy and deletion', () {
    test('a deleted legacy record does not come back on the next import',
        () async {
      SharedPreferences.setMockInitialValues({
        'workout_history_v1': [
          jsonEncode(_current('a')),
          jsonEncode(_current('b'))
        ],
      });
      final store = WorkoutHistoryStore();
      expect(await store.load(), hasLength(2));
      await store.delete('a');
      WorkoutDatabase.close();
      // The in-memory database is gone; the next open re-imports the legacy
      // copy, which must no longer contain the deleted workout.
      expect((await store.load()).map((r) => r.id), ['b']);
    });

    test('clearing history also clears the legacy copy', () async {
      SharedPreferences.setMockInitialValues({
        'workout_history_v1': [jsonEncode(_current('a')), 'broken'],
      });
      final store = WorkoutHistoryStore();
      await store.clear();
      expect(await store.load(), isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('workout_history_v1'), isNull);
      final db = (await WorkoutDatabase.instance()).db;
      expect(await db.query('unreadable_workouts'), isEmpty);
    });

    test('if the database cannot open, the legacy store keeps working',
        () async {
      final previous = WorkoutDatabase.pathOverride;
      // A directory is not a valid database file.
      final dir = await Directory.systemTemp.createTemp('repcoach_bad');
      addTearDown(() => dir.delete(recursive: true));
      WorkoutDatabase.pathOverride = dir.path;
      addTearDown(() => WorkoutDatabase.pathOverride = previous);

      SharedPreferences.setMockInitialValues({
        'workout_history_v1': [jsonEncode(_current('a'))],
      });
      final store = WorkoutHistoryStore();
      expect((await store.load()).single.id, 'a');
      await store.save(WorkoutRecord.fromJson(_current('b', day: 3)));
      expect((await store.load()).map((r) => r.id), ['b', 'a']);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('workout_history_v1'), hasLength(2));
    });

    test('a failed verification leaves the legacy data in place', () async {
      SharedPreferences.setMockInitialValues({
        'workout_history_v1': [jsonEncode(_current('a'))],
      });
      final db = await WorkoutDatabase.instance();
      // Simulate a database that silently drops a row during import.
      await db.db.execute('''
        CREATE TRIGGER drop_rows AFTER INSERT ON workouts
        BEGIN DELETE FROM workouts WHERE id = NEW.id; END''');
      await db.db.delete('workouts');
      await expectLater(db.importLegacy(await SharedPreferences.getInstance()),
          throwsStateError);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('workout_history_v1'), hasLength(1));
    });
  });
}
