/// Nhận xét buổi tập KHÔNG cần mạng, suy từ số liệu đã đo.
///
/// Trước đây trang kết quả chỉ có nhận xét của Gemini. Mất mạng là nó không nói
/// được gì ngoài con số rep — mà người tập thì hay tập ở chỗ sóng yếu.
///
/// **Vì sao trả về enum chứ không trả về câu chữ.** IMPLEMENTATION_PLAN §8 mô tả
/// `WorkoutFeedback` chứa `String summary`, `List<String> strengths`… Làm đúng
/// vậy thì domain phải biết tới `S`, tức là tầng nghiệp vụ phụ thuộc tầng hiển
/// thị, và mỗi lần thêm ngôn ngữ lại phải sửa domain. Ở đây domain chỉ kết luận
/// "có chuyện gì", còn UI dịch sang câu chữ. Đổi lại, test khẳng định trên enum
/// nên chặt hơn hẳn so với so khớp chuỗi.
library;

import '../data/workout_record.dart';

/// Nhận xét đến từ đâu — để giao diện nói thật với người dùng.
enum FeedbackSource {
  /// Suy từ luật ngay trên máy, luôn có kể cả khi mất mạng.
  rules,

  /// Do Gemini sinh, cần mạng và cần người dùng bấm.
  ai,
}

/// Một điều đáng nói về buổi tập.
enum FeedbackNote {
  // --- điểm tốt ---
  goalReached,
  steadyCadence,
  goodRange,
  balancedSides,
  goodCameraSetup,

  // --- điểm cần cải thiện ---
  /// Mất dấu người quá nhiều — gần như luôn là do đặt máy, không phải do tập.
  poseLostOften,
  amplitudeDropped,
  leftRightUneven,
  repsTooFast,
  shortSession,
}

class WorkoutFeedback {
  const WorkoutFeedback({
    required this.strengths,
    required this.improvements,
    required this.nextGoalReps,
    required this.hasEnoughData,
    this.source = FeedbackSource.rules,
  });

  final List<FeedbackNote> strengths;
  final List<FeedbackNote> improvements;

  /// Gợi ý mục tiêu cho buổi sau. Null khi chưa đủ cơ sở để gợi ý.
  final int? nextGoalReps;

  /// false thì **không được** kết luận gì về kỹ thuật, chỉ tóm tắt con số.
  final bool hasEnoughData;

  final FeedbackSource source;

  bool get isEmpty => strengths.isEmpty && improvements.isEmpty;
}

/// Ngưỡng của riêng bộ luật này.
///
/// Đây là **điểm khởi đầu**, không phải hằng số đã kiểm chứng — trừ
/// [fastRepSeconds]. Chỉnh lại khi có số liệu thật từ người test.
class FeedbackThresholds {
  const FeedbackThresholds({
    this.poseLostPercent = 25,
    this.amplitudeDropPercent = 15,
    this.leftRightDiffPercent = 15,
    this.steadyCadenceScore = 80,
    this.goodRangeScore = 80,
    this.balancedSidesScore = 80,
    this.goodPlacementPercent = 85,
    this.fastRepSeconds = 1.0,
    this.minRepsForQuality = 5,
    this.shortSessionReps = 3,
  });

  /// Tỉ lệ khung hình mất dấu vượt mức này thì ưu tiên khuyên chỉnh camera.
  final double poseLostPercent;

  final double amplitudeDropPercent;
  final double leftRightDiffPercent;
  final int steadyCadenceScore;
  final int goodRangeScore;
  final int balancedSidesScore;
  final int goodPlacementPercent;

  /// Nhịp trung bình nhanh hơn mức này thì khuyên chậm lại.
  ///
  /// 1,0 s dựa trên đo thật: 7 video hít đất cho nhịp trung vị 1,0–1,6 s
  /// (ADR 0002). Dưới mức đó là nhanh hơn mọi buổi tập đã quan sát được.
  final double fastRepSeconds;

  /// Ít hơn số rep này thì không kết luận gì về kỹ thuật.
  final int minRepsForQuality;

  /// Buổi tập ngắn tới mức chỉ nên nhắc tập thêm.
  final int shortSessionReps;
}

class RuleBasedFeedback {
  const RuleBasedFeedback({this.thresholds = const FeedbackThresholds()});

  final FeedbackThresholds thresholds;

  WorkoutFeedback analyze(WorkoutRecord r) {
    final t = thresholds;
    final strengths = <FeedbackNote>[];
    final improvements = <FeedbackNote>[];

    final lostPercent =
        r.poseFrames == 0 ? 0.0 : r.lostFrames / r.poseFrames * 100;

    // Mất dấu nhiều thì xét TRƯỚC và chặn mọi kết luận về kỹ thuật: số liệu đo
    // trên một buổi mà máy không nhìn thấy người thì không nói lên điều gì.
    final poseUnreliable = lostPercent > t.poseLostPercent;
    if (poseUnreliable) improvements.add(FeedbackNote.poseLostOften);

    final q = r.quality;
    final enoughData = q != null &&
        q.hasEnoughData &&
        r.reps >= t.minRepsForQuality &&
        !poseUnreliable;

    if (r.goalReached) strengths.add(FeedbackNote.goalReached);
    if (!poseUnreliable && r.placementScore >= t.goodPlacementPercent) {
      strengths.add(FeedbackNote.goodCameraSetup);
    }
    if (r.reps > 0 && r.reps <= t.shortSessionReps) {
      improvements.add(FeedbackNote.shortSession);
    }

    if (enoughData) {
      if (q.cadenceConsistency >= t.steadyCadenceScore) {
        strengths.add(FeedbackNote.steadyCadence);
      }
      if (q.rangeOfMotion >= t.goodRangeScore) {
        strengths.add(FeedbackNote.goodRange);
      }
      if (q.leftRightBalance >= t.balancedSidesScore) {
        strengths.add(FeedbackNote.balancedSides);
      }
      if (q.amplitudeDropPercent > t.amplitudeDropPercent) {
        improvements.add(FeedbackNote.amplitudeDropped);
      }
      if (q.leftRightDiffPercent > t.leftRightDiffPercent) {
        improvements.add(FeedbackNote.leftRightUneven);
      }
      if (q.avgRepSeconds > 0 && q.avgRepSeconds < t.fastRepSeconds) {
        improvements.add(FeedbackNote.repsTooFast);
      }
    }

    return WorkoutFeedback(
      strengths: strengths,
      improvements: improvements,
      nextGoalReps: _nextGoal(r, enoughData),
      hasEnoughData: enoughData,
    );
  }

  /// Gợi ý mục tiêu buổi sau.
  ///
  /// Không gợi ý khi buổi tập không đáng tin: đẩy mục tiêu lên dựa trên một con
  /// số đếm sai thì tệ hơn là im lặng.
  int? _nextGoal(WorkoutRecord r, bool enoughData) {
    if (r.reps <= 0) return null;
    final target = r.targetReps;
    if (target != null && !r.goalReached) {
      // Chưa đạt thì giữ nguyên mục tiêu cũ, đừng hạ xuống cho dễ.
      return target;
    }
    if (!enoughData) return null;
    // Tăng 10%, ít nhất một rep, làm tròn lên bội số của 5 cho dễ nhớ.
    final base = target != null && target > r.reps ? target : r.reps;
    final raised = base + (base * 0.1).ceil().clamp(1, 1 << 30);
    return ((raised + 4) ~/ 5) * 5;
  }
}
