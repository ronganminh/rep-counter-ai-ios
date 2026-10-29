import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/backend/backend_rpc.dart';
import 'package:rep_counter_app/features/social/social.dart';
import 'package:rep_counter_app/features/social/supabase_social_api.dart';

import '../../support/contract_rpc.dart';

/// S-1 on Supabase: every call matches `supabase/contracts/social.json`
/// (also checked by supabase/tests/social.test.sql); refusals become
/// SocialError; states and rows map to the seam's types.
void main() {
  final contract = loadContract('social');
  final calls = <String, Map<String, Object?>>{};
  late Map<String, Object?> responses;
  late SupabaseSocialApi api;

  setUp(() {
    calls.clear();
    responses = {
      'social_create_invite': {
        'code': '0123456789abcdef',
        'expires_at': '2026-11-05T09:00:00Z'
      },
      'social_accept_invite': {'user_id': 'u-ann', 'state': 'request_received'},
      'social_respond': {'state': 'friends'},
      'social_state': {'state': 'request_sent'},
      'social_block': {'state': 'blocked'},
      'social_report': {'ok': true},
      'social_friends': [
        {'user_id': 'u-bob', 'display_name': 'Bob', 'state': 'friends'},
        {'user_id': 'u-cam', 'display_name': null, 'state': 'request_received'},
      ],
      'social_leaderboard': [
        {'display_name': 'Bob', 'reps': 45, 'me': false},
        {'display_name': 'Ann', 'reps': 30, 'me': true},
      ],
    };
    api = SupabaseSocialApi(
        ContractRpc(contract, (fn, params) {
          calls[fn] = params;
          return responses[fn];
        }),
        now: () => DateTime.utc(2026, 10, 29, 15)); // a Thursday
  });

  test('the contract lists every function the adapter calls', () {
    expect((contract['functions'] as Map).keys.toSet(), {
      'social_create_invite',
      'social_accept_invite',
      'social_respond',
      'social_state',
      'social_block',
      'social_report',
      'social_friends',
      'social_leaderboard',
    });
    expect(contract['states'], [
      'none',
      'request_sent',
      'request_received',
      'friends',
      'blocked',
    ]);
  });

  test('calls and mapping', () async {
    expect(await api.createInvite(), '0123456789abcdef');
    await api.acceptInvite('0123456789abcdef');
    expect(calls['social_accept_invite'], {'p_code': '0123456789abcdef'});
    await api.respond('u-ann', accept: true);
    expect(calls['social_respond'], {'p_user': 'u-ann', 'p_accept': true});
    expect(await api.state('u-bob'), FriendState.requestSent);
    await api.block('u-cam');
    await api.report('u-cam', 'spam');
    expect(calls['social_report'], {'p_user': 'u-cam', 'p_reason': 'spam'});

    final friends = await api.friends();
    expect(friends.map((f) => (f.userId, f.displayName, f.state)), [
      ('u-bob', 'Bob', FriendState.friends),
      ('u-cam', '', FriendState.requestReceived),
    ]);

    final board = await api.leaderboard('push_up');
    expect(
        board.map((r) => (r.displayName, r.reps)), [('Bob', 45), ('Ann', 30)]);
    expect(calls['social_leaderboard'], {
      'p_exercise_id': 'push_up',
      'p_since': '2026-10-26T00:00:00.000Z', // Monday UTC
    });
  });

  test('refusals are SocialError with the server code', () async {
    for (final code in (contract['errors'] as List).cast<String>()) {
      responses['social_accept_invite'] = {'error': code};
      await expectLater(api.acceptInvite('x'),
          throwsA(isA<SocialError>().having((e) => e.code, 'code', code)));
    }
    responses['social_state'] = {'state': 'unknown'};
    await expectLater(api.state('u'), throwsA(isA<BackendException>()));
  });

  test('flag gate', () {
    expect(Social.enabled, isFalse);
    expect(createSocialApi(), isNull);
    final rpc = ContractRpc(contract, (_, __) => null);
    expect(createSocialApi(enabled: false, rpc: rpc), isNull);
    expect(createSocialApi(enabled: true, rpc: rpc), isA<SupabaseSocialApi>());
  });

  test('in-memory friends(): requests and friends, not people who block me',
      () async {
    final server = InMemorySocialServer()
      ..names.addAll({'ann': 'Ann', 'bob': 'Bob', 'cam': 'Cam'});
    final ann = server.as('ann'),
        bob = server.as('bob'),
        cam = server.as('cam');
    await bob.acceptInvite(await ann.createInvite());
    await bob.respond('ann', accept: true);
    await cam.acceptInvite(await ann.createInvite());
    expect((await ann.friends()).map((f) => (f.userId, f.state)), [
      ('bob', FriendState.friends),
      ('cam', FriendState.requestSent),
    ]);
    await bob.block('ann');
    expect((await ann.friends()).map((f) => f.userId), ['cam']);
  });
}
