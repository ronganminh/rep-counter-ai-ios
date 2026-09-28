# Phase 8 — Chi tiết lịch sử và dữ liệu từng rep

Hoàn thiện ngày 27/09/2026, theo checklist Phase 8 trong migration guide.

## Quyết định lưu dữ liệu

Repo đã lưu `rep_details` từ đợt thay UI: thời gian từng rep, set và cờ có lưu ý.
Không cần chuyển database hoặc thay key lịch sử. Tiếp tục dùng
`workout_history_v1`, mở rộng tùy chọn phần chi tiết:

```json
{
  "rep_details_version": 2,
  "rep_details": [
    { "seconds": 0.55, "set": 1, "flagged": true, "flags": ["tooFast"] },
    { "seconds": 1.20, "set": 1, "flagged": false, "flags": [] }
  ]
}
```

Đây chỉ là ví dụ cấu trúc. Production lấy duration, set membership và flags từ
`WorkoutSummary`/`RepMetric` thật. Không tạo bản ghi mẫu, không tính lại rep hoặc
chất lượng trong UI. Chi tiết và phiên bản này **không nằm trong AI payload**.

| Dữ liệu đã lưu | Cách hiển thị |
| --- | --- |
| Aggregate cũ, chưa có chi tiết | Giữ số rep/set/thời gian/điểm; thông báo chưa có nhịp từng rep. |
| Chi tiết cũ có `flagged`, thiếu `flags` | Vẫn vẽ thời gian và set; không suy diễn loại lỗi hoặc số rep quá nhanh. |
| Chi tiết mới, `flags: []` | Không có lưu ý chất lượng được ghi nhận cho rep đó. |
| Chi tiết mới có flags | Hiển thị lưu ý thật khi chạm rep; thống kê `tooFast` từ flag đã lưu. |
| Chi tiết hỏng hoặc version chưa hỗ trợ | Bỏ qua phần chi tiết khi đọc; aggregate vẫn mở được. |
| JSON cả bản ghi không đọc được | Ẩn bản ghi đó khi tải; giữ nguyên chuỗi gốc khi lưu/xóa bản ghi khác. |

Không có migration tự xóa hoặc viết lại toàn bộ lịch sử khi mở app. Parser giữ
khác biệt giữa thiếu loại lưu ý (`null`) và đã ghi nhận không có lưu ý (`[]`).
Nếu một rep trong danh sách bị hỏng, bỏ qua toàn bộ phần chi tiết để tránh đánh
lại số thứ tự sai cho những rep còn lại. Phần quality tùy chọn hỏng cũng không
làm mất số liệu aggregate của bản ghi.

## Biểu đồ nhịp

- Nhóm cột theo set đã lưu, ghi số rep mỗi set và số thứ tự rep trong danh sách.
- Chiều cao theo thời gian thực tế, dùng chung thang đo giữa các set.
- Đường ngang thể hiện **trung bình dữ liệu đã lưu**, không phải nhịp khuyến nghị.
- Chạm cột để xem số giây, set và loại lưu ý. Có vùng chạm 44 px, nhãn trợ năng
  và cuộn ngang cho buổi tập dài.
- Cam thể hiện có lưu ý chất lượng; biểu tượng riêng đánh dấu `tooFast`.
- Không dùng mốc “dưới 1 giây” của mockup để phân loại lại: giữ nguyên kết luận
  engine cũ. Không coi mọi cờ chất lượng là rep quá nhanh.
- Nếu chỉ có một phần chi tiết, ghi rõ số rep có dữ liệu; tổng rep của buổi không đổi.

## Chi tiết và thao tác lịch sử

- Mở từ tab Lịch sử dùng lại màn kết quả, với ngày giờ trên thanh tiêu đề và nút quay lại.
- Nhận xét AI đã lưu được hiển thị nguyên vẹn, không tự gọi lại và không hiện nút
  tạo lại không cần thiết. Bản ghi chưa có AI vẫn có thể yêu cầu bằng nút.
- Nút Xong và Xóa nằm cố định ở đáy. Xóa cần xác nhận, rồi quay về danh sách với
  **Hoàn tác trong 5 giây**. Hủy giữ nguyên buổi tập; lỗi xóa giữ màn hình để thử lại.
- Undo giữ nguyên JSON đã xóa, gồm cả phản hồi AI mới nhất, chi tiết và field chưa biết.
  Không ghi đè nếu cùng ID đã được khôi phục thành một bản mới hơn.
- History tự tải lại sau khi đóng chi tiết. AppShell giữ widget History để không
  làm mất kết quả xóa/Undo khi route quay lại.
- Sửa tràn logo Home ở chữ 2× trong luồng điều hướng và tăng tương phản thông báo Undo.

## Độ an toàn của kho lịch sử

Các thao tác load/save/AI update/delete/restore/clear được thực hiện lần lượt
giữa các instance trong cùng app isolate, tránh ghi đè snapshot cũ khi nhiều
thao tác đến gần nhau. Lỗi một thao tác không chặn thao tác tiếp theo.

Ghi/xóa bị SharedPreferences từ chối sẽ báo lỗi; thử tải lại cache từ disk để
không hiển thị thành công giả. `saveFeedback` chỉ cập nhật text trên bản ghi hiện
có, giữ nguyên metric và field chưa biết. Giới hạn vẫn là 100 buổi gần nhất theo
ngày bắt đầu; các chuỗi hỏng chưa đọc được được giữ riêng cho đến khi người dùng
yêu cầu xóa toàn bộ dữ liệu. Không thay cơ chế lưu thành database mới.

## Kiểm tra

- `flutter analyze --no-pub`: sạch.
- `flutter test --no-pub`: **279 test qua**, gồm **25 test Phase 8 mới**.
- Bao phủ mapping summary → persisted timing/flags; payload AI không đổi;
  đọc dữ liệu cũ/hỏng/version mới; cập nhật đồng thời; bảo toàn field chưa biết;
  xóa/Undo; lỗi xóa; dữ liệu một phần và biểu đồ 200 rep.
- Widget kiểm tra tiếng Việt/Anh, màn hình 320 px, chữ 2×; luồng thực qua
  AppShell → History → Detail → Delete → Undo chạy trong widget test.
- So sánh 13 file counter/exercise/placement/pose mapper/workout domain với ZIP
  gốc: byte-identical. Công thức engine không đổi.
- Build iOS simulator debug và iPhone release không ký: thành công.
- Bản Phase 8 đã cài/mở trên RepCoach iPhone 17 Pro, iOS 26 Universal
  (`1B9AAA8C-CF32-4A9E-B6AC-E212674078AE`).

## Ảnh

Ảnh dưới đây là **render widget với fixture riêng trong test**, không phải kết quả
của buổi tập thật hoặc ảnh thao tác native trên simulator:

- [Chi tiết buổi tập và AI đã lưu](history-detail.png)
- [Biểu đồ theo set và rep được chọn](pace-selected.png)
- [Dữ liệu nhịp cũ thiếu loại lưu ý](pace-legacy.png)
- [Xóa và hoàn tác trên History](history-deleted.png)

```bash
flutter test test/phase8_test.dart \
  --dart-define=PHASE8_SCREENSHOTS=/tmp/repcoach-phase8-previews
```

## Còn lại

Chia sẻ ảnh story chưa triển khai. Phase 9 còn kiểm tra/polish trên thiết bị thật
và chuẩn bị phát hành. Native build/launch và widget test chưa xác nhận camera,
độ chính xác rep, âm thanh/rung hoặc toàn bộ thao tác trên iPhone thật.
