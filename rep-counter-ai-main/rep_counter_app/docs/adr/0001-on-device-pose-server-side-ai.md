# ADR 0001 — Pose chạy trên thiết bị, AI chạy trên server

- Trạng thái: chấp nhận
- Ngày: 2026-09-01
- Liên quan: IMPLEMENTATION_PLAN §2.1, §2.3, §9

## Bối cảnh

App cần đếm rep theo thời gian thực từ camera, và cần một đoạn nhận xét bằng ngôn
ngữ tự nhiên sau buổi tập. Hai việc này có yêu cầu trái ngược nhau: một cái cần độ
trễ dưới 50 ms và chạy được khi mất mạng, cái kia cần một model ngôn ngữ lớn và một
API key không được lộ.

## Quyết định

**Pose chạy hoàn toàn trên thiết bị** bằng ML Kit Pose (BlazePose). Không gửi frame,
ảnh khuôn mặt hay landmark thô lên server.

**AI chỉ nhận bản tổng hợp đã tính xong** — một JSON dưới 2 KB gồm số rep, số set,
nhịp, biên độ và các tỉ lệ chất lượng. Backend giữ API key; app không bao giờ chứa key.

**Số rep do thuật toán xác định trên thiết bị quyết định.** AI chỉ diễn đạt số liệu
thành câu chữ, không được tính lại hay suy đoán lại bất kỳ con số nào.

## Lý do

Ba lý do, xếp theo mức quan trọng:

1. **Riêng tư.** Video tập là dữ liệu nhạy cảm — người dùng thường cởi trần, quay
   trong phòng riêng. Không rời khỏi máy là cách bảo vệ mạnh nhất, và cũng là điều
   dễ giải thích nhất khi khai báo với store.

2. **Độ trễ.** Đếm rep phải phản hồi ngay trong frame. Bất kỳ round-trip mạng nào
   cũng phá trải nghiệm.

3. **Hoạt động khi mất mạng.** Buổi tập phải hoàn tất và lưu được không cần mạng.
   AI là phần thêm, không phải điều kiện.

## Hệ quả

- Cần một `RuleBasedFeedbackService` chạy trên máy, trả **cùng model** với AI, để
  màn hình kết quả luôn có nội dung ngay.
- Cần backend riêng (không nằm trong app Flutter) chỉ để giữ key và validate.
- Không thể dùng AI để cứu các trường hợp pose kém — mọi cải thiện độ chính xác
  phải làm ở phía thuật toán trên máy.
- Chất lượng pose phụ thuộc góc đặt camera, mà ta không kiểm soát được. Vì vậy app
  **phải** hướng dẫn đặt máy và chỉ đếm khi tư thế đạt (xem `placement.dart`).

## Phương án đã cân nhắc và loại

- **Gửi video lên server rồi phân tích ở đó.** Cho phép dùng model mạnh hơn, nhưng
  hỏng cả ba lý do trên. Loại.
- **Để AI đọc landmark thô và tự đếm.** Tốn token, không xác định (cùng đầu vào có
  thể ra số khác nhau), không kiểm thử được bằng unit test, và không chạy offline.
  Loại.
