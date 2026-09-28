import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/features/workout/data/workout_record.dart';

void main() {
  test('WorkoutRecord round trip và AI payload không chứa dữ liệu hình ảnh', () {
    final record = WorkoutRecord(
      id: '1', exerciseId: 'push_up', exerciseName: 'Hít đất',
      startedAt: DateTime(2026, 9, 5), durationSeconds: 42,
      reps: 12, sets: 1, targetReps: 10,
      poseFrames: 100, readyFrames: 80, lostFrames: 5,
    );
    final copy = WorkoutRecord.fromJson(record.toJson());
    expect(copy.reps, 12);
    expect(copy.goalReached, isTrue);
    expect(copy.placementScore, 80);
    expect(copy.toAiPayload().keys, isNot(contains('video')));
    expect(copy.toAiPayload().keys, isNot(contains('landmarks')));
  });
}
