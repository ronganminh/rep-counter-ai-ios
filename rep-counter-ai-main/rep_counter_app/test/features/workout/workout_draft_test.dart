import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/exercise.dart';
import 'package:rep_counter_app/features/workout/application/workout_controller.dart';
import 'package:rep_counter_app/features/workout/application/workout_draft_recorder.dart';
import 'package:rep_counter_app/features/workout/data/workout_draft_store.dart';
import 'package:rep_counter_app/features/workout/data/workout_history_store.dart';
import 'package:rep_counter_app/features/workout/data/workout_record.dart';
import 'package:rep_counter_app/features/workout/domain/workout_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'workout_controller_test.dart'
    show FakeClock, observation, frame, calibration;

/// F-4: drafts are recorded from the read-only UI state, written only when
/// the count changes, and cleared when the workout is saved or discarded.
void main() {
  late FakeClock clock;
  late WorkoutController controller;
  late WorkoutDraftRecorder recorder;
  late DateTime now;
  final store = WorkoutDraftStore();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    clock = FakeClock();
    now = DateTime(2026, 10, 23, 9);
    controller = WorkoutController(
        requireCountdown: false,
        profile: pushUp,
        targetReps: 20,
        clock: clock,
        now: () => now,
        saveRecord: WorkoutHistoryStore().save);
    recorder = WorkoutDraftRecorder(controller, now: () => now);
    controller.cameraStarted();
    frame(controller);
  });
  tearDown(() {
    recorder.dispose();
    controller.dispose();
  });

  void rep(int second) {
    clock.elapsed = Duration(seconds: second);
    controller.acceptRep(observation(second), clock.elapsed);
  }

  test('no draft before the first counted rep', () async {
    for (var i = 0; i < 30; i++) {
      clock.elapsed = Duration(seconds: i);
      frame(controller);
    }
    await recorder.flush();
    expect(await store.load(), isNull);
    expect(recorder.writes, 0);
  });

  test('writes once per counted rep, not per frame', () async {
    rep(2);
    for (var i = 0; i < 50; i++) {
      frame(controller);
    }
    rep(4);
    rep(6);
    for (var i = 0; i < 50; i++) {
      frame(controller);
    }
    await recorder.flush();
    expect(recorder.writes, 3);
    final draft = (await store.load())!;
    expect(draft.reps, 3);
    expect(draft.exerciseId, 'push_up');
    expect(draft.targetReps, 20);
    expect(draft.mode, WorkoutMode.targetReps);
    expect(draft.durationSeconds, 6);
    expect(draft.startedAt, now.subtract(const Duration(seconds: 2)));
  });

  test('a saved workout clears the draft', () async {
    rep(2);
    rep(4);
    await recorder.flush();
    expect(await store.load(), isNotNull);
    await controller.finish(calibration: calibration);
    await recorder.flush();
    expect(await store.load(), isNull);
    expect((await WorkoutHistoryStore().load()).single.reps, 2);
  });

  test('a discarded workout clears the draft', () async {
    rep(2);
    await recorder.flush();
    controller.abort();
    await recorder.flush();
    expect(await store.load(), isNull);
  });

  group('recovery', () {
    WorkoutDraft draft({int reps = 14, DateTime? updated}) => WorkoutDraft(
          startedAt: DateTime(2026, 10, 23, 8),
          updatedAt: updated ?? DateTime(2026, 10, 23, 8, 5),
          exerciseId: 'push_up',
          exerciseName: 'Hít đất',
          reps: reps,
          sets: 2,
          durationSeconds: 168,
          mode: WorkoutMode.targetReps,
          targetReps: 20,
        );

    test('the window is 12 hours', () {
      final d = draft();
      expect(d.isExpired(d.updatedAt.add(const Duration(hours: 12))), isFalse);
      expect(
          d.isExpired(d.updatedAt.add(const Duration(hours: 12, minutes: 1))),
          isTrue);
    });

    test('save as partial writes exactly one partial record', () async {
      final d = draft();
      await store.save(d);
      expect(await store.pendingRecovery(), isNotNull);
      final record = await store.savePartial(d);
      // A second tap (or a retry) must not create another record.
      await WorkoutHistoryStore().save(d.toPartialRecord());
      final history = await WorkoutHistoryStore().load();
      expect(history, hasLength(1));
      expect(history.single.id, record.id);
      expect(history.single.partial, isTrue);
      expect(history.single.reps, 14);
      expect(history.single.quality, isNull);
      expect(await store.load(), isNull);
      expect(
          jsonDecode(jsonEncode(history.single.toJson()))['partial'], isTrue);
    });

    test('a draft whose workout was already saved is not offered again',
        () async {
      final d = draft();
      await store.save(d);
      await WorkoutHistoryStore().save(WorkoutRecord(
          id: 'finished',
          exerciseId: 'push_up',
          exerciseName: 'Hít đất',
          startedAt: d.startedAt.add(const Duration(seconds: 3)),
          durationSeconds: 200,
          reps: 16,
          sets: 2,
          targetReps: 20,
          poseFrames: 10,
          readyFrames: 10,
          lostFrames: 0));
      expect(await store.pendingRecovery(), isNull);
      expect(await store.load(), isNull, reason: 'stale draft cleared');
      expect(await WorkoutHistoryStore().load(), hasLength(1));
    });

    test('an unreadable draft is ignored, not a crash', () async {
      SharedPreferences.setMockInitialValues({WorkoutDraftStore.key: '{oops'});
      expect(await store.pendingRecovery(), isNull);
    });

    test('expired drafts are still offered (never silently discarded)',
        () async {
      final d = draft(updated: DateTime(2026, 10, 20));
      await store.save(d);
      final pending = await store.pendingRecovery();
      expect(pending, isNotNull);
      expect(pending!.isExpired(DateTime(2026, 10, 23)), isTrue);
    });
  });
}
