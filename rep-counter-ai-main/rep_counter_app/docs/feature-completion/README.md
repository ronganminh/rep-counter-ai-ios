# Bổ sung chức năng sau Phase 8

Ngày 28/09/2026. Tiếp tục yêu cầu hoàn thiện các thao tác còn thiếu trên UI mới.
Email góp ý được chủ app xác nhận là `ronganminh221@gmail.com`; app hiện đang
thử nghiệm trên Google Play, chưa có trang App Store.

## Đã triển khai

| Chức năng | Hành vi |
| --- | --- |
| Story kết quả | Mở từ nút Chia sẻ ở kết quả hoặc chi tiết lịch sử. PNG 1080 × 1920 dùng số liệu thật của bản ghi và nhận xét hiện có; nhận xét dài rút gọn bằng dấu ba chấm. Không dùng ảnh camera. |
| Lưu ảnh | Chỉ hỏi quyền thêm ảnh khi bấm Lưu ảnh. Thành công mới báo đã lưu; có xử lý từ chối quyền, lỗi bộ nhớ và lỗi xuất ảnh. |
| Chia sẻ | Mở bảng chia sẻ hệ thống với PNG; có vị trí neo cho iPad. Hủy bảng chia sẻ không báo thành công giả. App đích quyết định có hỗ trợ đăng story trực tiếp hay không. |
| AI tự động | Mặc định tắt. Bật tại Cài đặt → AI tự động sau khi đọc và đồng ý thông báo dữ liệu gửi đi. Chỉ kích hoạt sau khi lưu buổi tập mới. Không tự gửi khi xem lịch sử. |
| Lỗi AI | Giữ kết quả local, hiển thị lỗi và cho thử lại. Dùng nguyên endpoint/payload tổng hợp và cơ chế lưu nhận xét hiện có. Không gửi ảnh, video, landmark hoặc chi tiết từng rep. |
| Âm báo set | Công tắc lưu trên máy, mặc định tắt. Âm bắt đầu/kết thúc theo chuyển trạng thái working/resting của SessionTracker cũ. Không phát do rebuild widget. |
| Nhắc tư thế | Dùng placement status và cờ chất lượng từ analyzer cũ; tối đa một nhắc mỗi 8 giây. Có công tắc riêng, đồng thời tuân theo công tắc giọng đọc. Không thay đổi số rep. |
| Góp ý | Mở bản nháp email, người dùng tự gửi. Nếu máy không mở được email, hiện địa chỉ và nút sao chép. |
| Đánh giá | Android mở Google Play với applicationId `com.ronganminh.repcoach`. Bản test cần tài khoản có quyền truy cập. iOS thông báo chưa có listing; sau này cấu hình `--dart-define=APP_STORE_ID=<numeric-id>`. |
| Bài tập | Nối lại 4 profile có sẵn: hít đất, kéo xà, curl tạ, duỗi tay sau qua đầu. Chọn bài → mục tiêu → camera nhận đúng profile, dùng hướng dẫn cũ. Bộ lọc lịch sử và trang hiệu chỉnh hiển thị đủ 4 bài. |

Tắt AI tự động ngăn yêu cầu mới, không thu hồi yêu cầu đã gửi. Nút yêu cầu AI
thủ công vẫn hoạt động. Chính sách quyền riêng tư và mô tả trên kết quả đã cập
nhật cho cả tiếng Việt/Anh. Bản HTML privacy/support và mô tả Data Safety trong
repo cũng được đồng bộ; chưa triển khai website hoặc sửa thông tin trên Play Console.

