# Kéo xà (pull_up)

Trạng thái: **chỉ hiện ở bản `diag`** (hoặc `--dart-define=ENABLE_PULL_UP=true`).
Bản `store` vẫn bị chặn bởi A8. Xem `docs/PULL_UP_RELEASE_GATE.md` và
`test/fixtures/pull_up_validation_manifest.json` để biết evidence còn thiếu.

## Cách đếm

| Thành phần | Giá trị | Lý do |
|---|---|---|
| Tín hiệu | góc khuỷu, trung bình hai tay | treo ~175°, đỉnh ~30–60° |
| Ngưỡng | hi 140 / lo 90, biên độ ≥ 40 | |
| Làm mượt | trung bình trượt 2 khung | 5 khung ở 5 fps san phẳng cả đỉnh rep (24/47) |
| Cổng từng khung | cổ tay không thấp hơn vai quá 0.3 × bề rộng vai | loại người đứng nghỉ giữa set |
| `startFromTop` | chỉ bắt đầu sau khi đã treo thẳng tay | lúc với tay bám xà khuỷu gập–duỗi đúng một vòng |
| Khoảng cách | vai 6–45% cạnh ngắn | máy phải xa để thấy cả xà |
| Set tối thiểu | 1 rep (hít đất: 3) | set 1–2 rep là bình thường; quy tắc 3 rep trừ cả video quay lưng về 0 |

Cổng áp **từng khung**, không đi qua 2 s ân hạn của trạng thái đặt người: 2 s đó
rơi đúng lúc buông xà, tay gập rồi thả xuống, đủ để bị tính một rep.

## Khung xương mẫu và nút "?"

Mẫu trên màn hình tập (`lib/guide_template.dart`) là trung vị 1387 khung treo
thật của IMG_8708, lấy đối xứng qua giữa khung, kèm một vạch xà trên cổ tay.
Người trông nhỏ giữa màn hình là cố ý. Nút "?" cạnh tên bài mở
`exercise_help_sheet.dart`; nội dung ở `lib/core/i18n/exercise_help.dart`, viết
theo các chấm vai–khuỷu–cổ tay chứ không theo số độ.

## Kiểm trên video thật (`pull_up/`, 7.5 fps)

Các số dưới đây chỉ là **đếm tay tổng hợp (aggregate count)**. Chúng chưa có
annotation từng rep/mount/dismount/pose-loss nên không đủ để suy ra
precision/recall hoặc quyết định mở store.


| Video | Đếm tay | App | Rep ma |
|---|---|---|---|
| `IMG_8708.MOV` — trực diện, ngoài trời, 10 set | 47 | 46 | 0 |
| `Messenger_creation_…mp4` — quay lưng, sát người, 15 set × 2 | 30 | 21 | 0 |

Video quay lưng sót nhiều vì máy đặt quá gần: lúc treo, bàn tay và xà nằm ngoài
khung trên, pose không thấy cổ tay. App báo "thấy cả xà và hai tay — lùi máy ra".

Đã thử và bỏ: tín hiệu "mũi ngang cổ tay" (đúng định nghĩa cằm qua xà) — chia
cho bề rộng vai, mà lúc treo vai co giãn, sai hơn 20 rep.

## Tái tạo

    python tools/gen_pullup_fixture.py      # cần mediapipe, opencv

Sinh `test/fixtures/pull_up_*.json`; `test/pull_up_test.dart` phát lại và so
từng rep với bản Python.

## A8 release gate

A8 hiện kết luận **BLOCKED**: chưa đủ coverage dataset, chưa có annotation
human event-level, chưa có production CameraPage replay cho pull-up và chưa có
real-device validation trên recent + older supported iPhone. Không được bật
store visibility bằng cách nới gate.

## Chưa làm

- Backend Gemini vẫn ghi cứng "push-up session" trong prompt. Nhận xét AI đang
  tắt (`ENABLE_AI_FEEDBACK`), nhưng phải sửa trước khi bật cho kéo xà.
- Chưa có người thật dùng qua app: ML Kit trên điện thoại khác MediaPipe trên
  máy tính, và fps thật có thể thấp hơn 7.5. Cần CSV từ bản diag.
