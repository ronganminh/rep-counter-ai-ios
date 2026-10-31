import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/backend/backend_rpc.dart';
import 'package:rep_counter_app/features/inbox/push_inbox.dart';
import 'package:rep_counter_app/features/inbox/supabase_push_inbox_api.dart';

import '../../support/contract_rpc.dart';

/// NT-2 on Supabase: calls match `supabase/contracts/push_inbox.json`;
/// inbox rows map to InboxItem and non-app links are dropped.
void main() {
  final contract = loadContract('push_inbox');

  test('tokens, inbox and read state go through the contract', () async {
    final calls = <String, Map<String, Object?>>{};
    final api = SupabasePushInboxApi(ContractRpc(contract, (fn, params) {
      calls[fn] = params;
      if (fn != 'inbox_list') return {'ok': true};
      final rows = [
        {
          'id': 'n2',
          'kind': 'invite',
          'link': 'repcoach://invites/abc',
          'title': 'Ann invited you',
          'body': 'Tap to answer',
          'created_at': '2026-10-29T12:00:00Z',
          'read_at': null,
        },
        {
          'id': 'n1',
          'kind': 'friend_request',
          'link': 'repcoach://friends/requests',
          'title': 'New friend request',
          'body': null,
          'created_at': '2026-10-29T11:00:00Z',
          'read_at': '2026-10-29T11:30:00Z',
        },
        {
          'id': 'bad',
          'kind': 'system',
          'link': 'https://example.com',
          'title': 'x',
          'body': null,
          'created_at': '2026-10-29T10:00:00Z',
          'read_at': null,
        },
      ];
      for (final r in rows) {
        expect(r.keys.toSet(), contractKeys(contract, 'inbox_row'));
      }
      return rows;
    }));

    await api.registerToken(PushPlatform.apns, 'device-token-1');
    expect(calls['push_register_token'],
        {'p_platform': 'apns', 'p_token': 'device-token-1'});
    await api.unregisterToken('device-token-1');
    expect(calls['push_unregister_token'], {'p_token': 'device-token-1'});

    final items = await api.inbox();
    expect(items.map((i) => (i.id, i.unread)), [('n2', true), ('n1', false)]);
    expect(items.first.body, 'Tap to answer');
    expect(calls['inbox_list'], {'p_limit': 50});

    await api.markRead('n2');
    expect(calls['inbox_mark_read'], {'p_id': 'n2'});
  });

  test('platform names match the database check', () {
    expect([for (final p in PushPlatform.values) p.name], ['apns', 'fcm']);
  });

  test('errors and the flag gate', () async {
    await expectLater(
        SupabasePushInboxApi(FailingRpc(const BackendException('28000')))
            .inbox(),
        throwsA(isA<BackendException>()));
    expect(PushInbox.enabled, isFalse);
    expect(PushInbox.inboxEnabled, isFalse);
    expect(createPushInboxApi(), isNull);
    final rpc = ContractRpc(contract, (_, __) => null);
    expect(createPushInboxApi(enabled: false, rpc: rpc), isNull);
    expect(createPushInboxApi(enabled: true, rpc: rpc),
        isA<SupabasePushInboxApi>());
  });
}
