/// Giữ vài giây tín hiệu gần nhất trong lúc chưa đếm được (L-D40).
///
/// Lúc canh vị trí, `CameraPage` huỷ chu kỳ đang dở ở mọi frame. Nếu người tập
/// bắt đầu rep đầu tiên trước khi khung báo "ready" (thường gặp: họ đã vào thế
/// và cử động trước khi app kịp nhận), đáy của rep đó bị quên; tới lúc ready
/// tín hiệu đã đi lên quá nửa nên biên độ còn lại không đủ và rep đầu bị sót.
///
/// Bộ đệm này giữ các frame liên tục gần nhất (mặc định 2,5 s). Đúng frame
/// chuyển sang đếm được, [primeTracker] nạp lại chúng vào tracker để tracker
/// biết chu kỳ đang dở, rồi **bỏ mọi event** sinh ra trong lúc nạp: không rep
/// nào được tính cho khoảng thời gian chưa ready. Chỉ rep hoàn tất ở frame
/// ready trở đi mới được đếm, như cũ.
library;

import 'dart:collection';

import '../../../rep_counter.dart';
import 'rep_tracker.dart';

/// Một frame đã rút gọn, giữ đủ để dựng lại [PoseSample].
class BufferedPoseFrame {
  const BufferedPoseFrame({
    required this.at,
    this.left,
    this.right,
    this.torsoDeviationDeg,
    this.poseConfidence = 1.0,
  });

  final Duration at;
  final double? left;
  final double? right;
  final double? torsoDeviationDeg;
  final double poseConfidence;
}

class PositioningSignalBuffer {
  PositioningSignalBuffer({
    this.window = const Duration(milliseconds: 2500),
    this.maxGap = const Duration(milliseconds: 500),
  });

  /// Chỉ giữ frame trong khoảng này tính tới frame mới nhất.
  final Duration window;

  /// Hai frame cách nhau hơn mức này thì coi như đứt quãng: bỏ phần cũ.
  final Duration maxGap;

  final Queue<BufferedPoseFrame> _frames = Queue<BufferedPoseFrame>();

  bool get isEmpty => _frames.isEmpty;
  int get length => _frames.length;

  void clear() => _frames.clear();

  void add(BufferedPoseFrame f) {
    final last = _frames.isEmpty ? null : _frames.last;
    if (last != null && (f.at < last.at || f.at - last.at > maxGap)) {
      _frames.clear();
    }
    _frames.addLast(f);
    while (f.at - _frames.first.at > window) {
      _frames.removeFirst();
    }
  }

  /// Lấy hết frame (cũ → mới) và làm rỗng bộ đệm.
  List<BufferedPoseFrame> drain() {
    final out = _frames.toList(growable: false);
    _frames.clear();
    return out;
  }
}

/// Nạp [frames] vào [tracker] qua [smooth] (cùng đường đi với frame thật) để
/// tracker nhớ đáy của chu kỳ đang dở. Mọi event trả về đều bị bỏ, nên không
/// rep nào được tính cho các frame này.
///
/// [pick] chọn giá trị thô từ frame (tay trái, tay phải, hoặc trung bình).
void primeTracker(
  RepTracker tracker,
  RollingMean smooth,
  Iterable<BufferedPoseFrame> frames,
  double? Function(BufferedPoseFrame f) pick,
) {
  for (final f in frames) {
    final raw = pick(f);
    final v = raw == null ? null : smooth.add(raw);
    tracker.update(PoseSample(
      at: f.at,
      signal: v,
      leftAngle: f.left,
      rightAngle: f.right,
      torsoDeviationDeg: f.torsoDeviationDeg,
      poseConfidence: f.poseConfidence,
    ));
  }
}
