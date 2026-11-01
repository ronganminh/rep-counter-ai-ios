import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/features/progression/xp.dart';

/// G-1 seam: XP rules and the in-memory server.

void main() {
  test('off by default', () => expect(Xp.enabled, isFalse));

  test('award rules: reps, time, manual half, cap, nothing for empty', () {
    expect(
        XpRules.forWorkout(
            const XpWorkout(clientId: 'a', reps: 20, durationSeconds: 60)),
        30);
    expect(
        XpRules.forWorkout(
            const XpWorkout(clientId: 'b', reps: 0, durationSeconds: 60)),
        20,
        reason: 'timed: one point per 6 s');
    expect(
        XpRules.forWorkout(const XpWorkout(
            clientId: 'c', reps: 20, durationSeconds: 60, manual: true)),
        15);
    expect(
        XpRules.forWorkout(
            const XpWorkout(clientId: 'd', reps: 1000, durationSeconds: 60)),
        XpRules.maxPerWorkout);
    expect(
        XpRules.forWorkout(
            const XpWorkout(clientId: 'e', reps: 0, durationSeconds: 0)),
        0);
  });

  test('levels', () {
    expect(XpRules.levelFor(0), 1);
    expect(XpRules.levelFor(49), 1);
    expect(XpRules.levelFor(50), 2);
    expect(XpRules.levelFor(200), 3);
    const p = XpProgress(260);
    expect(p.level, 3);
    expect(p.intoLevel, 60);
    expect(p.levelSize, 250);
  });

  test('one award per workout; deletion keeps XP; corrections subtract',
      () async {
    final server = InMemoryXpServer();
    const w = XpWorkout(clientId: 'w1', reps: 20, durationSeconds: 60);
    expect(server.onWorkoutSynced(w), 30);
    expect(server.onWorkoutSynced(w), 0, reason: 'D-09');
    server.onWorkoutDeleted('w1');
    expect((await server.progress()).xpTotal, 30, reason: 'D-05');
    server.correct('w1', 30);
    expect((await server.progress()).xpTotal, 0);
  });
}
