# Phase 3 — ảnh render kiểm tra giao diện

Ảnh tạo từ widget thật bằng `test/phase3_visual_test.dart`, màn 393 × 852 logical
pixels, tỉ lệ xuất ảnh 2x, font đi kèm app. Đây **không phải screenshot simulator**.
Lịch sử trống dùng SharedPreferences mock chỉ trong test, không ghi dữ liệu mẫu vào app.

- [Home](home.png)
- [History trống](history.png)
- [Settings](settings.png)

Tạo lại từ thư mục Flutter app:

```bash
flutter test test/phase3_visual_test.dart \
  --dart-define=PHASE3_SCREENSHOTS=docs/phase3
```

Test cũng kiểm tra ba tab với cỡ chữ gấp đôi; chỉ xuất ảnh cỡ chữ thường.
