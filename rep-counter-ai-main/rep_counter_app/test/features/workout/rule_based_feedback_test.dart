/// Mỗi nhánh luật một test, theo IMPLEMENTATION_PLAN §8.
///
/// Khẳng định trên enum chứ không so khớp chuỗi: đổi câu chữ hay thêm ngôn ngữ
/// không được làm vỡ test về hành vi.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/features/workout/data/workout_record.dart';
import 'package:rep_counter_app/features/workout/domain/rule_based_feedback.dart';

const _engine = RuleBasedFeedback();

WorkoutQuality _quality({
  double avgRepSeconds = 1.8,
  double amplitudeDropPercent = 0,
  double leftRightDiffPercent = 0,
  int cadenceConsistency = 60,
  int rangeOfMotion = 60,
  int leftRightBalance = 60,
  bool hasEnoughData = true,
}) =>
    WorkoutQuality(
      flaggedReps: 0,
      avgRepSeconds: avgRepSeconds,
      avgAmplitude: 55,
      amplitudeDropPercent: amplitudeDropPercent,
      leftRightDiffPercent: leftRightDiffPercent,
      qualityScore: 70,
      rangeOfMotion: rangeOfMotion,
      cadenceConsistency: cadenceConsistency,
      leftRightBalance: leftRightBalance,
      poseAlignment: 70,
      hasEnoughData: hasEnoughData,
    );

WorkoutRecord _record({
  int reps = 20,
  int? targetReps,
  int poseFrames = 1000,
  int readyFrames = 950,
  int lostFrames = 20,
  WorkoutQuality? quality,
}) =>
    WorkoutRecord(
      id: 'w1',
      exerciseId: 'push_up',
      exerciseName: 'Hít đất',
      startedAt: DateTime(2026, 9, 20),
      durationSeconds: 120,
      reps: reps,
      sets: 1,
      targetReps: targetReps,
      poseFrames: poseFrames,
      readyFrames: readyFrames,
      lostFrames: lostFrames,
      quality: quality ?? _quality(),
    );

void main() {
  group('mất dấu pose', () {
    test('mất dấu nhiều thì khuyên chỉnh camera', () {
      final f = _engine.analyze(
          _record(poseFrames: 1000, lostFrames: 400, readyFrames: 500));
      expect(f.improvements, contains(FeedbackNote.poseLostOften));
    });

    test('mất dấu nhiều thì KHÔNG kết luận gì về kỹ thuật', () {
      final f = _engine.analyze(_record(
        poseFrames: 1000,
        lostFrames: 400,
        readyFrames: 500,
        quality: _quality(amplitudeDropPercent: 40, leftRightDiffPercent: 40),
      ));
      expect(f.hasEnoughData, isFalse);
      expect(f.improvements, isNot(contains(FeedbackNote.amplitudeDropped)));
      expect(f.improvements, isNot(contains(FeedbackNote.leftRightUneven)));
    });
  });

  test('biên độ tụt cuối buổi thì có nhận xét', () {
    final f = _engine.analyze(
        _record(quality: _quality(amplitudeDropPercent: 30)));
    expect(f.improvements, contains(FeedbackNote.amplitudeDropped));
  });

  test('hai bên lệch nhiều thì có nhận xét', () {
    final f = _engine.analyze(
        _record(quality: _quality(leftRightDiffPercent: 25)));
    expect(f.improvements, contains(FeedbackNote.leftRightUneven));
  });

  test('nhịp đều thì ghi nhận là điểm tốt', () {
    final f = _engine.analyze(
        _record(quality: _quality(cadenceConsistency: 92)));
    expect(f.strengths, contains(FeedbackNote.steadyCadence));
  });

  test('rep quá nhanh thì khuyên chậm lại', () {
    final f = _engine.analyze(_record(quality: _quality(avgRepSeconds: 0.8)));
    expect(f.improvements, contains(FeedbackNote.repsTooFast));
  });

  test('nhịp 1,5 giây là bình thường, đừng bảo người ta chậm lại', () {
    final f = _engine.analyze(_record(quality: _quality(avgRepSeconds: 1.5)));
    expect(f.improvements, isNot(contains(FeedbackNote.repsTooFast)));
  });

  group('dữ liệu quá ít', () {
    test('ít rep thì không kết luận kỹ thuật', () {
      final f = _engine.analyze(_record(
        reps: 3,
        quality: _quality(amplitudeDropPercent: 40),
      ));
      expect(f.hasEnoughData, isFalse);
      expect(f.improvements, isNot(contains(FeedbackNote.amplitudeDropped)));
      expect(f.improvements, contains(FeedbackNote.shortSession));
    });

    test('summary nói chưa đủ dữ liệu thì tôn trọng', () {
      final f = _engine
          .analyze(_record(quality: _quality(hasEnoughData: false)));
      expect(f.hasEnoughData, isFalse);
    });

    test('bản ghi cũ không có số liệu chất lượng vẫn chạy được', () {
      final f = _engine.analyze(WorkoutRecord(
        id: 'old',
        exerciseId: 'push_up',
        exerciseName: 'Hít đất',
        startedAt: DateTime(2026, 1, 1),
        durationSeconds: 100,
        reps: 15,
        sets: 1,
        targetReps: null,
        poseFrames: 500,
        readyFrames: 480,
        lostFrames: 10,
      ));
      expect(f.hasEnoughData, isFalse);
      expect(f.nextGoalReps, isNull);
    });
  });

  group('mục tiêu buổi sau', () {
    test('đạt mục tiêu thì nâng lên, làm tròn bội số 5', () {
      final f = _engine.analyze(_record(reps: 20, targetReps: 20));
      expect(f.strengths, contains(FeedbackNote.goalReached));
      expect(f.nextGoalReps, 25);
    });

    test('chưa đạt thì giữ nguyên mục tiêu cũ, không hạ xuống', () {
      final f = _engine.analyze(_record(reps: 12, targetReps: 30));
      expect(f.nextGoalReps, 30);
    });

    test('không có rep nào thì không gợi ý gì', () {
      final f = _engine.analyze(_record(reps: 0));
      expect(f.nextGoalReps, isNull);
    });

    test('buổi tập không đáng tin thì không đẩy mục tiêu lên', () {
      final f = _engine.analyze(_record(
        reps: 30,
        poseFrames: 1000,
        lostFrames: 500,
        readyFrames: 400,
      ));
      expect(f.nextGoalReps, isNull);
    });
  });

  test('đặt máy tốt thì ghi nhận', () {
    final f = _engine.analyze(_record(poseFrames: 1000, readyFrames: 980));
    expect(f.strengths, contains(FeedbackNote.goodCameraSetup));
  });

  test('buổi tập tốt thì có điểm mạnh và không bịa điểm yếu', () {
    final f = _engine.analyze(_record(
      reps: 25,
      targetReps: 20,
      quality: _quality(
        cadenceConsistency: 90,
        rangeOfMotion: 88,
        leftRightBalance: 85,
      ),
    ));
    expect(f.hasEnoughData, isTrue);
    expect(f.strengths, contains(FeedbackNote.goalReached));
    expect(f.strengths, contains(FeedbackNote.goodRange));
    expect(f.improvements, isEmpty);
  });
}
