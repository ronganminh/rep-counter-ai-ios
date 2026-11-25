import '../../core/backend/backend_rpc.dart';
import 'ai_credits.dart';

/// [CreditedAiApi] on Supabase: `ai_credit_balance` (SQL function) and the
/// `ai-request` Edge Function, shapes in `supabase/contracts/credits.json`.
/// The server grants the weekly allowance, charges once per request id,
/// calls the provider and refunds on failure.
class SupabaseAiCreditsApi implements CreditedAiApi {
  SupabaseAiCreditsApi(this._rpc);

  final BackendRpc _rpc;

  @override
  Future<CreditBalance> balance() async {
    final res = await _rpc.rpc('ai_credit_balance', {});
    if (res is! Map) throw const BackendException('invalid_response');
    return CreditBalance(
      balance: (res['balance'] as num).toInt(),
      weeklyAllowance: (res['weekly_allowance'] as num).toInt(),
      weekStart: DateTime.parse(res['week_start'] as String),
      pro: res['pro'] == true,
    );
  }

  @override
  Future<CreditedAnswer> ask({
    required String requestId,
    required CreditedRequest kind,
    required String locale,
    List<CoachMessage> messages = const [],
    Map<String, Object?>? context,
    int version = 1,
    String? memory,
  }) async {
    final Object? res;
    try {
      res = await _rpc.invoke('ai-request', {
        'request_id': requestId,
        'kind': kind.wireName,
        'locale': locale,
        'messages': [
          for (final m in messages)
            {'role': m.fromUser ? 'user' : 'assistant', 'content': m.content}
        ],
        'context': context,
        // v2 only: v1 bodies stay exactly as before.
        if (version == 2) 'version': 2,
        if (version == 2 && memory != null && memory.isNotEmpty)
          'memory': memory,
      });
    } on BackendException catch (e) {
      final balance = (e.body?['balance'] as num?)?.toInt() ?? 0;
      throw switch (e.code) {
        'insufficient_credits' => InsufficientCredits(balance),
        'duplicate_request' => DuplicateAiRequest(balance),
        'provider_error' => AiProviderFailed(balance),
        'limit_reached' =>
          AiLimitReached(e.body?['scope'] as String? ?? 'user_daily'),
        _ => e,
      };
    }
    if (res is! Map || res['text'] is! String) {
      throw const BackendException('invalid_response');
    }
    final data = res['data'];
    final memoryOut = res['memory'];
    return CreditedAnswer(
      requestId: res['request_id'] as String,
      text: res['text'] as String,
      balance: (res['balance'] as num).toInt(),
      data: data is Map ? data.cast<String, Object?>() : null,
      memory: memoryOut is String ? memoryOut : null,
    );
  }
}

/// The credited-AI backend for this build: null unless `ENABLE_ACCOUNTS`
/// and `ENABLE_AI_CREDITS` are both on and Supabase is initialised.
CreditedAiApi? createCreditedAiApi(
        {bool enabled = AiCredits.enabled, BackendRpc? rpc}) =>
    switch (rpc ?? supabaseBackendRpc(enabled: enabled)) {
      final BackendRpc r when enabled => SupabaseAiCreditsApi(r),
      _ => null,
    };
