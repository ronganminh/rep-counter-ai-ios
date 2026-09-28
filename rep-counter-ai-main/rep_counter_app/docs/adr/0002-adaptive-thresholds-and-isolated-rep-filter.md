# ADR 0002 — Ngưỡng tự thích ứng và bộ lọc nhịp đơn độc

- Trạng thái: chấp nhận, **chưa triển khai trong Dart** (dự kiến Phase 3)
- Ngày: 2026-09-01
- Sửa đổi: IMPLEMENTATION_PLAN §5.3, §5.4
- Bằng chứng: 7 video hít đất thật, 75 phút, 41 rep đếm bằng mắt

## Bối cảnh

`IMPLEMENTATION_PLAN` §5.4 giữ ngưỡng cố định `repHi` / `repLo` / `minAmplitude`, và
coi calibration (§5.5) là cách xử lý khác biệt giữa người dùng. Bản Dart hiện tại
(`exercise.dart`) đang theo đúng như vậy: `repHi: 140, repLo: 100`.

Chúng tôi đã dựng lại toàn bộ pipeline bằng Python trên 7 video thật để đo, thay vì
suy đoán. Kết quả bác bỏ cách làm này.

## Quyết định 1 — Ngưỡng bám theo cửa sổ trượt, không cố định

Mỗi thời điểm, lấy phân vị 10/90 của tín hiệu trong cửa sổ trượt ±4.5 giây quanh nó,
rồi đặt ngưỡng trên/dưới vào 2/3 và 1/3 của biên độ đó.

### Bằng chứng

Video `20241110_164842.mp4` có người tập tầm hẹp: **đáy chỉ xuống ~130°**, cao hơn
`repLo = 100`. Trigger không bao giờ nạp lại được.

| | Ngưỡng cố định | Ngưỡng tự thích ứng |
|---|---|---|
| Rep đếm được trên 7.45 phút | **3** | **103** |

Ngưỡng cố định không chỉ kém chính xác — nó **hỏng hoàn toàn** với người có tầm vận
động khác người mà ngưỡng được dò ra.

### Vì sao calibration không đủ

Calibration chốt ngưỡng một lần, cho **góc máy đó, ngày đó**. Nhưng chính kế hoạch có
trường `amplitudeDropPercent` — tức đã biết biên độ **tụt dần trong buổi tập** khi
người tập mệt. Ngưỡng chốt lúc đầu buổi sẽ sai vào cuối buổi. Cửa sổ trượt tự bám theo.

Calibration vẫn giữ, nhưng làm lớp phụ (gợi ý biên độ mục tiêu), không phải nguồn
ngưỡng chính.

### Độ nhạy tham số

Quét **162 tổ hợp** (visibility, cửa sổ làm mượt, cửa sổ thích ứng, biên độ tối thiểu,
chu kỳ tối thiểu): **cả 162 cho cùng kết quả** trên tập kiểm chứng. Bản ngưỡng cố định
thì ngược lại — chỉ 24/108 tổ hợp đúng trên hai video, và sai hoàn toàn trên video thứ ba.

## Quyết định 2 — Loại nhịp đơn độc

Một rep chỉ được tính khi thuộc nhóm **≥2 rep cách nhau ≤4 giây**.

### Bằng chứng

Trên 7 video có **113 dương tính giả**. Kiểm tra bằng mắt 3 nhịp đơn độc trong
`copy_4FAC…mov`: cả 3 đều là **người đang quỳ nghỉ rồi chống tay xuống sàn** để vào
tư thế. Động tác gập rồi duỗi tay đó vượt ngưỡng y như một rep.

Trong app, `PlacementStatus.ready` chặn được phần lớn — nhưng không phải tất cả, vì
lúc chống tay xuống thì người đã gần đúng tư thế rồi.

### Cảnh báo: KHÔNG lọc theo nhịp trung vị

Bản trước loại set có nhịp trung vị chậm hơn 3 giây. Nó đã ném đi cả một đoạn hít đất
**chậm nhưng có thật** trong `IMG_8752.MOV` — kiểm tra bằng mắt thấy người đang tập
thật, mệt và chậm, và biên độ các rep đó (65°) còn **lớn hơn** các rep được giữ (52°).

| Cấu hình lọc | Sai lệch trên 7 cửa sổ kiểm chứng |
|---|---|
| Gộp 6 s, tối thiểu 3 rep, lọc nhịp ≤3 s | **7 rep** |
| Gộp 4 s, tối thiểu 2 rep, **không lọc nhịp** | **2 rep** |

`IMG_8752.MOV` đi từ 46 lên **81 rep** sau khi bỏ bộ lọc nhịp.

## Độ chính xác sau cả hai quyết định

39/41 rep đúng (95%) trên 7 cửa sổ đếm bằng mắt, phủ 5/7 video. **Không cửa sổ nào
đếm dư.** Hai rep sai đều là sót, và cả hai rơi vào đoạn 0.3–0.6 giây MediaPipe không
phát hiện được người — không thể cứu từ dữ liệu pose.

## Hệ quả cho việc triển khai

- `RepCounter` giữ nguyên lõi Schmitt trigger. **Chỉ nguồn ngưỡng đổi**, từ hằng số
  sang giá trị bám cửa sổ. Vì vậy `test/rep_counter_test.dart` và test vector Python
  **vẫn còn giá trị và không được sửa** (§18).
- Cần thêm một bộ đệm tín hiệu trượt trên thiết bị. Bản real-time chỉ nhìn **quá khứ**
  (không có nửa cửa sổ tương lai như bản phân tích video), nên sẽ có độ trễ khởi động:
  vài rep đầu chưa đủ dữ liệu để dựng ngưỡng. Cần một ngưỡng khởi tạo, và ADR này
  **chưa giải quyết** điểm đó — phải đo trên thiết bị ở Phase 3.
- Bộ lọc nhịp đơn độc làm số rep **chỉ chốt được sau 4 giây**. Với hiển thị real-time,
  nên đếm lạc quan rồi trừ lại, hoặc hiện rep đầu ở trạng thái "tạm tính".

## Việc chưa làm

- Bản Dart hiện vẫn dùng ngưỡng cố định. Đổi ở Phase 3, sau khi có characterization test.
- Chưa đo trên thiết bị thật; mọi số ở trên đến từ video quay sẵn chạy qua MediaPipe
  trên máy tính.
