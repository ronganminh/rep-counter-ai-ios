import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/backend/backend_rpc.dart';
import '../../core/data/local_data_changes.dart';
import '../../widgets/status_badges.dart';
import '../auth/application/auth_controller.dart';
import '../auth/domain/merge_preview.dart';
import 'cloud_sync.dart';
import 'plan_sync.dart';
import 'workout_sync_source.dart';

/// What the guest → account merge would do, from a full read of the
/// account (nothing is written until [SyncController.applyMerge]).
class MergePlan {
  const MergePlan(
      {required this.preview,
      required this.local,
      required this.remote,
      required this.conflicts});

  final MergePreview preview;

  /// Undecided workouts on this phone and the account's live workouts, by
  /// client id.
  final Map<String, Map<String, Object?>> local;
  final Map<String, SyncWorkout> remote;

  /// Same workout (client id) on both sides with different content.
  final Set<String> conflicts;
}

/// Runs cloud sync (A-2) for the signed-in user and reports its state for
/// [SyncStatusBadge]. Never throws to the UI and never deletes local data
/// because of a failure: failed rounds leave changes pending and retry.
///
/// Rounds run: when the app opens signed in, at sign-in, shortly after a
/// workout or plan is saved or deleted, when the app returns to the
/// foreground, on "Sync now", and on a backoff after a failure.
class SyncController extends ChangeNotifier with WidgetsBindingObserver {
  SyncController({
    required this.auth,
    required this.workoutsApi,
    this.plansApi,
    WorkoutSyncSource? workouts,
    PlanSyncSource? plans,
    this.debounce = const Duration(seconds: 2),
    this.retryDelays = const [
      Duration(seconds: 30),
      Duration(minutes: 2),
      Duration(minutes: 10),
    ],
  })  : workouts = workouts ?? const WorkoutSyncSource(),
        plans = plansApi == null ? null : (plans ?? PlanSyncSource());

  final AuthController auth;
  final CloudSyncApi workoutsApi;
  final CloudSyncApi? plansApi;
  final WorkoutSyncSource workouts;
  final PlanSyncSource? plans;
  final Duration debounce;
  final List<Duration> retryDelays;

  StreamSubscription<LocalDataKind>? _localSub;
  Timer? _timer;
  int _failures = 0;
  String? _linkedUser;
  bool _started = false, _disposed = false;
  Future<void>? _running;
  bool _again = false;

  int _pending = 0, _undecided = 0;
  SyncBlocker? _blocker;
  bool _everSynced = false;

  /// Workouts, deletions and plans waiting for upload.
  int get pending => _pending;

  /// Workouts on this phone the user has not yet merged or kept local.
  int get undecided => _undecided;

  bool get signedIn => auth.state is AuthSignedIn;

  /// Offer "Bring your workouts" (P9-06).
  bool get mergeOffered => signedIn && _undecided > 0;

  bool get busy => _running != null;

  SyncBlocker? get blocker => _blocker;

  SyncBadgeState get badge {
    final s = auth.state;
    if (s is AuthGuest) return SyncBadgeState.guestOnly;
    return switch (_blocker) {
      SyncBlocker.offline => SyncBadgeState.offline,
      SyncBlocker.server => SyncBadgeState.failed,
      _ when _pending == 0 && _everSynced => SyncBadgeState.synced,
      _ => SyncBadgeState.pending,
    };
  }

