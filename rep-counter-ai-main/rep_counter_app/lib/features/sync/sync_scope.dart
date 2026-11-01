import 'package:flutter/widgets.dart';

import '../../core/backend/backend_rpc.dart';
import '../auth/application/auth_controller.dart';
import 'cloud_sync.dart';
import 'plan_sync.dart';
import 'supabase_cloud_sync_api.dart';
import 'sync_controller.dart';

/// Provides the [SyncController] when cloud sync is on (`ENABLE_ACCOUNTS`
/// and `ENABLE_CLOUD_SYNC`, Supabase configured). Without it every sync
/// badge, banner and the account delete scopes hide themselves.
class SyncScope extends InheritedNotifier<SyncController> {
  const SyncScope(
      {super.key, required SyncController controller, required super.child})
      : super(notifier: controller);

  static SyncController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SyncScope>()?.notifier;
}

/// The sync controller for this build, or null when sync is off or the
/// backend is not configured. Not started: the caller calls `start()`.
SyncController? createSyncController(AuthController auth,
    {bool enabled = CloudSync.enabled, BackendRpc? rpc}) {
  if (!enabled) return null;
  final backend = rpc ?? supabaseBackendRpc(enabled: enabled);
  if (backend == null) return null;
  return SyncController(
    auth: auth,
    workoutsApi: SupabaseCloudSyncApi(backend),
    plansApi: SupabasePlanSyncApi(backend),
  );
}
