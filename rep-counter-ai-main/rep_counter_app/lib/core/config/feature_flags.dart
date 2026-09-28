/// Công tắc tính năng cho giai đoạn MVP.
///
/// PHẦN 1 của kế hoạch chỉ làm push-up. Hai bài tạ vẫn còn code nhưng bị ẩn khỏi
/// UI thay vì xoá, vì chúng là dữ liệu tham chiếu cho thiết kế tín hiệu: mỗi bài
/// hỏng theo một kiểu keypoint khác nhau, và đó là lý do lõi đếm phải tách rời
/// khỏi cách rút tín hiệu.
///
/// Bật lại bằng `--dart-define=ENABLE_ALL_EXERCISES=true` khi cần thử.
library;

import 'package:flutter/services.dart' show appFlavor;

class FeatureFlags {
  const FeatureFlags._();

  /// Chỉ hiện push-up trong danh sách bài tập.
  static const bool enableAllExercises =
      bool.fromEnvironment('ENABLE_ALL_EXERCISES', defaultValue: false);

  /// Gửi tổng hợp buổi tập cho AI. Tắt ở Phase 0-3 vì backend chưa có.
  static const bool enableAiFeedback =
      bool.fromEnvironment('ENABLE_AI_FEEDBACK', defaultValue: false);

  /// Bài duy nhất được hỗ trợ ở MVP.
  static const String mvpExerciseId = 'push_up';

  /// Kéo xà: mới chỉ kiểm trên 2 video, chưa có người thật dùng qua app.
  ///
  /// Hiện ở bản `diag` để tester quay video + CSV về; bản `store` giữ nguyên
  /// cho tới khi số liệu từ tester xác nhận. Ép bật bằng
  /// `--dart-define=ENABLE_PULL_UP=true`.
  static bool get enablePullUp =>
      const bool.fromEnvironment('ENABLE_PULL_UP') || appFlavor == 'diag';

  /// Id các bài hiện trên màn hình chính.
  static Set<String> get visibleExerciseIds => {
        mvpExerciseId,
        if (enablePullUp) 'pull_up',
      };
}
