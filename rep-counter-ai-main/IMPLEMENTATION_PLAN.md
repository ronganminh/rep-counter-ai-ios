# Kế hoạch triển khai 2 phần: Rep Counter AI và nền tảng tập theo video mẫu

## 0. Mục tiêu tài liệu

Tài liệu này là execution spec dành cho coding agent. Hãy triển khai theo từng phase, không làm toàn bộ trong một commit và không mở rộng sang bài tập khác trước khi push-up đạt tiêu chí nghiệm thu.

Roadmap được khóa thành hai phần tuần tự:

```text
PHẦN 1 — Ứng dụng cá nhân
MediaPipe push-up counter → workout metrics → AI feedback → store-ready

PHẦN 2 — Nền tảng cộng đồng
Account → upload video mẫu → xử lý template → share → người khác tập theo
```

Không bắt đầu Phần 2 khi Phần 1 chưa đạt release gate. Phần 2 phải tái sử dụng pose pipeline, workout domain và AI feedback của Phần 1; không viết một bộ đếm thứ hai.

Mục tiêu Phần 1 là ứng dụng Flutter phát hành được lên Google Play và App Store, có khả năng:

1. Dùng camera và ML Kit Pose/MediaPipe để đếm push-up theo thời gian thực.
2. Chỉ đếm khi người dùng nằm đúng vị trí và pose đủ tin cậy.
3. Lưu số liệu chất lượng của từng rep và từng set.
4. Tổng hợp buổi tập hoàn toàn bằng thuật toán xác định trên thiết bị.
5. Gửi JSON tổng hợp nhỏ lên backend để Gemini viết nhận xét.
6. Hoạt động được khi offline; AI là tính năng bổ sung, không phải điều kiện để hoàn tất workout.
7. Không tải video, ảnh khuôn mặt hoặc toàn bộ landmark lên server trong phiên bản đầu.

Mục tiêu Phần 2 là bổ sung tài khoản và khả năng biến một video mẫu thành bài tập có thể chia sẻ, để người khác xem và tập theo bằng camera cùng pipeline MediaPipe.

## A. Ranh giới hai phần

### Phần 1 — bắt buộc hoàn thành trước

- Không cần tài khoản.
- Chỉ push-up.
- Camera và MediaPipe chạy on-device.
- Đếm rep/set và lưu lịch sử local.
- AI nhận xét từ JSON tổng hợp.
- Có offline fallback.
- Đủ kiểm thử, privacy và store readiness.

### Phần 2 — chỉ triển khai sau release gate Phần 1

- Đăng ký, đăng nhập, đăng xuất và quản lý tài khoản.
- Creator upload video mẫu.
- Backend xử lý video thành movement template.
- Public, unlisted và private sharing.
- Người khác mở link, xem video và tập theo.
- So sánh theo phase, không so pixel hoặc ép khớp từng frame.
- Moderation, report và quản trị nội dung public.

### Không nằm trong hai phần đầu

- Livestream.
- Marketplace/thanh toán/subscription.
- Comment/chat.
- Tự nhận dạng chính xác mọi bài tập bất kỳ.
- Gemini xem toàn bộ video người tập.
- Chẩn đoán chấn thương hoặc tuyên bố y khoa.

## 1. Repo và trạng thái ban đầu

Project Flutter nằm tại:

```text
rep_counter_app/
```

Các file quan trọng hiện có:

```text
lib/main.dart                 Điều hướng và màn hình chọn bài
lib/camera_page.dart          Camera, ML Kit Pose và pipeline realtime
lib/exercise.dart             Định nghĩa tín hiệu/ngưỡng bài tập
lib/placement.dart            Kiểm tra vị trí, khoảng cách và hướng thân
lib/rep_counter.dart          Schmitt trigger, merge arms, session/set
lib/overlay_painter.dart      Khung hướng dẫn, skeleton và trace
test/rep_counter_test.dart    Test lõi đếm đối chiếu dữ liệu Python
```

Thuật toán hiện tại:

```text
Camera frame
→ google_mlkit_pose_detection
→ MediaPipe landmarks
→ PoseMapper
→ elbow angle trái/phải
→ trung bình trượt
→ Schmitt trigger
→ SessionTracker
```

Các điểm đã có:

- Push-up dùng trung bình góc khuỷu trái/phải.
- Có `repHi`, `repLo`, `minAmplitude`, `minPeriod`.
- Có reset state khi mất pose.
- Chỉ đếm khi `PlacementStatus.ready`.
- Có hiệu chỉnh ngưỡng bằng percentile.
- Có test lõi đếm rep.
- Android scaffold và quyền camera đã được tạo.

Các điểm còn thiếu:

- Chưa có vòng đời workout rõ ràng: chuẩn bị, đếm ngược, tập, pause, kết thúc.
- Chưa lưu metric của từng rep.
- Chưa phát hiện/ghi nhận rep không hoàn chỉnh.
- Chưa có màn hình kết quả và lịch sử.
- Chưa có backend Gemini.
- Chưa có fallback feedback khi offline.
- Chưa hoàn thiện xử lý lỗi camera/permission.
- Chưa kiểm chứng PoseMapper/rotation trên ma trận thiết bị thật.
- Chưa có scaffold và cấu hình iOS production.

## 2. Nguyên tắc kiến trúc bắt buộc

### 2.1 Phân tách trách nhiệm

```text
MediaPipe/ML Kit: phát hiện landmark
Dart domain logic: đếm và chấm metric
Local storage: lưu workout và feedback
Backend: bảo vệ Gemini API key và validate request
Gemini: diễn đạt số liệu thành nhận xét
```

Gemini không được:

- Quyết định lại tổng rep hoặc số set.
- Phân tích video ở MVP.
- Tự tạo metric không có trong input.
- Chẩn đoán chấn thương, bệnh lý hoặc thay thế chuyên gia.

### 2.2 Offline-first

- Workout phải hoàn thành và lưu được khi không có mạng.
- Feedback rule-based phải có ngay trên thiết bị.
- AI request có thể retry sau.
- Không chặn màn hình kết quả để chờ Gemini.

### 2.3 Privacy-first

- Xử lý camera trên thiết bị.
- Không ghi video mặc định.
- Không gửi frame, khuôn mặt hoặc landmark thô lên backend.
- Chỉ gửi `WorkoutAiPayload` đã tổng hợp.
- Không nhúng `GEMINI_API_KEY` trong Flutter, `.env` đóng gói trong APK hoặc source control.

## 3. Kiến trúc thư mục mục tiêu

Không cần chuyển toàn bộ code trong một lần. Di chuyển dần và giữ test xanh sau mỗi bước.

