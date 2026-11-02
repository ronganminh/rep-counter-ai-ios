import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:rep_counter_app/exercise.dart';
import 'package:rep_counter_app/features/workout/domain/head_drop_fallback.dart';
import 'package:rep_counter_app/features/workout/domain/rep_metric.dart';
import 'package:rep_counter_app/features/workout/domain/rep_tracker.dart';

/// Front-view push-up, the shape measured on the user video of 2026-11-02:
/// hands about 330 px apart near the bottom of a 720 px wide view, the nose
/// about 1.3 wrist spans above them at the top and level with them at the
/// bottom.
Landmarks _frame({required double noseY, double span = 330}) {
  PoseLandmark p(PoseLandmarkType t, double x, double y) =>
      PoseLandmark(type: t, x: x, y: y, z: 0, likelihood: 0.95);
  const wristY = 880.0;
  return Landmarks({
    PoseLandmarkType.nose: p(PoseLandmarkType.nose, 360, noseY),
    PoseLandmarkType.leftWrist:
        p(PoseLandmarkType.leftWrist, 360 + span / 2, wristY),
    PoseLandmarkType.rightWrist:
        p(PoseLandmarkType.rightWrist, 360 - span / 2, wristY),
  });
}

const _config = HeadDropFallback();

double? _signal(Landmarks lm) => headDropSignal(lm,
        minLikelihood: 0.4, viewShortSide: 720, config: _config)
    ?.signal;

/// A frame with planted hands at (360, 880), 330 px apart.
HeadDropFrame _f(double h, {Offset wrists = const Offset(360, 880)}) =>
    (signal: h, wrists: wrists, span: 330);

/// Head height (in wrist spans) for one rep, 15 frames a second.
const _oneRep = [1.3, 1.3, 1.1, 0.8, 0.4, 0.15, 0.05, 0.1, 0.4, 0.8, 1.1, 1.3, 1.3];

Duration _ms(int ms) => Duration(milliseconds: ms);

List<RepEvent> _feed(HeadDropChannel c, List<double> heads, int startMs,
    {List<RepEvent> Function(int i, Duration at)? elbowAt}) {
  final out = <RepEvent>[];
  for (var i = 0; i < heads.length; i++) {
    final at = _ms(startMs + i * 67);
    if (elbowAt != null) out.addAll(c.filterPrimary(elbowAt(i, at), 150));
    out.addAll(c.update(at: at, frame: _f(heads[i])));
  }
  return out;
}

