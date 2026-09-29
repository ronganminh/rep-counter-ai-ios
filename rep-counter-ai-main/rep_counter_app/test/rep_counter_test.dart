/// Kiểm tra lõi đếm rep của Dart khớp với bản Python trong notebook.
///
/// `rep_vector.json` sinh bằng chính hàm `detect_reps` của Python trên một tín
/// hiệu tổng hợp có: dao động 1.2 s, một đoạn nghỉ 3 s ở tư thế duỗi thẳng, một
/// đoạn mất pose 0.5 s, và nhiễu. Nếu test này đỏ nghĩa là bản port đã lệch —
/// đừng sửa số kỳ vọng, hãy sửa `rep_counter.dart`.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/exercise.dart';
import 'package:rep_counter_app/rep_counter.dart';

void main() {
  late Map<String, dynamic> v;

  setUpAll(() {
    v = jsonDecode(File('test/rep_vector.json').readAsStringSync()) as Map<String, dynamic>;
  });

  test('đếm rep khớp với bản Python trên tín hiệu tổng hợp', () {
    final sr = (v['sampleRateHz'] as num).toDouble();
    final signal = (v['signal'] as List).map((e) => e == null ? double.nan : (e as num).toDouble()).toList();
    final expected = (v['expectedRepFrames'] as List).cast<int>();

    final counter = RepCounter(
      hi: (v['hi'] as num).toDouble(),
      lo: (v['lo'] as num).toDouble(),
      minAmplitude: (v['minAmp'] as num).toDouble(),
      minPeriod: Duration(milliseconds: v['minPeriodMs'] as int),
    );

    final got = <int>[];
    for (var i = 0; i < signal.length; i++) {
      final t = Duration(microseconds: (i / sr * 1e6).round());
      if (counter.update(signal[i], t) != null) got.add(i);
    }

    expect(got, expected, reason: 'thời điểm đếm phải trùng từng frame với Python');
    expect(counter.count, expected.length);
  });

  test('mất pose thì không ghép đáy cũ với đỉnh mới', () {
    final c = RepCounter(hi: 140, lo: 100, minAmplitude: 40);
    var t = Duration.zero;
    Duration next() => t += const Duration(milliseconds: 33);

    c.update(80, next());               // xuống đáy
    c.onSignalLost();                   // mất pose giữa chừng
    // Sau khi mất pose, mẫu đầu tiên khoá lại trạng thái chứ không đếm ngay.
    expect(c.update(170, next()), isNull);
    expect(c.count, 0);
  });

  test('biên độ nhỏ hơn ngưỡng thì không tính là rep', () {
    final c = RepCounter(hi: 140, lo: 100, minAmplitude: 40);
    var t = Duration.zero;
    Duration next() => t += const Duration(milliseconds: 33);

    c.update(130, next());              // khoá ở trạng thái 'down'
    c.update(145, next());              // vượt hi nhưng chỉ tăng 15 < 40
    expect(c.count, 0);
  });

  test('hai rep quá sát nhau bị chặn bởi minPeriod', () {
    final c = RepCounter(
      hi: 140, lo: 100, minAmplitude: 40,
      minPeriod: const Duration(milliseconds: 500),
    );
    Duration at(int ms) => Duration(milliseconds: ms);

    c.update(80, at(0));
    c.update(170, at(100));             // rep 1
    c.update(80, at(200));
    c.update(170, at(300));             // cách rep 1 chỉ 200 ms -> bỏ
    expect(c.count, 1);
  });

  group('gộp hai tay', () {
    test('hai tay cùng lúc chỉ tính một rep', () {
      final m = TwoArmMerger(window: const Duration(milliseconds: 400));
      expect(m.accept('L', const Duration(milliseconds: 1000)), isTrue);
      expect(m.accept('R', const Duration(milliseconds: 1120)), isFalse);
      expect(m.total, 1);
    });

    test('xen kẽ từng tay thì tính riêng', () {
      final m = TwoArmMerger(window: const Duration(milliseconds: 400));
      expect(m.accept('L', const Duration(milliseconds: 1000)), isTrue);
      expect(m.accept('R', const Duration(milliseconds: 1700)), isTrue); // lệch 0.7 s
      expect(m.total, 2);
    });
  });

  group('theo dõi set (nhân quả)', () {
    test('hết giờ nghỉ thì chốt set', () {
      final s = SessionTracker(restTimeout: const Duration(seconds: 6), minReps: 3);
      for (var i = 0; i < 5; i++) {
        s.onRep(Duration(milliseconds: 1000 * i));
      }
      expect(s.state, SessionState.working);
      s.tick(const Duration(seconds: 11)); // 7 s sau rep cuối
      expect(s.state, SessionState.resting);
      expect(s.sets.length, 1);
      expect(s.sets.first.reps, 5);
      expect(s.totalReps, 5);
    });

    test('rep đã xác nhận không giảm khi chốt set ngắn', () {
      final s =
          SessionTracker(restTimeout: const Duration(seconds: 6), minReps: 3);
      s.onRep(Duration.zero);
      s.onRep(const Duration(seconds: 1));
      expect(s.totalReps, 2);
      s.tick(const Duration(seconds: 8));
      expect(s.sets.length, 1);
      expect(s.sets.single.reps, 2);
      expect(s.totalReps, 2,
          reason: 'accepted rep là nguồn sự thật và phải tăng đơn điệu');
    });
  });

  test('hiệu chỉnh cần dao động thật mới đề xuất ngưỡng', () {
    final c = Calibrator(minSamples: 10, minSpan: 0.15);
    for (var i = 0; i < 40; i++) {
      c.add(1.0); // đứng yên
    }
    expect(c.suggest(), isNull);

    c.reset();
    for (var i = 0; i < 40; i++) {
      c.add(i.isEven ? 0.0 : 2.0);
    }
    final s = c.suggest();
    expect(s, isNotNull);
    expect(s!.hi, greaterThan(s.lo));
  });

  group('hiệu chỉnh với góc khuỷu (độ)', () {
    // Đứng yên, tay rung ±6° quanh 170° trong ~15 s ở 9 fps.
    List<double> still() => [
          for (var i = 0; i < 140; i++) 170 + 6 * math.sin(i * 1.7),
        ];
    // 5 rep hít đất, góc 70°..170°, 30 khung mỗi rep.
    List<double> reps() => [
          for (var i = 0; i < 150; i++)
            120 + 50 * math.cos(2 * math.pi * i / 30),
        ];

    test('mức mặc định 0.15 nhận cả lúc đứng yên — lỗi cũ', () {
      final c = Calibrator();
      still().forEach(c.add);
      expect(c.suggest(), isNotNull,
          reason: 'đây là lỗi đã sửa ở camera_page; nếu đổi mặc định thì '
              'cập nhật chú thích ở đó');
    });

    for (final p in [pushUp, pullUp]) {
      test('${p.id}: đứng yên thì không nhận, tập thật thì nhận', () {
        final c = Calibrator(minSpan: p.minAmplitude);
        still().forEach(c.add);
        expect(c.suggest(), isNull);

        c.reset();
        reps().forEach(c.add);
        final s = c.suggest();
        expect(s, isNotNull);
        expect(s!.lo, inInclusiveRange(90, 115));
        expect(s.hi, inInclusiveRange(125, 150));
        expect(s.minAmp, greaterThanOrEqualTo(p.minAmplitude / 2));
      });
    }
  });
}

