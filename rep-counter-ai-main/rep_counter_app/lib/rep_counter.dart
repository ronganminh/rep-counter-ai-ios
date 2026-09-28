/// Lõi đếm rep — thuần Dart, không phụ thuộc camera hay ML Kit.
///
/// Đây là bản port 1-1 của `detect_reps` + `merge_arms` trong notebook Python,
/// nên `test/rep_counter_test.dart` so được kết quả với số liệu sinh từ Python.
///
/// Khác biệt DUY NHẤT so với notebook: phần tách set ở đây là **nhân quả**
/// (chỉ nhìn quá khứ). Notebook gom set bằng cả rep tương lai — đúng cho phân
/// tích video nhưng không dùng được khi đang quay trực tiếp.
library;

import 'dart:collection';
import 'dart:math' as math;

/// Làm mượt nhân quả: trung bình trượt cửa sổ ngắn.
///
/// Notebook dùng Savitzky-Golay đối xứng — cần cả mẫu tương lai nên real-time
/// không xài được. Trung bình trượt trễ nửa cửa sổ; giữ cửa sổ ~0.15–0.2 s để
/// độ trễ không đáng kể so với nhịp rep ~1 s.
class RollingMean {
  RollingMean(this.window) : assert(window >= 1);

  final int window;
  final Queue<double> _buf = Queue<double>();
  double _sum = 0;

  void reset() {
    _buf.clear();
    _sum = 0;
  }

  double add(double v) {
    _buf.addLast(v);
    _sum += v;
    if (_buf.length > window) _sum -= _buf.removeFirst();
    return _sum / _buf.length;
  }
}

/// Bản ghi một rep vừa được đếm.
///
/// Tên là `CountedRep` chứ không phải `RepEvent`: `rep_tracker.dart` dùng
/// `RepEvent` cho cả chuỗi sự kiện của một chu kỳ (bắt đầu / chạm đáy / hoàn tất
/// / huỷ), còn lớp này chỉ là kết quả cuối của phép đếm.
class CountedRep {
  CountedRep({required this.at, required this.amplitude, required this.peak});

  /// Thời điểm tín hiệu vượt ngưỡng trên — sớm hơn đỉnh thật ~0.1–0.2 s.
  final Duration at;
  final double amplitude;
  final double peak;
}

enum _Phase { unknown, down, up }

/// Trigger Schmitt: đếm khi tín hiệu đi LÊN cắt [hi], sau khi đã xuống dưới [lo].
///
/// Hai chốt chặn nhiễu, giống hệt notebook:
///  - [minAmplitude]: chênh lệch đáy→đỉnh tối thiểu, loại rung tay lúc nghỉ.
///  - [minPeriod]: khoảng cách tối thiểu giữa hai rep, chống đếm kép.
class RepCounter {
  RepCounter({
    required this.hi,
    required this.lo,
    required this.minAmplitude,
    this.minPeriod = const Duration(milliseconds: 500),
    this.startFromTop = false,
  }) : assert(hi > lo, 'hi phải lớn hơn lo, nếu không trigger mất trễ');

  final double hi;
  final double lo;
  final double minAmplitude;
  final Duration minPeriod;

  /// Chỉ bắt đầu theo dõi khi đã thấy tín hiệu ở trên [hi] (tư thế nghỉ).
  ///
  /// Mặc định (false) giống notebook: vào giữa chừng ở dưới [lo] thì coi như
  /// đang ở đáy, đi lên qua [hi] là tính một rep. Kéo xà KHÔNG dùng được như
  /// vậy: lúc với tay bám xà, khuỷu gập rồi duỗi ra đúng một vòng — trên video
  /// thật mỗi lần lên xà sinh một rep ma. Bật cờ này thì rep đầu chỉ tính sau
  /// khi đã treo thẳng tay.
  final bool startFromTop;

  _Phase _phase = _Phase.unknown;
  double _trough = double.infinity;
  Duration? _lastRep;
  int count = 0;

  /// Mất pose -> quên trạng thái, tránh ghép đáy trước với đỉnh sau khoảng trống.
  void onSignalLost() => _phase = _Phase.unknown;

  void reset() {
    _phase = _Phase.unknown;
    _trough = double.infinity;
    _lastRep = null;
    count = 0;
  }

  /// Trả về [CountedRep] đúng frame đếm được 1 rep, ngược lại null.
  CountedRep? update(double v, Duration t) {
    if (v.isNaN) {
      onSignalLost();
      return null;
    }
    if (_phase == _Phase.unknown) {
      if (v > hi) {
        _phase = _Phase.up;
      } else if (!startFromTop) {
        _phase = _Phase.down;
      }
      _trough = v;
      return null;
    }

    if (_phase == _Phase.down) {
      if (v < _trough) _trough = v;
      if (v > hi) {
        final amp = v - _trough;
        _phase = _Phase.up;
        final farEnough = _lastRep == null || (t - _lastRep!) >= minPeriod;
        if (amp >= minAmplitude && farEnough) {
          _lastRep = t;
          count++;
          return CountedRep(at: t, amplitude: amp, peak: v);
        }
      }
    } else if (v < lo) {
      _phase = _Phase.down;
      _trough = v;
    }
    return null;
  }
}

