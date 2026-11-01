import '../../core/backend/backend_rpc.dart';
import 'xp.dart';

/// [XpApi] on Supabase: `xp_progress` (`supabase/contracts/xp.json`). XP is
/// awarded by the database when a workout syncs, so the app only reads.
class SupabaseXpApi implements XpApi {
  SupabaseXpApi(this._rpc);

  final BackendRpc _rpc;

  @override
  Future<XpProgress> progress() async {
    final res = await _rpc.rpc('xp_progress', {});
    if (res is! Map || res['xp_total'] is! num) {
      throw const BackendException('invalid_response');
    }
    return XpProgress((res['xp_total'] as num).toInt());
  }
}

/// The XP backend for this build: null unless `ENABLE_ACCOUNTS` and
/// `ENABLE_XP` are both on and Supabase is initialised.
XpApi? createXpApi({bool enabled = Xp.enabled, BackendRpc? rpc}) =>
    switch (rpc ?? supabaseBackendRpc(enabled: enabled)) {
      final BackendRpc r when enabled => SupabaseXpApi(r),
      _ => null,
    };
