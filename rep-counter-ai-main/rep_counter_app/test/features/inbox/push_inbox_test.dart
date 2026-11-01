import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/features/inbox/push_inbox.dart';

/// NT-2 seam: tokens, inbox order, read state, links only in payloads.

void main() {
  var now = DateTime.utc(2026, 11, 2, 9);
  late InMemoryPushInbox server;

  setUp(() {
    now = DateTime.utc(2026, 11, 2, 9);
    server = InMemoryPushInbox(now: () => now);
  });

  test('off by default', () => expect(PushInbox.enabled, isFalse));

  test('inbox row first, push carries only title and link', () async {
    await server.registerToken(PushPlatform.apns, 'tok1');
    await server.registerToken(PushPlatform.apns, 'tok1');
    expect(server.tokens, hasLength(1), reason: 'one row per token');
    server.send(
        kind: 'friend_request',
        link: 'repcoach://friends/requests',
        title: 'New friend request',
        body: 'Bob wants to train with you');
    expect(server.sent.single,
        ('tok1', 'New friend request', 'repcoach://friends/requests'));
    expect((await server.inbox()).single.body, 'Bob wants to train with you');
  });

  test('only in-app links', () {
    expect(PushInbox.isValidLink('repcoach://inbox'), isTrue);
    for (final bad in ['https://evil.example', 'javascript:x', '']) {
      expect(() => server.send(kind: 'x', link: bad, title: 't'),
          throwsArgumentError);
    }
  });

  test('newest first; read state; sign-out stops pushes', () async {
    await server.registerToken(PushPlatform.fcm, 'tok2');
    server.send(kind: 'race', link: 'repcoach://races/r1', title: 'Race');
    now = now.add(const Duration(minutes: 1));
    final second =
        server.send(kind: 'billing', link: 'repcoach://membership', title: 'B');
    var items = await server.inbox();
    expect(items.first.id, second.id);
    expect(items.every((i) => i.unread), isTrue);
    await server.markRead(second.id);
    items = await server.inbox();
    expect(items.first.unread, isFalse);
    expect(items.last.unread, isTrue);
    await server.unregisterToken('tok2');
    server.send(kind: 'race', link: 'repcoach://races/r2', title: 'R2');
    expect(server.sent, hasLength(2), reason: 'no push after sign-out');
    expect(await server.inbox(), hasLength(3), reason: 'inbox still kept');
  });
}