```text
lib/
  app/
    app.dart
    routes.dart
    theme.dart
  core/
    config/
      app_config.dart
    errors/
      app_exception.dart
    network/
      api_client.dart
  features/
    workout/
      domain/
        exercise_profile.dart
        rep_metric.dart
        set_metric.dart
        workout_session.dart
        workout_summary.dart
        workout_state.dart
        rep_quality_analyzer.dart
        workout_aggregator.dart
      application/
        workout_controller.dart
      data/
        workout_repository.dart
        local_workout_repository.dart
      presentation/
        workout_page.dart
        workout_result_page.dart
        workout_history_page.dart
        widgets/
    pose/
      domain/
        pose_mapper.dart
        placement_evaluator.dart
      application/
        pose_pipeline.dart
      presentation/
        pose_overlay_painter.dart
    feedback/
      domain/
        workout_feedback.dart
        feedback_schema.dart
      application/
        feedback_service.dart
        rule_based_feedback_service.dart
        ai_feedback_service.dart
      data/
        feedback_api_client.dart
  main.dart
```

Không bắt buộc áp dụng state-management package lớn. Với phạm vi MVP, có thể dùng `ChangeNotifier`, `ValueNotifier` hoặc controller thuần Dart. Nếu thêm Riverpod/BLoC phải giải thích lợi ích và bổ sung test tương ứng.

## 4. Domain model cần triển khai

### 4.1 Workout lifecycle

```dart
enum WorkoutPhase {
  idle,
  initializingCamera,
  positioning,
  calibrating,
  countdown,
  active,
  paused,
  completing,
  completed,
  failed,
}
```

Quy tắc:

- Không đếm ở `positioning`, `calibrating`, `countdown`, `paused`.
- Chuyển sang `countdown` chỉ khi placement ổn định đủ số frame.
- Khi placement mất trong lúc `active`, pause bộ đếm tín hiệu nhưng không nhất thiết đổi toàn bộ workout sang `paused`.
- `completed` phải chốt set đang mở trước khi tổng hợp.

### 4.2 Rep metric

```dart
class RepMetric {
  final String id;
  final int index;
  final int setIndex;
  final Duration startedAt;
  final Duration bottomAt;
  final Duration completedAt;
  final double bottomAngle;
  final double topAngle;
  final double amplitude;
  final double? leftBottomAngle;
  final double? rightBottomAngle;
  final double leftRightDifference;
  final double maxTorsoDeviation;
  final double averagePoseConfidence;
  final bool valid;
  final List<RepQualityFlag> flags;
}
```

```dart
enum RepQualityFlag {
  shallow,
  incompleteLockout,
  tooFast,
  tooSlow,
  leftRightUneven,
  bodyAlignmentLost,
  poseUnreliable,
}
```

Không dùng `RepQualityFlag` để thay đổi số rep trong phase đầu. Trước hết giữ logic valid rep tương thích thuật toán cũ; quality flags phục vụ feedback. Sau khi có ground truth mới cân nhắc loại rep không chuẩn.

### 4.3 Set metric

```dart
class SetMetric {
  final int index;
  final DateTime startedAt;
  final DateTime endedAt;
  final List<RepMetric> reps;
  final int validReps;
  final int flaggedReps;
  final double averageRepSeconds;
  final double averageAmplitude;
  final double cadenceVariation;
}
```

### 4.4 Workout summary

```dart
class WorkoutSummary {
  final String id;
  final String exerciseId;
  final DateTime startedAt;
  final DateTime endedAt;
  final List<SetMetric> sets;
  final int totalReps;
  final int flaggedReps;
  final double averageRepSeconds;
  final double averageAmplitude;
  final double amplitudeDropPercent;
  final double leftRightDifferencePercent;
  final double poseLostPercent;
  final int qualityScore;
  final CalibrationSnapshot calibration;
  final int? targetReps;
  final bool goalReached;
  final int repsAboveGoal;
  final double? goalProgressPercent;
}
```

Quy ước mục tiêu:

- `targetReps == null`: người dùng chọn tập tự do/bỏ qua mục tiêu.
- `targetReps > 0`: có mục tiêu tổng rep cho cả workout.
- Không dùng `0` để biểu thị bỏ qua.
- `goalReached = targetReps != null && totalReps >= targetReps`.
- `repsAboveGoal = goalReached ? totalReps - targetReps : 0`.
- `goalProgressPercent` có thể vượt 100% nếu người dùng tiếp tục tập.
- Mục tiêu không được tác động vào thuật toán đếm hoặc quality score.

Tất cả model lưu local phải có `toJson/fromJson` và schema version để hỗ trợ migration sau này.

## 5. Hoàn thiện pipeline MediaPipe push-up

### 5.1 Chuẩn hóa hệ tọa độ

Tách `PoseMapper` khỏi `camera_page.dart` và viết unit test cho:

- Rotation 0, 90, 180, 270 độ.
- Camera trước mirror và camera sau không mirror.
- `BoxFit.cover` crop ngang/dọc.
- Các tỷ lệ 16:9, 4:3 và màn hình dài.
- Preview size khác input image size.

Acceptance:

- Landmark vai/khuỷu/cổ tay nằm đúng trên skeleton trong ảnh chụp kiểm thử.
- Sai số mapping mục tiêu dưới 2% cạnh ngắn màn hình.

### 5.2 Pose quality gate

Một frame được dùng cho counting khi:

- Có ít nhất vai, khuỷu, cổ tay và hông cần thiết.
- Landmark đạt `minLikelihood`.
- Phần lớn landmark cần thiết nằm trong guide zone.
- Bề rộng vai nằm trong khoảng hợp lệ.
- Trục vai–hông gần phương ngang.
- Placement status đã debounce.

Theo dõi thêm:

```text
totalProcessedFrames
countableFrames
poseLostFrames
partiallyOutFrames
wrongPoseFrames
```

`poseLostPercent` phải dựa trên frame đã xử lý, không dựa trên FPS camera danh nghĩa.

### 5.3 Signal và smoothing

- Giữ elbow angle làm tín hiệu push-up.
- Lấy mean hai tay khi cả hai hợp lệ.
- Nếu chỉ có một tay hợp lệ, cho phép dùng một tay nhưng đánh dấu confidence thấp hơn.
- Reset rolling mean khi mất pose hoặc placement không hợp lệ.
- Không dùng smoothing đối xứng cần mẫu tương lai.
- Cho phép cấu hình rolling window theo thời gian mục tiêu, không hard-code phụ thuộc FPS nếu có thể.

### 5.4 Rep state machine mở rộng

Mở rộng `RepCounter` hoặc tạo `RepTracker` để phát event:

```text
RepStarted
RepReachedBottom
RepCompleted
RepAborted
```

Một rep hợp lệ cần:

- Đã xuống dưới `lo`.
- Sau đó lên trên `hi`.
- `amplitude >= minAmplitude`.
- Khoảng cách với rep trước `>= minPeriod`.
- Không có signal gap dài hơn ngưỡng giữa chu kỳ.

Giữ test vector Python hiện có không đổi. Nếu thay đổi hành vi, thêm test mới và giải thích vì sao; không sửa expected vector chỉ để test xanh.

### 5.5 Calibration

Luồng UX:

1. Người dùng vào đúng khung.
2. App hướng dẫn tập 3–5 rep tự nhiên.
3. Thu mẫu chỉ khi placement ready.
4. Tính percentile 10/90.
5. Kiểm tra span tối thiểu.
6. Preview ngưỡng mới.
7. Lưu theo exercise/camera/device.

Fallback:

