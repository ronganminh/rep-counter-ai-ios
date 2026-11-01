import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/backend/backend_rpc.dart';
import 'package:rep_counter_app/features/sync/plan_sync.dart';
import 'package:rep_counter_app/features/sync/cloud_sync.dart';

import '../../support/contract_rpc.dart';

/// A-2 plans on Supabase: the adapter speaks `supabase/contracts/sync.json`
/// (plan rows), which `supabase/tests/sync.test.sql` checks against the
/// real `sync_push_plans` / `sync_pull_plans`.
void main() {
  final contract = loadContract('sync');
  final at = DateTime.utc(2026, 10, 31, 9);

  Map<String, Object?> row(String id, {bool deleted = false}) {
    final r = <String, Object?>{
      'plan_id': id,
      'doc': {'plan': {'id': id}, 'sessions': []},
      'client_updated_at': at.toIso8601String(),
      'deleted_at': deleted ? at.toIso8601String() : null,
      'server_seq': 7,
    };
    expect(r.keys.toSet(), contractKeys(contract, 'plan_row'));
    return r;
  }

  test('push and pull map plan rows both ways', () async {
    final rpc = ContractRpc(contract, (fn, p) {
      switch (fn) {
        case 'sync_push_plans':
          final rows = (p['p_rows'] as List).cast<Map>();
          for (final r in rows) {
            expect(r.keys.toSet(), contractKeys(contract, 'plan_push_row'));
          }
          return [for (final r in rows) row(r['plan_id'] as String)];
        case 'sync_pull_plans':
          expect(p, {'p_after': 3, 'p_limit': 500});
          return {
            'rows': [row('a'), row('b', deleted: true)],
            'cursor': 7,
            'has_more': false,
          };
      }
      return null;
    });
    final api = SupabasePlanSyncApi(rpc);
    final stored = await api.push([
      SyncWorkout(
          clientId: 'a',
          raw: const {'plan': {'id': 'a'}, 'sessions': []},
          clientUpdatedAt: at)
    ]);
    expect(stored.single.clientId, 'a');
    expect(stored.single.serverSeq, 7);

    final page = await api.pull(after: 3);
    expect(page.cursor, 7);
    expect(page.workouts.map((w) => w.clientId), ['a', 'b']);
    expect(page.workouts.last.isTombstone, isTrue);
    expect(await api.clientIds(), isEmpty);
  });

  test('a malformed answer is a backend error, not a crash', () async {
    final api = SupabasePlanSyncApi(
        ContractRpc(contract, (fn, p) => {'rows': 'x', 'cursor': 1}));
    await expectLater(api.pull(after: 0),
        throwsA(isA<BackendException>()));
    final bad = SupabasePlanSyncApi(ContractRpc(contract, (fn, p) => {
          'rows': [
            {'plan_id': 1}
          ],
          'cursor': 1,
        }));
    await expectLater(bad.pull(after: 0), throwsA(isA<BackendException>()));
  });
}
