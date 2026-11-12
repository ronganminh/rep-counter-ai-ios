/// L-D40: giữ tín hiệu gần nhất lúc canh vị trí để không sót rep đầu.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/features/workout/domain/positioning_signal_buffer.dart';
import 'package:rep_counter_app/features/workout/domain/rep_tracker.dart';
import 'package:rep_counter_app/rep_counter.dart';

Duration _ms(int v) => Duration(milliseconds: v);

/// Ngưỡng của cuốn tạ (tín hiệu -1 = duỗi, +1 = gập).
RepTracker _tracker() => RepTracker(
      counter: RepCounter(hi: 0.15, lo: -0.55, minAmplitude: 0.60),
    );

BufferedPoseFrame _f(int ms, double v) =>
    BufferedPoseFrame(at: _ms(ms), left: v, right: v);

/// Chạy các frame "thật" (sau ready) và đếm số rep hoàn tất.
int _live(RepTracker t, RollingMean s, List<(int, double)> frames) {
  var reps = 0;
  for (final (ms, v) in frames) {
    final events = t.update(PoseSample(at: _ms(ms), signal: s.add(v)));
    reps += events.whereType<RepCompleted>().length;
  }
  return reps;
}

void main() {
  group('PositioningSignalBuffer', () {
    test('chỉ giữ 2,5 s gần nhất', () {
      final b = PositioningSignalBuffer();
      for (var ms = 0; ms <= 5000; ms += 200) {
        b.add(_f(ms, 0));
      }
      final frames = b.drain();
      expect(frames.first.at, _ms(2600));
      expect(frames.last.at, _ms(5000));
      expect(b.isEmpty, isTrue);
    });

    test('đứt quãng quá 0,5 s thì bỏ phần cũ', () {
      final b = PositioningSignalBuffer()
        ..add(_f(0, 0))
        ..add(_f(200, 0))
        ..add(_f(1000, 0));
      expect(b.drain().map((f) => f.at), [_ms(1000)]);
    });

    test('thời gian đi lùi (đổi nguồn frame) thì bỏ phần cũ', () {
      final b = PositioningSignalBuffer()
        ..add(_f(1000, 0))
        ..add(_f(400, 0));
      expect(b.length, 1);
    });

    test('clear làm rỗng', () {
      final b = PositioningSignalBuffer()..add(_f(0, 0));
      b.clear();
      expect(b.isEmpty, isTrue);
    });
  });

  group('primeTracker', () {
    // Rep đầu bắt đầu lúc còn canh vị trí; ready đến khi tạ đã lên nửa chừng.
    const before = [(0, -1.0), (200, -1.0), (400, -0.6), (600, -0.2)];
    const after = [(800, 0.0), (1000, 0.5), (1200, 0.9), (1400, 0.3)];

    test('không mồi: rep đầu bị sót (biên độ còn lại 0,5 < 0,6)', () {
      final t = _tracker();
      expect(_live(t, RollingMean(1), after), 0);
    });

    test('có mồi: rep đầu được đếm đúng một lần', () {
      final t = _tracker();
      final s = RollingMean(1);
      primeTracker(
          t, s, [for (final (ms, v) in before) _f(ms, v)], (f) => f.left);
      expect(_live(t, s, after), 1);
    });

    test('rep hoàn tất trọn trong lúc canh vị trí không được tính', () {
      final t = _tracker();
      final s = RollingMean(1);
      final full = [
        (0, -1.0), (200, -0.2), (400, 0.6), (600, 0.9), (800, 0.6) //
      ];
      primeTracker(
          t, s, [for (final (ms, v) in full) _f(ms, v)], (f) => f.left);
      // Sau ready vẫn ở trên: không có rep nào.
      expect(_live(t, s, const [(1000, 0.7), (1200, 0.8)]), 0);
    });

    test('đứng yên lúc canh vị trí: ready không sinh rep', () {
      final t = _tracker();
      final s = RollingMean(1);
      primeTracker(t, s, [for (var ms = 0; ms < 2000; ms += 200) _f(ms, -1.0)],
          (f) => f.left);
      expect(_live(t, s, const [(2000, -1.0), (2200, -0.95)]), 0);
    });

    test('mất tín hiệu trong bộ đệm cắt chu kỳ, như frame thật', () {
      final t = _tracker();
      final s = RollingMean(1);
      primeTracker(
        t,
        s,
        [
          _f(0, -1.0),
          const BufferedPoseFrame(at: Duration(milliseconds: 200)),
          _f(400, -0.2),
        ],
        (f) => f.left,
      );
      // Đáy -1,0 trước chỗ mất tín hiệu bị quên, không ghép với đỉnh sau:
      // chỉ còn -0,2 → 0,3 = 0,5 < 0,6 nên không đếm.
      expect(_live(t, s, const [(600, 0.0), (800, 0.3)]), 0);
    });
  });
}
