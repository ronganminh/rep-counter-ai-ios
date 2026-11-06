import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/config/feature_flags.dart';
import 'package:rep_counter_app/exercise.dart';
import 'package:rep_counter_app/main.dart';

/// Plan 07 PR B: the clip smoke set is measure-only and separate from the
/// three reference replays.
void main() {
  Map<String, dynamic> read(String path) =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

  test('CI video mode opens a locked exercise (pull-up) by id', () {
    // The store build hides pull-up; the replay must still be able to run it.
    expect(FeatureFlags.visibleExerciseIds, isNot(contains('pull_up')));
    expect(ciVideoProfile('pull_up'), same(pullUp));
    expect(ciVideoProfile('curl'), same(dumbbellCurl));
    // Default and unknown ids keep the reference replays on push-up.
    expect(ciVideoProfile('push_up'), same(pushUp));
    expect(ciVideoProfile('nope'), same(pushUp));
  });

  test('clip smoke manifest is eye-counted and consistent', () {
    final set = read('test/fixtures/clip_smoke_set.json');
    final clips = set['clips'] as Map<String, dynamic>;
    expect(clips.keys, containsAll(['clip-pull-up-l02', 'clip-curl-b01']));
    final ids = allExercises.map((p) => p.id).toSet();
    for (final entry in clips.entries) {
      final c = entry.value as Map<String, dynamic>;
      expect(ids, contains(c['exercise']), reason: entry.key);
      expect(c['counted_by'], 'eye, sample clip');
      expect(c['sha256'], matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(c['url'], contains('@${set['source_tag']}/'));
      expect(c['human_ground_truth'],
          (c['loops'] as int) * (c['reps_per_loop'] as int));
    }
  });

  test('the smoke set never touches the reference baselines', () {
    final reference = read('test/fixtures/video_ground_truth.json');
    final clips = read('test/fixtures/clip_smoke_set.json')['clips'] as Map;
    expect(reference.keys.toSet().intersection(clips.keys.toSet()), isEmpty);
    expect(reference.keys,
        containsAll(['pushup-a', 'pushup-b', 'pushup-rest-regression']));
  });
}
