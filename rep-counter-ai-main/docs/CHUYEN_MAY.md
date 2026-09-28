# Chuyển sang máy khác để code

Repo trên GitHub: `Juliolayme/rep-counter-ai` (private, nhánh `main`).
Clone về là build được bản `store` và `diag`, **trừ phần ký release**.

## 1. Chép tay 3 thứ không nằm trong git

| Thứ | Đường dẫn ở máy cũ | Đặt vào đâu ở máy mới |
|---|---|---|
| Kho khoá ký Play | `rep_counter_app/android/upload-keystore.jks` | đúng chỗ cũ |
| Mật khẩu kho khoá | `rep_counter_app/android/key.properties` | đúng chỗ cũ |
| Khoá API Gemini (chạy backend ở máy) | `backend/.env` | đúng chỗ cũ, mẫu xem `backend/.env.example` |

Thiếu hai file đầu thì **không build được bản nộp Play**. Đừng gửi chúng qua
chat, email hay đẩy lên GitHub; chép bằng USB hoặc kho mật khẩu.

`.gitignore` đã chặn `*.zip`: gói `android.zip` để chuyển máy có chứa cả khoá.

## 2. Cài đặt máy mới

- Flutter (bản dùng để phát triển: 3.47), Android SDK, JDK 17.
- `flutter pub get` trong `rep_counter_app/`.
- Python cho `tools/`: `pip install mediapipe opencv-python numpy scipy pandas matplotlib`.
- Kiểm tra: `flutter analyze` và `flutter test` (phải xanh, 141 test).

Gradle wrapper và icon launcher đã có sẵn, không cần dựng lại.

## 3. Dữ liệu nặng — sao lưu riêng, đừng đưa lên git

| Thứ | Ở đâu | Cỡ | Cần cho việc gì |
|---|---|---|---|
| Video hít đất | `push_up/` | ~6,8 GB | ngưỡng, mẫu khung xương, test hồi quy |
| Video kéo xà | `pull_up/` | ~548 MB | sinh lại fixture kéo xà |
| Video gốc | `IMG_2425.MOV`, `IMG_2427.MOV` | ~1,8 GB | dữ liệu thô |
| Video debug trong app | `rep_counter_app/assets/debug/` | 18 MB | màn hình thử bằng video (bản debug) |
| Ảnh phân tích | `analysis/` | 1,8 MB | |
| APK gửi tester | `Downloads/RepCoach-AI-apk/` | 353 MB | build lại được |
| Thư mục nộp Play | `Downloads/RepCoach-Play-Upload/` | 94 MB | build lại được |
| Video + CSV tester gửi về | `Downloads/repcoach-*.csv`, `*.mp4` | | ground truth độ chính xác |

Fixture test kéo xà đã nằm trong repo, nên **không có video vẫn chạy test được**.
Chỉ cần video khi muốn sinh lại fixture (`python tools/gen_pullup_fixture.py`).

## 4. Tài khoản, không phải file

- Google Play Console (nên bật xác thực 2 bước).
- VPS `14.225.207.90`, user `nduythanh`, domain `repcoach-ai.duckdns.org` —
  backend Gemini chạy ở đây, khoá API nằm trong cấu hình systemd trên VPS.
- GitHub.
