import '../../core/backend/backend_rpc.dart';
import 'push_inbox.dart';

/// [PushInboxApi] on Supabase: the `push_*` / `inbox_*` SQL functions
/// (`supabase/contracts/push_inbox.json`). Items whose link is not an
/// in-app `repcoach://` link are dropped, as the router would refuse them.
class SupabasePushInboxApi implements PushInboxApi {
  SupabasePushInboxApi(this._rpc);

  final BackendRpc _rpc;

  @override
  Future<void> registerToken(PushPlatform platform, String token) => _rpc.rpc(
      'push_register_token', {'p_platform': platform.name, 'p_token': token});

  @override
  Future<void> unregisterToken(String token) =>
      _rpc.rpc('push_unregister_token', {'p_token': token});

  @override
  Future<List<InboxItem>> inbox() async {
    final res = await _rpc.rpc('inbox_list', {'p_limit': 50});
    if (res is! List) throw const BackendException('invalid_response');
    return [
      for (final raw in res)
        if (raw is Map && PushInbox.isValidLink('${raw['link']}'))
          InboxItem(
            id: raw['id'] as String,
            kind: raw['kind'] as String,
            link: raw['link'] as String,
            title: raw['title'] as String,
            body: raw['body'] as String?,
            createdAt: DateTime.parse(raw['created_at'] as String),
            readAt: raw['read_at'] == null
                ? null
                : DateTime.parse(raw['read_at'] as String),
          ),
    ];
  }

  @override
  Future<void> markRead(String id) => _rpc.rpc('inbox_mark_read', {'p_id': id});
}

/// The push / inbox backend for this build: null unless `ENABLE_ACCOUNTS`
/// and `ENABLE_PUSH` are both on and Supabase is initialised.
PushInboxApi? createPushInboxApi(
        {bool enabled = PushInbox.enabled, BackendRpc? rpc}) =>
    switch (rpc ?? supabaseBackendRpc(enabled: enabled)) {
      final BackendRpc r when enabled => SupabasePushInboxApi(r),
      _ => null,
    };
