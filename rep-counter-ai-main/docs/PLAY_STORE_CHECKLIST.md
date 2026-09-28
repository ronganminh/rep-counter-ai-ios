# Google Play release checklist — RepCoach AI

## Bắt buộc trước khi upload AAB

- Thay ba giá trị placeholder trong `lib/core/legal/legal_config.dart`.
- Đăng `docs/privacy-policy.html` ở một URL HTTPS công khai, không geo-block, không dùng PDF.
- Privacy Policy trong Play Console và trong app phải cùng URL/nội dung.
- Hoàn thành Data safety, kể cả khi video chỉ xử lý trên thiết bị.
- Health apps declaration: chọn **Health and fitness → Activity and fitness**.
- Store description phải ghi: “Ứng dụng không phải thiết bị y tế và không chẩn đoán, điều trị, chữa khỏi hoặc phòng ngừa bất kỳ tình trạng y khoa nào.”
- Khai camera là chức năng cốt lõi; xin quyền đúng lúc sau giải thích trong onboarding.
- Backend production bắt buộc HTTPS; không phát hành với LAN URL hoặc `usesCleartextTraffic=true`.
- Thay applicationId `com.example.rep_counter_app`, tên app, icon, adaptive icon và signing key.
- Tắt/ẩn nút “Kiểm thử bằng video có sẵn” trong release production.
- Chuẩn bị feature graphic, icon 512×512, phone screenshots và support email.
- Upload Android App Bundle (`flutter build appbundle --release --flavor store`), không dùng debug APK. Xem `rep_counter_app/docs/BUILD_FLAVORS.md` — dự án có hai biến thể, lệnh thiếu `--flavor` sẽ báo lỗi.

## Data safety dự kiến cho MVP hiện tại

- Camera/video: xử lý tạm thời trên thiết bị, không thu thập, không chia sẻ.
- Workout summary: gửi đến backend/Gemini chỉ khi người dùng bấm nhận xét AI; khai chính xác theo cách backend production lưu log/telemetry.
- Lịch sử: lưu cục bộ, người dùng xóa được trong Cài đặt.
- Không tài khoản, quảng cáo, location, contacts hay Health Connect trong MVP.

Khi bổ sung tài khoản ở Phase sau, phải cập nhật Data safety, privacy policy và thêm xóa tài khoản trong app lẫn URL web công khai.
