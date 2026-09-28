/// Kéo xà: cổng "đang bám xà", cờ `startFromTop`, và phát lại hai video thật.
///
/// Fixture trong `test/fixtures/pull_up_*.json` sinh bằng
/// `tools/gen_pullup_fixture.py` (MediaPipe trên video trong `pull_up/`, 7.5 fps).
/// Số rep kỳ vọng là của bản Python tham chiếu chạy cùng thuật toán; nếu test
/// phát lại đỏ thì bản Dart đã lệch khỏi thứ đã được kiểm với đếm tay — đừng
/// sửa số kỳ vọng.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/exercise.dart';
import 'package:rep_counter_app/features/diag/diag_recorder.dart';
import 'package:rep_counter_app/placement.dart';
import 'package:rep_counter_app/rep_counter.dart';

const _view = Size(1080, 1920);

/// Người đứng giữa khung, vai rộng 200 px, vai ở y = 900.
Landmarks _body({required double wristY, double likelihood = 0.95}) {
  PoseLandmark l(PoseLandmarkType t, double x, double y) =>
      PoseLandmark(type: t, x: x, y: y, z: 0, likelihood: likelihood);
  final m = {
    PoseLandmarkType.nose: l(PoseLandmarkType.nose, 540, 800),
    PoseLandmarkType.leftShoulder: l(PoseLandmarkType.leftShoulder, 640, 900),
    PoseLandmarkType.rightShoulder: l(PoseLandmarkType.rightShoulder, 440, 900),
    PoseLandmarkType.leftElbow: l(PoseLandmarkType.leftElbow, 700, 800),
    PoseLandmarkType.rightElbow: l(PoseLandmarkType.rightElbow, 380, 800),
    PoseLandmarkType.leftWrist: l(PoseLandmarkType.leftWrist, 680, wristY),
    PoseLandmarkType.rightWrist: l(PoseLandmarkType.rightWrist, 400, wristY),
    PoseLandmarkType.leftHip: l(PoseLandmarkType.leftHip, 610, 1250),
    PoseLandmarkType.rightHip: l(PoseLandmarkType.rightHip, 470, 1250),
  };
  return Landmarks(m);
}

bool _gate(Landmarks lm) => pullUp.countGate!(lm, pullUp.minLikelihood);

