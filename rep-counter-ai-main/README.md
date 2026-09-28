# RepCoach AI

Ứng dụng Flutter dùng MediaPipe Pose để đếm số lần tập, hỗ trợ đặt mục tiêu, lưu lịch sử và nhận phản hồi ngắn gọn từ Gemini.

## Tính năng hiện tại

- Đếm push-up theo thời gian thực bằng camera trước.
- Hướng dẫn căn vị trí cơ thể trước khi tập.
- Đặt mục tiêu hoặc chọn tập tự do.
- Lưu kết quả và lịch sử ngay trên thiết bị.
- Gửi bản tóm tắt thống kê nhẹ đến Gemini để nhận xét.
- Không tải video hoặc khung hình camera lên máy chủ.

## Cấu trúc dự án

- `rep_counter_app/`: ứng dụng Flutter.
- `backend/`: proxy Gemini, giữ API key ngoài APK.
- `docs/`: website GitHub Pages, Privacy Policy và Điều khoản.
- `tools/`: công cụ phân tích và kiểm thử video.

## Quyền riêng tư

Camera và video được xử lý trên thiết bị. Khi người dùng chủ động yêu cầu nhận xét AI, ứng dụng chỉ gửi số rep, thời lượng, mục tiêu và thống kê chất lượng — không gửi ảnh hoặc video.

- [Chính sách quyền riêng tư](https://repcoach-ai.duckdns.org/privacy-policy.html)
- [Điều khoản sử dụng](https://repcoach-ai.duckdns.org/terms.html)
- [Hỗ trợ](https://repcoach-ai.duckdns.org/support.html)

## Nhà phát triển

**RỒNG ẨN MÌNH**  
[ronganminh221@gmail.com](mailto:ronganminh221@gmail.com)

