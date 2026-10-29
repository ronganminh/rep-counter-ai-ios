// Supabase Edge Function: ai-request. See handler.ts for the contract and
// supabase/README.md for deployment and secrets.
import { createClient } from "jsr:@supabase/supabase-js@2";
import { type CreditState, handleAiRequest } from "./handler.ts";
import { completeWithGroq, DEFAULT_MODEL } from "./provider.ts";

const admin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false, autoRefreshToken: false } },
);

const apiKey = Deno.env.get("GROQ_API_KEY") ?? "";
const model = Deno.env.get("GROQ_MODEL") || DEFAULT_MODEL;

async function rpc<T>(fn: string, params: Record<string, unknown>) {
  const { data, error } = await admin.rpc(fn, params);
  if (error) throw new Error(`${fn} failed`);
  return data as T;
}

Deno.serve((req) =>
  handleAiRequest(req, {
    async getUserId(jwt) {
      const { data, error } = await admin.auth.getUser(jwt);
      return error || !data.user ? null : data.user.id;
    },
    providerConfigured: apiKey.length > 0,
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
    complete: (prompt) => completeWithGroq(prompt, { apiKey, model }),
    log: (event, fields) => console.log(JSON.stringify({ event, ...fields })),
  })
);
