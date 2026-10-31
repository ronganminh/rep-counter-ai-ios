import 'package:flutter/widgets.dart';

import '../../core/backend/backend_rpc.dart';
import '../achievements/achievement.dart';
import '../auth/application/auth_controller.dart';
import '../sync/sync_controller.dart';
import 'supabase_xp_api.dart';
import 'xp.dart';

/// XP, level and achievements from the account (G-1). The server awards
/// them when workouts sync, so this only reads: at sign-in, when Home or
/// Progress opens, and after each sync round. Nothing is taken away when a
/// workout is deleted (D-05); a failed read keeps the last values.
class XpController extends ChangeNotifier {
  XpController({required this.auth, required this.api, this.sync}) {
    auth.addListener(_onAuth);
    sync?.addListener(_onSync);
    _onAuth();
  }

  final AuthController auth;
  final XpApi api;
  final SyncController? sync;

  XpProgress? _progress;
  List<AchievementId> _achievements = const [];
  bool _loading = false, _failed = false, _disposed = false, _syncBusy = false;

  XpProgress? get progress => _progress;

  /// Server achievements this app knows, in unlock order.
  List<AchievementId> get achievements => _achievements;
  bool get failed => _failed;
  bool get signedIn => auth.state is AuthSignedIn;

  void _onAuth() {
    if (signedIn) {
      refresh();
    } else {
      _progress = null;
      _achievements = const [];
      _failed = false;
      _notify();
    }
  }

  void _onSync() {
    final busy = sync!.busy;
    if (_syncBusy && !busy) refresh(); // a round just finished
    _syncBusy = busy;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    auth.removeListener(_onAuth);
    sync?.removeListener(_onSync);
    super.dispose();
  }

  /// Never throws.
  Future<void> refresh() async {
    if (!signedIn || _loading) return;
    _loading = true;
    try {
      final progress = await api.progress();
      final unlocked = await api.achievements();
      _progress = progress;
      _achievements = [
        for (final u in unlocked)
          for (final id in AchievementId.values)
            if (id.name == u.id) id
      ];
      _failed = false;
    } catch (e) {
      _failed = true;
      if (e is BackendException && e.notSignedIn) auth.markExpired();
    }
    _loading = false;
    _notify();
  }
}

class XpScope extends InheritedNotifier<XpController> {
  const XpScope(
      {super.key, required XpController controller, required super.child})
      : super(notifier: controller);

  static XpController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<XpScope>()?.notifier;
}

/// Null unless `ENABLE_XP` is on and the backend is configured.
XpController? createXpController(AuthController auth,
    {SyncController? sync, bool enabled = Xp.enabled, BackendRpc? rpc}) {
  final api = createXpApi(enabled: enabled, rpc: rpc);
  return api == null ? null : XpController(auth: auth, api: api, sync: sync);
}
