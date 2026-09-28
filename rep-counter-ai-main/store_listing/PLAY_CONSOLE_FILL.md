# Bảng điền Google Play Console — RepCoach AI

File này gom **mọi giá trị cần điền**, theo đúng thứ tự Play Console hỏi. Dán
cả file cho trợ lý trong trình duyệt, hoặc tự mở ra điền tay.

> **Không có giá trị nào trong file này là bí mật.** Mật khẩu keystore, tài
> khoản Google, khoá API — tuyệt đối không đưa vào đây và không đưa cho bất kỳ
> trợ lý nào.

---

## 0. Ba việc PHẢI tự làm, đừng giao cho trợ lý

1. **Tải file `.aab` lên** — hộp chọn file của trình duyệt, tiện ích mở rộng
   không thao tác được vì lý do bảo mật.
2. **Đăng ký Play App Signing** và giữ `android/upload-keystore.jks`. Mất khoá
   này là **vĩnh viễn không cập nhật được app nữa**.
3. **Bấm gửi duyệt.** Data safety và Health declaration là **lời khai chính
   thức** với Google. Khai sai không phải lỗi kỹ thuật — nó dẫn tới gỡ app.
   Đọc lại từng câu trước khi gửi.

---

## 1. Tạo ứng dụng

| Trường | Giá trị |
|---|---|
| App name | `RepCoach AI: Đếm Hít Đất` |
| Default language | `Tiếng Việt (vi-VN)` |
| App or game | App |
| Free or paid | Free |
| Package name | `com.ronganminh.repcoach` |

Chọn tiếng Việt vì bộ ảnh màn hình là tiếng Việt. Thêm listing tiếng Anh sau
bằng `PLAY_STORE_LISTING_EN.md`.

---

## 2. Store listing

Lấy nguyên văn từ [`PLAY_STORE_LISTING_VI.md`](PLAY_STORE_LISTING_VI.md).

| Trường | Giá trị | Độ dài |
|---|---|---|
| Tên ứng dụng | `RepCoach AI: Đếm Hít Đất` | 24/30 |
| Mô tả ngắn | `Đếm rep bằng camera, đặt mục tiêu, nhận nhận xét AI sau buổi tập.` | 65/80 |
| Mô tả đầy đủ | phần "Mô tả đầy đủ" trong file trên | 2107/4000 |

**Đồ hoạ** (đường dẫn tính từ thư mục `store_listing/`):

| Mục | File |
|---|---|
| App icon 512×512 | `assets/app-icon-512.png` |
| Feature graphic 1024×500 | `assets/feature-graphic-1024x500.png` |
| Ảnh điện thoại (8 ảnh, đúng thứ tự) | `assets/screenshots/play-8-vi/01…08` |

Play chỉ nhận tối đa 8 ảnh. Thư mục `play-8-vi` đã đánh số sẵn theo thứ tự
hiển thị, cứ tải lần lượt 01 → 08.

**Liên hệ:**

| Trường | Giá trị |
|---|---|
| Email hỗ trợ | `ronganminh221@gmail.com` |
| Website | `https://repcoach-ai.duckdns.org/` |
| Điện thoại | để trống |

---

## 3. App content — điền lần lượt

### 3.1 Privacy policy

```
https://repcoach-ai.duckdns.org/privacy-policy.html
```

### 3.2 App access

Chọn: **All functionality is available without special access**.
App không có đăng nhập, không có tài khoản, không có mã mời.

### 3.3 Ads

Chọn: **No, my app does not contain ads.**

### 3.4 Content rating

| Câu hỏi | Trả lời |
|---|---|
| Email | `ronganminh221@gmail.com` |
| Category | Reference, News, or Educational → hoặc **Health & Fitness** nếu có |
| Bạo lực, tình dục, ngôn từ thô tục, cờ bạc, chất kích thích | **Không** cho tất cả |
| Nội dung do người dùng tạo, chia sẻ công khai | **Không** |
| Chia sẻ vị trí | **Không** |
| Mua hàng trong ứng dụng | **Không** |

### 3.5 Target audience

- Nhóm tuổi: **13 trở lên** (đừng chọn nhóm trẻ em — kéo theo cả bộ quy định
  Families riêng)
- App có hấp dẫn trẻ em không: **Không**

### 3.6 Data safety

Đây là phần dễ sai nhất. Chi tiết và lý do ở
[`DATA_SAFETY_EN.md`](DATA_SAFETY_EN.md).

| Câu hỏi | Trả lời |
|---|---|
| App có thu thập hoặc chia sẻ dữ liệu người dùng không? | **Có** |
| Dữ liệu có được mã hoá khi truyền không? | **Có** (backend chạy HTTPS, đã kiểm) |
| Có cách yêu cầu xoá dữ liệu không? | **Có** — xoá trong app; máy chủ không lưu |

**Khai đúng MỘT loại dữ liệu:**

