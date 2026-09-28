# Hai biến thể build: `store` và `diag`

Từ khi thêm tính năng ghi màn hình, dự án có **hai biến thể**. Lệnh build cũ
(`flutter build appbundle --release`) **không còn dùng được** — phải chỉ rõ
biến thể.

| | `store` | `diag` |
|---|---|---|
| Dùng để | Nộp Google Play | Gửi tay cho người test |
| applicationId | `com.ronganminh.repcoach` | `com.ronganminh.repcoach.diag` |
| Tên hiện trên máy | RepCoach AI | RepCoach DIAG |
| Ghi màn hình | **Không có** | Có |
| Quyền thêm | — | `FOREGROUND_SERVICE_MEDIA_PROJECTION`, `POST_NOTIFICATIONS` |

## Lệnh build

```bash
# Nộp Play
flutter build appbundle --release --flavor store

# APK gửi người test (nhẹ hơn, theo từng kiến trúc CPU)
flutter build apk --release --flavor store --split-per-abi

# Bản chẩn đoán có ghi màn hình
flutter build apk --release --flavor diag
```

## Vì sao tách bằng flavor, không dùng `if` trong code

Lớp `DiagRecorder` có **hai bản cài đặt cùng tên**:

- `android/app/src/diag/kotlin/.../DiagRecorder.kt` — bản thật, gọi MediaProjection
- `android/app/src/store/kotlin/.../DiagRecorder.kt` — bản rỗng, `available = false`

`MainActivity` ở `src/main` gọi chung một lớp và không cần biết đang chạy bản
nào. Kết quả: APK lên Play **không chứa một dòng mã MediaProjection nào**, cũng
không có quyền liên quan. Đã kiểm chứng bằng cách quét dex:

```
store:  không có DiagRecorderService / MediaProjection / createScreenCaptureIntent
diag:   có đủ bốn
```

Phía Flutter cũng không cần cờ biên dịch: `DiagRecorder.available` hỏi qua
MethodChannel, bản store trả `false` nên nút ghi tự ẩn.

## Không thể tạo `.aab` từ bản diag

`build.gradle.kts` chặn task `packageDiag*Bundle` và `signDiag*Bundle`.

Lý do phải chặn: `flutter build appbundle --release` (thiếu `--flavor`) build
**cả hai** biến thể. Nó báo lỗi ở cuối, nhưng vẫn để lại một
`app-diag-release.aab` **hoàn chỉnh** trên đĩa (đã kiểm: 91,5 MB, 383 entry).
Một lần bấm nhầm là nộp bản có quyền ghi màn hình lên Play.

Hai điểm dễ sai khi viết guard này, đã trả giá:

1. Chặn `bundleDiagRelease` **không có tác dụng** — đó chỉ là task vòng đời,
   chạy sau khi file đã tạo xong. Task tạo file thật là `packageDiagReleaseBundle`.
2. Đừng dùng `startsWith("bundleDiag")` — nó khớp cả
   `bundleDiagReleaseClassesToCompileJar`, chặn nhầm thì vỡ luôn bản APK diag.

Lưới an toàn thứ hai, độc lập với Gradle: applicationId của bản diag là
`com.ronganminh.repcoach.diag`, nên Play Console tự từ chối nếu nộp vào listing
của `com.ronganminh.repcoach`.

## Bản diag ghi lại những gì

Vào `getExternalFilesDir(null)/diag/` — vùng file riêng của app, không cần quyền
bộ nhớ nào:

- `repcoach-<máy>-<thời gian>.mp4` — màn hình, tối đa 720px ngang, 20 fps,
  2,5 Mbps, **không có tiếng** (`MediaRecorder` chỉ nhận nguồn hình, nên
  manifest không cần `RECORD_AUDIO`).
- `repcoach-<thời gian>.csv` — mỗi khung một dòng:
  `ms,raw,smooth,hi,lo,pose,status,reps,rep_event`

CSV mới là thứ cho phép **chạy lại bộ đếm ngoại tuyến** với tham số khác để tìm
nguyên nhân đếm sai. Video chỉ trả lời được câu "khung xương có bám người
không" — nhưng đúng câu đó thì số liệu không nói được.

Thông số quay chọn theo đo thực tế trên LG V60: 720px/24fps/4 Mbps cho ra 41 MB
cho 87 giây, tức buổi 5 phút ~140 MB, người test khó gửi qua chat. Hạ xuống
20 fps / 2,5 Mbps còn khoảng 15 MB mỗi phút. Bản thân app cũng chỉ tính được
~15 khung/giây nên 20 fps là đủ.
