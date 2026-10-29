import 'package:flutter/foundation.dart';

import '../../core/config/feature_flags.dart';

/// NT-2 push and inbox seam (06_SUPABASE_SCHEMA_PROPOSAL §7, D-19). Push
/// tokens, the in-app inbox and read state. No APNs / FCM SDK, no backend:
/// the flag stays off. Local reminders (NT-1) do not use any of this.
class PushInbox {
  const PushInbox._();

  static const bool enabled = FeatureFlags.enableAccounts &&
      bool.fromEnvironment('ENABLE_PUSH', defaultValue: false);

  /// Inbox links must be in-app links (the N-2a router input).
  static bool isValidLink(String link) =>
      link.startsWith('repcoach://') && link.length <= 300;
}

enum PushPlatform { apns, fcm }

@immutable
class InboxItem {
  const InboxItem(
      {required this.id,
      required this.kind,
      required this.link,
      required this.title,
      required this.createdAt,
      this.body,
      this.readAt});

  final String id, kind, link, title;
  final String? body;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get unread => readAt == null;
}

/// The account side (`push_tokens`, `inbox_items`, `send-push`).
abstract interface class PushInboxApi {
  /// Registers or refreshes this device's token (one row per token).
  Future<void> registerToken(PushPlatform platform, String token);

  /// Called on sign-out so the device stops receiving pushes.
  Future<void> unregisterToken(String token);

  /// Newest first.
  Future<List<InboxItem>> inbox();
  Future<void> markRead(String id);
}

/// Server rules for tests and UI work. [send] is what `send-push` would do:
/// write the inbox row first, then push only a title and the link.
class InMemoryPushInbox implements PushInboxApi {
  InMemoryPushInbox({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final tokens = <String, PushPlatform>{};
  final _items = <InboxItem>[];

  /// What was handed to APNs / FCM: (token, title, link) only.
  final sent = <(String, String, String)>[];
  var _n = 0;

  InboxItem send(
      {required String kind,
      required String link,
      required String title,
      String? body}) {
    if (!PushInbox.isValidLink(link)) {
      throw ArgumentError.value(link, 'link', 'must be a repcoach:// link');
    }
    final item = InboxItem(
        id: 'n${++_n}',
        kind: kind,
        link: link,
        title: title,
        body: body,
        createdAt: _now());
    _items.add(item);
    for (final t in tokens.keys) {
      sent.add((t, title, link));
    }
    return item;
  }

  @override
  Future<void> registerToken(PushPlatform platform, String token) async =>
      tokens[token] = platform;

  @override
  Future<void> unregisterToken(String token) async => tokens.remove(token);

  @override
  Future<List<InboxItem>> inbox() async => _items.reversed.toList();

  @override
  Future<void> markRead(String id) async {
    final i = _items.indexWhere((e) => e.id == id);
    if (i < 0 || !_items[i].unread) return;
    final e = _items[i];
    _items[i] = InboxItem(
        id: e.id,
        kind: e.kind,
        link: e.link,
        title: e.title,
        body: e.body,
        createdAt: e.createdAt,
        readAt: _now());
  }
}
