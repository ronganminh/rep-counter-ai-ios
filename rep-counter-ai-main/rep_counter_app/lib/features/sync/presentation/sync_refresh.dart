import 'package:flutter/widgets.dart';

import '../sync_scope.dart';

/// For screens that show local workouts or plans (Home, History): calls
/// [reloadAfterSync] when cloud sync wrote account data into this phone,
/// in place, so the screen keeps its own state (e.g. a pending Undo).
/// Nothing happens when sync is off.
mixin ReloadOnSync<T extends StatefulWidget> on State<T> {
  int? _syncRevision;

  /// Reload without a loading state; the old content stays until then.
  void reloadAfterSync();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final revision = SyncScope.maybeOf(context)?.dataRevision;
    final seen = _syncRevision;
    _syncRevision = revision;
    if (seen != null && revision != null && revision != seen) {
      reloadAfterSync();
    }
  }
}
