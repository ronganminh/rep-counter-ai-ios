/// Ngưỡng hiệu chỉnh phải sống qua lần mở app sau, và tách theo từng bài.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/features/workout/data/calibration_store.dart';
import 'package:rep_counter_app/features/workout/domain/quality_thresholds.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _store = CalibrationStore();

CalibrationSnapshot _snap({
  double hi = 140,
  double lo = 100,
  double amp = 40,
  CalibrationSource source = CalibrationSource.userCalibration,
}) =>
    CalibrationSnapshot(
        repHi: hi, repLo: lo, minAmplitude: amp, source: source);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('chưa hiệu chỉnh thì trả null', () async {
    expect(await _store.load('push_up'), isNull);
  });

  test('lưu rồi đọc lại đúng giá trị', () async {
    expect(await _store.save('push_up', _snap(hi: 132.5, lo: 96.25, amp: 36.5)),
        isTrue);
    final got = await _store.load('push_up');

    expect(got, isNotNull);
    expect(got!.repHi, 132.5);
    expect(got.repLo, 96.25);
    expect(got.minAmplitude, 36.5);
    expect(got.source, CalibrationSource.userCalibration);
  });

  test('lỗi lưu được báo lại cho giao diện thay vì báo thành công', () async {
    expect(await _store.save('push_up', _snap(amp: double.nan)), isFalse);
    expect(await _store.load('push_up'), isNull);
  });

  test('mỗi bài tập một ngưỡng riêng', () async {
    // Thang đo khác nhau hoàn toàn: hít đất là góc khuỷu (độ), cuốn tạ là độ
    // nghiêng cẳng tay (-1..1). Dùng lẫn là bộ đếm hỏng hẳn.
    await _store.save('push_up', _snap(hi: 140, lo: 100, amp: 40));
    await _store.save('curl', _snap(hi: 0.15, lo: -0.55, amp: 0.6));

    expect((await _store.load('push_up'))!.repHi, 140);
    expect((await _store.load('curl'))!.repHi, 0.15);
  });

  test('lưu đè lên giá trị cũ', () async {
    await _store.save('push_up', _snap(hi: 140));
    await _store.save('push_up', _snap(hi: 120));
    expect((await _store.load('push_up'))!.repHi, 120);
  });

  test('xoá dữ liệu thì xoá ngưỡng của mọi bài', () async {
    await _store.save('push_up', _snap());
    await _store.save('curl', _snap());

    await _store.clearAll();

    expect(await _store.load('push_up'), isNull);
    expect(await _store.load('curl'), isNull);
  });

  test('xoá ngưỡng KHÔNG đụng tới dữ liệu khác trong prefs', () async {
    SharedPreferences.setMockInitialValues({
      'app_language': 'en',
      'workout_history': '[]',
    });
    await _store.save('push_up', _snap());

    await _store.clearAll();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_language'), 'en');
    expect(prefs.getString('workout_history'), '[]');
  });

  test('dữ liệu hỏng thì trả null chứ không ném', () async {
    SharedPreferences.setMockInitialValues({
      'calibration_push_up': 'day khong phai json',
    });
    // Một bản ghi lỗi không được làm người dùng không vào được buổi tập.
    expect(await _store.load('push_up'), isNull);
  });

  group('ngưỡng đã lưu có dùng được không', () {
    test('ngưỡng từ lần hiệu chỉnh lúc đứng yên (lỗi cũ) bị bỏ qua', () {
      // Đứng yên rung tay ±6°: span ~12°, Calibrator cũ cho minAmp ~6°.
      final bad = _snap(hi: 172, lo: 168, amp: 6);
      expect(isPlausibleCalibration(bad, profileMinAmplitude: 40), isFalse);
    });

    test('ngưỡng từ lần tập thật được dùng', () {
      // Tập thật 70°..170°: span ~100°, minAmp ~50°.
      final good = _snap(hi: 137, lo: 103, amp: 50);
      expect(isPlausibleCalibration(good, profileMinAmplitude: 40), isTrue);
    });

    test('ngưỡng mặc định của bài luôn hợp lệ', () {
      expect(isPlausibleCalibration(_snap(), profileMinAmplitude: 40), isTrue);
    });
  });
}
