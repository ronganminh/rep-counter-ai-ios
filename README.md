# RepCoach AI — Flutter / iOS

App Flutter đang phát triển tại [`rep-counter-ai-main/rep_counter_app`](rep-counter-ai-main/rep_counter_app).
Thiết kế tham chiếu: [`design-handoff`](design-handoff). Tiến độ và quyết định migration:
[`MIGRATION_NOTES.md`](rep-counter-ai-main/MIGRATION_NOTES.md).

## Chạy trên Mac

```bash
cd rep-counter-ai-main/rep_counter_app
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
export PATH="/tmp/repcoach-flutter-sdk/bin:$PATH"
flutter pub get
flutter analyze
flutter test
flutter devices
# Dùng lệnh build/cài simulator bên dưới.
```

Flutter SDK hiện nằm trong `/tmp/repcoach-flutter-sdk`; nếu thư mục tạm bị dọn,
cài Flutter lại và dùng đường dẫn SDK của bạn. iOS dùng CocoaPods, minimum iOS 15.5.
Mở `rep-counter-ai-main/rep_counter_app/ios/Runner.xcworkspace` bằng Xcode để chọn
Signing Team trước khi cài lên iPhone thật.

## Giao diện mới hiện tại

- Đã thay các màn còn dùng UI cũ: onboarding, quyền camera, chuẩn bị/hiệu chỉnh,
  HUD đếm rep, tạm dừng, lưu, kết quả, hướng dẫn và trang pháp lý.
- Home, chọn bài, mục tiêu, History và Settings dùng thiết kế mới; mọi số liệu
  production lấy từ engine/store thật. Kết quả mới có điểm form và nhịp từng rep;
  lịch sử cũ thiếu chi tiết vẫn đọc được.
- Giữ nguyên thuật toán đếm, ML Kit mapping và placement. Hiệu chỉnh lấy mẫu thật.
- Phase 6: bắt đầu sau khi tư thế ổn định và đếm ngược 3–2–1; chuẩn bị/hiệu chỉnh
  không cộng rep hoặc thời gian tập. Có giọng đọc, rung và công tắc lưu lựa chọn.
- Phase 7: hoàn thiện màn kết quả, vòng vượt mục tiêu, thẻ nhận xét AI/offline,
  thử lại khi lỗi mạng và thử lưu lại nhận xét khi lỗi bộ nhớ.
- Phase 8: chi tiết lịch sử, nhịp theo set, lưu loại lưu ý từng rep, xóa/hoàn tác
  và đọc lịch sử cũ; không cần đổi kho dữ liệu.
- Bổ sung sau Phase 8: ảnh story/lưu/chia sẻ, AI tự động có consent, âm báo set,
  nhắc tư thế, email góp ý/Google Play và mở lại 4 bài có engine.
  [Chi tiết và phần còn lại](rep-counter-ai-main/rep_counter_app/docs/feature-completion/README.md).
- `flutter analyze`: sạch. `flutter test`: **302 test qua**.
- Build simulator debug và iPhone release (không ký) thành công; bản mới **đã cài và mở** trên
  `RepCoach iPhone 17 Pro` (`1B9AAA8C-CF32-4A9E-B6AC-E212674078AE`).
- [Ảnh onboarding mới từ simulator](rep-counter-ai-main/rep_counter_app/docs/phase4/ios26-onboarding.png).
  [Bộ ảnh và phạm vi migration](rep-counter-ai-main/rep_counter_app/docs/new-ui/README.md).
- Runtime iOS 26 Universal boot bằng **ARM64**; app x86_64 chạy qua Rosetta 2.
  ML Kit hiện tại chưa hỗ trợ simulator iOS 27 ARM-only.
- Camera, skeleton alignment và 10 rep thực tế cần kiểm tra trên iPhone thật.
  Giọng đọc và rung cũng cần nghe/cảm nhận trên thiết bị thật.
- [Chi tiết Phase 6 và ảnh giao diện](rep-counter-ai-main/rep_counter_app/docs/phase6/README.md).
- [Chi tiết Phase 7 và ảnh kết quả](rep-counter-ai-main/rep_counter_app/docs/phase7/README.md).
- [Chi tiết Phase 8 và ảnh lịch sử/nhịp rep](rep-counter-ai-main/rep_counter_app/docs/phase8/README.md).

### Lệnh đã dùng thành công với simulator iOS 26

Chạy từ `rep-counter-ai-main/rep_counter_app`, với `DEVELOPER_DIR` và Flutter PATH như trên.
Bỏ lệnh `boot` nếu thiết bị đã chạy:

```bash
xcrun simctl boot 1B9AAA8C-CF32-4A9E-B6AC-E212674078AE --arch=arm64
tool/build_ios.sh --simulator --debug
xcrun simctl install 1B9AAA8C-CF32-4A9E-B6AC-E212674078AE build/ios/iphonesimulator/Runner.app
xcrun simctl launch 1B9AAA8C-CF32-4A9E-B6AC-E212674078AE com.ronganminh.repCounterApp
```

`tool/build_ios.sh` giữ lựa chọn Xcode cho cả native build hooks khi máy đang
chọn Command Line Tools mặc định. Script chỉ tạo wrapper tạm, không thay đổi
`xcode-select`. Nếu Flutter chưa có trong PATH, thêm
`FLUTTER_BIN=/tmp/repcoach-flutter-sdk/bin/flutter` trước lệnh script.

Trong Xcode 27, mở **Xcode → Open Developer Tool → Device Hub** và chọn thiết bị trên.

Ảnh render từ widget test có thể tạo bằng:

```bash
flutter test test/phase3_visual_test.dart \
  --dart-define=PHASE3_SCREENSHOTS=/tmp/repcoach-phase3
```

Đây là ảnh render kiểm tra giao diện, không phải ảnh app đang chạy trong simulator.
Ảnh hiện tại: [Home](rep-counter-ai-main/rep_counter_app/docs/phase3/home.png),
[History](rep-counter-ai-main/rep_counter_app/docs/phase3/history.png),
[Settings](rep-counter-ai-main/rep_counter_app/docs/phase3/settings.png).
