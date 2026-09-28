/// Công cụ chẩn đoán cho bản `diag` gửi người test.
///
/// Hai thứ được ghi lại:
///
///  1. **Video màn hình** — do Android quay qua MediaProjection. Cho thấy
///     khung xương có bám người thật hay không, thứ mà số liệu không nói được.
///  2. **CSV từng khung hình** — giá trị tín hiệu, ngưỡng hi/lo, có thấy pose
///     hay không, và thời điểm mỗi rep được tính. Đây mới là thứ cho phép chạy
///     lại bộ đếm ngoại tuyến với tham số khác để tìm nguyên nhân đếm sai.
///
/// Bản `store` không có gì trong này: kênh trả `available = false` nên giao
/// diện tự ẩn, và phía Android lớp `DiagRecorder` là bản rỗng.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../exercise.dart';

/// Các điểm pose ghi kèm mỗi dòng CSV, theo đúng thứ tự cột.
///
/// Có toạ độ thì chạy lại được MỌI tín hiệu và cổng mới ngoại tuyến. Bản cũ chỉ
/// ghi tín hiệu tay trái, nên muốn thử một đặc trưng khác (ví dụ tỉ lệ thân /
/// vai để chặn rep khi đứng) phải chạy lại pose trên video quay màn hình.
const diagLandmarks = [
  PoseLandmarkType.nose,
  PoseLandmarkType.leftShoulder,
  PoseLandmarkType.rightShoulder,
  PoseLandmarkType.leftElbow,
  PoseLandmarkType.rightElbow,
  PoseLandmarkType.leftWrist,
  PoseLandmarkType.rightWrist,
  PoseLandmarkType.leftHip,
  PoseLandmarkType.rightHip,
];

/// Dòng tiêu đề CSV. Chín cột đầu giữ nguyên như bản cũ để script cũ còn đọc.
String diagCsvHeader() => [
      'ms,raw,smooth,hi,lo,pose,status,reps,rep_event',
      'raw_r,gate,exercise,view_w,view_h',
      for (final t in diagLandmarks) '${t.name}_x,${t.name}_y,${t.name}_p',
    ].join(',');

class DiagRecorder {
  DiagRecorder._();

  static final DiagRecorder instance = DiagRecorder._();

  static const _channel = MethodChannel('repcoach/diag');

  bool? _available;
  IOSink? _csv;
  File? _csvFile;
  int _rows = 0;

  /// Bản này có hỗ trợ ghi màn hình không. Hỏi một lần rồi nhớ luôn.
  Future<bool> get available async {
    if (_available != null) return _available!;
    try {
      _available = await _channel.invokeMethod<bool>('available') ?? false;
    } on PlatformException {
      _available = false;
    } on MissingPluginException {
      _available = false;
    }
    return _available!;
  }

  Future<bool> get isRecording async {
    try {
      return await _channel.invokeMethod<bool>('isRecording') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Mở hộp thoại xin phép của hệ thống rồi bắt đầu quay.
  ///
  /// Trả về false nếu người dùng từ chối — không phải lỗi, đừng báo đỏ.
  Future<bool> start({String exercise = ''}) async {
    try {
      final ok = await _channel.invokeMethod<bool>('start') ?? false;
      if (ok) await _openCsv(exercise);
      return ok;
    } catch (error) {
      debugPrint('[diag] khong bat dau ghi duoc: $error');
      return false;
    }
  }

  /// Dừng quay. Trả về đường dẫn video, hoặc null nếu không có gì đang quay.
  Future<String?> stop() async {
    await _closeCsv();
    try {
      return await _channel.invokeMethod<String?>('stop');
    } catch (error) {
      debugPrint('[diag] khong dung ghi duoc: $error');
      return null;
    }
  }

  /// Chép file ra bộ nhớ chung. Trả về vị trí đọc được, null nếu hỏng.
  ///
  /// Video vào `Movies/RepCoach`, số liệu vào `Download/RepCoach` — người test
  /// mở Thư viện hay trình quản lý file là thấy, gửi đi lúc nào cũng được và
  /// không mất khi gỡ app.
  Future<String?> save(String path) async {
    try {
      return await _channel.invokeMethod<String?>('save', {'path': path});
    } catch (error) {
      debugPrint('[diag] khong luu duoc: $error');
      return null;
    }
  }

  String? get csvPath => _csvFile?.path;
  int get csvRows => _rows;

  Future<void> _openCsv(String exercise) async {
    try {
      final dir = await _channel.invokeMethod<String>('dir');
      if (dir == null) return;
      final stamp = DateTime.now()
          .toIso8601String()
          .replaceAll(RegExp(r'[:.]'), '-')
          .substring(0, 19);
      final tag = exercise.isEmpty ? '' : '-$exercise';
      final file = File('$dir/repcoach$tag-$stamp.csv');
      final sink = file.openWrite();
      sink.writeln(diagCsvHeader());
      _csvFile = file;
      _csv = sink;
      _rows = 0;
    } catch (error) {
      debugPrint('[diag] khong mo duoc CSV: $error');
    }
  }

  /// Ghi một dòng cho mỗi khung hình đã xử lý.
  ///
  /// Gọi trong vòng xử lý khung hình nên phải rẻ: chỉ nối chuỗi vào bộ đệm,
  /// không `await`, không mã hoá JSON.
  void row({
    required Duration at,
    required double? raw,
    required double? smooth,
    required double hi,
    required double lo,
    required bool poseFound,
    required String status,
    required int reps,
    bool repEvent = false,
    double? rawRight,
    bool? gate,
    String exercise = '',
    Size? view,
    Landmarks? landmarks,
  }) {
    final sink = _csv;
    if (sink == null) return;
    sink.writeln(diagCsvRow(
      at: at,
      raw: raw,
      smooth: smooth,
      hi: hi,
      lo: lo,
      poseFound: poseFound,
      status: status,
      reps: reps,
      repEvent: repEvent,
      rawRight: rawRight,
      gate: gate,
      exercise: exercise,
      view: view,
      landmarks: landmarks,
    ));
    _rows++;
  }

  Future<void> _closeCsv() async {
    final sink = _csv;
    _csv = null;
    if (sink == null) return;
    try {
      await sink.flush();
      await sink.close();
    } catch (error) {
      debugPrint('[diag] khong dong duoc CSV: $error');
    }
  }
}

/// Một dòng CSV — tách ra hàm thuần để test được số cột khớp tiêu đề.
String diagCsvRow({
  required Duration at,
  required double? raw,
  required double? smooth,
  required double hi,
  required double lo,
  required bool poseFound,
  required String status,
  required int reps,
  bool repEvent = false,
  double? rawRight,
  bool? gate,
  String exercise = '',
  Size? view,
  Landmarks? landmarks,
}) {
  String n(double? v, [int d = 4]) => v == null ? '' : v.toStringAsFixed(d);
  final b = StringBuffer()
    ..write('${at.inMilliseconds},${n(raw)},${n(smooth)},')
    ..write('${n(hi)},${n(lo)},')
    ..write('${poseFound ? 1 : 0},$status,$reps,${repEvent ? 1 : 0},')
    ..write('${n(rawRight)},${gate == null ? '' : (gate ? 1 : 0)},$exercise,')
    ..write('${n(view?.width, 0)},${n(view?.height, 0)}');
  for (final t in diagLandmarks) {
    final l = landmarks?.get(t);
    b.write(l == null
        ? ',,,'
        : ',${l.x.toStringAsFixed(1)},${l.y.toStringAsFixed(1)},'
            '${l.likelihood.toStringAsFixed(2)}');
  }
  return b.toString();
}
