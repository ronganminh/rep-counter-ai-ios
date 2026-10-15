# ADR 0003 — vNext Track A engine and UI guardrails

- Trạng thái: chấp nhận
- Ngày: 2026-09-30
- Phạm vi: Track A vNext
- Liên quan: ADR 0001, ADR 0002, Phase A0

## Bối cảnh

vNext bổ sung feedback tức thời, Form Score giải thích được, Time Challenge,
Progress/PR, Export, Routines, Achievements và Voice cadence. Các thay đổi này làm
presentation và local product state lớn hơn, nhưng không được tạo nguồn đếm rep thứ
hai hoặc làm sai lệch trạng thái thật chỉ để khớp mockup.

Code hiện tại đã có chuỗi nguồn sự thật:

```text
RepCounter
→ RepTracker
→ WorkoutController
→ WorkoutUiState
→ WorkoutHud / WorkoutRecord / ResultPage
```

## Quyết định

### 1. Accepted reps là monotonic

Một rep đã được engine chấp nhận không bị trừ lại bởi quality warning.

- `RepCompleted` đi qua các gate hiện có rồi mới được `WorkoutController.acceptRep`.
- Quality flags mô tả chất lượng của rep đã chấp nhận; chúng không đổi accepted total.
- `RepAborted` / placement loss / signal loss không tự tạo rep và không trừ rep đã
  chấp nhận trước đó.
- UI không được có `repCount++` riêng.

Vì vậy trạng thái `countedWarning` trong vNext vẫn phải nói rõ rep **đã được tính**.

### 2. Figma là nguồn chuẩn cho presentation, không phải nguồn dữ liệu runtime

Polished Figma frames quyết định hierarchy, component, copy và interaction intent.
Figma không được override trạng thái engine thật.

Nếu một metric chưa tồn tại hoặc không đủ dữ liệu đáng tin cậy, UI phải hiển thị
unavailable/insufficient thay vì bịa số để giống mockup. Đặc biệt, thiếu Form Score
không được biểu diễn thành `0/100`.

### 3. AI không có quyền quyết định rep count hoặc deterministic Form Score

AI feedback là lớp diễn đạt/nhận xét phụ sau buổi tập.

- AI không đếm lại rep.
- AI không thay đổi `WorkoutRecord.reps`.
- AI không tự tạo hoặc sửa deterministic Form Score.
- Lỗi/offline AI không được làm mất local result.

### 4. Challenge và Routine quan sát engine hiện có

Time Challenge và Routine được phép thêm mode/config/timer/rest state, nhưng rep vẫn
đi qua cùng production workout pipeline. Không tạo counter song song trong widget,
challenge controller hoặc routine controller.

### 5. Regression baseline và human ground truth là hai khái niệm khác nhau

`test/fixtures/video_ground_truth.json` lưu:

- `current_engine_count`: số kỳ vọng để phát hiện regression của engine hiện tại;
- `human_ground_truth`: annotation bằng người, để `null` cho đến khi thật sự được
  annotate thủ công.

Không copy engine count sang human ground truth để tạo cảm giác accuracy hoàn hảo.
Re-baseline engine count phải có lý do được ghi lại và review. Thay đổi chủ đích
trong engine được phép tạo baseline mới sau khi cùng fixture chạy lặp lại cho kết
quả xác định; không được biến số engine mới thành human ground truth.

## Hệ quả

- Track A có thể mở rộng UI/state mà không viết lại engine.
- Feedback warning sau rep phải giữ semantics "counted".
- Mọi màn mới phải derive count từ `WorkoutUiState` / saved `WorkoutRecord`.
- Form/quality UI chỉ hiển thị dữ liệu deterministic có thật.
- Mọi thay đổi engine-neutral phải giữ production replay baseline hiện hành trong
  manifest và `HUD == saved == result`.

### Re-baseline 2026-10-14 sau sửa false positive lúc ngồi nghỉ

Gate tư thế hít đất là thay đổi có chủ đích trong engine, không phải thay đổi
engine-neutral. Production replay ở GitHub Actions run `38581459034` cho kết quả
xác định `pushup-a: 28 -> 15` và `pushup-b: 67 -> 21`, với
`HUD == saved == result`. Hai số mới chỉ là regression baseline; human ground
truth vẫn là `null`. Baseline cũ được giữ ở trường `previous_engine_count` để
không mất lịch sử.
