# Phase 6 — Hiệu chỉnh, đếm ngược và phản hồi

Hoàn thành phần triển khai ngày 27/09/2026 theo migration guide.

## Luồng hoạt động

1. Chọn bài/mục tiêu, mở camera, nhấn **Vào vị trí & bắt đầu**.
2. Engine xác nhận tư thế hợp lệ liên tục 1,5 giây, sau đó hiện **3 → 2 → 1**.
3. Sau đếm ngược mới nhận rep và chạy thời gian tập. Khung hình chuẩn bị và
   hiệu chỉnh không đóng góp vào thống kê chất lượng buổi tập.
4. Mất tư thế hoặc không nhận frame mới trong 750 ms sẽ hủy đếm ngược;
   cần ổn định tư thế lại rồi bắt đầu từ 3. Placement grace của buổi tập không
   được dùng để vượt qua điều kiện này.
5. Tạm dừng/ra nền hủy đếm ngược và lời đọc đang chờ. Nếu buổi tập đã bắt đầu,
   tiếp tục giữ nguyên số rep/thời gian và không đếm ngược lần nữa.

## Hiệu chỉnh và mục tiêu

- Giao diện dùng số mẫu thực tế và ngưỡng do calibrator cũ tính. Hiệu chỉnh thủ
  công vẫn được giữ; không mô phỏng quy trình hoàn tất sau đúng ba rep.
- Trong lúc hiệu chỉnh, rep và đồng hồ tập dừng. Chỉ thông báo đã lưu khi
  `CalibrationStore.save` trả về thành công. Nếu lưu thất bại, ngưỡng vừa tính
  vẫn dùng trong buổi hiện tại và UI báo rõ chưa lưu được.
- Banner đạt mục tiêu xuất hiện một lần trong ba giây; tiếp tục đếm vượt mục
  tiêu. Giọng đọc và rung nhận cùng sự kiện đạt mục tiêu một lần.

## Giọng đọc và rung

- `flutter_tts` 4.2.5 dùng giọng hệ thống theo ngôn ngữ app: `vi-VN`/`en-US`.
  [Tài liệu plugin](https://pub.dev/packages/flutter_tts).
- Đọc đếm ngược, bắt đầu, số rep và đạt mục tiêu. Sự kiện mới thay lời đọc cũ;
  pause/mute/dispose loại bỏ sự kiện đang chờ, không đọc bù rep cũ.
- Rung nhẹ cho nhịp đếm/rep, rung mức medium khi bắt đầu/đạt mục tiêu.
- Settings có hai công tắc thực; HUD có bật/tắt giọng đọc. Lựa chọn lưu cục bộ
  bằng `training_voice_v1` và `training_haptics_v1`, mặc định bật.
- Thiếu giọng hệ thống hoặc plugin lỗi: thông báo một lần, engine vẫn chạy.
  Không thêm quyền microphone. Android khai báo truy vấn TTS service.

## Phạm vi thay đổi

- Controller quản lý cổng bắt đầu và timer countdown; clock theo dõi frame tách
  khỏi clock thời gian tập. CameraPage chuyển sự kiện sang feedback service.
- 13 file engine/domain (counter, exercise, placement, pose mapper và toàn bộ
  workout domain) đã so sánh byte với ZIP cũ: giống nguyên bản.
- Công thức, camera conversion/coordinate mapping và AI payload giữ nguyên.
  `CalibrationStore.save` đổi kết quả từ `void` sang `bool` để UI phản ánh lỗi lưu;
  key, dữ liệu lưu và công thức hiệu chỉnh không đổi.

## Kiểm tra và hình ảnh

- `flutter analyze --no-pub`: không có lỗi.
- `flutter test --no-pub`: **214 test qua**.
- Bao phủ start intent, 3–2–1, mất tư thế, frame bị ngắt, calibration, lifecycle,
  finish/abort, hàng đợi giọng đọc, mute, thiếu giọng, haptic và lưu công tắc.
  Widget chạy ở màn hình hẹp và chữ 2x; các regression test engine cũ vẫn qua.
- Build iOS simulator debug và iPhone release không ký: thành công.
- Đã cài và mở bản Phase 6 trên **RepCoach iPhone 17 Pro / iOS 26 Universal**,
  UUID `1B9AAA8C-CF32-4A9E-B6AC-E212674078AE` (ARM64 runtime, x86_64 app qua Rosetta).
- [Ảnh native sau khi mở app](ios26-launch.png): onboarding giao diện mới.
  Ảnh này chỉ xác nhận app native khởi chạy.
- Các ảnh sau là **render từ widget test**, HUD dùng fixture chỉ trong test:
  [Chuẩn bị](hud-positioning.png), [đếm ngược](hud-countdown.png),
  [hiệu chỉnh](hud-calibrating.png), [Settings](settings.png).

Tạo lại ảnh widget từ thư mục app:

```bash
flutter test test/new_ui_test.dart \
  --dart-define=NEW_UI_SCREENSHOTS=/tmp/repcoach-phase6-previews
flutter test test/phase3_visual_test.dart \
  --dart-define=PHASE3_SCREENSHOTS=/tmp/repcoach-phase6-tabs
```

## Cần kiểm tra trên iPhone thật

Chưa xác nhận camera/pose alignment và độ chính xác 10 rep ngoài đời; chưa nghe
giọng hoặc cảm nhận rung trên phần cứng. Test plugin dùng mock không xác nhận
những việc đó. Kiểm tra thêm giọng Việt/Anh đã cài, chế độ im lặng/âm thanh nhạc,
ra nền/quay lại trong countdown, hiệu chỉnh rồi tập và tiếp tục vượt mục tiêu.
Device Hub automation từng timeout; không coi việc cài/mở bằng simctl là kiểm tra
toàn bộ thao tác native. Story sharing và kiểm tra phát hành/TestFlight còn riêng.
