/// Lưu ngưỡng hiệu chỉnh giữa các lần mở app.
///
/// Trước đây hiệu chỉnh xong là dùng được cho đúng buổi đó; thoát app là mất,
/// lần sau phải chỉnh lại từ đầu. Mà ngưỡng hiệu chỉnh chính là thứ làm bộ đếm
/// hợp với từng người: 7 video thật cho thấy tầm vận động chênh nhau rất xa
/// giữa người và giữa góc máy (ADR 0002).
///
/// Lưu theo TỪNG BÀI TẬP. Ngưỡng của hít đất là góc khuỷu tay, của cuốn tạ là
/// độ nghiêng cẳng tay — hai thang đo khác nhau, dùng chung một ngưỡng thì bộ
/// đếm hỏng hẳn.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/quality_thresholds.dart';

/// Ngưỡng đã lưu có đủ rộng để dùng không.
///
/// Bản trước bản sửa hiệu chỉnh nhận cả lúc đứng yên rung tay (xem chú thích
/// `_calibrator` trong camera_page), nên trên máy tester có thể đang lưu một
/// ngưỡng nằm trong vùng nhiễu. Calibrator cho `minAmp = span / 2` và giờ
/// đòi `span >= minAmplitude` của bài, nên bản hợp lệ luôn có
/// `minAmp >= minAmplitude / 2`. Không đạt thì bỏ qua, dùng ngưỡng mặc định.
bool isPlausibleCalibration(CalibrationSnapshot s,
        {required double profileMinAmplitude}) =>
    s.repHi > s.repLo && s.minAmplitude >= profileMinAmplitude / 2;

class CalibrationStore {
  const CalibrationStore();

  static const _prefix = 'calibration_';

  String _key(String exerciseId) => '$_prefix$exerciseId';

  /// Ngưỡng đã lưu của bài này, hoặc null nếu chưa từng hiệu chỉnh.
  ///
  /// Hỏng dữ liệu thì trả null chứ không ném: một bản ghi lỗi không được làm
  /// người dùng không vào được buổi tập.
  Future<CalibrationSnapshot?> load(String exerciseId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(exerciseId));
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return CalibrationSnapshot.fromJson(json);
    } catch (error) {
      debugPrint('[calibration] khong doc duoc: $error');
      return null;
    }
  }

  /// Reports persistence failure so UI never claims an unsaved calibration was saved.
  Future<bool> save(String exerciseId, CalibrationSnapshot snapshot) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_key(exerciseId), jsonEncode(snapshot.toJson()));
    } catch (error) {
      debugPrint('[calibration] khong luu duoc: $error');
      return false;
    }
  }

  /// Removes only the selected exercise. Does not change calibration formulas.
  Future<void> reset(String exerciseId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(exerciseId));
  }

  /// Xoá ngưỡng của mọi bài tập.
  ///
  /// Dùng chung với nút xoá lịch sử: người dùng bấm "xoá dữ liệu trên máy" thì
  /// phải xoá hết, để lại ngưỡng cũ là nói một đằng làm một nẻo.
  Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys().where((k) => k.startsWith(_prefix))) {
        await prefs.remove(key);
      }
    } catch (error) {
      debugPrint('[calibration] khong xoa duoc: $error');
    }
  }
}
