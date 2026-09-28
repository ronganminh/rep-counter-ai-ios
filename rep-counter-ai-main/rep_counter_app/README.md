# rep_counter_app — đếm rep thời gian thực

Flutter + **MediaPipe Pose** (qua `google_mlkit_pose_detection`), chạy hoàn toàn
trên máy, không cần mạng.

## Trạng thái: CHƯA CHẠY THỬ TRÊN MÁY THẬT

**Cập nhật migration 27/09/2026:** đã build thành công iOS device không ký và
simulator x86_64 bằng Flutter 3.47.5 / Xcode 27. Home, History, Settings đã chuyển
sang thiết kế mới; xem `../MIGRATION_NOTES.md`. Camera/ML Kit chưa được kiểm tra
trên iPhone thật. Bản simulator chưa cài được vào runtime iOS 27 ARM do ML Kit
cũ chỉ có simulator x86_64. Phân biệt rõ hai phần:

**Cập nhật Phase 4:** đã tách controller buổi tập, 173 kiểm thử qua. Đã cài và mở
app thành công trên iOS 26 Universal (runtime boot ARM64, app x86_64 qua Rosetta),
có ảnh onboarding native tại `docs/phase4/ios26-onboarding.png`. Xem README ở
gốc workspace để dùng đúng lệnh chạy. Chưa xác minh nhận diện trên iPhone thật.

| Phần | Mức độ tin cậy |
|---|---|
| `lib/rep_counter.dart` — lõi đếm | **có test đối chiếu số liệu Python**, chạy `flutter test` là biết |
| `lib/exercise.dart`, `placement.dart` | logic thuần, đọc kỹ được nhưng chưa chạy |
| `lib/camera_page.dart` — camera + ML Kit | **rủi ro nhất**, chưa chạy lần nào |

Chỗ dễ hỏng nhất là `_toInputImage` và `PoseMapper` — xoay ảnh và đổi hệ toạ độ
giữa các đời `camera` / `google_mlkit_pose_detection` hay đổi API. Nếu khung xương
vẽ lệch khỏi người, lỗi gần như chắc chắn nằm ở hai chỗ đó.

## Chạy

```bash
cd rep_counter_app
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
flutter pub get
flutter test                               # kiểm tra lõi đếm trước
flutter run
```

Cần thêm:

- **Android** — `minSdkVersion 21` trở lên trong `android/app/build.gradle`, và
  `<uses-permission android:name="android.permission.CAMERA"/>` trong `AndroidManifest.xml`.
- **iOS** — project, camera usage description và CocoaPods đã có; minimum iOS 15.5.
  Mở `ios/Runner.xcworkspace`, chọn Signing Team khi chạy trên iPhone thật.

## Ngưỡng mặc định KHÔNG dùng thẳng được

Các ngưỡng trong `exercise.dart` lấy từ notebook Python, nơi keypoint do
**YOLO11-pose (COCO-17)** sinh ra. MediaPipe dùng **33 điểm**, đánh số khác và
chuẩn hoá khác, nên cùng một động tác cho ra dải giá trị khác.

Vì vậy app có sẵn nút **Hiệu chỉnh** (biểu tượng ⚙ góc trên phải):

1. Vào đúng khung, bấm Hiệu chỉnh.
2. Tập 3–5 rep bình thường.
3. Bấm lại — app lấy phân vị 10 % / 90 % của tín hiệu vừa ghi, đặt `lo` và `hi`
   vào 1/3 và 2/3 khoảng dao động, `minAmp` bằng nửa biên độ.

Đây đúng là cách ô "Dò ngưỡng tự động" trong notebook làm, và nó còn tự thích ứng
theo tầm vận động của từng người.

## Khung hướng dẫn và màu

| Màu | Trạng thái | Đếm rep? |
|---|---|---|
| Đỏ | chưa thấy người | không |
| Hổ phách | thấy người nhưng lọt khung / sai khoảng cách / sai hướng thân | không |
| Xanh lá | đạt | **có** |

Viền khung còn **đổi từ nét đứt sang nét liền** khi đạt, để người mù màu đỏ–lục
vẫn phân biệt được.

**App chỉ đếm khi xanh lá.** Đây không phải chi tiết trang trí: không có chốt này
thì mỗi lần bước vào hay ra khỏi khung đều tạo một cú vượt ngưỡng và cộng oan một
rep.

Bốn tiêu chí chấm trong `placement.dart`:

1. Đủ các keypoint bài tập cần (cho phép thiếu tối đa 25 %).
2. Các điểm nằm trong khung hướng dẫn (cho phép 20 % ra ngoài).
3. Bề rộng vai so với cạnh ngắn khung → quá nhỏ là "lại gần", quá lớn là "lùi ra".
4. Góc trục thân (vai giữa → hông giữa) khớp hướng bài yêu cầu.

## Vì sao khung hướng dẫn quan trọng hơn nó trông có vẻ

Trên bộ 7 video hít đất thật, cùng một bài và cùng một thuật toán, tỉ lệ frame đủ
keypoint chênh nhau rất xa **chỉ vì góc đặt máy**:

| Video | Đủ 6 keypoint thân trên |
|---|---|
| `IMG_5087.MOV` | 98.8 % |
| `100pushup.mp4` | 72.2 % |

Và chỗ hỏng **không rải đều — nó dồn đúng vào đáy mỗi rep**, khi đầu lấp đầy khung
và người bị khung cắt (~1.8 lần mất keypoint mỗi rep, mỗi lần ~0.21 s). Đáy chính
là thứ định nghĩa một rep.

Dùng model to hơn không cứu được: `yolo11x-pose` ở `imgsz=960` cũng chỉ đủ keypoint
ở 1/8 frame đáy. Đây là giới hạn của góc quay, không phải của model.

Nên với hít đất, khung hướng dẫn vẽ **thân người nằm ngang** và nhắc đặt máy
**ngang hông, quay từ bên sườn** — không phải quay trực diện từ phía trước.

## Khác biệt so với notebook

| Thành phần | Trạng thái |
|---|---|
| Công thức 3 tín hiệu | port sang, đổi chỉ số keypoint COCO → MediaPipe |
| `detect_reps` (trigger Schmitt) | **giữ nguyên** — vốn đã nhân quả |
| `merge_arms` | giữ nguyên |
| Làm mượt | **thay** Savitzky-Golay bằng trung bình trượt — SG đối xứng cần mẫu tương lai |
| `group_sets` | **viết lại** nhân quả: quá `restTimeout` không có rep thì chốt set |
| Vẽ video 2 lượt | bỏ |

`group_sets` của notebook gom set bằng cả rep **tương lai** — đúng cho phân tích
video nhưng không thể dùng khi đang quay trực tiếp.

## Tinh chỉnh

| Triệu chứng | Sửa |
|---|---|
| Đếm thiếu (không hết tầm) | Hiệu chỉnh lại, hoặc hạ `repHi` |
| Đếm dư khi đứng nghỉ | Nâng `minAmplitude` |
| Một nhịp thành hai | Nâng `minPeriod`, tăng cửa sổ `RollingMean` |
| Màu nhấp nháy liên tục | Nâng `StatusDebouncer.needed` |
| Khó vào được trạng thái xanh | Nới `shoulderWidthFraction`, `torsoAngleTolerance` |
| Máy nóng / tụt fps | Giữ `ResolutionPreset.medium`, hoặc bỏ frame xen kẽ |