- Nếu calibration không đủ mẫu: giữ ngưỡng cũ.
- Nếu span quá nhỏ: hướng dẫn tập đủ biên độ hoặc đổi góc camera.
- Có nút reset calibration.

## 6. Rep quality analyzer

Tất cả ngưỡng quality phải nằm trong config/profile, không rải magic number trong UI.

Khởi điểm đề xuất, cần tinh chỉnh bằng dữ liệu thật:

```text
tooFast: completedAt - startedAt < 700 ms
tooSlow: completedAt - startedAt > 5000 ms
leftRightUneven: chênh góc hai bên > 20 độ
poseUnreliable: averagePoseConfidence < 0.55
bodyAlignmentLost: torso deviation vượt tolerance trong phần đáng kể chu kỳ
```

`shallow` và `incompleteLockout` phải dựa trên calibration/profile cá nhân, không chỉ dựa trên ngưỡng YOLO cũ.

Quality score 0–100 do thuật toán cố định tính. Công thức ban đầu:

```text
35% range of motion
25% cadence consistency
20% left/right balance
20% pose/body alignment quality
```

Viết unit test cho biên 0, 100, dữ liệu thiếu và set chỉ có một rep.

## 7. Workout controller và UX

### 7.1 Màn hình chuẩn bị

- Giải thích đặt điện thoại ngang hông, quay từ bên sườn.
- Xin camera permission tại thời điểm cần dùng.
- Xử lý denied, permanently denied và mở app settings.
- Hiển thị trạng thái camera initialization/error.

Trước khi mở camera, hiển thị bước “Kế hoạch hôm nay”:

```text
HÍT ĐẤT HÔM NAY

Mục tiêu số rep
[ − ]   20   [ + ]

Gợi ý: 10 · 20 · 30 · 50

[ BẮT ĐẦU ]
[ × Bỏ qua mục tiêu ]
```

Yêu cầu:

- Cho nhập số nguyên bằng bàn phím và nút tăng/giảm.
- Validation trong khoảng cấu hình, MVP đề xuất `1..999`.
- Chọn nhanh các mức gợi ý.
- Nút `×`/“Bỏ qua” đặt `targetReps = null` và chuyển sang tập tự do.
- Ghi nhớ mục tiêu gần nhất để gợi ý, nhưng không tự bắt đầu workout.
- Không yêu cầu số set trong MVP.
- Camera permission chỉ xin sau khi người dùng bấm bắt đầu, không xin ở màn hình home.

### 7.2 Màn hình tập

Hiển thị:

- Rep hiện tại.
- Nếu có mục tiêu, hiển thị `current / target`, progress bar và số rep còn lại.
- Nếu tập tự do, chỉ hiển thị tổng rep.
- Set hiện tại.
- Thời gian.
- Placement status.
- Skeleton và guide zone.
- Countdown.
- Pause, resume, finish.
- Calibration.

Không để HUD che vùng cơ thể quan trọng trên màn hình nhỏ. Thêm accessibility semantics và không chỉ dùng màu để biểu thị trạng thái.

Khi đạt mục tiêu lần đầu:

- Không mở dialog blocking che camera ngay lập tức.
- Hiển thị celebration overlay không chặn trong 2–3 giây, có rung nhẹ/âm thanh tùy cài đặt.
- Chỉ phát một lần trong workout bằng state `goalCelebrationShown`.
- Sau overlay, cho chọn `Kết thúc` hoặc `Tập thêm` ở vị trí an toàn.
- Nếu tiếp tục, hiển thị dạng `23 / 20` và `+3 vượt mục tiêu`.
- Không cộng rep, hoàn tất workout hoặc gọi AI chỉ vì vừa đạt mục tiêu.

Logic controller:

```dart
if (targetReps != null &&
    totalReps >= targetReps! &&
    !goalCelebrationShown) {
  goalCelebrationShown = true;
  emitGoalReached();
}
```

### 7.3 Kết thúc workout

Khi bấm finish:

1. Dừng counting.
2. Chốt set đang mở.
3. Tổng hợp `WorkoutSummary`.
4. Lưu local ngay.
5. Điều hướng tới result page.
6. Chạy rule-based feedback ngay.
7. Gọi AI bất đồng bộ nếu có mạng và người dùng đã đồng ý.
8. Cập nhật feedback khi API trả về.

### 7.4 Result page

Hiển thị:

- Tổng rep, set, thời gian.
- Mục tiêu, phần trăm hoàn thành và số rep vượt mục tiêu nếu có.
- Quality score với mô tả “ước tính”.
- Rep cadence và amplitude theo set.
- Điểm làm tốt.
- Điểm cần cải thiện.
- Mục tiêu buổi sau.
- Trạng thái AI: loading, ready, offline, failed.
- Nút retry AI.

Không dùng câu chữ mang tính y khoa.

### 7.5 History

MVP lưu local:

- Danh sách workout mới nhất trước.
- Chi tiết từng workout.
- Xóa một workout.
- Xóa toàn bộ lịch sử với confirmation.
- Không yêu cầu account ở MVP.
- Mỗi dòng lịch sử hiển thị `23/20 · Đạt mục tiêu`, `14/20 · 70%` hoặc `18 rep · Tập tự do`.

Workout kết thúc sớm vẫn phải được lưu. Không gọi đó là thất bại; hiển thị tiến độ trung tính và tích cực.

Chọn một local database phổ biến và được duy trì. Trước khi thêm dependency, kiểm tra license, iOS privacy manifest và tình trạng maintenance.

## 8. Rule-based feedback offline

Tạo `RuleBasedFeedbackService` trả cùng model với AI:

```dart
class WorkoutFeedback {
  final String summary;
  final List<String> strengths;
  final List<String> improvements;
  final String nextGoal;
  final String disclaimer;
  final FeedbackSource source;
}
```

Quy tắc tối thiểu:

- `poseLostPercent` cao: ưu tiên khuyên đổi góc/khoảng cách camera.
- `amplitudeDropPercent` cao: nhận xét biên độ giảm cuối buổi.
- `leftRightDifferencePercent` cao: nhận xét hai bên chưa đồng đều, không chẩn đoán nguyên nhân.
- Cadence variation thấp: ghi nhận nhịp ổn định.
- Rep quá nhanh nhiều: đề xuất chậm lại với mục tiêu đo được.
- Dữ liệu quá ít: chỉ tóm tắt, không suy luận chất lượng.

Viết snapshot/golden test hoặc unit test chính xác cho từng nhánh.

## 9. Gemini backend

### 9.1 Yêu cầu triển khai

Backend có thể dùng Cloud Run, Firebase Functions hoặc nền tảng serverless tương đương. Không đặt backend trong Flutter app. Nếu tạo chung repo, dùng:

```text
backend/
  src/
  test/
  package.json
  .env.example
  README.md
```

Không commit secret. Dùng biến môi trường:

```text
GEMINI_API_KEY
GEMINI_MODEL=gemini-2.5-flash-lite
```

### 9.2 Endpoint

```http
POST /v1/workouts/feedback
Content-Type: application/json
```

Request tối đa khoảng 8 KB. MVP thực tế nên dưới 2 KB.

