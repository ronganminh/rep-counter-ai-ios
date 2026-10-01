import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rep_counter_app/features/routine/data/routine_store.dart';
import 'package:rep_counter_app/features/routine/domain/routine_preset.dart';

RoutinePreset sample({
  String id = 'morning',
  String name = 'Hít đất buổi sáng',
  int reps = 15,
  int sets = 3,
  int rest = 60,
  bool voice = true,
}) =>
    RoutinePreset(
      id: id,
      name: name,
      exerciseId: 'push_up',
      targetReps: reps,
      targetSets: sets,
      restSeconds: rest,
      voiceCoachEnabled: voice,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('routine v1 JSON round trip preserves exact contract fields', () {
    final value = sample();
    final decoded = RoutinePreset.fromJson(
      jsonDecode(jsonEncode(value.toJson())) as Map<String, dynamic>,
    );

    expect(decoded.id, value.id);
    expect(decoded.name, value.name);
    expect(decoded.exerciseId, 'push_up');
    expect(decoded.targetReps, 15);
    expect(decoded.targetSets, 3);
    expect(decoded.restSeconds, 60);
    expect(decoded.voiceCoachEnabled, isTrue);
    expect(value.toJson().keys, containsAll(<String>[
      'name',
      'exercise_id',
      'target_reps',
      'target_sets',
      'rest_seconds',
      'voice_coach_enabled',
    ]));
  });

  test('routine rejects invalid/future payloads instead of guessing', () {
    expect(
      () => sample(reps: 0).validate(),
      throwsA(isA<FormatException>()),
    );
    final future = sample().toJson()..['schema_version'] = 2;
    expect(
      () => RoutinePreset.fromJson(future),
      throwsA(isA<FormatException>()),
    );
  });

  test('CRUD persists locally across new store instances', () async {
    await RoutineStore().save(sample());
    expect((await RoutineStore().load()).single.name, 'Hít đất buổi sáng');

    await RoutineStore().save(sample(name: 'Sức mạnh', sets: 5));
    final edited = (await RoutineStore().load()).single;
    expect(edited.name, 'Sức mạnh');
    expect(edited.targetSets, 5);

    await RoutineStore().delete('morning');
    expect(await RoutineStore().load(), isEmpty);
  });

  test('snapshot is independent from later preset edits', () {
    final original = sample();
    final snapshot = original.toSnapshot();
    final edited = original.copyWith(name: 'Tên mới', targetSets: 5);

    expect(snapshot.name, 'Hít đất buổi sáng');
    expect(snapshot.targetSets, 3);
    expect(edited.name, 'Tên mới');
    expect(edited.targetSets, 5);
  });
}
