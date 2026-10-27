import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/exercise.dart';
import 'package:rep_counter_app/features/routine/domain/routine_preset.dart';
import 'package:rep_counter_app/features/workout/application/workout_controller.dart';
import 'package:rep_counter_app/features/workout/application/workout_draft_recorder.dart';
import 'package:rep_counter_app/features/workout/application/workout_ui_state.dart';
import 'package:rep_counter_app/features/workout/data/workout_draft_store.dart';
import 'package:rep_counter_app/features/workout/data/workout_history_store.dart';
import 'package:rep_counter_app/features/workout/data/workout_record.dart';
import 'package:rep_counter_app/features/workout/domain/rep_metric.dart';
import 'package:rep_counter_app/features/workout/domain/workout_mode.dart';
import 'package:rep_counter_app/rep_counter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'workout_controller_test.dart'
    show FakeClock, observation, frame, calibration;

/// W-5 / decision B: resuming an unfinished workout continues from the saved
/// count. The rep engine is not changed or seeded; the controller adds the
/// saved reps, sets and time to what a fresh engine counts.

final _start = DateTime(2026, 10, 26, 7, 30);

WorkoutDraft _draft({int reps = 14, int sets = 2, int? target = 20}) =>
    WorkoutDraft(
      startedAt: _start,
      updatedAt: _start.add(const Duration(minutes: 3)),
      exerciseId: pushUp.id,
      exerciseName: pushUp.name,
      reps: reps,
      sets: sets,
      durationSeconds: 168,
      mode: target == null ? WorkoutMode.free : WorkoutMode.targetReps,
      targetReps: target,
    );

WorkoutResumeSeed _seed(WorkoutDraft d) => WorkoutResumeSeed(
      recordId: d.recordId,
      startedAt: d.startedAt,
      reps: d.reps,
      sets: d.sets,
      elapsed: Duration(seconds: d.durationSeconds),
    );