```json
{
  "schema_version": 1,
  "locale": "vi",
  "workout_id": "uuid",
  "workout": {
    "exercise": "push_up",
    "total_reps": 31,
    "target_reps": 30,
    "goal_reached": true,
    "reps_above_goal": 1,
    "flagged_reps": 3,
    "sets": [
      {
        "reps": 12,
        "duration_sec": 25.0,
        "avg_rep_sec": 1.82,
        "avg_amplitude": 74.1
      }
    ],
    "avg_rep_sec": 1.71,
    "avg_amplitude": 69.8,
    "amplitude_drop_percent": 14.2,
    "left_right_diff_percent": 8.3,
    "pose_lost_percent": 4.1,
    "quality_score": 82
  }
}
```

Response:

```json
{
  "schema_version": 1,
  "workout_id": "uuid",
  "feedback": {
    "summary": "Bạn hoàn thành 31 lần hít đất trong 3 set.",
    "strengths": ["Nhịp hai set đầu khá ổn định."],
    "improvements": ["Biên độ giảm về cuối buổi."],
    "next_goal": "Giữ biên độ trung bình từ 68 độ trở lên.",
    "disclaimer": "Nhận xét chỉ mang tính tham khảo tập luyện."
  },
  "meta": {
    "model": "gemini-2.5-flash-lite",
    "prompt_version": "pushup-feedback-v1"
  }
}
```

### 9.3 Validation

Backend phải:

- Chỉ chấp nhận `exercise=push_up` ở MVP.
- Validate finite numbers, ranges và array length.
- Validate `target_reps` là null hoặc số nguyên dương; tự kiểm tra tính nhất quán của `goal_reached` và `reps_above_goal` với `total_reps` thay vì tin mù dữ liệu client.
- Không tin `quality_score` để thực hiện logic nhạy cảm.
- Không cho client truyền prompt/model/system instruction.
- Rate limit theo installation/user/IP phù hợp.
- Timeout Gemini.
- Retry tối đa một lần với lỗi retryable.
- Validate Gemini response bằng schema.
- Không trả raw exception hoặc API key.
- Dùng idempotency theo `workout_id` để tránh gọi lặp.

### 9.4 Prompt

System instruction version `pushup-feedback-v1`:

```text
Bạn là trợ lý phản hồi buổi tập hít đất.

Dựa duy nhất trên số liệu được cung cấp:
- Viết bằng ngôn ngữ được yêu cầu, ngắn gọn, tích cực và cụ thể.
- Không thay đổi hoặc suy đoán lại số rep, set hay điểm số.
- Không chẩn đoán chấn thương, bệnh lý hoặc đưa lời khuyên điều trị.
- Không khẳng định kỹ thuật đúng/sai khi dữ liệu pose không đủ.
- Nếu tỷ lệ mất pose cao, ưu tiên hướng dẫn camera thay vì phê bình kỹ thuật.
- Trả tối đa 2 strengths, tối đa 2 improvements và đúng 1 next_goal đo được.
- Nếu dữ liệu quá ít, nói rõ chưa đủ dữ liệu để đánh giá chất lượng.
```

Dùng structured output/JSON Schema. Không parse JSON từ markdown code fence.

### 9.5 Observability

Log:

- Request ID.
- Workout ID đã hash hoặc pseudonymous.
- Status code.
- Latency.
- Model.
- Prompt version.
- Token usage nếu API cung cấp.
- Loại lỗi.

Không log:

- API key.
- Prompt đầy đủ chứa dữ liệu người dùng.
- IP lâu dài nếu không cần.
- Video, frame hoặc landmark.

Thêm budget alert và rate limit trước public launch.

## 10. Flutter API client

Tạo interface để test/fallback dễ dàng:

```dart
abstract interface class FeedbackService {
  Future<WorkoutFeedback> generate(WorkoutSummary workout);
}
```

`AiFeedbackService`:

- Chuyển `WorkoutSummary` thành payload nhỏ.
- Timeout 8–12 giây.
- Không retry vô hạn.
- Parse schema chặt chẽ.
- Map network/timeout/schema/server error thành domain error.
- Không làm mất feedback local nếu AI thất bại.
- Nếu có mục tiêu, thêm `target_reps`, `goal_reached` và `reps_above_goal` vào payload; tập tự do gửi `target_reps: null` hoặc bỏ trường theo schema thống nhất.

Không hard-code production URL rải rác. Đọc từ `--dart-define` hoặc config build-time không chứa secret.

## 11. Test strategy

### 11.1 Unit tests

Bắt buộc có test cho:

- Góc khuỷu.
- Mean hai tay và trường hợp thiếu một tay.
- Rolling mean/reset.
- Schmitt trigger.
- Min amplitude/min period.
- Signal lost giữa rep.
- Session/set close.
- Calibration percentile và insufficient span.
- Rep quality flags.
- Workout aggregator.
- Quality score.
- Rule-based feedback.
- JSON serialization/migration.
- Gemini response validation.
- Goal calculation ở dưới, bằng và trên mục tiêu.
- `targetReps = null` cho tập tự do.
- Goal celebration chỉ phát đúng một lần dù rep tiếp tục tăng.
- Serialization/migration của các trường mục tiêu.

### 11.2 Widget tests

- Permission denied UI.
- Positioning → countdown → active.
- Pause/resume/finish.
- Result loading AI.
- Result AI failed và retry.
- Offline feedback.
- History empty/list/detail/delete.
- Goal setup: nhập số, validation, preset và bỏ qua bằng `×`.
- Workout HUD có/không có mục tiêu.
- Celebration overlay không chặn counting và chỉ hiện một lần.
- Kết thúc sớm vẫn lưu đúng tiến độ.

### 11.3 Integration tests

Tạo abstraction cho pose source để replay dữ liệu đã lưu thay vì cần camera thật trong CI.

```text
RecordedPoseFrame[] → PosePipeline → expected reps/metrics
```

Không commit video rất lớn vào Git thường. Dùng fixture landmark JSON nhỏ; video benchmark để external storage hoặc Git LFS.

### 11.4 Thiết bị thật

Ma trận tối thiểu:

- Android low/mid/high-end.
- Android 10 hoặc min version thực tế đến Android mới nhất.
- Camera trước/sau.
- Portrait/landscape nếu cả hai được hỗ trợ.
- 4:3 và 16:9 input.
- Ánh sáng yếu/vừa/tốt.
- Áo sáng/tối và nền đơn giản/phức tạp.
- Người cao/thấp, nhiều tầm vận động.
- Push-up đủ, nửa rep, quá nhanh, pause giữa rep.
- Người bước vào/ra khung.
- Tay hoặc hông bị che.
- Mất mạng khi kết thúc workout.

### 11.5 Ground truth

Trước production beta, xây tập benchmark:

- Tối thiểu 20 người.
- 5–10 set/người.
- Mục tiêu 2.000–3.000 rep được người kiểm tra gán nhãn.
- Ghi expected rep count, timestamp gần đúng và loại rep.

Chỉ số release gate đề xuất:

