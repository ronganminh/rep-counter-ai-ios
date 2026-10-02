import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rep_counter_app/features/achievements/achievement.dart';
import 'package:rep_counter_app/features/achievements/achievement_service.dart';
import 'package:rep_counter_app/features/workout/data/workout_history_store.dart';
import 'package:rep_counter_app/features/workout/data/workout_record.dart';
import 'package:rep_counter_app/features/workout/domain/workout_mode.dart';

WorkoutRecord record({
  required String id,
  required DateTime at,
  int reps = 10,
  WorkoutMode mode = WorkoutMode.free,
  int? challengeSeconds,
  int? durationSeconds,
}) =>
    WorkoutRecord(
      id: id,
      exerciseId: 'push_up',
      exerciseName: 'Hít đất',
      startedAt: at,
      durationSeconds: durationSeconds ??
          (mode == WorkoutMode.timed ? challengeSeconds ?? 60 : 60),
      reps: reps,
      sets: 1,
      targetReps: null,
      mode: mode,
      challengeSeconds:
          mode == WorkoutMode.timed ? challengeSeconds ?? 60 : null,
      poseFrames: 100,
      readyFrames: 90,
      lostFrames: 10,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('claim is post-save only and idempotent', () async {
    final history = WorkoutHistoryStore();
    final service = AchievementService(history: history);
    final current = record(
      id: 'first',
      at: DateTime(2026, 10, 2),
      reps: 12,
    );

    expect(
      await service.claimAfterResult(current, now: DateTime(2026, 10, 2)),
      isEmpty,
      reason: 'an active/unsaved workout must never earn a badge',
    );
    expect(await service.earned(), isEmpty);

    await history.save(current);
    final first =
        await service.claimAfterResult(current, now: DateTime(2026, 10, 2));
    expect(first, contains(AchievementId.firstWorkout));
    expect(first, contains(AchievementId.newPersonalRecord));

    expect(
      await service.claimAfterResult(current, now: DateTime(2026, 10, 2)),
      isEmpty,
      reason: 'the same result cannot award the same badge twice',
    );
  });

  test('finite local rules cover total reps streak challenge and 10 workouts',
      () async {
    final history = WorkoutHistoryStore();
    final service = AchievementService(history: history);
    final now = DateTime(2026, 10, 8);

    for (var i = 0; i < 9; i++) {
      await history.save(record(
        id: 'r$i',
        at: now.subtract(Duration(days: i > 6 ? 6 : i)),
        reps: 10,
      ));
    }
    final current = record(
      id: 'timed',
      at: now,
      reps: 12,
      mode: WorkoutMode.timed,
      challengeSeconds: 60,
    );
    await history.save(current);

    final earned = await service.claimAfterResult(current, now: now);
    expect(earned, contains(AchievementId.totalReps100));
    expect(earned, contains(AchievementId.streak7));
    expect(earned, contains(AchievementId.firstTimeChallenge));
    expect(earned, contains(AchievementId.workouts10));
    expect(earned, contains(AchievementId.newPersonalRecord));
  });

  test('target-reps workout does not invent a personal-record category', () {
    final current = WorkoutRecord(
      id: 'target',
      exerciseId: 'push_up',
      exerciseName: 'Hít đất',
      startedAt: DateTime(2026, 10, 2),
      durationSeconds: 60,
      reps: 20,
      sets: 1,
      targetReps: 20,
      mode: WorkoutMode.targetReps,
      poseFrames: 100,
      readyFrames: 90,
      lostFrames: 10,
    );

    final qualifying = AchievementService.qualifyingAchievements(
      records: [current],
      current: current,
      now: DateTime(2026, 10, 2),
    );
    expect(qualifying, isNot(contains(AchievementId.newPersonalRecord)));
  });
}