| Trường | Giá trị |
|---|---|
| Loại | Health and fitness → **Fitness info** |
| Collected | **Có** |
| Shared | **Không** — backend và Gemini chỉ xử lý thay mặt app |
| Processed ephemerally | **Có** |
| Required hay optional | **Optional** — chỉ gửi khi người dùng bấm nhận xét AI |
| Mục đích | App functionality; Personalization |

**KHÔNG khai là thu thập** (những thứ này không rời khỏi máy):

- Khung hình camera
- Landmark tư thế
- Lịch sử tập lưu cục bộ

**Không thu thập:** tên, email, tài khoản, vị trí, danh bạ, ảnh/video, âm
thanh, thanh toán, mã quảng cáo, tin nhắn, tệp.

### 3.7 Health apps declaration

Chi tiết ở [`HEALTH_APPS_DECLARATION_EN.md`](HEALTH_APPS_DECLARATION_EN.md).

- Danh mục: **Health and fitness → Activity and fitness**
- **Đừng** chọn bất kỳ mục nào về thiết bị y tế, chẩn đoán, điều trị, hỗ trợ
  quyết định lâm sàng hay quản lý bệnh.

Mô tả tính năng (dán nguyên văn):

```
RepCoach AI uses the device camera and on-device MediaPipe pose estimation to
count push-up repetitions, help users position themselves in view, record
workout goals and history locally, and optionally generate general fitness
feedback from a lightweight workout summary. The app does not upload camera
frames or videos and is not a medical device.
```

Lý do xin quyền camera (dán nguyên văn):

```
Camera access is required only for the core push-up counting experience. Video
frames are analyzed on the device with MediaPipe and are not uploaded by the
app. Users see a clear explanation before the Android camera permission prompt.
```

### 3.8 Các mục còn lại

| Mục | Trả lời |
|---|---|
| Government apps | Không |
| Financial features | Không có |
| News app | Không |
| COVID-19 contact tracing | Không |
| Data deletion URL | không cần — không có tài khoản |

---

## 4. Closed testing

**Phải là Closed testing.** Internal testing **không tính** vào yêu cầu 14 ngày
của tài khoản cá nhân.

| Trường | Giá trị |
|---|---|
| Track | Closed testing → tạo track mới |
| Tên track | `Closed test 1` |
| Danh sách tester | tạo email list, thêm **12 tài khoản Gmail** |
| Countries | Việt Nam (hoặc thêm nước khác nếu tester ở đó) |
| File tải lên | `rep_counter_app/build/app/outputs/bundle/storeRelease/app-store-release.aab` |
| Release name | `1.0.0 (2)` |

Ghi chú phát hành (release notes), tiếng Việt:

```
Bản thử nghiệm đầu tiên. Đếm hít đất bằng camera trước, chạy hoàn toàn trên
máy. Có mục tiêu số rep, lịch sử tập và nhận xét AI tuỳ chọn.
```

---

## 5. Kiểm tra lần cuối trước khi bấm gửi

- [ ] Package là `com.ronganminh.repcoach`, **không phải** `...repcoach.diag`
- [ ] File `.aab` lấy từ thư mục `storeRelease`, không phải `diagRelease`
- [ ] **File `.aab` build SAU lần sửa code cuối cùng.** Đã suýt nộp nhầm một
      bản build trước bản vá khung hướng dẫn — bản đó không đếm được rep nào.
      Kiểm bằng:
      `python tools/verify_bundle_is_current.py <đường dẫn .aab>`
      Phải thấy `"Luu vao may" CO` và `"Gui video" khong`. Đừng tin ngày sửa
      file: chép file đi chỗ khác là ngày đổi theo lúc chép, không phải lúc build.
- [ ] Đủ 8 ảnh, đúng thứ tự 01 → 08
- [ ] Mở thử `https://repcoach-ai.duckdns.org/privacy-policy.html` — phải ra
      trang chính sách, không phải trang trắng
- [ ] Data safety khai **Fitness info = optional**, không khai camera
- [ ] Health declaration **không** chọn mục nào liên quan y tế
- [ ] Đã lưu `upload-keystore.jks` và `key.properties` ở nơi an toàn ngoài máy

---

## 6. Sau khi được duyệt

1. Gửi link opt-in cho 12 người test
2. Nhắc họ **gỡ bản APK sideload trước** — Play ký lại bằng khoá khác nên chữ
   ký không khớp, cài đè sẽ báo "App not installed"
3. Nhắc họ **đừng rời nhóm** trong suốt 14 ngày, dưới 12 người là gián đoạn
4. Mỗi lần nộp bản vá: tăng số build trong `pubspec.yaml`
   (hiện là `1.0.0+2`, lần sau `+3`) rồi build lại bằng
   `flutter build appbundle --release --flavor store`, và kiểm bằng
   `python tools/verify_bundle_is_current.py`