```text
Sai số trung bình ≤ 1 rep/set trong điều kiện setup đúng
Không đếm kép trên benchmark chuẩn
False rep khi bước vào/ra khung gần 0
Crash-free sessions ≥ 99.5% trong beta
AI JSON parse success ≥ 99.5%
P95 AI latency mục tiêu < 5 giây
```

Không tuyên bố accuracy marketing trước khi benchmark đủ lớn.

## 12. Performance và reliability

- Giữ `ResolutionPreset.medium` nếu độ chính xác đủ.
- Không xử lý frame mới khi detector đang busy.
- Đo actual processed FPS.
- Tránh `setState` toàn màn hình nếu chỉ HUD thay đổi.
- Giới hạn trace buffer.
- Không giữ toàn bộ landmarks của buổi tập trong RAM.
- Chỉ giữ accumulator và dữ liệu theo rep.
- Đóng camera stream/detector đúng lifecycle.
- Xử lý app background/resume.
- Xử lý camera bị app khác chiếm dụng.
- Test workout liên tục 20 phút về nhiệt, pin và memory.

## 13. Security và privacy checklist

- Không có Gemini key trong Flutter binary.
- Không commit `.env`, signing key hoặc service credentials.
- HTTPS only.
- Backend rate limiting và payload validation.
- Privacy Policy có URL công khai.
- Consent trước khi gửi workout summary cho AI.
- Cho phép tắt AI.
- Cho phép xóa lịch sử local.
- Nếu có account sau này, cung cấp account deletion.
- Không dùng fitness data cho advertising/data mining.
- Không gọi sản phẩm là thiết bị y tế.
- Hiển thị disclaimer phù hợp.
- Review dependency licenses và privacy declarations trước release.

## 14. Store readiness

### 14.1 Android/Google Play

- Đổi application ID khỏi `com.example.rep_counter_app`.
- Chọn package ID vĩnh viễn trước khi upload lần đầu.
- Target Android API 36 cho kế hoạch phát hành từ 31/08/2026.
- Đặt minSdk theo yêu cầu cao nhất của Flutter/camera/ML Kit và test thiết bị tương ứng.
- Tạo upload key/signing config; không commit keystore/password.
- Build `.aab`, không dùng debug APK để phát hành.
- Hoàn thành Data Safety.
- Hoàn thành Health Apps declaration.
- Khai báo camera permission đúng mục đích.
- Chuẩn bị privacy policy, screenshots, icon, feature graphic, mô tả store.
- Closed testing trước production.
- Kiểm tra chính sách tài khoản developer hiện hành tại thời điểm submit.

### 14.2 iOS/App Store

- Cần macOS + Xcode để build/sign/test.
- Sinh iOS scaffold mà không ghi đè lib hiện có.
- Thêm `NSCameraUsageDescription` rõ ràng.
- Test ML Kit và coordinate mapping trên iPhone thật.
- Tạo `PrivacyInfo.xcprivacy` hợp lệ.
- Audit privacy manifests của dependency.
- Hoàn thành App Privacy Nutrition Label.
- Không lưu health/fitness data vào iCloud nếu không đáp ứng chính sách tương ứng.
- TestFlight internal → external → App Review.
- Chuẩn bị review notes giải thích camera xử lý pose trên thiết bị và AI chỉ nhận summary.

## 15. Telemetry production

Telemetry là opt-in hoặc được khai báo minh bạch. Chỉ thu metric vận hành tối thiểu:

```text
workout_started
placement_ready
calibration_started/completed/failed
workout_completed
camera_error
pose_processing_fps_bucket
feedback_requested/succeeded/failed
```

Không gửi rep landmarks hoặc video cùng analytics. Không dùng raw workout detail nếu aggregate event là đủ.

Dashboard nên theo dõi:

- Funnel onboarding → workout completed.
- Tỷ lệ placement ready.
- Calibration failure.
- Crash-free sessions.
- Camera error theo device/OS.
- AI success/latency/cost.
- Retry rate.

## 16. Kế hoạch PHẦN 1 — Rep Counter + AI Feedback

### Phase 0 — Baseline và bảo vệ hành vi cũ, 2–3 ngày

Tasks:

- Chạy `flutter analyze` và `flutter test`.
- Ghi nhận baseline test.
- Thêm test PoseMapper hiện tại trước refactor.
- Tạo feature flags để ẩn bài ngoài push-up.
- Viết ADR ngắn về on-device pose + server-side AI.

Exit criteria:

- Test hiện có xanh.
- Có baseline và không đổi expected Python vector.

### Phase 1 — Domain refactor và rep metrics, 1–2 tuần

Tasks:

- Tách domain model.
- Mở rộng rep events.
- Thêm `RepMetric`, `SetMetric`, `WorkoutSummary`.
- Thêm aggregator và quality analyzer.
- Unit test toàn bộ domain.

Exit criteria:

- Camera UI vẫn đếm như trước.
- Mỗi rep hợp lệ sinh metric.
- Summary deterministic và test được không cần Flutter binding.

### Phase 2 — Workout lifecycle và result offline, 1–2 tuần

Tasks:

- Controller/state machine.
- Goal setup trước workout (`targetReps` hoặc tập tự do).
- Countdown/pause/resume/finish.
- Goal progress HUD và celebration overlay một lần.
- Result page.
- Rule-based feedback.
- Local persistence và history.
- Permission/error UX.

Exit criteria:

- Hoàn thành một workout end-to-end khi airplane mode.
- Kill/reopen app vẫn xem được history.
- Có thể bỏ qua mục tiêu và tập tự do.
- Đạt mục tiêu không làm dừng hoặc cộng sai rep; người dùng chọn kết thúc hay tập thêm.
- Workout kết thúc trước mục tiêu vẫn được lưu với tiến độ đúng.

### Phase 3 — Pose hardening, 1–2 tuần

Tasks:

- PoseMapper tests/refactor.
- Rotation/mirror/lifecycle.
- Frame quality statistics.
- Calibration UX và persistence.
- Replay fixtures.
- Thiết bị thật vòng đầu.

Exit criteria:

- Skeleton khớp preview trên thiết bị mục tiêu.
- Benchmark nội bộ đạt release gate sơ bộ.

### Phase 4 — Gemini backend và app integration, 1 tuần

Tasks:

- Backend endpoint/schema/rate limit.
- Gemini structured output.
- Flutter client.
- Retry/cache/fallback.
- Backend và integration tests.
- Monitoring/budget alert.

Exit criteria:

- Không có secret trong app/repo.
- AI failure không làm mất workout.
- Response luôn được validate trước khi hiển thị.

### Phase 5 — Product polish và accessibility, 1 tuần

Tasks:

- Onboarding.
- Copywriting và disclaimer.
- Dark/light contrast nếu hỗ trợ.
- Screen sizes và text scaling.
- Semantics/haptic/audio cues phù hợp.
- Store assets draft.

Exit criteria:

- Người mới có thể hoàn thành workout không cần hướng dẫn trực tiếp.

### Phase 6 — Beta/benchmark/release, 2–3 tuần

Tasks:

- Ground truth dataset.
- Closed beta.
- Fix accuracy/crash/device issues.
- Privacy/store declarations.
- Android AAB signed release.
- iOS TestFlight khi có macOS/Xcode.

