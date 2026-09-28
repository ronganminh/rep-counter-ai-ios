/// Đổi toạ độ landmark sang hệ toạ độ widget đang hiển thị.
///
/// Tách khỏi `camera_page.dart` để test được mà không cần camera hay ML Kit.
/// File này **cố ý không import google_mlkit** — phần chuyển đổi từ `Pose` nằm ở
/// `data/mlkit_pose_adapter.dart`. Nhờ vậy `pose_mapper_test.dart` chạy thuần Dart.
///
/// Sai ở đây là bug âm thầm và tốn thời gian nhất: khung xương vẽ lệch khỏi người,
/// và **mọi phép chấm "trong khung hướng dẫn" đều sai theo**, nên bộ đếm từ chối
/// đếm mà không rõ lý do.
library;

import 'dart:ui' show Offset, Size;

class PoseMapper {
  const PoseMapper({
    required this.rawImageSize,
    required this.viewSize,
    this.rotationDegrees = 0,
    this.mirror = false,
  });

  /// Kích thước ảnh camera trả về, **chưa xoay** (theo hướng cảm biến).
  final Size rawImageSize;

  /// Kích thước widget đang hiển thị preview.
  final Size viewSize;

  /// Góc xoay cảm biến: 0, 90, 180 hoặc 270.
  final int rotationDegrees;

  /// true cho camera trước — ảnh preview bị lật ngang.
  final bool mirror;

  /// Kích thước ảnh **sau khi xoay dựng đứng**.
  ///
  /// ML Kit trả landmark trong hệ toạ độ của ảnh ĐÃ xoay, nên mọi phép tính tỉ lệ
  /// phải dùng kích thước này. Quên hoán đổi w/h ở 90°/270° là lỗi kinh điển:
  /// khung xương lệch đúng bằng tỉ lệ khung hình.
  Size get uprightImageSize => (rotationDegrees.abs() % 180 == 90)
      ? Size(rawImageSize.height, rawImageSize.width)
      : rawImageSize;

  /// Hệ số phóng của `BoxFit.cover`: lấy cạnh nào phải phóng NHIỀU hơn.
  double get scale {
    final s = uprightImageSize;
    if (s.width <= 0 || s.height <= 0) return 1;
    final sx = viewSize.width / s.width;
    final sy = viewSize.height / s.height;
    return sx > sy ? sx : sy;
  }

  /// Phần bị cắt mỗi bên do `BoxFit.cover` (âm nghĩa là ảnh tràn ra ngoài view).
  Offset get offset {
    final s = uprightImageSize;
    return Offset(
      (viewSize.width - s.width * scale) / 2,
      (viewSize.height - s.height * scale) / 2,
    );
  }

  /// (x, y) trong hệ toạ độ ảnh đã dựng đứng -> toạ độ trên widget.
  Offset map(double x, double y) {
    final k = scale;
    final o = offset;
    final vx = x * k + o.dx;
    final vy = y * k + o.dy;
    return Offset(mirror ? viewSize.width - vx : vx, vy);
  }

  PoseMapper copyWith({Size? rawImageSize, Size? viewSize, int? rotationDegrees, bool? mirror}) =>
      PoseMapper(
        rawImageSize: rawImageSize ?? this.rawImageSize,
        viewSize: viewSize ?? this.viewSize,
        rotationDegrees: rotationDegrees ?? this.rotationDegrees,
        mirror: mirror ?? this.mirror,
      );

  @override
  String toString() => 'PoseMapper(raw=$rawImageSize, upright=$uprightImageSize, '
      'view=$viewSize, rot=$rotationDegrees, mirror=$mirror)';
}
