/// L-D41: cửa sổ làm mượt theo thời gian, chỉ cho cuốn tạ.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/exercise.dart';
import 'package:rep_counter_app/rep_counter.dart';

Duration _ms(num v) => Duration(microseconds: (v * 1000).round());

/// Số mẫu đang được trung bình: đưa vào toàn 0 rồi một mẫu 1.
int _span(RollingMean m, double stepMs, {int warm = 20}) {
  for (var i = 0; i < warm; i++) {
    m.add(0, at: _ms(i * stepMs));
  }
  final mean = m.add(1, at: _ms(warm * stepMs));
  return (1 / mean).round();
}

/// Một rep cuốn tạ giống set 4 (5 fps): đỉnh thô chỉ 2 khung.
const _rep5fps = [-1.0, -1.0, -0.9, -0.56, 0.78, 0.56, -0.91, -1.0, -1.0];

int _count(RollingMean smooth, List<double> raw, double stepMs) {
  final c = RepCounter(hi: 0.15, lo: -0.55, minAmplitude: 0.60);
  var reps = 0;
  for (var i = 0; i < raw.length; i++) {
    final at = _ms(i * stepMs);
    if (c.update(smooth.add(raw[i], at: at), at) != null) reps++;
  }
  return reps;
}

void main() {
  group('RollingMean.maxAge', () {
    test('không đặt maxAge: giữ nguyên theo số mẫu', () {
      expect(_span(RollingMean(5), 200), 5);
      expect(_span(RollingMean(5), 1000 / 15), 5);
    });

    test('350 ms: 2 mẫu ở 5 fps, 3 ở 7,5 fps, 5 (trần) ở 15 và 30 fps', () {
      RollingMean m() => RollingMean(5, maxAge: _ms(350));
      expect(_span(m(), 200), 2);
      expect(_span(m(), 1000 / 7.5), 3);
      expect(_span(m(), 1000 / 15), 5);
      expect(_span(m(), 1000 / 30), 5);
    });

    test('không có at: chỉ giới hạn theo số mẫu', () {
      final m = RollingMean(5, maxAge: _ms(350));
      for (var i = 0; i < 10; i++) {
        m.add(0);
      }
      expect(m.add(1), closeTo(0.2, 1e-9));
    });

    test('thời gian đi lùi thì bắt đầu lại', () {
      final m = RollingMean(5, maxAge: _ms(350))
        ..add(10, at: _ms(1000))
        ..add(10, at: _ms(1100));
      expect(m.add(2, at: _ms(0)), 2);
    });

    test('reset xoá cả mốc thời gian', () {
      final m = RollingMean(5, maxAge: _ms(350))..add(10, at: _ms(1000));
      m.reset();
      expect(m.add(3, at: _ms(0)), 3);
      expect(m.add(5, at: _ms(100)), 4);
    });
  });

  group('cuốn tạ', () {
    test('chỉ cuốn tạ đặt smoothDuration 350 ms', () {
      expect(dumbbellCurl.smoothDuration, const Duration(milliseconds: 350));
      expect(dumbbellCurl.smoothWindow, 5);
      for (final p in [pushUp, pullUp, overheadExtension]) {
        expect(p.smoothDuration, isNull, reason: p.id);
      }
    });

    test('đỉnh ngắn ở 5 fps: cửa sổ 5 khung sót, theo thời gian thì đếm', () {
      expect(_count(RollingMean(5), _rep5fps, 200), 0);
      expect(
          _count(RollingMean(5, maxAge: dumbbellCurl.smoothDuration), _rep5fps,
              200),
          1);
    });

    test('tín hiệu nhiễu nhỏ quanh tay duỗi không thành rep', () {
      final raw = [
        for (var i = 0; i < 50; i++) i.isEven ? -0.95 : -0.75,
      ];
      expect(
          _count(RollingMean(5, maxAge: dumbbellCurl.smoothDuration), raw, 200),
          0);
    });
  });
}
