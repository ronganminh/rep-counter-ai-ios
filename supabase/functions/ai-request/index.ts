// Supabase Edge Function: ai-request. See handler.ts for the contract and
// supabase/README.md for deployment and secrets.
//
// Secrets (supabase secrets set ...; never in the app or the repository):
//   AI_PROVIDER            groq (default) | anthropic
//   AI_FALLBACK_PROVIDER   optional: the other provider, used on error / timeout
//   GROQ_API_KEY, GROQ_MODEL
//   ANTHROPIC_API_KEY, ANTHROPIC_MODEL, ANTHROPIC_MAX_TOKENS, ANTHROPIC_EFFORT
//   AI_DAILY_LIMIT_PER_USER   requests per user per UTC day (0 = no limit)
//   AI_MONTHLY_LIMIT_TOTAL    requests of all users per UTC month (0 = no limit)
import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  type CreditState,
  handleAiRequest,
  type UsageCounts,
} from "./handler.ts";
import type { HistoryRow } from "./coach_context.ts";
import { completeWithFallback, providersFromEnv } from "./providers.ts";

const admin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false, autoRefreshToken: false } },
);

const providers = providersFromEnv(Deno.env);
const limit = (name: string, fallback: number) => {
  const raw = Deno.env.get(name);
  const n = Number(raw);
  return raw && Number.isInteger(n) && n >= 0 ? n : fallback;
};
const limits = {
  perUserDaily: limit("AI_DAILY_LIMIT_PER_USER", 30),
  monthlyTotal: limit("AI_MONTHLY_LIMIT_TOTAL", 5_000),
};

async function rpc<T>(fn: string, params: Record<string, unknown>) {
  const { data, error } = await admin.rpc(fn, params);
  if (error) throw new Error(`${fn} failed`);
  return data as T;
}

const log = (event: string, fields?: Record<string, unknown>) =>
  console.log(JSON.stringify({ event, ...fields }));

Deno.serve((req) =>
  handleAiRequest(req, {
    async getUserId(jwt) {
      const { data, error } = await admin.auth.getUser(jwt);
      return error || !data.user ? null : data.user.id;
    },
    providerConfigured: providers.some((p) => p.configured),
    consume: (userId, requestId, kind) =>
      rpc<CreditState & { status: "charged" | "duplicate" | "insufficient" }>(
        "ai_credit_consume",
        { p_user: userId, p_request_id: requestId, p_kind: kind },
      ),
    refund: (userId, requestId) =>
      rpc<CreditState & { refunded: boolean }>("ai_credit_refund", {
        p_user: userId,
        p_request_id: requestId,
      }),
    usage: (userId) => rpc<UsageCounts>("ai_usage_counts", { p_user: userId }),
    limits,
    loadHistory: (userId) =>
      rpc<HistoryRow[]>("ai_coach_history", { p_user: userId, p_days: 28 }),
    complete: (prompt) => completeWithFallback(prompt, providers, log),
    log,
  })
);
