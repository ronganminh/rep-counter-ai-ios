import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/backend/backend_rpc.dart';
import 'package:rep_counter_app/features/progression/supabase_xp_api.dart';
import 'package:rep_counter_app/features/progression/xp.dart';

import '../../support/contract_rpc.dart';

/// G-1 on Supabase: the app's XP rules match the database's on the shared
/// examples of `supabase/contracts/xp.json`, and the adapter reads progress.
void main() {
  final contract = loadContract('xp');

  test('award examples: XpRules gives what xp_for_workout gives', () {
    for (final e in (contract['award_examples'] as List).cast<Map>()) {
      expect(
          XpRules.forWorkout(XpWorkout(
              clientId: 'x',
              reps: e['reps'] as int,
              durationSeconds: e['duration_seconds'] as int,
              manual: e['manual'] as bool)),
          e['xp'],
          reason: '$e');
    }
  });

  test('level examples match xp_level_for', () {
    for (final e in (contract['level_examples'] as List).cast<Map>()) {
      expect(XpProgress(e['xp'] as int).level, e['level'], reason: '$e');
    }
  });

  test('progress reads xp_progress', () async {
    final rpc = ContractRpc(contract, (fn, params) {
      final res = {'xp_total': 195, 'level': 2};
      final shape = ((contract['functions'] as Map)['xp_progress']
          as Map)['returns'] as Map;
      expect(res.keys.toSet(), shape.keys.toSet());
      return res;
    });
    final p = await SupabaseXpApi(rpc).progress();
    expect(p.xpTotal, 195);
    expect(p.level, 2);
    expect(p.intoLevel, 145);
    expect(rpc.calls, ['xp_progress']);
  });

  test('errors and the flag gate', () async {
    await expectLater(
        SupabaseXpApi(FailingRpc(const BackendException('28000'))).progress(),
        throwsA(isA<BackendException>()));
    await expectLater(
        SupabaseXpApi(ContractRpc(contract, (_, __) => {'level': 1}))
            .progress(),
        throwsA(isA<BackendException>()));
    expect(Xp.enabled, isFalse);
    expect(createXpApi(), isNull);
    final rpc = ContractRpc(contract, (_, __) => null);
    expect(createXpApi(enabled: false, rpc: rpc), isNull);
    expect(createXpApi(enabled: true, rpc: rpc), isA<SupabaseXpApi>());
  });
}
