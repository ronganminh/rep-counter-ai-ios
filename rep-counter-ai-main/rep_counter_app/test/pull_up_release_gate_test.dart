import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/config/feature_flags.dart';

Map<String, dynamic> loadJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  const manifestPath = 'test/fixtures/pull_up_validation_manifest.json';

  test('A8 fixture metrics stay tied to explicit human aggregate counts', () {
    final manifest = loadJson(manifestPath);
    final fixtures = (manifest['fixtures'] as List).cast<Map<String, dynamic>>();

    final metrics = <String, Map<String, num>>{};
    for (final evidence in fixtures) {
      final fixture = loadJson(evidence['fixture_file'] as String);
      final human = evidence['actual_rep_count'] as int;
      final legacyHuman = fixture['ground_truth_reps'] as int;
      final engine = (fixture['expected_rep_ms'] as List).length;

      expect(human, legacyHuman,
          reason: 'A8 manifest must not silently rewrite manual counts');
      metrics[evidence['id'] as String] = {
        'human': human,
        'engine': engine,
        'absolute_error': (engine - human).abs(),
      };
    }

    expect(metrics['pull_up_front'], {
      'human': 47,
      'engine': 46,
      'absolute_error': 1,
    });
    expect(metrics['pull_up_back_closeup'], {
      'human': 30,
      'engine': 21,
      'absolute_error': 9,
    });
  });

  test('A8 does not claim event precision or release metrics without annotation',
      () {
    final manifest = loadJson(manifestPath);
    final fixtures = (manifest['fixtures'] as List).cast<Map<String, dynamic>>();
    const requiredAnnotationFields = <String>[
      'valid_rep_intervals_ms',
      'invalid_partial_attempt_intervals_ms',
      'mount_intervals_ms',
      'dismount_intervals_ms',
      'pose_loss_windows_ms',
    ];

    for (final evidence in fixtures) {
      expect(evidence['camera_angle_notes'], isA<String>());
      expect((evidence['camera_angle_notes'] as String).trim(), isNotEmpty);
      expect(evidence['annotation_status'], 'aggregate_count_only');
      for (final field in requiredAnnotationFields) {
        expect(evidence.containsKey(field), isTrue);
        expect(evidence[field], isNull,
            reason: '$field must stay explicitly unavailable until annotated');
      }
    }

    expect(manifest['production_replay_evidence'], isEmpty,
        reason: 'HUD/saved/result and production monotonicity are not yet '
            'validated for pull-up');
  });

  test('A8 dataset coverage is explicitly incomplete instead of inferred', () {
    final manifest = loadJson(manifestPath);
    final required =
        (manifest['required_dataset_coverage'] as List).cast<String>().toSet();
    final covered = <String>{};
    for (final evidence
        in (manifest['fixtures'] as List).cast<Map<String, dynamic>>()) {
      covered.addAll((evidence['coverage_tags'] as List).cast<String>());
    }

    final missing = required.difference(covered);
    expect(missing, contains('slight_left_right_angle'));
    expect(missing, contains('different_body_sizes'));
    expect(missing, contains('different_clothing'));
    expect(missing, contains('mount_dismount_rest'));
    expect(missing, contains('temporary_pose_loss'));
  });

  test('A8 real-device evidence is required and currently missing', () {
    final manifest = loadJson(manifestPath);
    final devices =
        manifest['real_device_validation'] as Map<String, dynamic>;

    expect(devices['recent_supported_iphone'], isNull);
    expect(devices['older_supported_iphone'], isNull);
    expect(devices['normal_session_thermal_behavior'], isNull);
  });

  test('A8 release decision stays blocked and default store visibility stays off',
      () {
    final manifest = loadJson(manifestPath);
    final decision = manifest['release_decision'] as Map<String, dynamic>;

    expect(decision['status'], 'blocked');
    expect(decision['store_visible'], isFalse);
    expect(FeatureFlags.visibleExerciseIds, isNot(contains('pull_up')));
  });

  test('A8 does not add pull-up to automated production replay prematurely', () {
    final workflow = File('../../.github/workflows/ios-ci.yml').readAsStringSync();

    expect(workflow, isNot(contains('pullup-')));
    expect(workflow, isNot(contains('pull_up')));
  });
}