Exit criteria:

- Đạt accuracy/crash/AI gates.
- Store checklist hoàn tất.

## 17. Definition of Done cho mỗi task

Một task chỉ được coi là xong khi:

1. Code compile.
2. `flutter analyze` không có issue mới.
3. Unit/widget test liên quan tồn tại và pass.
4. Không làm hỏng test vector thuật toán cũ.
5. Error/loading/empty state được xử lý.
6. Không thêm secret hoặc dữ liệu nhạy cảm vào repo.
7. Documentation/config được cập nhật nếu behavior thay đổi.
8. Đã test trên thiết bị thật nếu task liên quan camera/lifecycle.

Lệnh kiểm tra tối thiểu:

```powershell
cd rep_counter_app
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

Trước Android release:

```powershell
flutter build appbundle --release
```

## 18. Quy tắc làm việc dành cho coding agent

- Đọc README và toàn bộ `lib/`, `test/` trước khi sửa.
- Không xóa hoặc thay thuật toán cũ nếu chưa có test chứng minh hành vi mới.
- Làm từng phase, commit nhỏ và có mô tả.
- Trước mỗi refactor lớn, thêm characterization test.
- Không sửa expected test chỉ để làm test pass.
- Không thêm package nếu Dart/Flutter SDK đã giải quyết đủ.
- Không đưa API key vào app dù chỉ để demo; dùng mock backend hoặc biến môi trường server.
- Không upload video mẫu lên dịch vụ bên ngoài.
- Giữ app offline-first.
- Khi không chắc về API camera/ML Kit hiện tại, kiểm tra tài liệu chính thức và plugin version đang khóa.
- Sau thay đổi camera/pose, luôn build Android và ghi rõ phần nào chưa test trên thiết bị thật.
- Dừng và báo lại nếu thay đổi yêu cầu sản phẩm, privacy scope hoặc store declarations.

## 19. Backlog sau MVP

Chỉ bắt đầu sau khi push-up production ổn định:

- Đồng bộ nhiều thiết bị và account.
- Health Connect/HealthKit.
- Dumbbell curl và overhead extension.
- Personalized trend nhiều tuần.
- Coach plans.
- Voice cues.
- Phân tích một số frame đại diện với consent riêng.
- Subscription.
- Localization ngoài tiếng Việt/Anh.

## 20. Deliverable kết thúc PHẦN 1

Phiên bản production candidate phải cung cấp:

- Flutter Android app đếm push-up ổn định bằng MediaPipe/ML Kit.
- Workout lifecycle hoàn chỉnh.
- Local history và offline feedback.
- Backend Gemini bảo mật.
- AI feedback có schema và fallback.
- Unit/widget/integration tests.
- Benchmark report.
- Privacy Policy và data-flow documentation.
- Android signed AAB cho closed testing.
- iOS project, privacy manifest và TestFlight build khi có máy macOS.

## 21. Release gate trước khi bắt đầu PHẦN 2

Chỉ bắt đầu account/video/sharing khi tất cả điều kiện sau đạt:

- Push-up counting đạt benchmark đã định nghĩa.
- Workout lifecycle hoạt động end-to-end offline.
- Lịch sử local và result page ổn định.
- Gemini backend không lộ secret và có fallback.
- Android closed beta không còn lỗi blocker.
- Crash-free sessions đạt mục tiêu.
- PoseMapper đã kiểm chứng trên thiết bị thật.
- Domain model có schema version và không phụ thuộc UI camera.
- Có tài liệu API/data flow/privacy của Phần 1.

Nếu chưa đạt gate, tiếp tục sửa Phần 1. Không dùng account hoặc video sharing để né vấn đề accuracy của pose counter.

# PHẦN 2 — Account, video mẫu và tập theo qua link chia sẻ

## 22. Mục tiêu sản phẩm Phần 2

Cho phép creator đăng ký tài khoản, upload video mẫu của bài được hỗ trợ, xác nhận template do backend trích xuất, publish và chia sẻ link/QR.

Cho phép trainee mở link, xem video mẫu, bật camera tập theo, nhận rep/score/cue realtime và AI feedback. Guest được xem và tập với post public/unlisted; chỉ cần đăng nhập khi upload, publish hoặc đồng bộ kết quả.

Nguyên tắc:

- Video public không đồng nghĩa “đã được chuyên gia xác minh”.
- Creator phải tự chọn loại bài ở MVP; classifier chỉ gợi ý/kiểm tra.
- Bài đầu tiên vẫn là push-up side-view.
- Không so pixel hoặc ép người tập khớp từng frame.
- Tái sử dụng pose pipeline, counter, metrics và AI của Phần 1.

## 23. Kiến trúc Phần 2

```text
Creator Flutter app
  → Auth
  → xin signed upload URL
  → upload trực tiếp object storage
  → queue/processing worker
  → probe + scan + transcode + thumbnail
  → MediaPipe video pipeline
  → rep segmentation + template generator
  → creator preview + moderation
  → publish ExercisePost

Trainee app / deep link
  → fetch ExercisePost + MovementTemplate nhỏ
  → stream/cache video mẫu
  → on-device MediaPipe camera
  → phase matcher + existing rep counter
  → realtime cues + score
  → WorkoutSummary
  → existing Gemini feedback service