void main() {
  group('headDropSignal', () {
    test('is about 1.3 at the top and near 0 at the bottom', () {
      expect(_signal(_frame(noseY: 880 - 1.3 * 330)), closeTo(1.3, 1e-9));
      expect(_signal(_frame(noseY: 880)), closeTo(0, 1e-9));
    });

    test('is null when the wrists collapse or the nose is missing', () {
      expect(_signal(_frame(noseY: 500, span: 40)), isNull);
      final noNose = Landmarks({
        PoseLandmarkType.leftWrist: PoseLandmark(
            type: PoseLandmarkType.leftWrist,
            x: 500,
            y: 880,
            z: 0,
            likelihood: 0.95),
        PoseLandmarkType.rightWrist: PoseLandmark(
            type: PoseLandmarkType.rightWrist,
            x: 200,
            y: 880,
            z: 0,
            likelihood: 0.95),
      });
      expect(_signal(noNose), isNull);
    });
  });

  group('HeadDropChannel', () {
    test('counts a rep the elbow channel missed', () {
      final c = HeadDropChannel(_config);
      final events = _feed(c, _oneRep, 0);
      final reps = events.whereType<RepCompleted>().toList();
      expect(reps, hasLength(1));
      // No elbow angle was seen: neutral angles, so no false "shallow" flag.
      expect(reps.single.observation.bottomAngle, 90);
      expect(reps.single.observation.topAngle, 170);
    });

    test('one physical rep seen by both channels counts once', () {
      final c = HeadDropChannel(_config);
      // The elbow channel completes the same rep two frames after the head.
      final head = _feed(c, _oneRep, 0, elbowAt: (i, at) {
        if (i != 12) return const [];
        return [
          RepCompleted(at, _observation(at)),
        ];
      });
      final all = head.whereType<RepCompleted>().toList();
      expect(all, hasLength(1), reason: 'head rep counted, elbow duplicate dropped');
    });

    test('an elbow rep first suppresses the head rep of the same cycle', () {
      final c = HeadDropChannel(_config);
      final events = _feed(c, _oneRep, 0, elbowAt: (i, at) {
        if (i != 9) return const [];
        return [RepCompleted(at, _observation(at))];
      });
      final reps = events.whereType<RepCompleted>().toList();
      expect(reps, hasLength(1));
      expect(reps.single.at, _ms(9 * 67), reason: 'the elbow rep is kept');
    });

    test('consecutive reps two seconds apart all count', () {
      final c = HeadDropChannel(_config);
      final heads = [
        for (var r = 0; r < 4; r++) ...[..._oneRep, ...List.filled(17, 1.3)],
      ];
      final reps = _feed(c, heads, 0).whereType<RepCompleted>();
      expect(reps, hasLength(4));
    });

    test('an interruption at the bottom drops the half-done rep', () {
      final c = HeadDropChannel(_config);
      _feed(c, _oneRep.sublist(0, 7), 0);
      c.interrupt(_ms(500));
      // Back at the top after the interruption: no rep from the old bottom.
      final after = _feed(c, const [1.3, 1.3, 1.3], 600);
      expect(after.whereType<RepCompleted>(), isEmpty);
    });

    test('one missing frame at the bottom does not lose the rep', () {
      // Same rule as the elbow channel (RepCounter.onSignalLost): the phase is
      // forgotten, and a frame below `lo` restarts it at the bottom.
      final c = HeadDropChannel(_config);
      final out = <RepEvent>[];
      for (var i = 0; i < _oneRep.length; i++) {
        out.addAll(c.update(
            at: _ms(i * 67), frame: i == 6 ? null : _f(_oneRep[i])));
      }
      expect(out.whereType<RepCompleted>(), hasLength(1));
    });

    test('hands moving (a gesture while kneeling) is not a rep', () {
      // Hands go up to the head and back: the wrists travel a full span.
      final c = HeadDropChannel(_config);
      final out = <RepEvent>[];
      for (var i = 0; i < _oneRep.length; i++) {
        final lift = 330 * (1.3 - _oneRep[i]);
        out.addAll(c.update(
            at: _ms(i * 67),
            frame: _f(_oneRep[i], wrists: Offset(360, 880 - lift))));
      }
      expect(out.whereType<RepCompleted>(), isEmpty);
    });

    test('a small head bob in plank is not a rep', () {
      final c = HeadDropChannel(_config);
      const bob = [1.3, 1.2, 1.0, 0.9, 0.9, 1.0, 1.2, 1.3];
      expect(_feed(c, [...bob, ...bob, ...bob], 0).whereType<RepCompleted>(),
          isEmpty);
    });
  });

  group('RepChannelFusion', () {
    test('elbow reps alone are never suppressed', () {
      final f = RepChannelFusion();
      expect(f.acceptPrimary(_ms(0)), isTrue);
      expect(f.acceptPrimary(_ms(800)), isTrue);
    });

    test('a fallback rep long after the last rep counts', () {
      final f = RepChannelFusion();
      expect(f.acceptPrimary(_ms(0)), isTrue);
      expect(f.acceptFallback(_ms(2000)), isTrue);
      expect(f.acceptPrimary(_ms(2400)), isFalse);
      expect(f.acceptPrimary(_ms(4500)), isTrue);
    });
  });
}

RepObservation _observation(Duration at) => RepObservation(
      startedAt: at - const Duration(seconds: 1),
      bottomAt: at - const Duration(milliseconds: 500),
      completedAt: at,
      bottomAngle: 80,
      topAngle: 160,
    );