  /// Starts listening to sign-in, local changes and app resume, then syncs
  /// once if signed in. Call once.
  void start() {
    if (_started) return;
    _started = true;
    auth.addListener(_onAuth);
    _localSub = LocalDataChanges.stream.listen((_) => schedule());
    WidgetsBinding.instance.addObserver(this);
    _onAuth();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) schedule(Duration.zero);
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _localSub?.cancel();
    if (_started) {
      auth.removeListener(_onAuth);
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _onAuth() async {
    final s = auth.state;
    try {
      if (s is AuthSignedIn) {
        if (_linkedUser != s.user.id) {
          final switched = await workouts.link(s.user.id);
          if (switched) await plans?.reset();
          _linkedUser = s.user.id;
          _everSynced = false;
          _blocker = null;
        }
        await syncNow();
      } else if (s is AuthGuest) {
        _timer?.cancel();
        if (_linkedUser != null) await workouts.unlink();
        _linkedUser = null;
        _blocker = null;
        await _refreshCounts();
      } else {
        // Expired: changes keep queueing until the user signs in again.
        _blocker = SyncBlocker.signedOut;
        await _refreshCounts();
      }
    } catch (_) {
      // The database could not be opened: training goes on; nothing synced.
    }
    _notify();
  }

  /// Runs a round after [delay] (the debounce by default), coalescing calls.
  void schedule([Duration? delay]) {
    if (_disposed || !signedIn) return;
    _timer?.cancel();
    _timer = Timer(delay ?? debounce, syncNow);
  }

  /// One round now (pull then push, workouts then plans). A call while a
  /// round runs makes it run once more afterwards.
  Future<void> syncNow() {
    if (_running != null) {
      _again = true;
      return _running!;
    }
    // Started in a microtask so [busy] is already true when the round
    // first notifies listeners.
    return _running = Future<void>.microtask(_round).whenComplete(() {
      _running = null;
      _notify();
      if (_again && !_disposed) {
        _again = false;
        syncNow();
      }
    });
  }

  Future<void> _round() async {
    _timer?.cancel();
    if (!signedIn || _linkedUser == null) {
      await _refreshCounts();
      return;
    }
    _notify();
    SyncBlocker? blocker;
    try {
      final w =
          await SyncEngine(api: workoutsApi, local: workouts).tryRun();
      blocker = w.blocker;
      final p = plans;
      final pApi = plansApi;
      if (blocker == null && p != null && pApi != null) {
        blocker = (await SyncEngine(api: pApi, local: p).tryRun()).blocker;
      }
    } catch (_) {
      // Not a backend answer (e.g. the database is unavailable).
      blocker = SyncBlocker.server;
    }
    _blocker = blocker;
    if (blocker == null) {
      _everSynced = true;
      _failures = 0;
    } else if (blocker == SyncBlocker.signedOut) {
      auth.markExpired();
    } else {
      final delay = retryDelays.isEmpty
          ? null
          : retryDelays[_failures.clamp(0, retryDelays.length - 1)];
      _failures++;
      if (delay != null) schedule(delay);
    }
    await _refreshCounts();
  }

  Future<void> _refreshCounts() async {
    try {
      _pending = await workouts.pendingCount() +
          (signedIn ? await plans?.pendingCount() ?? 0 : 0);
      _undecided = (await workouts.clientIds()).length;
    } catch (_) {}
  }

  /// Waits for a running round, so a merge or delete never interleaves
  /// with one (they read and write the same rows).
  Future<void> _idle() async {
    try {
      await _running;
    } catch (_) {}
  }

  /// Reads the whole account to preview the merge. Throws
  /// [BackendException] when the account cannot be read; nothing changes.
  Future<MergePlan> prepareMerge() async {
    await _idle();
    final remote = await _pullAll();
    final local = await workouts.undecided();
    final conflicts = {
      for (final id in local.keys)
        if (remote[id] case final r? when !sameWorkout(local[id]!, r.raw)) id
    };
    return MergePlan(
      preview: MergePreview.compute(
          local: local.keys.toSet(),
          remote: remote.keys.toSet(),
          conflicts: conflicts),
      local: local,
      remote: remote,
      conflicts: conflicts,
    );
  }

  /// Brings the undecided workouts into the account. Workouts the account
  /// already has are not uploaded twice; for [MergePlan.conflicts] the
  /// phone's version wins when [keepPhone], else the account's.
  Future<void> applyMerge(MergePlan plan, {required bool keepPhone}) async {
    await _idle();
    final shared = plan.local.keys.where(plan.remote.containsKey).toSet();
    await workouts.resolve(
      upload: {
        ...plan.local.keys.where((id) => !plan.remote.containsKey(id)),
        if (keepPhone) ...plan.conflicts,
      },
      same: shared.difference(plan.conflicts),
      takeAccount: keepPhone
          ? const {}
          : {for (final id in plan.conflicts) id: plan.remote[id]!},
    );
    await syncNow();
  }

  /// "Keep workouts on this phone only": never uploaded, never offered again.
  Future<void> keepOnPhone() async {
    await _idle();
    await workouts.resolve(keep: await workouts.clientIds());
    await _refreshCounts();
    _notify();
  }

  /// D-20 "My account": deletes every workout in the account (tombstones,
  /// so other phones follow); this phone keeps its copies as local only.
  /// Throws [BackendException] when it cannot finish; run it again to
  /// continue (already deleted rows stay deleted).
  Future<void> deleteFromAccount() async {
    await _idle();
    final now = DateTime.now().toUtc();
    final live = (await _pullAll()).values.toList();
    if (live.isNotEmpty) {
      await workoutsApi.push([
        for (final w in live)
          SyncWorkout(
              clientId: w.clientId,
              raw: w.raw,
              clientUpdatedAt: now,
              deletedAt: now)
      ]);
    }
    await workouts.keepAllOnPhone();
    await _refreshCounts();
    _notify();
  }

  /// Every live workout in the account, by client id.
  Future<Map<String, SyncWorkout>> _pullAll() async {
    final rows = <String, SyncWorkout>{};
    var after = 0;
    while (true) {
      final page = await workoutsApi.pull(after: after);
      for (final w in page.workouts) {
        if (w.isTombstone) {
          rows.remove(w.clientId);
        } else {
          rows[w.clientId] = w;
        }
      }
      if (!page.hasMore || page.cursor <= after) break;
      after = page.cursor;
    }
    return rows;
  }

  /// Same workout content, ignoring the sync id and JSON number formats.
  static bool sameWorkout(Map<String, Object?> a, Map<String, Object?> b) {
    bool eq(Object? x, Object? y) {
      if (x is num && y is num) return x == y;
      if (x is Map && y is Map) {
        final keys = {...x.keys, ...y.keys}..remove('client_id');
        return keys.every((k) => eq(x[k], y[k]));
      }
      if (x is List && y is List) {
        if (x.length != y.length) return false;
        for (var i = 0; i < x.length; i++) {
          if (!eq(x[i], y[i])) return false;
        }
        return true;
      }
      return x == y;
    }

    return eq(a, b);
  }
}
