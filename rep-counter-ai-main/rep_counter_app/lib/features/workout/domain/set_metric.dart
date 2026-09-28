/// Số liệu của một set.
library;

import 'dart:math' as math;

import 'rep_metric.dart';

class SetMetric {
  const SetMetric({required this.index, required this.reps});

  /// Bắt đầu từ 1.
  final int index;
  final List<RepMetric> reps;

  int get validReps => reps.where((r) => r.valid).length;
  int get flaggedReps => reps.where((r) => r.flagged).length;

  Duration get startedAt =>
      reps.isEmpty ? Duration.zero : reps.first.observation.startedAt;
  Duration get endedAt =>
      reps.isEmpty ? Duration.zero : reps.last.observation.completedAt;
  double get durationSeconds => (endedAt - startedAt).inMicroseconds / 1e6;

  double get averageRepSeconds => _mean(reps.map((r) => r.durationSeconds));
  double get averageAmplitude => _mean(reps.map((r) => r.amplitude));

  /// Hệ số biến thiên của nhịp (độ lệch chuẩn / trung bình).
  ///
  /// Set có 0 hoặc 1 rep trả 0: **không phải "nhịp hoàn hảo"** mà là "không đo
  /// được". Nơi dùng phải phân biệt qua [hasCadence].
  double get cadenceVariation {
    if (reps.length < 2) return 0;
    final gaps = <double>[];
    for (var i = 1; i < reps.length; i++) {
      gaps.add((reps[i].observation.completedAt -
              reps[i - 1].observation.completedAt)
          .inMicroseconds /
          1e6);
    }
    final m = _mean(gaps);
    if (m <= 0) return 0;
    final varSum = gaps.fold<double>(0, (a, g) => a + math.pow(g - m, 2));
    return math.sqrt(varSum / gaps.length) / m;
  }

  bool get hasCadence => reps.length >= 2;

  static double _mean(Iterable<double> xs) {
    var n = 0;
    var s = 0.0;
    for (final x in xs) {
      if (x.isFinite) {
        s += x;
        n++;
      }
    }
    return n == 0 ? 0 : s / n;
  }

  static const int schemaVersion = 1;

  Map<String, dynamic> toJson() => {
        'schema_version': schemaVersion,
        'index': index,
        'reps': reps.map((r) => r.toJson()).toList(),
      };

  static SetMetric fromJson(Map<String, dynamic> j) {
    final v = (j['schema_version'] as num?)?.toInt() ?? 1;
    if (v > schemaVersion) {
      throw FormatException('SetMetric schema_version $v mới hơn bản app hiểu được '
          '($schemaVersion)');
    }
    return SetMetric(
      index: (j['index'] as num).toInt(),
      reps: ((j['reps'] as List?) ?? const [])
          .map((e) => RepMetric.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  String toString() => 'Set$index: ${reps.length} rep, '
      '${averageRepSeconds.toStringAsFixed(2)}s/rep, '
      'biên độ ${averageAmplitude.toStringAsFixed(1)}°';
}
