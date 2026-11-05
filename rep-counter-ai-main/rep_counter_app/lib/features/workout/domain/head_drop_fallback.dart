/// Second counting channel for front-view push-ups: the head dropping toward
/// the hands.
///
/// Why: with the phone low in front, ML Kit sometimes misplaces the body at
/// the bottom of a rep. It draws the hips on the face and straightens the
/// arms, so the elbow angle never crosses its lower threshold and a real rep
/// is lost. On the user video of 2026-11-02 the face and the two hands stay
/// tracked through those frames. The nose falls from well above the hands to
/// their level, so it can still see the rep.
///
/// The elbow channel stays the primary counter. This channel only adds a rep
/// when the elbow channel did not count one within [RepChannelFusion.window].
/// It runs behind the same count gate and placement checks as the elbow
/// channel, so a user sitting or kneeling between sets cannot feed it.
library;

import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../../exercise.dart';
import '../../../rep_counter.dart';
import 'rep_metric.dart';
import 'rep_tracker.dart';

/// Thresholds for the head-drop signal, in units of the distance between the
/// two wrists.
class HeadDropFallback {
  const HeadDropFallback({
    this.hi = 0.85,
    this.lo = 0.45,
    this.minAmplitude = 0.5,
    this.smoothWindow = 3,
    this.minPeriod = const Duration(milliseconds: 700),
    this.minWristSpanFraction = 0.15,
    this.maxHandTravel = 0.3,
    this.handWindow = const Duration(seconds: 2),
  });

  /// The head must come back above this to complete a rep.
  final double hi;

  /// The head must go below this to start a rep.
  final double lo;
  final double minAmplitude;
  final int smoothWindow;
  final Duration minPeriod;

  /// Wrist span as a fraction of the short side of the view. Closer wrists
  /// mean the landmarks collapsed; such a frame carries no signal.
  final double minWristSpanFraction;

  /// Hands stay planted through a push-up. A head rep is dropped when the
  /// midpoint of the wrists moved more than this many wrist spans during the
  /// last [handWindow]: that is a gesture (hands to the head while kneeling),
  /// not a push-up. Measured on pushup-1 (rest between sets).
  final double maxHandTravel;
  final Duration handWindow;
}

/// One frame of the head-drop channel.
typedef HeadDropFrame = ({double signal, Offset wrists, double span});

/// How far the nose is above the hands, in wrist spans.
///
/// The value is about 1.0–1.6 at the top of a push-up and 0.0–0.3 at the
/// bottom on the user video. It is null when the nose or a wrist is missing,
/// or when the wrists collapse together.
HeadDropFrame? headDropSignal(
  Landmarks lm, {
  required double minLikelihood,
  required double viewShortSide,
  required HeadDropFallback config,
}) {
  final nose = lm.pt(PoseLandmarkType.nose, minLikelihood: minLikelihood);
  final lw = lm.pt(PoseLandmarkType.leftWrist, minLikelihood: minLikelihood);
  final rw = lm.pt(PoseLandmarkType.rightWrist, minLikelihood: minLikelihood);
  if (nose == null || lw == null || rw == null) return null;
  final span = (lw.dx - rw.dx).abs();
  if (span < viewShortSide * config.minWristSpanFraction) return null;
  final mid = Offset((lw.dx + rw.dx) / 2, (lw.dy + rw.dy) / 2);
  return (signal: (mid.dy - nose.dy) / span, wrists: mid, span: span);
}

/// Lets one physical rep count once when two channels can each see it.
///
/// A primary rep is suppressed only when a fallback rep was counted within
/// [window] before it. A fallback rep is suppressed when any rep was counted
/// within [window] before it.
class RepChannelFusion {
  RepChannelFusion({this.window = const Duration(milliseconds: 1000)});

  final Duration window;
  Duration? _last;
  bool _lastWasFallback = false;

  bool acceptPrimary(Duration at) {
    final last = _last;
    final duplicate =
        last != null && _lastWasFallback && at - last <= window && at >= last;
    _last = at;
    _lastWasFallback = false;
    return !duplicate;
  }

  bool acceptFallback(Duration at) {
    final last = _last;
    if (last != null && at - last <= window && at >= last) return false;
    _last = at;
    _lastWasFallback = true;
    return true;
  }

