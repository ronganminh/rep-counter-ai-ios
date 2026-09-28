# Baseline — Phase 0

Ngày: 2026-09-01. Ghi lại trạng thái trước khi refactor, theo IMPLEMENTATION_PLAN §16 Phase 0.

## Kết quả baseline — đã xác nhận 2026-09-01

```text
flutter analyze   No issues found! (15.4s)
flutter test      00:02 +27: All tests passed!
```

27 test = 9 (rep_counter_test.dart) + 18 (pose_mapper_test.dart).

**Phase 0 đạt exit criteria**: test xanh, và test vector Python không bị sửa.

Lưu ý: máy dựng code không có Flutter SDK, nên hai lệnh trên do người dùng chạy.
`flutter build apk --debug` chưa chạy lại sau Phase 0.

Version đã khoá:

```text
camera                       0.11.4
camera_android_camerax       0.6.30
google_mlkit_pose_detection  0.14.1
google_mlkit_commons         0.11.1
permission_handler           11.4.0
flutter_lints                4.0.0
```

## Mức độ tin cậy từng file

| File | Đã kiểm chứng thế nào |
|---|---|
| `lib/rep_counter.dart` | Có test đối chiếu **từng frame** với bản Python (`test/rep_vector.json`) |
| `lib/features/pose/domain/pose_mapper.dart` | 18 test xanh; kỳ vọng đã kiểm chéo bằng bản mô phỏng Python |
| `lib/exercise.dart` | Logic thuần, đọc được, **chưa chạy** |
| `lib/placement.dart` | Logic thuần, **chưa chạy** |
| `lib/overlay_painter.dart` | **Chưa chạy** |
| `lib/camera_page.dart` | **Rủi ro cao nhất, chưa chạy lần nào** |

Chỗ dễ hỏng nhất là `_toInputImage` (định dạng ảnh, xoay) và việc nối `PoseMapper`.
Nếu khung xương vẽ lệch khỏi người trên thiết bị thật, lỗi gần như chắc chắn ở đó.

## Test vector Python — không được sửa

`test/rep_vector.json` sinh từ chính hàm `detect_reps` của notebook, trên một tín hiệu
tổng hợp có: dao động 1.2 s, một đoạn nghỉ 3 s ở tư thế duỗi thẳng, một đoạn mất pose
0.5 s, và nhiễu. Kỳ vọng là **13 rep tại đúng 13 frame index**.

Theo §18: nếu test này đỏ, sửa `rep_counter.dart`, **không sửa file vector**.

ADR 0002 đổi *nguồn* ngưỡng chứ không đổi lõi Schmitt, nên vector này vẫn còn giá trị
sau khi triển khai ngưỡng tự thích ứng.

## Ngưỡng hiện tại trong app so với ngưỡng đã kiểm chứng

`exercise.dart` đang dùng `repHi: 140, repLo: 100, minAmplitude: 40` — đo trên keypoint
**YOLO/COCO-17**, không phải MediaPipe. Đây là số tạm.

ADR 0002 ghi lý do chi tiết: ngưỡng cố định làm một trong 7 video đếm ra **3 rep thay
vì 103**. Chưa sửa trong Dart; để Phase 3.

## Độ chính xác đã đo (Python, không phải app)

39/41 rep (95%) trên 7 cửa sổ đếm bằng mắt, phủ 5/7 video, tổng 75 phút. Không cửa sổ
nào đếm dư. Chi tiết trong ADR 0002.

Con số này **chưa phải độ chính xác của app** — nó đo pipeline Python trên video quay
sẵn. Cần benchmark lại trên thiết bị theo §11.5.

## Đã làm trong Phase 0

- Tách `PoseMapper` khỏi `camera_page.dart` sang `features/pose/domain/`, không import
  ML Kit để test được thuần Dart.
- Thêm xử lý **góc xoay cảm biến** vào `PoseMapper` (trước đây caller tự hoán đổi w/h).
  Đây là thay đổi hành vi, có test riêng đánh dấu.
- Thêm `test/features/pose/pose_mapper_test.dart`: rotation 0/90/180/270, mirror
  camera trước, `BoxFit.cover` cắt ngang và dọc, 16:9 và 4:3, preview khác kích thước
  ảnh vào, và các trường hợp biên.
- Thêm `core/config/feature_flags.dart`; `main.dart` chỉ hiện push-up.
- ADR 0001 (pose on-device + AI server-side) và ADR 0002 (ngưỡng tự thích ứng).

## Phase 1 — domain buổi tập

`flutter analyze` sạch và toàn bộ test xanh (người dùng chạy, 2026-09-01).

Đã thêm `lib/features/workout/domain/`: `RepObservation`, `RepMetric`,
`RepQualityFlag`, `SetMetric`, `PoseQualityStats`, `QualityScore`,
`WorkoutSummary`, `RepTracker` (4 loại `RepEvent`), `RepQualityAnalyzer`,
`WorkoutAggregator`, `WorkoutPhase` — kèm 47 test Dart thuần.

`RepTracker` **bọc quanh** `RepCounter` chứ không sửa nó, để test vector Python
giữ nguyên giá trị (§18).

### Một lỗi đã gặp và cách sửa

`flutter analyze` báo `ambiguous_import`: `RepEvent` tồn tại ở cả `rep_counter.dart`
lẫn `rep_tracker.dart`. Đây là loại lỗi mà kiểm tra bằng mô phỏng Python không bắt
được — nó chỉ lộ khi trình biên dịch phân giải import.

Sửa bằng cách đổi `rep_counter.dart`: `RepEvent` -> `CountedRep`. Chọn đổi bên đó vì
`grep` xác nhận tên cũ chỉ dùng nội bộ file ấy (không có ở `camera_page.dart` hay
`rep_counter_test.dart`), và vì `CountedRep` đúng nghĩa hơn: nó là *kết quả* phép
đếm, còn `RepEvent` mới là *chuỗi sự kiện* của một chu kỳ. Đây là đổi tên thuần,
không đụng thuật toán.

## Việc cần làm ngay sau Phase 0

1. Build lên máy thật, chụp màn hình đối chiếu khung xương với người — đây là thứ
   duy nhất xác nhận được `PoseMapper`.
2. Đổi `applicationId` khỏi `com.example.rep_counter_app` **trước lần upload đầu tiên**
   (§14.1) — không đổi lại được sau đó.
