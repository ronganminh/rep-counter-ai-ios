/// Test domain buổi tập. Dart thuần — không cần Flutter binding, không cần camera.
library;

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/features/workout/domain/quality_thresholds.dart';
import 'package:rep_counter_app/features/workout/domain/rep_metric.dart';
import 'package:rep_counter_app/features/workout/domain/rep_quality_analyzer.dart';
import 'package:rep_counter_app/features/workout/domain/rep_tracker.dart';
import 'package:rep_counter_app/features/workout/domain/set_metric.dart';
import 'package:rep_counter_app/features/workout/domain/workout_aggregator.dart';
import 'package:rep_counter_app/features/workout/domain/workout_state.dart';
import 'package:rep_counter_app/features/workout/domain/workout_summary.dart';
import 'package:rep_counter_app/rep_counter.dart';

Duration ms(int v) => Duration(milliseconds: v);

RepObservation obs({
  int startMs = 0,
  int bottomMs = 500,
  int endMs = 1200,
  double bottom = 80,
  double top = 170,
  double? left,
  double? right,
  double torsoMax = 0,
  double torsoFrac = 0,
  double conf = 0.9,
}) =>
    RepObservation(
      startedAt: ms(startMs),
      bottomAt: ms(bottomMs),
      completedAt: ms(endMs),
      bottomAngle: bottom,
      topAngle: top,
      leftBottomAngle: left,
      rightBottomAngle: right,
      maxTorsoDeviation: torsoMax,
      torsoDeviationFraction: torsoFrac,
      averagePoseConfidence: conf,
      sampleCount: 20,
    );

RepMetric rep(int i, {int atMs = 0, double amp = 90, double bottom = 80,
    double? left, double? right, Set<RepQualityFlag> flags = const {}}) =>
    RepMetric(
      index: i,
      setIndex: 1,
      flags: flags,
      observation: obs(
        startMs: atMs,
        bottomMs: atMs + 500,
        endMs: atMs + 1200,
        bottom: bottom,
        top: bottom + amp,
        left: left,
        right: right,
      ),
    );

