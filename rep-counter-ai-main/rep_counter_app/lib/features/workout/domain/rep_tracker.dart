/// Theo dõi từng rep và phát event, gom số liệu thô cho `RepMetric`.
///
/// **Bọc quanh `RepCounter` chứ không sửa nó.** `RepCounter` có test đối chiếu
/// từng frame với bản Python (`test/rep_vector.json`); mọi thay đổi hành vi đếm ở
/// đó sẽ làm vector đó vô nghĩa. IMPLEMENTATION_PLAN §18 và §5.4 yêu cầu giữ nguyên.
///
/// Việc của lớp này chỉ là: quan sát dòng tín hiệu đi vào, tích luỹ số liệu giữa
/// hai lần `RepCounter` báo có rep, rồi đóng gói lại.
library;

import 'dart:math' as math;

import '../../../rep_counter.dart';
import 'rep_metric.dart';

/// Một khung dữ liệu pose đã rút gọn thành các con số cần cho việc đếm và chấm.
class PoseSample {
  const PoseSample({
    required this.at,
    required this.signal,
    this.leftAngle,
    this.rightAngle,
    this.torsoDeviationDeg,
    this.poseConfidence = 1.0,
  });

  final Duration at;

  /// Tín hiệu đã làm mượt dùng để đếm. `null` = mất pose ở khung này.
  final double? signal;

  final double? leftAngle;
  final double? rightAngle;

  /// Độ lệch trục thân so với phương yêu cầu (độ). `null` nếu không đo được.
  final double? torsoDeviationDeg;

  /// 0..1.
  final double poseConfidence;

  bool get hasSignal => signal != null && !signal!.isNaN;
}

sealed class RepEvent {
  const RepEvent(this.at);
  final Duration at;
}

/// Bắt đầu đi xuống từ tư thế trên.
class RepStarted extends RepEvent {
  const RepStarted(super.at);
}

/// Chạm đáy — tín hiệu bắt đầu đi lên trở lại.
class RepReachedBottom extends RepEvent {
  const RepReachedBottom(super.at, this.bottomAngle);
  final double bottomAngle;
}

/// Hoàn tất một rep hợp lệ.
class RepCompleted extends RepEvent {
  const RepCompleted(super.at, this.observation);
  final RepObservation observation;
}

/// Chu kỳ bị bỏ dở: mất pose, hoặc rời khỏi tư thế hợp lệ giữa chừng.
class RepAborted extends RepEvent {
  const RepAborted(super.at, this.reason);
  final RepAbortReason reason;
}

enum RepAbortReason { signalLost, placementLost, reset }

class RepTracker {
  RepTracker({
    required RepCounter counter,
    double torsoDeviationDeg = 25.0,
  })  : _counter = counter,
        _torsoDeviationDeg = torsoDeviationDeg;

  final RepCounter _counter;
  final double _torsoDeviationDeg;

  // Trạng thái tích luỹ giữa hai rep.
  Duration? _startedAt;
  Duration? _bottomAt;
  double _bottom = double.infinity;
  double? _leftAtBottom;
  double? _rightAtBottom;
  double _maxTorso = 0;
  int _torsoOverCount = 0;
  double _confSum = 0;
  int _samples = 0;
  bool _descending = false;
  double? _prevSignal;

  int get count => _counter.count;

  void reset() {
    _counter.reset();
    _clearAccumulator();
  }

  void _clearAccumulator() {
    _startedAt = null;
    _bottomAt = null;
    _bottom = double.infinity;
    _leftAtBottom = null;
    _rightAtBottom = null;
    _maxTorso = 0;
    _torsoOverCount = 0;
    _confSum = 0;
    _samples = 0;
    _descending = false;
    _prevSignal = null;
  }

  /// Báo mất pose hoặc rời tư thế hợp lệ. Trả event nếu đang dở một chu kỳ.
  RepEvent? onInterrupted(Duration at, RepAbortReason reason) {
    _counter.onSignalLost();
    final wasMidRep = _startedAt != null;
    _clearAccumulator();
    return wasMidRep ? RepAborted(at, reason) : null;
  }

  /// Nạp một khung. Trả về danh sách event phát sinh (thường 0 hoặc 1).
  List<RepEvent> update(PoseSample s) {
    if (!s.hasSignal) {
      final e = onInterrupted(s.at, RepAbortReason.signalLost);
      return e == null ? const [] : [e];
    }

    final v = s.signal!;
    final events = <RepEvent>[];

    // Tích luỹ chất lượng cho chu kỳ hiện tại.
    _confSum += s.poseConfidence;
    _samples++;
    final td = s.torsoDeviationDeg;
    if (td != null) {
      _maxTorso = math.max(_maxTorso, td);
      if (td > _torsoDeviationDeg) _torsoOverCount++;
    }

    // Phát hiện bắt đầu đi xuống / chạm đáy bằng chính dòng tín hiệu.
    // Không hỏi RepCounter vì trạng thái nội bộ của nó là chi tiết cài đặt.
    final prev = _prevSignal;
    if (prev != null) {
      if (!_descending && v < prev && v < _counter.hi) {
        _descending = true;
        _startedAt ??= s.at;
        events.add(RepStarted(s.at));
      }
      if (_descending && v > prev && _bottomAt == null) {
        _bottomAt = s.at;
        events.add(RepReachedBottom(s.at, _bottom));
      }
    }
    _prevSignal = v;

    if (v < _bottom) {
      _bottom = v;
      _bottomAt = null; // vẫn còn đi xuống -> đáy chưa chốt
      _leftAtBottom = s.leftAngle;
      _rightAtBottom = s.rightAngle;
    }

    final rep = _counter.update(v, s.at);
    if (rep != null) {
      final started = _startedAt ?? s.at;
      final bottomAt = _bottomAt ?? started;
      events.add(RepCompleted(
        s.at,
        RepObservation(
          startedAt: started,
          bottomAt: bottomAt,
          completedAt: s.at,
          bottomAngle: _bottom.isFinite ? _bottom : v,
          topAngle: v,
          leftBottomAngle: _leftAtBottom,
          rightBottomAngle: _rightAtBottom,
          maxTorsoDeviation: _maxTorso,
          torsoDeviationFraction: _samples == 0 ? 0 : _torsoOverCount / _samples,
          averagePoseConfidence: _samples == 0 ? 1 : _confSum / _samples,
          sampleCount: _samples,
        ),
      ));
      // Bắt đầu chu kỳ mới từ đỉnh vừa đạt.
      _clearAccumulator();
      _prevSignal = v;
    }
    return events;
  }
}
