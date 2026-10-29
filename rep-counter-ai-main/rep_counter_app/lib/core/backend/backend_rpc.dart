import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// The two ways the app talks to the account backend (D-12, Supabase):
/// SQL functions through PostgREST (`/rest/v1/rpc/<name>`) and Edge
/// Functions (`/functions/v1/<name>`). Each feature's Supabase adapter
/// (sync, credits, XP, social, billing, push) goes through this, so it is
/// unit-tested with a fake and never touches the SDK's singletons.
///
/// The request and response shapes are pinned by `supabase/contracts/*.json`,
/// which the database tests (`supabase/tests`) and the client tests both
/// check.
abstract interface class BackendRpc {
  /// Calls a SQL function as the signed-in user; returns its decoded JSON.
  Future<Object?> rpc(String function, Map<String, Object?> params);

  /// Calls an Edge Function with the user's JWT; returns its decoded JSON.
  Future<Object?> invoke(String function, Map<String, Object?> body);
}

/// A backend call failed. [code] is the Postgres SQLSTATE for SQL functions
/// (`28000` not signed in, `22023` bad argument, `42501` not allowed) or the
/// `error` field of an Edge Function's JSON body; [status] is the HTTP
/// status for Edge Functions. Never carries tokens or user data.
class BackendException implements Exception {
  const BackendException(this.code, {this.status, this.body});

  final String code;
  final int? status;

  /// An Edge Function's JSON error body (e.g. the balance with
  /// `insufficient_credits`); null for SQL functions.
  final Map<String, Object?>? body;

  bool get notSignedIn => code == '28000' || status == 401;

  @override
  String toString() =>
      'BackendException($code${status == null ? '' : ', $status'})';
}

/// [BackendRpc] over the app's Supabase client.
class SupabaseBackendRpc implements BackendRpc {
  SupabaseBackendRpc(this._client);

  final sb.SupabaseClient _client;

  @override
  Future<Object?> rpc(String function, Map<String, Object?> params) async {
    try {
      return await _client.rpc<Object?>(function, params: params);
    } on sb.PostgrestException catch (e) {
      throw BackendException(e.code ?? 'unknown');
    }
  }

  @override
  Future<Object?> invoke(String function, Map<String, Object?> body) async {
    try {
      final response = await _client.functions.invoke(function, body: body);
      return response.data;
    } on sb.FunctionException catch (e) {
      final details = e.details;
      final body = details is Map ? details.cast<String, Object?>() : null;
      final code = body?['error'] is String
          ? body!['error'] as String
          : 'http_${e.status}';
      throw BackendException(code, status: e.status, body: body);
    }
  }
}

/// The backend for a feature whose flag is [enabled]; null when the flag is
/// off (every shipped build) or Supabase was never initialised (accounts
/// off or not configured), so nothing touches the network.
BackendRpc? supabaseBackendRpc({required bool enabled}) {
  if (!enabled) return null;
  try {
    return SupabaseBackendRpc(sb.Supabase.instance.client);
  } catch (_) {
    return null;
  }
}