void main() {
  late FakeClock clock;
  late DateTime now;
  late List<WorkoutRecord> saved;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    clock = FakeClock();
    now = DateTime(2026, 10, 26, 9);
    saved = [];
  });

  WorkoutController resumed(WorkoutDraft d,
          {Future<void> Function(WorkoutRecord)? save}) =>
      WorkoutController(
          requireCountdown: false,
          profile: pushUp,
          targetReps: d.targetReps,
          clock: clock,
          now: () => now,
          resume: _seed(d),
          saveRecord: save ??
              (r) async {
                saved.add(r);
              });

  test('HUD starts at the saved count, sets and time', () {
    final c = resumed(_draft());
    addTearDown(c.dispose);
    expect(c.state.reps, 14);
    expect(c.state.completedSets, 2);
    expect(c.state.elapsed, const Duration(seconds: 168));
    expect(c.state.goalProgress, closeTo(14 / 20, 1e-9));
    c.cameraStarted();
    frame(c);
    expect(c.state.phase, WorkoutUiPhase.active,
        reason: 'counted reps exist, so this is not a fresh "ready" screen');
  });

  test('reps only grow from N; goal fires once at the target; one record',
      () async {
    final d = _draft();
    final c = resumed(d);
    addTearDown(c.dispose);
    c.cameraStarted();
    frame(c);
    final seen = <int>[c.state.reps];
    final reached = <bool>[];
    for (var i = 1; i <= 8; i++) {
      clock.advance(2);
      reached.add(c.acceptRep(observation(i * 2), clock.elapsed));
      seen.add(c.state.reps);
    }
    expect(seen, [for (var r = 14; r <= 22; r++) r]);
    expect(reached, [false, false, false, false, false, true, false, false],
        reason: 'the 6th new rep is the 20th in total');

    final record = await c.finish(calibration: calibration);
    expect(saved, [record]);
    expect(record.id, d.recordId, reason: 'same id as Save as partial');
    expect(record.startedAt, d.startedAt);
    expect(record.reps, 22);
    expect(record.reps, c.state.reps, reason: 'HUD and record agree');
    expect(record.sets, 3, reason: '2 earlier sets + 1 after resuming');
    expect(record.durationSeconds, 168 + 16);
    expect(record.targetReps, 20);
    expect(record.mode, WorkoutMode.targetReps);
    expect(record.goalReached, isTrue);
    expect(record.partial, isFalse);
    expect(record.repDetails, hasLength(8),
        reason: 'form data exists only for reps counted after resuming');
  });

  test('a saved count already at the goal does not fire the goal again', () {
    final c = resumed(_draft(reps: 20, target: 20));
    addTearDown(c.dispose);
    c.cameraStarted();
    frame(c);
    expect(c.state.goalReachedOnce, isTrue);
    clock.advance(2);
    expect(c.acceptRep(observation(2), clock.elapsed), isFalse);
    expect(c.state.reps, 21);
  });

  test('saving with no new reps keeps the saved count under the same id',
      () async {
    final d = _draft(target: null);
    final c = resumed(d);
    addTearDown(c.dispose);
    final record = await c.finish(calibration: calibration);
    expect(record.id, d.recordId);
    expect(record.reps, 14);
    expect(record.sets, 2);
    expect(record.mode, WorkoutMode.free);
    expect(record.durationSeconds, 168);
  });

  test('resume is refused for timed challenges and routines', () {
    expect(
        () => WorkoutController(
            profile: pushUp,
            timedChallenge: const TimedChallengeConfig(durationSeconds: 60),
            resume: _seed(_draft(target: null))),
        throwsA(isA<AssertionError>()));
    expect(_draft().copyWithMode(WorkoutMode.timed).canResume, isFalse);
    final routineDraft = WorkoutDraft.fromJson({
      ..._draft(target: null).toJson(),
      'routine': true,
    })!;
    expect(routineDraft.routine, isTrue);
    expect(routineDraft.canResume, isFalse);
    expect(_draft().canResume, isTrue);
    expect(_draft(target: null).canResume, isTrue);
  });

  group('draft and history', () {
    test('the resumed draft keeps its id and grows; finishing clears it',
        () async {
      final d = _draft();
      final store = WorkoutDraftStore();
      await store.save(d);
      final c = resumed(d, save: WorkoutHistoryStore().save);
      final recorder =
          WorkoutDraftRecorder(c, now: () => now, startedAt: d.startedAt);
      addTearDown(() {
        recorder.dispose();
        c.dispose();
      });
      c.cameraStarted();
      frame(c);
      for (var i = 1; i <= 3; i++) {
        clock.advance(2);
        c.acceptRep(observation(i * 2), clock.elapsed);
      }
      await recorder.flush();
      final draft = (await store.load())!;
      expect(draft.recordId, d.recordId);
      expect(draft.reps, 17);
      expect(draft.sets, 3);
      expect(draft.durationSeconds, 168 + 6);

      await c.finish(calibration: calibration);
      await recorder.flush();
      expect(await store.load(), isNull);
      final history = await WorkoutHistoryStore().load();
      expect(history.map((r) => (r.id, r.reps)), [(d.recordId, 17)]);
    });

    test('a routine draft is marked and is not offered for resume', () async {
      final c = WorkoutController(
          requireCountdown: false,
          profile: pushUp,
          routine: const RoutineSnapshot(
            id: 'r',
            name: 'r',
            exerciseId: 'push_up',
            targetReps: 5,
            targetSets: 2,
            restSeconds: 5,
            voiceCoachEnabled: false,
          ),
          clock: clock,
          now: () => now,
          saveRecord: (r) async {});
      final recorder = WorkoutDraftRecorder(c, now: () => now);
      addTearDown(() {
        recorder.dispose();
        c.dispose();
      });
      c.cameraStarted();
      frame(c);
      clock.advance(2);
      c.acceptRep(observation(2), clock.elapsed);
      await recorder.flush();
      final draft = (await WorkoutDraftStore().load())!;
      expect(draft.routine, isTrue);
      expect(draft.mode, WorkoutMode.free);
      expect(draft.canResume, isFalse);
    });

    test('a second crash after resuming still yields one record', () async {
      final d = _draft();
      final store = WorkoutDraftStore();
      final c = resumed(d, save: WorkoutHistoryStore().save);
      final recorder =
          WorkoutDraftRecorder(c, now: () => now, startedAt: d.startedAt);
      addTearDown(() {
        recorder.dispose();
        c.dispose();
      });
      c.cameraStarted();
      frame(c);
      clock.advance(2);
      c.acceptRep(observation(2), clock.elapsed);
      await recorder.flush();
      // The app closes again: only the draft is left. Saving it as partial
      // and a stale finished copy share one id, so history keeps one row.
      final again = (await store.load())!;
      await store.savePartial(again);
      await WorkoutHistoryStore().save(again.toPartialRecord());
      final history = await WorkoutHistoryStore().load();
      expect(history, hasLength(1));
      expect(history.single.id, d.recordId);
      expect(history.single.reps, 15);
      expect(await store.pendingRecovery(), isNull);
    });
  });

  test('fixture replay: resume at N, the real video counts M → N + M', () {
    // Same signal path as the pull-up replay in pull_up_test.dart, on the
    // unchanged RepCounter; each counted rep goes to a resumed controller.
    final d =
        jsonDecode(File('test/fixtures/pull_up_front.json').readAsStringSync())
            as Map<String, dynamic>;
    final tMs = (d['t_ms'] as List).cast<int>();
    double? n(Object? v) => v == null ? null : (v as num).toDouble();
    final left = (d['left'] as List).map(n).toList();
    final right = (d['right'] as List).map(n).toList();
    final gate = (d['gate'] as List).cast<bool>();
    final expectedM = (d['expected_rep_ms'] as List).length;

    const n0 = 9;
    final draft = WorkoutDraft(
      startedAt: _start,
      updatedAt: _start,
      exerciseId: pullUp.id,
      exerciseName: pullUp.name,
      reps: n0,
      sets: 1,
      durationSeconds: 95,
      mode: WorkoutMode.free,
    );
    final c = WorkoutController(
        requireCountdown: false,
        profile: pullUp,
        clock: clock,
        now: () => now,
        resume: _seed(draft),
        saveRecord: (r) async => saved.add(r));
    addTearDown(c.dispose);
    c.cameraStarted();
    frame(c);

    final counter = RepCounter(
      hi: pullUp.repHi,
      lo: pullUp.repLo,
      minAmplitude: pullUp.minAmplitude,
      minPeriod: pullUp.minPeriod,
      startFromTop: pullUp.startFromTop,
    );
    final smooth = RollingMean(pullUp.smoothWindow);
    final hud = <int>[c.state.reps];
    for (var i = 0; i < tMs.length; i++) {
      final at = Duration(milliseconds: tMs[i]);
      clock.elapsed = at;
      final vals = [left[i], right[i]].whereType<double>().toList();
      if (!gate[i] || vals.isEmpty) {
        counter.onSignalLost();
        if (!gate[i]) smooth.reset();
        continue;
      }
      final v = smooth.add(vals.reduce((a, b) => a + b) / vals.length);
      if (counter.update(v, at) != null) {
        c.acceptRep(
            RepObservation(
                startedAt: at - const Duration(seconds: 2),
                bottomAt: at - const Duration(seconds: 1),
                completedAt: at,
                bottomAngle: 70,
                topAngle: 160,
                sampleCount: 10),
            at);
        hud.add(c.state.reps);
      }
    }

    expect(counter.count, expectedM, reason: 'engine count is unchanged');
    expect(hud, [for (var r = n0; r <= n0 + expectedM; r++) r],
        reason: 'HUD starts at N and rises by one per counted rep');
    expect(c.state.reps, n0 + expectedM);
  });

  test('fixture replay: the saved record matches the HUD', () async {
    final c = resumed(_draft(target: null));
    addTearDown(c.dispose);
    c.cameraStarted();
    frame(c);
    final v = jsonDecode(File('test/rep_vector.json').readAsStringSync())
        as Map<String, dynamic>;
    final sr = (v['sampleRateHz'] as num).toDouble();
    final signal = (v['signal'] as List)
        .map((e) => e == null ? double.nan : (e as num).toDouble())
        .toList();
    final m = (v['expectedRepFrames'] as List).length;
    final counter = RepCounter(
      hi: (v['hi'] as num).toDouble(),
      lo: (v['lo'] as num).toDouble(),
      minAmplitude: (v['minAmp'] as num).toDouble(),
      minPeriod: Duration(milliseconds: v['minPeriodMs'] as int),
    );
    for (var i = 0; i < signal.length; i++) {
      final at = Duration(microseconds: (i / sr * 1e6).round());
      clock.elapsed = at;
      if (counter.update(signal[i], at) != null) {
        c.acceptRep(observation(at.inSeconds + 2), at);
      }
    }
    final record = await c.finish(calibration: calibration);
    expect(record.reps, 14 + m);
    expect(record.reps, c.state.reps);
    expect(saved.single.id, _draft().recordId);
  });
}

extension on WorkoutDraft {
  WorkoutDraft copyWithMode(WorkoutMode mode) => WorkoutDraft(
        startedAt: startedAt,
        updatedAt: updatedAt,
        exerciseId: exerciseId,
        exerciseName: exerciseName,
        reps: reps,
        sets: sets,
        durationSeconds: durationSeconds,
        mode: mode,
        targetReps: targetReps,
      );
}