  void reset() {
    _last = null;
    _lastWasFallback = false;
  }
}

/// The head-drop channel: smoothing, its own tracker, and the fusion with the
/// elbow channel.
class HeadDropChannel {
  HeadDropChannel(this.config)
      : _smooth = RollingMean(config.smoothWindow),
        _tracker = RepTracker(
          counter: RepCounter(
            hi: config.hi,
            lo: config.lo,
            minAmplitude: config.minAmplitude,
            minPeriod: config.minPeriod,
          ),
        );

  final HeadDropFallback config;
  final RollingMean _smooth;
  final RepTracker _tracker;
  final RepChannelFusion fusion = RepChannelFusion();

  // Elbow signal range seen since the last counted rep, so a fallback rep
  // still carries elbow angles for the quality checks and the history.
  double? _elbowMin, _elbowMax;

  final List<({Duration at, Offset wrists, double span})> _hands = [];

  bool get _handsPlanted {
    if (_hands.isEmpty) return false;
    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    final spans = <double>[];
    for (final h in _hands) {
      minX = math.min(minX, h.wrists.dx);
      maxX = math.max(maxX, h.wrists.dx);
      minY = math.min(minY, h.wrists.dy);
      maxY = math.max(maxY, h.wrists.dy);
      spans.add(h.span);
    }
    spans.sort();
    final span = spans[spans.length ~/ 2];
    return math.max(maxX - minX, maxY - minY) <= config.maxHandTravel * span;
  }

  /// Keeps the elbow events that are not duplicates of a fallback rep.
  List<RepEvent> filterPrimary(List<RepEvent> events, double? elbowSignal) {
    if (elbowSignal != null) {
      _elbowMin = _elbowMin == null || elbowSignal < _elbowMin!
          ? elbowSignal
          : _elbowMin;
      _elbowMax = _elbowMax == null || elbowSignal > _elbowMax!
          ? elbowSignal
          : _elbowMax;
    }
    final out = <RepEvent>[];
    for (final e in events) {
      if (e is RepCompleted) {
        if (!fusion.acceptPrimary(e.at)) continue;
        _elbowMin = _elbowMax = null;
      }
      out.add(e);
    }
    return out;
  }

  /// Feeds one frame of the head signal; returns a [RepCompleted] for a rep
  /// the elbow channel missed. Aborts of this channel are not reported: the
  /// elbow channel already reports the same interruption.
  List<RepEvent> update({
    required Duration at,
    required HeadDropFrame? frame,
    double? torsoDeviationDeg,
    double poseConfidence = 1.0,
  }) {
    final v = frame == null ? null : _smooth.add(frame.signal);
    if (frame == null) {
      _smooth.reset();
      _hands.clear();
    } else {
      _hands
        ..add((at: at, wrists: frame.wrists, span: frame.span))
        ..removeWhere((h) => at - h.at > config.handWindow);
    }
    final events = _tracker.update(PoseSample(
      at: at,
      signal: v,
      torsoDeviationDeg: torsoDeviationDeg,
      poseConfidence: poseConfidence,
    ));
    final out = <RepEvent>[];
    for (final e in events) {
      if (e is! RepCompleted) continue;
      if (!_handsPlanted) continue;
      if (!fusion.acceptFallback(e.at)) continue;
      final o = e.observation;
      out.add(RepCompleted(
        e.at,
        RepObservation(
          startedAt: o.startedAt,
          bottomAt: o.bottomAt,
          completedAt: o.completedAt,
          bottomAngle: _elbowMin ?? 90,
          topAngle: _elbowMax ?? 170,
          maxTorsoDeviation: o.maxTorsoDeviation,
          torsoDeviationFraction: o.torsoDeviationFraction,
          averagePoseConfidence: o.averagePoseConfidence,
          sampleCount: o.sampleCount,
        ),
      ));
      _elbowMin = _elbowMax = null;
    }
    return out;
  }

  /// Drops a half-done cycle (pose lost, left the valid position, paused).
  void interrupt(Duration at) {
    _tracker.onInterrupted(at, RepAbortReason.placementLost);
    _smooth.reset();
    _hands.clear();
    _elbowMin = _elbowMax = null;
  }
}
