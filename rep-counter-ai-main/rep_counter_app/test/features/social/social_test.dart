import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/features/social/social.dart';

/// S-1 seam: invites, requests, blocking, reports, friends-only boards.

void main() {
  var now = DateTime.utc(2026, 11, 2, 9);
  late InMemorySocialServer server;
  late SocialApi ann, bob, cam;

  setUp(() {
    now = DateTime.utc(2026, 11, 2, 9);
    server = InMemorySocialServer(now: () => now)
      ..names.addAll({'ann': 'Ann', 'bob': 'Bob', 'cam': 'Cam'});
    ann = server.as('ann');
    bob = server.as('bob');
    cam = server.as('cam');
  });

  test('off by default', () => expect(Social.enabled, isFalse));

  test('invite → request → accept makes friends both ways', () async {
    final code = await ann.createInvite();
    await bob.acceptInvite(code);
    expect(await ann.state('bob'), FriendState.requestSent);
    expect(await bob.state('ann'), FriendState.requestReceived);
    await bob.respond('ann', accept: true);
    expect(await ann.state('bob'), FriendState.friends);
    expect(await bob.state('ann'), FriendState.friends);
  });

  test('invites: own, used and expired are refused', () async {
    final code = await ann.createInvite();
    expect(() => ann.acceptInvite(code), throwsA(isA<SocialError>()));
    await bob.acceptInvite(code);
    expect(
        () => cam.acceptInvite(code),
        throwsA(
            isA<SocialError>().having((e) => e.code, 'code', 'invite_used')));
    final old = await ann.createInvite();
    now = now.add(const Duration(days: 8));
    expect(
        () => cam.acceptInvite(old),
        throwsA(isA<SocialError>()
            .having((e) => e.code, 'code', 'invite_expired')));
  });

  test('blocking ends the friendship and hides the blocker', () async {
    await bob.acceptInvite(await ann.createInvite());
    await bob.respond('ann', accept: true);
    await ann.block('bob');
    expect(await ann.state('bob'), FriendState.blocked);
    expect(await bob.state('ann'), FriendState.none,
        reason: 'never tells someone they were blocked');
    final code = await ann.createInvite();
    expect(() => bob.acceptInvite(code),
        throwsA(isA<SocialError>().having((e) => e.code, 'code', 'blocked')));
  });

  test('reports are kept server-side, reason capped', () async {
    await bob.report('cam', 'x' * 900);
    expect(server.reports.single.$3, hasLength(500));
  });

  test('leaderboard: me and friends, camera reps only, no strangers', () async {
    await bob.acceptInvite(await ann.createInvite());
    await bob.respond('ann', accept: true);
    server.cameraReps.addAll({
      'ann': {'push_up': 30},
      'bob': {'push_up': 42},
      'cam': {'push_up': 99},
    });
    final board = await ann.leaderboard('push_up');
    expect([for (final r in board) r.displayName], ['Bob', 'Ann']);
    expect(board.first.reps, 42);
  });
}