void main() {
  group('cổng đang bám xà', () {
    test('treo thẳng tay (cổ tay cao hơn vai 2 lần bề rộng vai) -> mở', () {
      expect(_gate(_body(wristY: 900 - 2.0 * 200)), isTrue);
    });

    test('lên đỉnh, vai sát xà (cổ tay thấp hơn vai 0.2 vai) -> vẫn mở', () {
      // Đỉnh rep thật có cổ tay chỉ cao hơn vai 0.04. Cổng chặn ở đây là mất
      // đúng khoảnh khắc quyết định của rep.
      expect(_gate(_body(wristY: 900 + 0.2 * 200)), isTrue);
    });

    test('đứng thả tay giữa hai set -> đóng', () {
      expect(_gate(_body(wristY: 1250)), isFalse);
    });

    test('không thấy cổ tay (máy đặt gần, tay khuất khỏi khung) -> đóng', () {
      final lm = _body(wristY: 500);
      final m = <PoseLandmarkType, PoseLandmark>{
        for (final t in PoseLandmarkType.values)
          if (lm.get(t) != null &&
              t != PoseLandmarkType.leftWrist &&
              t != PoseLandmarkType.rightWrist)
            t: lm.get(t)!,
      };
      expect(_gate(Landmarks(m)), isFalse);
    });
  });

  group('startFromTop', () {
    RepCounter make(bool top) => RepCounter(
        hi: 140, lo: 90, minAmplitude: 40, startFromTop: top,
        minPeriod: const Duration(milliseconds: 100));

    int run(RepCounter c, List<double> xs) {
      var n = 0;
      for (var i = 0; i < xs.length; i++) {
        if (c.update(xs[i], Duration(milliseconds: i * 130)) != null) n++;
      }
      return n;
    }

    // Với tay bám xà: khuỷu gập 60° rồi duỗi hẳn ra khi treo.
    const grab = <double>[60, 80, 120, 160, 175];

    test('tắt (mặc định, hít đất): lúc với tay bám xà bị tính một rep', () {
      expect(run(make(false), grab), 1);
    });

    test('bật: lúc bám xà không tính, rep kéo lên sau đó thì tính', () {
      expect(run(make(true), <double>[...grab, 120, 60, 40, 80, 150, 175]), 1);
    });

    test('mất tín hiệu giữa chừng thì phải treo thẳng lại mới đếm tiếp', () {
      final c = make(true);
      expect(run(c, [175, 170, 60, 40]), 0);
      c.onSignalLost();
      // Vào lại ở đáy rồi đi lên: không được ghép thành một rep.
      expect(run(c, [45, 100, 170]), 0);
    });
  });

  group('phát lại video thật', () {
    for (final name in ['pull_up_front', 'pull_up_back_closeup']) {
      test(name, () {
        final f = File('test/fixtures/$name.json');
        final d = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
        final tMs = (d['t_ms'] as List).cast<int>();
        double? n(Object? v) => v == null ? null : (v as num).toDouble();
        final left = (d['left'] as List).map(n).toList();
        final right = (d['right'] as List).map(n).toList();
        final gate = (d['gate'] as List).cast<bool>();

        // Cùng đường đi với camera_page cho CombineArms.mean.
        final counter = RepCounter(
          hi: pullUp.repHi,
          lo: pullUp.repLo,
          minAmplitude: pullUp.minAmplitude,
          minPeriod: pullUp.minPeriod,
          startFromTop: pullUp.startFromTop,
        );
        final smooth = RollingMean(pullUp.smoothWindow);
        final got = <int>[];
        for (var i = 0; i < tMs.length; i++) {
          if (!gate[i]) {
            counter.onSignalLost();
            smooth.reset();
            continue;
          }
          final vals = [left[i], right[i]].whereType<double>().toList();
          if (vals.isEmpty) {
            counter.onSignalLost();
            continue;
          }
          final v = smooth.add(vals.reduce((a, b) => a + b) / vals.length);
          if (counter.update(v, Duration(milliseconds: tMs[i])) != null) {
            got.add(tMs[i]);
          }
        }

        expect(got, (d['expected_rep_ms'] as List).cast<int>(),
            reason: 'phải khớp từng rep với bản Python đã kiểm bằng đếm tay');
        final truth = d['ground_truth_reps'] as int;
        expect(got.length, lessThanOrEqualTo(truth),
            reason: 'không được đếm nhiều hơn số rep thật');
      });
    }

    test('video trực diện: sót tối đa 5%, không rep ma', () {
      // Đếm tay 47 rep / 10 set. Bản hiện tại được 46 — sót một rep ở set 8
      // (445–456 s). Không rep nào lúc với tay bám xà hay buông xà: phần
      // "không vượt số thật" đã kiểm ở test phát lại phía trên.
      final d = jsonDecode(
              File('test/fixtures/pull_up_front.json').readAsStringSync())
          as Map<String, dynamic>;
      final truth = d['ground_truth_reps'] as int;
      expect((d['expected_rep_ms'] as List).length,
          greaterThanOrEqualTo((truth * 0.95).ceil()));
    });
  });

  group('đặt người', () {
    test('kéo xà không có khung chữ nhật', () {
      expect(guideFor(pullUp, S.vi).body, isNull);
    });

    test('đứng thả tay -> sai tư thế, kèm lời nhắc bám xà', () {
      final r = evaluatePlacement(
        profile: pullUp,
        lm: _body(wristY: 1250),
        viewSize: _view,
        guide: guideFor(pullUp, S.vi),
        strings: S.vi,
      );
      expect(r.status, PlacementStatus.wrongPose);
      expect(r.detail, S.vi.detailNotHanging);
    });

    test('đang treo -> sẵn sàng', () {
      final r = evaluatePlacement(
        profile: pullUp,
        lm: _body(wristY: 500),
        viewSize: _view,
        guide: guideFor(pullUp, S.vi),
        strings: S.vi,
      );
      expect(r.status, PlacementStatus.ready);
    });
  });

  test('hít đất không đổi hành vi', () {
    expect(pushUp.smoothWindow, 5);
    expect(pushUp.startFromTop, isFalse);
    expect(pushUp.countGate, isNull);
  });

  group('CSV chẩn đoán', () {
    int cols(String s) => s.split(',').length;

    test('số cột mỗi dòng khớp tiêu đề, có hay không có pose', () {
      final header = diagCsvHeader();
      final withPose = diagCsvRow(
        at: const Duration(milliseconds: 1234),
        raw: 170,
        smooth: 168,
        hi: 140,
        lo: 90,
        poseFound: true,
        status: 'ready',
        reps: 3,
        rawRight: 172,
        gate: true,
        exercise: 'pull_up',
        view: _view,
        landmarks: _body(wristY: 500),
      );
      final noPose = diagCsvRow(
        at: Duration.zero,
        raw: null,
        smooth: null,
        hi: 140,
        lo: 90,
        poseFound: false,
        status: 'noPose',
        reps: 0,
      );
      expect(cols(withPose), cols(header));
      expect(cols(noPose), cols(header));
    });

    test('chín cột đầu giữ nguyên như bản cũ', () {
      expect(diagCsvHeader(),
          startsWith('ms,raw,smooth,hi,lo,pose,status,reps,rep_event,'));
    });
  });
}