/// Gộp rep của hai tay xảy ra gần nhau thành một.
///
/// Tự đúng cho cả ba kiểu: hai tay đồng thời (gộp), xen kẽ (lệch nửa chu kỳ nên
/// không gộp), một tay (tay kia không sinh rep).
class TwoArmMerger {
  TwoArmMerger({this.window = const Duration(milliseconds: 400)});

  final Duration window;
  Duration? _lastAt;
  String? _lastArm;
  int total = 0;

  void reset() {
    _lastAt = null;
    _lastArm = null;
    total = 0;
  }

  /// [arm] là 'L' hoặc 'R'. Trả true nếu đây là một rep MỚI (không phải bản sao
  /// của tay kia trong cùng nhịp).
  bool accept(String arm, Duration at) {
    final isDuplicate = _lastAt != null &&
        _lastArm != null &&
        _lastArm != arm &&
        (at - _lastAt!) <= window;
    _lastAt = at;
    _lastArm = arm;
    if (isDuplicate) return false;
    total++;
    return true;
  }
}

enum SessionState { idle, working, resting }

class SetSummary {
  SetSummary({required this.index, required this.reps, required this.start, required this.end});

  final int index;
  final int reps;
  final Duration start;
  final Duration end;

  Duration get duration => end - start;
}

/// Theo dõi set theo thời gian thực — bản nhân quả của `group_sets`.
///
/// Quy tắc: có rep -> đang tập. Quá [restTimeout] không có rep nào -> chốt set
/// và chuyển sang nghỉ. Set ít hơn [minReps] rep bị bỏ (nhấc tay lẻ, chỉnh tư thế).
class SessionTracker {
  SessionTracker({
    this.restTimeout = const Duration(seconds: 6),
    this.minReps = 3,
  });

  final Duration restTimeout;
  final int minReps;

  final List<SetSummary> sets = [];
  SessionState state = SessionState.idle;
  int repsInCurrentSet = 0;
  int totalReps = 0;

  Duration? _setStart;
  Duration? _lastRepAt;

  void reset() {
    sets.clear();
    state = SessionState.idle;
    repsInCurrentSet = 0;
    totalReps = 0;
    _setStart = null;
    _lastRepAt = null;
  }

  void onRep(Duration at) {
    if (state != SessionState.working) {
      state = SessionState.working;
      _setStart = at;
      repsInCurrentSet = 0;
    }
    repsInCurrentSet++;
    totalReps++;
    _lastRepAt = at;
  }

  /// Gọi mỗi frame để phát hiện set kết thúc do hết giờ.
  void tick(Duration now) {
    if (state != SessionState.working || _lastRepAt == null) return;
    if (now - _lastRepAt! >= restTimeout) _closeSet();
  }

  /// Chốt set đang mở (gọi khi dừng buổi tập).
  void finish() => _closeSet();

  void _closeSet() {
    if (state == SessionState.working &&
        repsInCurrentSet >= minReps &&
        _setStart != null &&
        _lastRepAt != null) {
      sets.add(SetSummary(
        index: sets.length + 1,
        reps: repsInCurrentSet,
        start: _setStart!,
        end: _lastRepAt!,
      ));
    } else {
      // set quá ngắn -> không tính vào tổng, trả lại số rep đã cộng
      totalReps -= repsInCurrentSet;
    }
    state = SessionState.resting;
    repsInCurrentSet = 0;
    _setStart = null;
  }
}

/// Tự dò ngưỡng từ chính người đang tập, thay vì bê ngưỡng của người khác.
///
/// Cần thiết vì ngưỡng trong notebook đo trên keypoint COCO của YOLO; MediaPipe
/// đánh số và chuẩn hoá khác nên KHÔNG bê thẳng sang được.
class Calibrator {
  Calibrator({this.minSamples = 90, this.minSpan = 0.15});

  final int minSamples;

  /// Biên độ tối thiểu để coi là đã dao động thật, tính theo thang tín hiệu.
  final double minSpan;

  final List<double> _samples = [];

  int get sampleCount => _samples.length;

  void add(double v) {
    if (v.isNaN) return;
    _samples.add(v);
    if (_samples.length > 3000) _samples.removeAt(0);
  }

  void reset() => _samples.clear();

  /// Trả về (hi, lo, minAmp) hoặc null nếu chưa đủ dữ liệu / chưa dao động đủ.
  ({double hi, double lo, double minAmp})? suggest() {
    if (_samples.length < minSamples) return null;
    final s = List<double>.from(_samples)..sort();
    double pct(double p) => s[(p * (s.length - 1)).round().clamp(0, s.length - 1)];
    final lo = pct(0.10), hi = pct(0.90);
    final span = hi - lo;
    if (span < minSpan) return null;
    return (hi: lo + 2 * span / 3, lo: lo + span / 3, minAmp: span * 0.5);
  }
}

double clampDouble(double v, double lo, double hi) => math.max(lo, math.min(hi, v));
