import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/config/feature_flags.dart';

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  const manifestPath = 'test/fixtures/a9_stabilization_manifest.json';

  test('A9 maps all 24 vNext deliverables to implementation and tests', () {
    final manifest = _json(manifestPath);
    final deliverables =
        (manifest['deliverables'] as List).cast<Map<String, dynamic>>();

    expect(deliverables, hasLength(24));
    expect(
      deliverables.map((item) => item['id']).toSet(),
      Set<int>.from(List<int>.generate(24, (index) => index + 1)),
    );
    expect(deliverables.map((item) => item['node']).toSet(), hasLength(24));

    for (final item in deliverables) {
      final implementation =
          (item['implementation'] as List).cast<String>();
      final tests = (item['tests'] as List).cast<String>();
      expect(implementation, isNotEmpty, reason: 'deliverable ${item['id']}');
      expect(tests, isNotEmpty, reason: 'deliverable ${item['id']}');
      for (final path in [...implementation, ...tests]) {
        expect(
          File(path).existsSync(),
          isTrue,
          reason: 'deliverable ${item['id']} evidence missing: $path',
        );
      }
    }
  });

  test('A9 full sweep has automated evidence for all nine product flows', () {
    final manifest = _json(manifestPath);
    final sweep =
        (manifest['full_sweep'] as List).cast<Map<String, dynamic>>();
    const expected = <String>{
      'free_workout',
      'target_reps',
      'timed_challenge',
      'routine_workout',
      'history_reopen',
      'progress_filters',
      'export',
      'settings',
      'ai_result_ui',
    };

    expect(sweep.map((item) => item['id']).toSet(), expected);
    for (final item in sweep) {
      for (final path in (item['test_paths'] as List).cast<String>()) {
        expect(File(path).existsSync(), isTrue, reason: '${item['id']}: $path');
      }
    }
  });

  test('A9 regression baseline stays separate from human ground truth', () {
    final manifest = _json(manifestPath);
    final baseline = _json('test/fixtures/video_ground_truth.json');
    final regression =
        manifest['production_regression'] as Map<String, dynamic>;

    expect(regression['pushup_1']['expected_engine_count'], 28);
    expect(regression['pushup_2']['expected_engine_count'], 67);
    expect(regression['pushup_1']['human_ground_truth'], isNull);
    expect(regression['pushup_2']['human_ground_truth'], isNull);

    expect(baseline['pushup-a']['current_engine_count'], 28);
    expect(baseline['pushup-b']['current_engine_count'], 67);
    expect(baseline['pushup-a']['human_ground_truth'], isNull);
    expect(baseline['pushup-b']['human_ground_truth'], isNull);
  });

  test('A9 keeps pull-up gated after the blocked A8 decision', () {
    final a8 = _json('test/fixtures/pull_up_validation_manifest.json');
    final decision = a8['release_decision'] as Map<String, dynamic>;

    expect(decision['status'], 'blocked');
    expect(decision['store_visible'], isFalse);
    expect(FeatureFlags.visibleExerciseIds, isNot(contains('pull_up')));
  });

  test('A9 real-device gate is explicit and cannot be inferred from simulator CI',
      () {
    final manifest = _json(manifestPath);
    final realDevice =
        manifest['real_device_smoke'] as Map<String, dynamic>;

    expect(realDevice['status'], 'pending');
    expect(realDevice['evidence'], isNull);
    expect(realDevice['pull_up'], 'not_applicable_while_a8_gate_blocked');
  });
}