Âm WAV ngắn được tạo riêng cho app, không lấy từ nguồn bên ngoài. Thêm plugin
[share_plus](https://pub.dev/packages/share_plus), [gal](https://pub.dev/packages/gal),
[url_launcher](https://pub.dev/packages/url_launcher) và
[audioplayers](https://pub.dev/packages/audioplayers). iOS khai báo quyền chỉ thêm
ảnh; Android khai báo WRITE_EXTERNAL_STORAGE giới hạn maxSdkVersion 29 theo Gal.

## Kiểm tra

- `flutter analyze --no-pub`: sạch.
- `flutter test --no-pub`: **302 test qua**, gồm 23 test mới.
- Test mới bao phủ consent, không upload lịch sử, lỗi mạng, persist cài đặt,
  throttle giọng nói, âm báo, route của 4 bài, xuất PNG đúng kích thước,
  màn hình 320 px/text 2x và lỗi lưu ảnh.
- Test Phase 3 cập nhật số dòng “Chưa hiệu chỉnh”: cả 4 profile hiện được hiển thị.
  Vẫn kiểm tra reset chỉ xóa bài được chọn và giữ nguyên bài khác.
- Đối chiếu 13 file counter/exercise/placement/pose mapper/workout domain với ZIP
  gốc: byte-identical. Không sửa công thức hoặc ngưỡng engine.
- [Ảnh story từ widget test](story-fixture.png) dùng **fixture chỉ trong test**,
  không phải buổi tập người dùng và không được thêm vào lịch sử production.

Tái tạo ảnh:

```bash
flutter test test/feature_completion_test.dart \
  --dart-define=FEATURE_SCREENSHOTS=docs/feature-completion
```

### Build iOS trên máy này

`xcode-select -p` hiện trỏ đến Command Line Tools. `hooks_runner` lọc bỏ
`DEVELOPER_DIR` khi chạy build hook `objective_c`, khiến `xcrun` không tìm thấy
SDK iOS dù lệnh Flutter đã chỉ định Xcode. `tool/build_ios.sh` tạo wrapper xcrun
tạm trong PATH (biến PATH vẫn được hooks giữ lại), chọn Xcode cho riêng build,
rồi tự dọn wrapper. Không sửa plugin trong pub cache hoặc cấu hình toàn máy.

```bash
FLUTTER_BIN=/tmp/repcoach-flutter-sdk/bin/flutter \
  tool/build_ios.sh --simulator --debug --no-pub
FLUTTER_BIN=/tmp/repcoach-flutter-sdk/bin/flutter \
  tool/build_ios.sh --release --no-codesign --no-pub
```

- Build simulator debug và iPhone release không ký: thành công (68.6 MB).
- Đã cài/mở trên `RepCoach iPhone 17 Pro`, iOS 26 Universal, app x86_64 qua Rosetta.
- [Ảnh native sau khi mở app](ios26-launch.png) xác nhận màn Home mới khởi chạy;
  không phải bằng chứng đã thao tác camera/Photos/share sheet trên máy thật.
- Bộ ML Kit cũ vẫn cảnh báo không hỗ trợ simulator arm64; iOS 27 ARM-only chưa dùng được.
- Lần build đầu báo SwiftCompile không có output; build lại qua được bước Swift.
  Lỗi build hook SDK được giải quyết bằng script nêu trên.

## Phần còn lại

- **Hiệu chỉnh tự kết thúc đúng 3 rep:** chưa bật. Mục 9.6 của migration guide yêu
  cầu giữ Calibrator cũ đến khi có bằng chứng 3 rep đủ ổn định. Hiện app thu mẫu
  thật, kiểm tra số mẫu/biên độ và người dùng bấm hoàn tất. Cần video/thiết bị thật
  để kiểm chứng trước khi đổi điểm kết thúc; không dựng tiến độ rep giả.
- **Squat, gập bụng, lunge, jumping jack:** chưa có engine tương ứng. Vẫn ghi Sắp
  ra mắt; cần profile, placement, bộ đếm và bộ dữ liệu đánh giá riêng.
- **Phase 9 kiểm tra thiết bị/phát hành:** camera, skeleton, 10 rep thật, giọng nói,
  âm báo, rung, bảng chia sẻ và quyền Photos cần thử trên máy thật. Widget tests
  dùng driver/exporter giả; không khẳng định đã thực hiện các thao tác native đó.
- Chưa có signing team/Apple listing để phát hành iOS. Không upload store, không
  gửi email hay chia sẻ nội dung thay người dùng trong quá trình kiểm tra.
- Mac chưa có Android SDK được cấu hình; thay đổi Dart dùng chung đã được test,
  bản Android cần build/kiểm tra trong môi trường Android trước khi cập nhật track.
