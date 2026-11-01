import 'package:flutter/widgets.dart';

import '../../core/backend/backend_rpc.dart';
import '../auth/application/auth_controller.dart';
import 'push_inbox.dart';
import 'supabase_push_inbox_api.dart';

/// The in-app inbox (NT-2) for the signed-in user, read from Supabase
/// (`inbox_list`). Pushes stay off (`ENABLE_PUSH`); items are written by
/// `send-push` or from the dashboard. Never throws to the UI.
class InboxController extends ChangeNotifier {
  InboxController({required this.auth, required this.api}) {
    auth.addListener(_onAuth);
    _onAuth();
  }

  final AuthController auth;
  final PushInboxApi api;

  List<InboxItem> _items = const [];
  bool _loaded = false, _failed = false, _loading = false, _disposed = false;

  /// Read on this phone while the server call is pending or failed.
  final _readHere = <String>{};

  List<InboxItem> get items => _items;
  bool get loaded => _loaded;
  bool get failed => _failed;
  bool get signedIn => auth.state is AuthSignedIn;

  bool isUnread(InboxItem i) => i.unread && !_readHere.contains(i.id);
  int get unreadCount => _items.where(isUnread).length;

  void _onAuth() {
    if (signedIn) {
      refresh();
    } else {
      _items = const [];
      _readHere.clear();
      _loaded = false;
      _failed = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    auth.removeListener(_onAuth);
    super.dispose();
  }

  Future<void> refresh() async {
    if (!signedIn || _loading) return;
    _loading = true;
    try {
      _items = await api.inbox();
      _readHere.removeWhere(
          (id) => _items.every((i) => i.id != id || i.readAt != null));
      _loaded = true;
      _failed = false;
    } catch (e) {
      _failed = true;
      if (e is BackendException && e.notSignedIn) auth.markExpired();
    }
    _loading = false;
    _notify();
  }

  /// Marks [item] read here at once; the server follows when it can (the
  /// next refresh shows its answer).
  Future<void> markRead(InboxItem item) async {
    if (!isUnread(item)) return;
    _readHere.add(item.id);
    _notify();
    try {
      await api.markRead(item.id);
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    for (final i in _items.where(isUnread).toList()) {
      await markRead(i);
    }
  }
}

class InboxScope extends InheritedNotifier<InboxController> {
  const InboxScope(
      {super.key, required InboxController controller, required super.child})
      : super(notifier: controller);

  static InboxController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<InboxScope>()?.notifier;
}

/// Null unless `ENABLE_INBOX` (or `ENABLE_PUSH`) is on and the backend is
/// configured.
InboxController? createInboxController(AuthController auth,
    {bool enabled = PushInbox.inboxEnabled, BackendRpc? rpc}) {
  final api = createPushInboxApi(enabled: enabled, rpc: rpc);
  return api == null ? null : InboxController(auth: auth, api: api);
}
