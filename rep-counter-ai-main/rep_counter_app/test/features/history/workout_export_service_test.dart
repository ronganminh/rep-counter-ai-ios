import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rep_counter_app/features/history/export/workout_export_service.dart';
import 'package:rep_counter_app/features/workout/data/workout_history_store.dart';
import 'package:rep_counter_app/features/workout/data/workout_record.dart';

WorkoutRecord record({
  String id = 'a,1',
  String name = 'Hít đất "chuẩn"',
  String? aiFeedback = 'Giữ lưng thẳng, chậm lại.',
}) =>
    WorkoutRecord(
      id: id,
      exerciseId: 'push_up',
      exerciseName: name,
      startedAt: DateTime.utc(2026, 10, 2, 12, 30),
      durationSeconds: 90,
      reps: 17,
      sets: 2,
      targetReps: 20,
      poseFrames: 100,
      readyFrames: 87,
      lostFrames: 13,
      aiFeedback: aiFeedback,
      quality: const WorkoutQuality(
        flaggedReps: 2,
        avgRepSeconds: 2.4,
        avgAmplitude: 44.2,
        amplitudeDropPercent: 8.1,
        leftRightDiffPercent: 5.5,
        qualityScore: 82,
        rangeOfMotion: 84,
        cadenceConsistency: 80,
        leftRightBalance: 85,
        poseAlignment: 79,
        hasEnoughData: true,
      ),
    );

void main() {
  const service = WorkoutExportService();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('CSV escapes commas and quotes and preserves Vietnamese UTF-8', () {
    final file = service.build(
      records: [record()],
      format: WorkoutExportFormat.csv,
      includeSavedAiFeedback: false,
      now: DateTime(2026, 10, 2),
    );

    final text = utf8.decode(file.bytes);
    expect(file.fileName, 'repcoach-workouts-20261002.csv');
    expect(file.mimeType, 'text/csv');
    expect(text, contains('"a,1"'));
    expect(text, contains('"Hít đất ""chuẩn"""'));
    expect(text, contains('82'));
    expect(text, isNot(contains('Giữ lưng thẳng')));
    expect(text, isNot(contains('rep_details')));
    expect(text, isNot(contains('pose_frames')));
  });

  test('JSON has stable schema and includes only explicit AI feedback', () {
    final withoutAi = service.build(
      records: [record()],
      format: WorkoutExportFormat.json,
      includeSavedAiFeedback: false,
      now: DateTime(2026, 10, 2),
    );
    final without = jsonDecode(utf8.decode(withoutAi.bytes))
        as Map<String, dynamic>;
    expect(without['schemaVersion'], 1);
    final workout =
        (without['workouts'] as List).single as Map<String, dynamic>;
    expect(workout['exerciseName'], 'Hít đất "chuẩn"');
    expect(workout['placementScore'], 87);
    expect(workout['goalReached'], isFalse);
    expect(workout['aiFeedback'], isNull);
    expect(workout['quality']['formScore'], 82);
    expect(workout.containsKey('repDetails'), isFalse);
    expect(workout.containsKey('poseFrames'), isFalse);

    final withAi = service.build(
      records: [record()],
      format: WorkoutExportFormat.json,
      includeSavedAiFeedback: true,
      now: DateTime(2026, 10, 2),
    );
    final withMap =
        jsonDecode(utf8.decode(withAi.bytes)) as Map<String, dynamic>;
    final withWorkout =
        (withMap['workouts'] as List).single as Map<String, dynamic>;
    expect(withWorkout['aiFeedback'], 'Giữ lưng thẳng, chậm lại.');
  });

  test('empty history does not create an export', () {
    expect(
      () => service.build(
        records: const [],
        format: WorkoutExportFormat.csv,
        includeSavedAiFeedback: false,
      ),
      throwsA(isA<EmptyWorkoutExport>()),
    );
  });

  test('share failure never mutates or deletes workout history', () async {
    final original = record(id: 'keep');
    await WorkoutHistoryStore().save(original);

    await expectLater(
      service.createAndShare(
        records: [original],
        format: WorkoutExportFormat.json,
        includeSavedAiFeedback: false,
        share: (_) async => throw StateError('share failed'),
      ),
      throwsStateError,
    );

    final saved = await WorkoutHistoryStore().load();
    expect(saved, hasLength(1));
    expect(saved.single.id, 'keep');
    expect(saved.single.reps, 17);
    expect(saved.single.aiFeedback, original.aiFeedback);
  });
}
