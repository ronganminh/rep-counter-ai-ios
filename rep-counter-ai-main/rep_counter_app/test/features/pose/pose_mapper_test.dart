/// Characterization test cho PoseMapper — viết TRƯỚC khi refactor pipeline camera.
///
/// Mục đích không phải chứng minh mapper đúng trên thiết bị thật (chỉ ảnh chụp màn
/// hình mới làm được điều đó), mà là **khoá hành vi hiện tại** để lần refactor sau
/// có cái mà đối chiếu.
///
/// Chưa kiểm chứng trên thiết bị thật: xem docs/BASELINE.md.
library;

import 'dart:ui' show Offset, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/features/pose/domain/pose_mapper.dart';

/// So sánh Offset với sai số cho phép.
void expectOffset(Offset got, Offset want, {double tol = 0.01}) {
  expect((got.dx - want.dx).abs() < tol, isTrue,
      reason: 'dx: got ${got.dx}, want ${want.dx}');
  expect((got.dy - want.dy).abs() < tol, isTrue,
      reason: 'dy: got ${got.dy}, want ${want.dy}');
}

void main() {
  group('cùng tỉ lệ khung hình — không cắt', () {
    const m = PoseMapper(
      rawImageSize: Size(480, 640),
      viewSize: Size(240, 320),
    );

    test('hệ số phóng đúng và không có phần cắt', () {
      expect(m.scale, closeTo(0.5, 1e-9));
      expectOffset(m.offset, Offset.zero);
    });

    test('bốn góc ánh xạ đúng bốn góc', () {
      expectOffset(m.map(0, 0), const Offset(0, 0));
      expectOffset(m.map(480, 640), const Offset(240, 320));
    });

    test('tâm ảnh về tâm view', () {
      expectOffset(m.map(240, 320), const Offset(120, 160));
    });
  });

  group('BoxFit.cover cắt hai bên', () {
    // Ảnh 16:9 nằm ngang, view dọc cao -> phải phóng theo chiều cao, cắt bớt ngang.
    const m = PoseMapper(
      rawImageSize: Size(1600, 900),
      viewSize: Size(400, 800),
    );

    test('phóng theo cạnh cần nhiều hơn', () {
      expect(m.scale, closeTo(800 / 900, 1e-9));
    });

    test('phần cắt ngang là âm và đối xứng', () {
      final o = m.offset;
      expect(o.dx, lessThan(0));
      expect(o.dy, closeTo(0, 1e-9));
      // ảnh sau khi phóng rộng hơn view -> tràn đều hai bên
      expect(m.map(0, 0).dx, closeTo(o.dx, 1e-9));
      expect(m.map(1600, 0).dx, closeTo(viewRight(m), 1e-9));
    });

    test('tâm ảnh vẫn về tâm view dù bị cắt', () {
      expectOffset(m.map(800, 450), const Offset(200, 400));
    });
  });

  group('BoxFit.cover cắt trên dưới', () {
    // Ảnh dọc, view ngang -> phóng theo chiều rộng, cắt bớt dọc.
    const m = PoseMapper(
      rawImageSize: Size(720, 1280),
      viewSize: Size(800, 600),
    );

    test('phần cắt dọc là âm, ngang bằng 0', () {
      expect(m.scale, closeTo(800 / 720, 1e-9));
      expect(m.offset.dy, lessThan(0));
      expect(m.offset.dx, closeTo(0, 1e-9));
    });

    test('tâm ảnh về tâm view', () {
      expectOffset(m.map(360, 640), const Offset(400, 300));
    });
  });

  group('xoay cảm biến', () {
    const raw = Size(1280, 720); // ảnh cảm biến nằm ngang

    test('0 độ giữ nguyên kích thước', () {
      const m = PoseMapper(rawImageSize: raw, viewSize: Size(400, 800));
      expect(m.uprightImageSize, const Size(1280, 720));
    });

    test('180 độ giữ nguyên kích thước', () {
      const m = PoseMapper(rawImageSize: raw, viewSize: Size(400, 800), rotationDegrees: 180);
      expect(m.uprightImageSize, const Size(1280, 720));
    });

    test('90 độ hoán đổi rộng/cao', () {
      const m = PoseMapper(rawImageSize: raw, viewSize: Size(400, 800), rotationDegrees: 90);
      expect(m.uprightImageSize, const Size(720, 1280));
    });

    test('270 độ cũng hoán đổi', () {
      const m = PoseMapper(rawImageSize: raw, viewSize: Size(400, 800), rotationDegrees: 270);
      expect(m.uprightImageSize, const Size(720, 1280));
    });

    test('quên hoán đổi ở 90 độ làm lệch hẳn — đây là lỗi test này canh', () {
      const rotated = PoseMapper(
          rawImageSize: raw, viewSize: Size(400, 800), rotationDegrees: 90);
      const notRotated = PoseMapper(rawImageSize: raw, viewSize: Size(400, 800));
      // cùng một landmark, hai cách hiểu -> lệch rất xa, không phải sai số làm tròn
      final a = rotated.map(360, 640);
      final b = notRotated.map(360, 640);
      expect((a - b).distance, greaterThan(100));
    });
  });

  group('camera trước lật ngang', () {
    const back = PoseMapper(rawImageSize: Size(480, 640), viewSize: Size(240, 320));
    const front = PoseMapper(
        rawImageSize: Size(480, 640), viewSize: Size(240, 320), mirror: true);

    test('trục dọc không đổi', () {
      expect(front.map(100, 200).dy, closeTo(back.map(100, 200).dy, 1e-9));
    });

    test('trục ngang lật quanh tâm view', () {
      final f = front.map(100, 200);
      final b = back.map(100, 200);
      expect(f.dx + b.dx, closeTo(240, 1e-9)); // đối xứng qua x = width/2
    });

    test('điểm giữa không đổi khi lật', () {
      expectOffset(front.map(240, 320), back.map(240, 320));
    });
  });

  group('trường hợp biên', () {
    test('kích thước ảnh bằng 0 không làm vỡ', () {
      const m = PoseMapper(rawImageSize: Size(0, 0), viewSize: Size(100, 200));
      expect(m.scale, 1);
      expect(m.map(10, 10).dx.isFinite, isTrue);
    });

    test('preview khác kích thước ảnh vào vẫn ánh xạ tâm về tâm', () {
      const m = PoseMapper(rawImageSize: Size(640, 480), viewSize: Size(1080, 2400));
      expectOffset(m.map(320, 240), const Offset(540, 1200));
    });
  });
}

double viewRight(PoseMapper m) => m.viewSize.width - m.offset.dx;