void main() {
  group('RepObservation', () {
    test('biên độ và thời lượng', () {
      final o = obs(bottom: 70, top: 165, startMs: 100, endMs: 1600);
      expect(o.amplitude, closeTo(95, 1e-9));
      expect(o.duration, ms(1500));
    });

    test('thiếu một tay thì chênh lệch là 0 nhưng hasBothArms = false', () {
      final o = obs(left: 80, right: null);
      expect(o.leftRightDifference, 0);
      expect(o.hasBothArms, isFalse);
    });

    test('đủ hai tay thì tính được chênh lệch', () {
      final o = obs(left: 75, right: 95);
      expect(o.leftRightDifference, closeTo(20, 1e-9));
      expect(o.hasBothArms, isTrue);
    });
  });

  group('RepQualityAnalyzer', () {
    const a = RepQualityAnalyzer();

    test('rep bình thường không có cờ nào', () {
      expect(a.analyze(obs()), isEmpty);
    });

    test('quá nhanh', () {
      expect(a.analyze(obs(startMs: 0, endMs: 500)), contains(RepQualityFlag.tooFast));
    });

    test('quá chậm', () {
      expect(a.analyze(obs(startMs: 0, endMs: 6000)), contains(RepQualityFlag.tooSlow));
    });

    test('hai bên lệch', () {
      expect(a.analyze(obs(left: 70, right: 100)),
          contains(RepQualityFlag.leftRightUneven));
    });

    test('thiếu một tay thì KHÔNG kết luận lệch', () {
      expect(a.analyze(obs(left: 70, right: null)),
          isNot(contains(RepQualityFlag.leftRightUneven)));
    });

    test('pose kém tin cậy', () {
      expect(a.analyze(obs(conf: 0.4)), contains(RepQualityFlag.poseUnreliable));
    });

    test('lệch thân thoáng qua không bị gắn cờ', () {
      expect(a.analyze(obs(torsoMax: 40, torsoFrac: 0.05)),
          isNot(contains(RepQualityFlag.bodyAlignmentLost)));
    });

    test('lệch thân kéo dài mới bị gắn cờ', () {
      expect(a.analyze(obs(torsoMax: 40, torsoFrac: 0.5)),
          contains(RepQualityFlag.bodyAlignmentLost));
    });

    test('không có calibration thì không kết luận nông/không khoá khớp', () {
      final f = a.analyze(obs(bottom: 130, top: 150));
      expect(f, isNot(contains(RepQualityFlag.shallow)));
      expect(f, isNot(contains(RepQualityFlag.incompleteLockout)));
    });

    test('có calibration thì phát hiện rep nông', () {
      const cal = CalibrationSnapshot(
        repHi: 150, repLo: 100, minAmplitude: 40,
        referenceAmplitude: 90, referenceTopAngle: 170,
        source: CalibrationSource.userCalibration,
      );
      // biên độ 20 << 90 * 0.75
      expect(a.analyze(obs(bottom: 130, top: 150), calibration: cal),
          contains(RepQualityFlag.shallow));
    });

    test('có calibration thì phát hiện không duỗi hết', () {
      const cal = CalibrationSnapshot(
        repHi: 150, repLo: 100, minAmplitude: 40,
        referenceAmplitude: 90, referenceTopAngle: 170,
      );
      // top 130 < 170 * 0.85 = 144.5
      expect(a.analyze(obs(bottom: 40, top: 130), calibration: cal),
          contains(RepQualityFlag.incompleteLockout));
    });
  });

  group('SetMetric', () {
    test('set rỗng không làm vỡ phép tính', () {
      const s = SetMetric(index: 1, reps: []);
      expect(s.averageRepSeconds, 0);
      expect(s.averageAmplitude, 0);
      expect(s.cadenceVariation, 0);
      expect(s.hasCadence, isFalse);
    });

    test('set một rep: cadenceVariation = 0 nhưng hasCadence = false', () {
      final s = SetMetric(index: 1, reps: [rep(1)]);
      expect(s.cadenceVariation, 0);
      expect(s.hasCadence, isFalse,
          reason: 'một rep không đo được nhịp — khác với nhịp hoàn hảo');
    });

    test('nhịp đều -> biến thiên gần 0', () {
      final s = SetMetric(index: 1, reps: [
        rep(1, atMs: 0),
        rep(2, atMs: 1500),
        rep(3, atMs: 3000),
        rep(4, atMs: 4500),
      ]);
      expect(s.hasCadence, isTrue);
      expect(s.cadenceVariation, lessThan(0.01));
    });

    test('nhịp thất thường -> biến thiên lớn', () {
      final s = SetMetric(index: 1, reps: [
        rep(1, atMs: 0),
        rep(2, atMs: 1000),
        rep(3, atMs: 5000),
        rep(4, atMs: 6000),
      ]);
      expect(s.cadenceVariation, greaterThan(0.3));
    });
  });

  group('WorkoutAggregator gom set', () {
    const agg = WorkoutAggregator();

    test('rep liên tiếp thành một set', () {
      final sets = agg.groupIntoSets([
        rep(1, atMs: 0),
        rep(2, atMs: 1500),
        rep(3, atMs: 3000),
      ]);
      expect(sets.length, 1);
      expect(sets.first.reps.length, 3);
    });

    test('nghỉ dài tách thành hai set và đánh số lại', () {
      final sets = agg.groupIntoSets([
        rep(1, atMs: 0),
        rep(2, atMs: 1500),
        rep(3, atMs: 30000),
        rep(4, atMs: 31500),
      ]);
      expect(sets.length, 2);
      expect(sets[0].index, 1);
      expect(sets[1].index, 2);
      expect(sets[1].reps.every((r) => r.setIndex == 2), isTrue);
    });

    test('set grouping không loại rep đã được xác nhận', () {
      final sets = agg.groupIntoSets([
        rep(1, atMs: 0),
        rep(2, atMs: 1500),
        rep(3, atMs: 60000), // set một rep vẫn là rep hợp lệ
      ]);
      expect(sets.length, 2);
      expect(sets.expand((s) => s.reps).length, 3);
      expect(sets.last.reps.single.index, 3);
    });

    test('đặt minRepsPerSet = 1 thì giữ cả nhịp đơn độc', () {
      const keepAll = WorkoutAggregator(minRepsPerSet: 1);
      final sets = keepAll.groupIntoSets([rep(1, atMs: 0), rep(2, atMs: 60000)]);
      expect(sets.length, 2);
    });

    test('danh sách rỗng trả về rỗng', () {
      expect(agg.groupIntoSets([]), isEmpty);
    });
  });

  group('WorkoutAggregator số liệu tổng', () {
    const agg = WorkoutAggregator();

    test('biên độ không giảm -> 0%', () {
      final reps = List.generate(8, (i) => rep(i + 1, atMs: i * 1500, amp: 90));
      expect(agg.amplitudeDropPercent(reps), 0);
    });

    test('biên độ giảm cuối buổi được phát hiện', () {
      final reps = [
        for (var i = 0; i < 4; i++) rep(i + 1, atMs: i * 1500, amp: 100),
        for (var i = 4; i < 8; i++) rep(i + 1, atMs: i * 1500, amp: 80),
      ];
      expect(agg.amplitudeDropPercent(reps), closeTo(20, 0.01));
    });

    test('quá ít rep thì không kết luận biên độ giảm', () {
      expect(agg.amplitudeDropPercent([rep(1), rep(2)]), 0);
    });

    test('chênh hai tay chỉ tính trên rep đo được cả hai', () {
      final reps = [
        rep(1, atMs: 0, amp: 90, bottom: 80, left: 80, right: 98),
        rep(2, atMs: 1500, amp: 90, bottom: 80), // thiếu tay -> bỏ qua
      ];
      // chênh 18 độ trên biên độ 90 -> 20%
      expect(agg.leftRightDifferencePercent(reps), closeTo(20, 0.01));
    });

    test('không rep nào đo được hai tay -> 0', () {
      expect(agg.leftRightDifferencePercent([rep(1), rep(2)]), 0);
    });
  });

  group('QualityScore', () {
    const agg = WorkoutAggregator();
    const perfectPose = PoseQualityStats(
        totalProcessedFrames: 1000, countableFrames: 1000, poseLostFrames: 0);

    test('không có rep -> điểm 0 và hasEnoughData = false', () {
      final s = agg.score(sets: const [], poseStats: perfectPose);
      expect(s.overall, 0);
      expect(s.hasEnoughData, isFalse);
    });

    test('buổi tập hoàn hảo tiệm cận 100', () {
      final reps = [
        for (var i = 0; i < 10; i++)
          rep(i + 1, atMs: i * 1500, amp: 90, bottom: 80, left: 80, right: 80)
      ];
      final sets = agg.groupIntoSets(reps);
      final s = agg.score(sets: sets, poseStats: perfectPose);
      expect(s.rangeOfMotion, 100);
      expect(s.cadenceConsistency, 100);
      expect(s.leftRightBalance, 100);
      expect(s.poseAlignment, 100);
      expect(s.overall, 100);
      expect(s.hasEnoughData, isTrue);
    });

    test('mất pose nhiều kéo điểm căn chỉnh xuống', () {
      final reps = [
        for (var i = 0; i < 10; i++) rep(i + 1, atMs: i * 1500, amp: 90)
      ];
      final s = agg.score(
        sets: agg.groupIntoSets(reps),
        poseStats: const PoseQualityStats(
            totalProcessedFrames: 1000, countableFrames: 700, poseLostFrames: 300),
      );
      expect(s.poseAlignment, 40); // 100 - 30% * 2
      expect(s.overall, lessThan(100));
    });

    test('hai tay lệch kéo điểm cân bằng xuống', () {
      final reps = [
        for (var i = 0; i < 10; i++)
          rep(i + 1, atMs: i * 1500, amp: 90, bottom: 80, left: 75, right: 95)
      ];
      final s = agg.score(sets: agg.groupIntoSets(reps), poseStats: perfectPose);
      // chênh 20/90 = 22.2% -> 100 - 22.2*4 ≈ 11
      expect(s.leftRightBalance, lessThan(20));
    });

    test('điểm luôn nằm trong 0..100', () {
      final reps = [
        for (var i = 0; i < 6; i++)
          rep(i + 1, atMs: i * 1500, amp: 5, bottom: 80, left: 20, right: 160)
      ];
      final s = agg.score(
        sets: agg.groupIntoSets(reps),
        poseStats: const PoseQualityStats(
            totalProcessedFrames: 100, countableFrames: 10, poseLostFrames: 90),
      );
      for (final v in [
        s.rangeOfMotion,
        s.cadenceConsistency,
        s.leftRightBalance,
        s.poseAlignment,
        s.overall
      ]) {
        expect(v, inInclusiveRange(0, 100));
      }
    });

    test('ít rep -> hasEnoughData = false', () {
      final reps = [rep(1, atMs: 0), rep(2, atMs: 1500)];
      final s = agg.score(sets: agg.groupIntoSets(reps), poseStats: perfectPose);
      expect(s.hasEnoughData, isFalse);
    });
  });

  group('WorkoutSummary', () {
    const agg = WorkoutAggregator();

    WorkoutSummary sample() => agg.build(
          id: 'w1',
          exerciseId: 'push_up',
          startedAt: DateTime.utc(2026, 9, 1, 10),
          endedAt: DateTime.utc(2026, 9, 1, 10, 5),
          reps: [
            for (var i = 0; i < 6; i++)
              rep(i + 1, atMs: i * 1500, amp: 90, bottom: 80, left: 82, right: 78)
          ],
          poseStats: const PoseQualityStats(
              totalProcessedFrames: 900, countableFrames: 850, poseLostFrames: 50),
          calibration: const CalibrationSnapshot(
              repHi: 150, repLo: 100, minAmplitude: 40),
        );

    test('tổng hợp đúng số rep và set', () {
      final w = sample();
      expect(w.totalReps, 6);
      expect(w.sets.length, 1);
      expect(w.averageAmplitude, closeTo(90, 1e-6));
    });

    test('xác định: chạy hai lần cho kết quả giống hệt', () {
      expect(sample().toJson().toString(), sample().toJson().toString());
    });

    test('vòng JSON giữ nguyên dữ liệu', () {
      final a = sample();
      final b = WorkoutSummary.fromJson(a.toJson());
      expect(b.id, a.id);
      expect(b.totalReps, a.totalReps);
      expect(b.sets.length, a.sets.length);
      expect(b.sets.first.reps.length, a.sets.first.reps.length);
      expect(b.score.overall, a.score.overall);
      expect(b.poseStats.poseLostFrames, a.poseStats.poseLostFrames);
      expect(b.startedAt.toUtc(), a.startedAt.toUtc());
    });

    test('schema version mới hơn thì báo lỗi rõ ràng thay vì đọc bừa', () {
      final j = sample().toJson()..['schema_version'] = 99;
      expect(() => WorkoutSummary.fromJson(j), throwsFormatException);
    });

    test('payload AI nhỏ, không có landmark', () {
      final p = sample().toAiPayload();
      final s = p.toString();
      expect(s.length, lessThan(2048), reason: '§9.2: dưới 2 KB');
      expect(s.contains('landmark'), isFalse);
      expect(s.contains('frame'), isFalse);
      expect((p['workout'] as Map)['total_reps'], 6);
    });
  });

  group('RepTracker', () {
    /// Tín hiệu hình sin: mỗi chu kỳ là một rep.
    List<PoseSample> wave({int reps = 3, int perRep = 30, double lo = 70, double hi = 170}) {
      final out = <PoseSample>[];
      final mid = (lo + hi) / 2, amp = (hi - lo) / 2;
      for (var i = 0; i < reps * perRep; i++) {
        // bắt đầu ở đỉnh rồi đi xuống
        final phase = i / perRep * 2 * math.pi;
        final v = mid + amp * math.cos(phase);
        out.add(PoseSample(
          at: ms((i * 1000 / perRep).round()),
          signal: v,
          leftAngle: v,
          rightAngle: v,
          torsoDeviationDeg: 5,
          poseConfidence: 0.9,
        ));
      }
      // thêm một mẫu đỉnh cuối để rep cuối được chốt
      out.add(PoseSample(at: ms((reps * perRep * 1000 / perRep).round()), signal: hi,
          leftAngle: hi, rightAngle: hi, torsoDeviationDeg: 5, poseConfidence: 0.9));
      return out;
    }

    RepTracker makeTracker() => RepTracker(
          counter: RepCounter(
            hi: 140, lo: 100, minAmplitude: 40,
            minPeriod: const Duration(milliseconds: 300),
          ),
        );

    test('mỗi chu kỳ sinh đúng một RepCompleted', () {
      final t = makeTracker();
      final done = <RepCompleted>[];
      for (final s in wave(reps: 3)) {
        done.addAll(t.update(s).whereType<RepCompleted>());
      }
      expect(done.length, 3);
      expect(t.count, 3);
    });

    test('mỗi rep mang theo số liệu đo được', () {
      final t = makeTracker();
      RepCompleted? first;
      for (final s in wave(reps: 2)) {
        final done = t.update(s).whereType<RepCompleted>();
        if (first == null && done.isNotEmpty) first = done.first;
      }
      expect(first, isNotNull);
      final o = first!.observation;
      expect(o.amplitude, greaterThan(40));
      expect(o.sampleCount, greaterThan(0));
      expect(o.averagePoseConfidence, closeTo(0.9, 0.05));
      expect(o.maxTorsoDeviation, closeTo(5, 0.01));
      expect(o.hasBothArms, isTrue);
    });

    test('mất tín hiệu giữa chừng phát RepAborted', () {
      final t = makeTracker();
      final samples = wave(reps: 2);
      final events = <RepEvent>[];
      for (var i = 0; i < samples.length; i++) {
        // cắt tín hiệu ở giữa rep đầu
        final s = (i == 12)
            ? PoseSample(at: samples[i].at, signal: null)
            : samples[i];
        events.addAll(t.update(s));
      }
      expect(events.whereType<RepAborted>().length, greaterThanOrEqualTo(1));
      expect(events.whereType<RepAborted>().first.reason, RepAbortReason.signalLost);
    });

    test('mất tư thế hợp lệ cũng huỷ chu kỳ đang dở', () {
      final t = makeTracker();
      final samples = wave(reps: 1);
      t.update(samples[5]);
      t.update(samples[10]);
      final e = t.onInterrupted(ms(999), RepAbortReason.placementLost);
      expect(e, isA<RepAborted>());
      expect((e as RepAborted).reason, RepAbortReason.placementLost);
    });

    test('reset xoá cả bộ đếm lẫn số liệu tích luỹ', () {
      final t = makeTracker();
      for (final s in wave(reps: 2)) {
        t.update(s);
      }
      expect(t.count, greaterThan(0));
      t.reset();
      expect(t.count, 0);
      expect(t.onInterrupted(ms(0), RepAbortReason.reset), isNull);
    });
  });

  group('WorkoutPhase', () {
    test('chỉ active mới được đếm', () {
      for (final p in WorkoutPhase.values) {
        expect(p.countsReps, p == WorkoutPhase.active, reason: p.name);
      }
    });

    test('phase kết thúc không cần camera', () {
      expect(WorkoutPhase.completed.needsCamera, isFalse);
      expect(WorkoutPhase.failed.needsCamera, isFalse);
      expect(WorkoutPhase.completed.isTerminal, isTrue);
    });

    test('positioning cần camera nhưng không đếm', () {
      expect(WorkoutPhase.positioning.needsCamera, isTrue);
      expect(WorkoutPhase.positioning.countsReps, isFalse);
    });
  });
}