```

Không upload video xuyên qua application API. Backend chỉ tạo signed URL, quản lý metadata và trạng thái job. MVP có thể là modular monolith cộng một worker riêng; không cần chia mọi chức năng thành microservice.

Các thành phần logic:

- Managed auth.
- Content API và database.
- Object storage/CDN.
- Job queue và video-processing worker.
- Template generator.
- Moderation/admin.
- Gemini feedback service hiện có.

## 24. Authentication và account

Phạm vi bắt buộc:

- Đăng ký email/password hoặc identity provider đáng tin cậy.
- Xác minh email nếu dùng email/password.
- Login/logout/reset password.
- Refresh/revoke session.
- Profile.
- Xóa tài khoản trong app.

Quy tắc kỹ thuật:

- Ưu tiên managed auth; không tự lưu password.
- Flutter lưu credential trong secure storage.
- Backend lấy user identity từ token đã verify, không tin `userId` trong request body.
- Rate-limit register/login/reset.
- Không log password/token.
- Object-level authorization cho mọi post/video/attempt.

Role:

```text
user     xem và tập theo
creator  upload/publish nội dung
reviewer duyệt nội dung
admin    report/takedown/quản trị
```

MVP có thể cho mọi user tạo private/unlisted; quyền public dành cho creator được mời để giảm tải moderation.

Account deletion phải revoke session, ẩn nội dung ngay, xóa/anonymize dữ liệu theo policy, xóa media/template theo retention job và trả confirmation cho người dùng.

## 25. Data model Phần 2

### UserProfile

```text
id, displayName, avatarUrl?, bio?, role
status: active | suspended | deletion_pending | deleted
createdAt, updatedAt
```

### ExercisePost

```text
id, creatorId, publicId, slug, title, description
exerciseType, difficulty, cameraView
targetReps?, targetSets?
visibility: private | unlisted | public
processingStatus: draft | uploading | queued | processing | ready | failed
moderationStatus: not_required | pending | approved | rejected | removed
verificationStatus: unverified | coach_verified
sourceVideoAssetId, playbackAssetId, thumbnailAssetId
movementTemplateId, schemaVersion
publishedAt?, createdAt, updatedAt
```

Không dùng ID tăng tuần tự trong URL public.

### VideoAsset

```text
id, ownerId, storageKey, sanitizedFileName
mimeType, sizeBytes, durationMs?, width?, height?, sha256?
uploadStatus, scanStatus, transcodeStatus, createdAt
```

### MovementTemplate

```text
id, exercisePostId, exerciseType, cameraView
requiredLandmarks, phaseDefinitions, referenceMetrics
normalizedSequence?, qualityReport
modelVersion, algorithmVersion, schemaVersion, createdAt
```

Template push-up mẫu:

```json
{
  "schema_version": 1,
  "exercise_type": "push_up",
  "camera_view": "side",
  "required_landmarks": ["shoulder", "elbow", "wrist", "hip", "ankle"],
  "phases": [
    {"name": "top", "elbow_angle": [150, 180]},
    {"name": "descending"},
    {"name": "bottom", "elbow_angle": [70, 105]},
    {"name": "ascending"}
  ],
  "reference": {
    "rep_duration_sec": 1.8,
    "down_ratio": 0.55,
    "up_ratio": 0.45,
    "amplitude": 76.0,
    "max_torso_deviation": 12.0
  }
}
```

### WorkoutAttempt

```text
id, exercisePostId, traineeId?, installationId?
workoutSummary, comparisonScore, feedback, feedbackSource
algorithmVersion, templateVersion, createdAt
```

Guest attempt lưu local. Chỉ upload/sync khi có account và consent.

### Moderation

```text
ContentReport: id, reporterId?, exercisePostId, reason, detail?, status, createdAt
ModerationDecision: id, exercisePostId, reviewerId, decision, reason, createdAt
```

## 26. Upload và video-processing pipeline

Tạo upload session:

```http
POST /v1/video-uploads
Authorization: Bearer <token>
```

```json
{
  "file_name": "pushup-demo.mov",
  "mime_type": "video/quicktime",
  "size_bytes": 52428800,
  "sha256": "optional-client-hash"
}
```

Response:

```json
{
  "asset_id": "uuid",
  "upload_url": "short-lived-signed-url",
  "expires_at": "ISO-8601",
  "required_headers": {}
}
```

Client upload thẳng storage. Sau upload, storage event hoặc complete endpoint tạo job. Server phải probe object thật, không tin extension/MIME từ client.

Giới hạn MVP cấu hình server-side:

- 100–200 MB/video.
- Tối đa 2 phút.
- MP4/MOV.
- Một người chính.
- 3–30 rep.
- Push-up side-view.

Worker stages:

```text
uploaded → validating → scanning → probing → transcoding
→ pose_extracting → rep_segmenting → template_generating
→ moderation_pending/ready
```

Mỗi stage phải idempotent, retryable, có error code đọc được. Client poll/realtime trạng thái; không giữ HTTP request dài đến khi hoàn tất.

Output:

- Playback H.264/AAC hoặc adaptive streaming.
- Normalize orientation.
- Thumbnail đã bỏ metadata không cần thiết.
- CDN URL không lộ storage credential.
- Private content dùng signed playback URL.
- Lifecycle rule dọn upload dở/temp artifacts.

## 27. Tạo movement template

Pipeline worker:

1. Decode video theo sample rate cấu hình.
2. Chạy MediaPipe với schema landmarks tương thích mobile.
3. Chọn một người chính; reject nếu nhiều người làm pose không ổn định.
4. Kiểm tra required landmarks và pose coverage.
5. Normalize translation theo hip/torso center.
6. Normalize scale theo torso/shoulder size.
7. Canonicalize camera side và left/right.
8. Tính joint angles, normalized distances và torso orientation.
9. Làm mượt.
10. Segment top/descending/bottom/ascending và từng rep.
11. Loại outlier khỏi reference aggregate nhưng báo creator.
12. Tạo reference ranges, tempo và quality report.

Quality report:

```json
{
  "usable": true,
  "detected_reps": 8,
  "pose_coverage_percent": 96.2,
  "camera_view_match": true,
  "warnings": ["Rep 7 mất landmark cổ tay"],
  "suggested_trim": {"start_ms": 1800, "end_ms": 21800}
}
```

Creator phải preview và xác nhận trước publish. Không dùng một video creator để huấn luyện classifier tổng quát.

## 28. Nhận dạng bài tập

MVP:

- Creator bắt buộc chọn `push_up`.
- Hệ thống kiểm tra video có tương thích push-up side-view.
- Confidence thấp thì yêu cầu video khác hoặc chỉnh metadata.

Sau MVP mới xây classifier từ dataset normalized landmark features. Phải có class `unknown`, dữ liệu đa dạng về người/góc quay/môi trường, và creator vẫn xác nhận. Gemini không làm classifier chính.

## 29. So sánh người tập với template

Không so pixel/tọa độ màn hình. So sánh:

- Joint angles.
- Normalized pairwise distances.
- Torso orientation.
- Phase duration ratio.
- Range of motion.
- Left/right symmetry.

MVP dùng phase matcher:

```text
top → descending → bottom → ascending → top
```

Người dùng tập theo tốc độ riêng. So feature trong cùng phase với range template; không phạt chỉ vì nhanh/chậm nếu vẫn trong giới hạn.

Scoring giải thích được:

```text
35% range of motion
25% body alignment
20% left/right balance
10% tempo similarity
10% stability
```

Lưu component score, không chỉ tổng:

```json
{
  "overall": 82,
  "range_of_motion": 76,
  "body_alignment": 91,
  "left_right_balance": 84,
  "tempo": 79,
  "stability": 87
}
```

Không mô tả điểm 100 là kỹ thuật hoàn hảo. Đây là mức phù hợp với template theo metric quan sát được.

Realtime cue do rule engine on-device tạo và có debounce/cooldown:

- Xuống sâu hơn.
- Giữ thân ổn định.
- Hai bên chưa đều.
- Chậm lại.
- Lùi xa camera.
- Đúng nhịp.

Ưu tiên lỗi camera/pose trước nhận xét technique. DTW chỉ thêm sau khi phase matcher có benchmark.

## 30. Sharing và deep link

Route:

```text
https://<domain>/workouts/<public-id-or-slug>
```

- Có app: mở detail page bằng deep link.
- Chưa có app: landing/web preview và link cài.
- Private: yêu cầu account có quyền.
- Unlisted: ai có link xem được, không index/search.
- Public: xuất hiện search/profile sau moderation.
- Share sheet hỗ trợ link và QR.
- Không đưa access token dài hạn vào URL.

Không công khai kết quả trainee mặc định.

## 31. UX Phần 2

Creator:

```text
Create → chọn push-up → hướng dẫn góc quay → chọn/quay video
→ metadata → upload progress → processing
→ preview skeleton/rep markers → visibility
→ review/publish → share
```

Trainee:

```text
Open link → video detail → watch instructions → Start
→ permission → placement/calibration → countdown
→ phase-based training → result → AI feedback
→ login optional để sync
```

Phải xử lý UI cho upload lỗi/hết hạn, codec không hỗ trợ, video quá lớn/dài, không thấy hoặc nhiều người, pose coverage thấp, sai camera view, thiếu rep, processing failed và moderation rejected/removed.

## 32. Moderation, verification và bản quyền

Tách rõ:

```text
visibility: private | unlisted | public
moderation: pending | approved | rejected | removed
verification: unverified | coach_verified
```

Yêu cầu:

- Scan cơ bản cả upload private.
- Public theo workflow moderation đã định nghĩa.
- Có report, admin takedown và audit log.
- Creator xác nhận quyền dùng video/nhạc/nội dung.
- Policy cho nội dung nguy hiểm và impersonation.
- AI không được tự gắn `coach_verified`.
- Có appeal tối thiểu trước public launch.

MVP nên invite-only cho quyền publish public.

## 33. API tối thiểu Phần 2

```text
GET/PATCH/DELETE /v1/me

