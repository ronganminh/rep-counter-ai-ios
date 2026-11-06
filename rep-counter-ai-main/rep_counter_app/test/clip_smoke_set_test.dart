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
    expect(
        clips.keys,
        containsAll(
            ['clip-pull-up-l02', 'clip-curl-b01', 'clip-real-curl-img0967']));
    final ids = allExercises.map((p) => p.id).toSet();
    for (final entry in clips.entries) {
      final c = entry.value as Map<String, dynamic>;
      expect(ids, contains(c['exercise']), reason: entry.key);
      expect(c['sha256'], matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(c['bytes'], isA<int>());
      expect(c['human_ground_truth'],
          (c['loops'] as int) * (c['reps_per_loop'] as int));
      switch (c['kind']) {
        case 'sample':
          expect(c['counted_by'], 'eye, sample clip');
          expect(c['url'], contains('@${set['source_tag']}/'));
        case 'owner_recording':
          expect(c['loops'], 1);
          expect(c['counted_by'], startsWith('eye'));
          expect(c['human_reviewed'], isFalse,
              reason: 'flip only after a person checks the count');
          expect(c['url'], contains(c['drive_id']));
          expect(c['transcode'], {'fps': 5, 'width': 720, 'height': 1280});
          final duration = c['duration_ms'] as int;
          final sets = (c['sets'] as List).cast<Map<String, dynamic>>();
          var total = 0;
          var lastEnd = -1;
          for (final s in sets) {
            final reps = [
              ...(s['image_left_ms'] as List).cast<int>(),
              ...(s['image_right_ms'] as List).cast<int>(),
            ];
            expect(s['reps'], reps.length, reason: 'set ${s['set']}');
            total += reps.length;
            final walkIn = s['walk_in_ms'] as int;
            final ready = s['ready_ms'] as int;
            final first = s['first_rep_ms'] as int;
            final end = s['end_ms'] as int;
            expect(walkIn, greaterThan(lastEnd));
            expect(walkIn <= ready && ready <= first && first < end, isTrue);
            expect(end, lessThanOrEqualTo(duration));
            expect(reps.reduce((a, b) => a < b ? a : b), first);
            expect(reps.every((t) => t >= first && t <= end), isTrue);
            lastEnd = end;
            // No eye-counted rep falls inside a rest window.
            for (final r in (c['rest_ms'] as List).cast<List>()) {
              expect(reps.any((t) => t >= r[0] && t <= r[1]), isFalse);
            }
          }
          expect(total, c['human_ground_truth']);
        default:
          fail('${entry.key}: unknown kind ${c['kind']}');
      }
    }
  });

  test('owner recordings stay out of the repo', () {
    // Only the link, size and hash are kept; the video is never committed.
    final clips = read('test/fixtures/clip_smoke_set.json')['clips'] as Map;
    for (final entry in clips.entries) {
      final c = entry.value as Map<String, dynamic>;
      if (c['kind'] != 'owner_recording') continue;
      final name = c['source_name'] as String;
      final tracked =
          Process.runSync('git', ['ls-files', '--', '*$name']).stdout as String;
      expect(tracked.trim(), isEmpty, reason: name);
      expect(File('test/fixtures/$name').existsSync(), isFalse);
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
