# Phase 7 — Màn kết quả buổi tập

Hoàn thiện ngày 27/09/2026, tiếp nối UI mới và Phase 6.

## Phần đã hoàn thành

| Yêu cầu | Triển khai |
| --- | --- |
| Result hero | Vòng 232 px, số rep thật; vòng lime cho tiến độ, cung xanh bằng tỷ lệ rep vượt mục tiêu. |
| Trạng thái mục tiêu | Dừng sớm có tỷ lệ và câu khích lệ; đạt/vượt mục tiêu có badge; tập tự do không hiện mẫu số mục tiêu. |
| Set và thời gian | Đọc trực tiếp `WorkoutRecord`: bài tập, set, thời gian tập, ngày giờ bắt đầu. |
| Điểm form | Dùng `WorkoutQuality`: tổng điểm và bốn thành phần. Thiếu dữ liệu thì thông báo rõ, không tạo điểm thay thế. |
| AI/offline | Một thẻ với nhãn nguồn rõ ràng, giữ nhận xét trên máy hoặc nhận xét đã lưu khi đang tải/lỗi. Có thử lại. |
| Hành động cố định | Nút Xong luôn ở đáy: kết quả buổi mới về Home, chi tiết lịch sử quay lại màn trước. |
| Dữ liệu thật | Không thêm số liệu hoặc phản hồi mẫu vào production; tất cả fixture nằm trong test. |

### Các trạng thái nhận xét

- **Chưa yêu cầu AI:** hiển thị nhận xét từ `RuleBasedFeedback` trên máy, nút yêu cầu AI và giải thích dữ liệu được gửi.
- **Đang tải:** hiển thị trạng thái tiến trình; không cho gửi trùng. Nội dung cũ vẫn đọc được. Khi giảm chuyển động bật, thanh trạng thái không chạy animation liên tục.
- **Đã nhận:** hiển thị nguyên văn phản hồi từ service và lưu vào buổi tập đã có.
- **Offline / timeout / lỗi server:** giữ nguyên số liệu buổi tập; hiển thị lỗi và nút thử lại. Nếu chưa có AI thì dùng nhận xét trên máy.
- **AI chưa cấu hình:** thông báo đúng trạng thái của bản build, dùng nhận xét trên máy và không hiện nút gửi không hoạt động.
- **Lỗi lưu nhận xét:** giữ nội dung vừa nhận, báo chưa lưu và cho **Thử lưu lại**; không gọi AI thêm lần nữa chỉ để thử ghi bộ nhớ.

`ResultController` quản lý các trạng thái này. Đóng/thay bản ghi sẽ bỏ qua phản
hồi cũ đến muộn. Mở kết quả hoặc lịch sử không tự gửi dữ liệu lên AI.
`WorkoutHistoryStore.saveFeedback` chỉ cập nhật text cho bản ghi hiện có; không
ghi đè metrics từ snapshot UI, không tạo lại bản ghi đã bị xóa trước khi cập nhật,
và báo lỗi nếu SharedPreferences từ chối ghi.

## Giữ nguyên và giới hạn phạm vi

- Giữ nguyên service AI, endpoint/payload tổng hợp, engine chất lượng và các
  quy tắc offline. Không gửi video, ảnh hoặc raw landmarks.
- Backend hiện trả một chuỗi nhận xét, nên UI hiển thị chuỗi đó nguyên vẹn;
  không tự bịa hoặc suy diễn các mục “Tốt/Cải thiện” từ văn bản AI.
- Các mục Tốt/Cải thiện/mục tiêu buổi sau của phần offline do engine cũ cung cấp.
- Giữ cơ chế AI được yêu cầu bằng nút. Chưa thêm tự động gửi hoặc công tắc AI toàn app.
- Nút Xong đã cố định. Luồng tạo/chia sẻ ảnh story chưa được triển khai trong Phase 7;
  không có nút Chia sẻ chưa hoạt động. Biểu đồ rep hiện tại được giữ nguyên cho Phase 8.
- 13 file counter/exercise/placement/pose mapper/workout domain so sánh byte với
  ZIP gốc: không đổi. Schema lịch sử và aggregate AI payload không đổi trong phase này.

## Kiểm tra

- `flutter analyze --no-pub`: sạch.
- `flutter test --no-pub`: **254 test qua**, gồm **40 test mới** cho Phase 7.
- Bao phủ 0 rep, dừng sớm, đạt đúng/vượt mục tiêu, tự do, tiếng Việt/Anh, màn hình
  320 px và chữ 2×, nút đáy không di chuyển khi cuộn, điểm form khác số mẫu thiết kế.
- Bao phủ yêu cầu AI chủ động, chống gửi trùng, truyền ngôn ngữ, lỗi mạng/server/
  timeout/cấu hình, giữ phản hồi cũ, thử lưu lại, phản hồi muộn và bảo toàn metrics.
- iOS simulator debug build: thành công; bản Phase 7 đã cài và mở trên RepCoach
  iPhone 17 Pro, iOS 26 Universal (ARM64 runtime, x86_64 app qua Rosetta).
- iPhone release build không ký: thành công.

Test AI dùng response/failure được tiêm trong test, không gửi dữ liệu lên backend
thật. Build và mở app không xác nhận toàn bộ thao tác kết quả trên native hoặc
chất lượng phản hồi của backend đang chạy. Camera/pose, giọng và rung trên iPhone
thật vẫn cần kiểm tra như đã ghi ở Phase 6.

## Ảnh giao diện

Các ảnh sau là **render widget**, dùng fixture riêng trong test, không phải ảnh
kết quả một buổi tập thật trên simulator:

- [Vượt mục tiêu](result-over.png), [đạt đúng mục tiêu](result-met.png)
- [Dừng sớm](result-partial.png), [tập tự do](result-free.png), [0 rep](result-empty.png)
- [Điểm form từ dữ liệu bản ghi](result-form.png)
- [Đang tải AI](feedback-loading.png), [offline](feedback-offline.png),
  [lỗi](feedback-error.png), [chưa cấu hình](feedback-unavailable.png)

Tạo lại ảnh từ thư mục app:

```bash
flutter test test/phase7_test.dart \
  --dart-define=PHASE7_SCREENSHOTS=/tmp/repcoach-phase7-previews
```

Ảnh [native mở app](ios26-launch.png) chỉ xác nhận bản build mới khởi chạy;
app đang ở Home với lịch sử trống, không chèn dữ liệu mẫu để chụp kết quả.