POST /v1/video-uploads
POST /v1/video-uploads/{id}/complete
GET  /v1/video-assets/{id}

POST   /v1/exercise-posts
GET    /v1/exercise-posts/{publicId}
PATCH  /v1/exercise-posts/{id}
DELETE /v1/exercise-posts/{id}
POST   /v1/exercise-posts/{id}/publish
GET    /v1/me/exercise-posts

GET  /v1/processing-jobs/{id}
GET  /v1/movement-templates/{id}
POST /v1/exercise-posts/{id}/attempts
GET  /v1/me/attempts
POST /v1/exercise-posts/{id}/reports
```

API cần pagination, object-level authz, idempotency và versioning.

## 34. Test strategy Phần 2

Auth/security:

- Không đọc/sửa/xóa private object người khác.
- Token expired/revoked và account deletion.
- Signed URL hết hạn/scope đúng.
- MIME spoof, oversize, malicious filename.
- Rate limit auth/upload/report.

Processing:

- Idempotent retry và storage event lặp.
- Corrupt/unsupported/orientation video.
- Không/một/nhiều người.
- Pose coverage thấp, thiếu rep.
- Worker crash giữa stage.

Template/comparison:

- Normalize scale/translation/mirror.
- Người nhanh/chậm hơn reference.
- Khác tỷ lệ cơ thể và sai camera view.
- Phase/scoring boundaries.
- Schema migration/version mismatch.

Sharing/moderation:

- Deep link installed/not installed.
- Public/unlisted/private.
- Guest không sync mặc định.
- Link/QR không chứa credential.
- Report/approve/reject/remove/audit.

## 35. Security, privacy và cost control Phần 2

- Storage private by default.
- Signed URL ngắn hạn.
- CDN auth đúng visibility.
- Scan file/content; strip metadata.
- Encryption transit/at rest.
- Per-user upload/storage quota.
- Queue concurrency và worker timeout.
- Lifecycle dọn temp/upload dở.
- Account deletion/retention jobs.
- Consent riêng cho upload/public sharing.
- Cập nhật Privacy Policy cho account/video/moderation/AI.
- Không dùng fitness/video cho quảng cáo hoặc training ngoài consent/policy.
- Dashboard và alert storage, egress, transcode, worker, database, Gemini.

## 36. Kế hoạch phase Phần 2

### P2-Phase 0 — Architecture spike, 3–5 ngày

- Chọn managed auth/database/storage/queue/deployment.
- Threat model, data flow và cost estimate.
- Prototype signed upload + processing job.
- Khóa schema v1.

Exit: upload không qua app server; worker xử lý được object; client không có secret.

### P2-Phase 1 — Account, 1 tuần

- Register/login/logout/reset/profile/delete.
- Secure token storage.
- Backend authz tests.

Exit: auth lifecycle hoàn chỉnh và không truy cập object người khác.

### P2-Phase 2 — Upload/processing, 1–2 tuần

- Signed URL, progress/retry.
- Probe/scan/transcode/thumbnail.
- Queue/job status và storage lifecycle.

Exit: video tốt tạo playback; video lỗi có code rõ; retry không tạo trùng.

### P2-Phase 3 — Push-up template generator, 2 tuần

- Pose extraction/normalization/segmentation.
- Quality report và template v1.
- Creator preview/confirm.
- Dataset tests.

Exit: side-view chuẩn tạo template; video không đạt bị reject đúng lý do.

### P2-Phase 4 — Post/sharing, 1–2 tuần

- CRUD post và visibility.
- Publish workflow.
- Deep link/web landing/share/QR.
- Creator profile/list.

Exit: guest mở public/unlisted; private authz đúng; link không có secret.

### P2-Phase 5 — Tập theo template, 2 tuần

- Download/cache template và video player.
- Phase matcher/component scoring/realtime cues.
- Result + Gemini tái sử dụng.
- Attempt sync cho account.

Exit: khác tốc độ vẫn match phase; score giải thích được; cache xong có thể tập offline.

### P2-Phase 6 — Moderation/public beta, 1–2 tuần

- Report/reviewer/admin/takedown/audit.
- Invite-only public creator.
- Analytics/cost monitoring.
- Cập nhật policy/store declarations.

Exit: public content theo moderation; report/takedown end-to-end; quota/alerts hoạt động.

## 37. Release gate Phần 2

- Account lifecycle/deletion pass.
- Object-level authorization đã test.
- Signed upload/media không lộ private storage.
- Processing idempotent.
- Template success đạt mục tiêu trên video chuẩn.
- Phase matcher/scoring benchmark nhiều người/tốc độ.
- Visibility đúng.
- Moderation/report/takedown sẵn sàng.
- Privacy/store disclosures cập nhật.
- Cost alerts hoạt động.
- Guest mở link → tập → result không bị buộc login.

## 38. Deliverable kết thúc PHẦN 2

- Managed auth và account deletion.
- Signed video upload.
- Background processing pipeline.
- Push-up template generator.
- Creator preview/publish.
- Public/unlisted/private post.
- Deep link và share/QR.
- Guest xem/tập theo.
- Phase comparison, component scores, realtime cues.
- Attempt sync cho account.
- Gemini feedback tái sử dụng.
- Moderation/report/admin tối thiểu.
- Security/privacy/cost monitoring và test suite.

## 39. Prompt dành cho coding agent

Bắt đầu Phần 1:

```text
Đọc toàn bộ IMPLEMENTATION_PLAN.md và repo. Chỉ triển khai Phase 0 trong mục 16 của PHẦN 1. Không làm account, upload hoặc sharing. Chạy analyze/test/build và báo cáo exit criteria.
```

Bắt đầu Phần 2 sau release gate:

```text
Đọc toàn bộ IMPLEMENTATION_PLAN.md. Xác minh release gate mục 21 bằng code và test. Nếu đạt, chỉ triển khai P2-Phase 0 trong mục 36; chưa tích hợp provider trước khi architecture spike được duyệt.
```
