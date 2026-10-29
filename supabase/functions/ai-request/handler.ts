// ai-request (AI-1; D-07, D-08, D-09, D-21).
//
// Credited AI calls: coach chat, advanced analysis, progress review. Basic
// post-workout feedback stays free and does not come here (D-07).
//
// Order: authenticate the JWT -> validate -> charge one credit for the
// request id (ai_credit_consume; a retry of the same id is refused, never
// charged twice) -> call the provider -> on provider failure refund the
// credit (ai_credit_refund). Nothing of the conversation is stored or
// logged (D-21); the answer goes back to the app only.
//
// Pure request handling with injected dependencies (handler_test.ts);
// index.ts wires Supabase and the provider. Shapes:
// supabase/contracts/credits.json.

export const KINDS = [
  "coach_chat",
  "advanced_analysis",
  "progress_review",
] as const;
export type Kind = typeof KINDS[number];
export type Locale = "en" | "vi";

export interface ChatMessage {
  role: "user" | "assistant";
  content: string;
}

export interface CreditState {
  balance: number;
  weekly_allowance: number;
  week_start: string;
  pro: boolean;
}

export interface ProviderPrompt {
  kind: Kind;
  locale: Locale;
  messages: ChatMessage[];
  context: Record<string, unknown> | null;
}

export interface AiRequestDeps {
  /** Resolves the bearer token to a user id, or null when invalid. */
  getUserId(jwt: string): Promise<string | null>;
  /** Whether the AI provider key is configured. */
  providerConfigured: boolean;
  consume(
    userId: string,
    requestId: string,
    kind: Kind,
  ): Promise<
    CreditState & { status: "charged" | "duplicate" | "insufficient" }
  >;
  refund(
    userId: string,
    requestId: string,
  ): Promise<CreditState & { refunded: boolean }>;
  /** Calls the provider; throws on any failure. Returns the answer text. */
  complete(prompt: ProviderPrompt): Promise<string>;
  log?(event: string, fields?: Record<string, unknown>): void;
}

export const LIMITS = {
  bodyBytes: 65_536,
  messages: 20,
  messageChars: 2_000,
  contextChars: 16_000,
  answerChars: 4_000,
} as const;

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });

type Parsed = {
  requestId: string;
  kind: Kind;
  locale: Locale;
  messages: ChatMessage[];
  context: Record<string, unknown> | null;
};

export function parseBody(text: string): Parsed | null {
  if (new TextEncoder().encode(text).length > LIMITS.bodyBytes) return null;
  let body: unknown;
  try {
    body = JSON.parse(text);
  } catch {
    return null;
  }
  if (!body || typeof body !== "object" || Array.isArray(body)) return null;
  const b = body as Record<string, unknown>;

  const requestId = b["request_id"];
  if (
    typeof requestId !== "string" || !/^[A-Za-z0-9_-]{1,80}$/.test(requestId)
  ) return null;

  const kind = b["kind"];
  if (typeof kind !== "string" || !KINDS.includes(kind as Kind)) return null;

  const locale = b["locale"] ?? "en";
  if (locale !== "en" && locale !== "vi") return null;

  const messages: ChatMessage[] = [];
  const rawMessages = b["messages"] ?? [];
  if (!Array.isArray(rawMessages) || rawMessages.length > LIMITS.messages) {
    return null;
  }
  for (const m of rawMessages) {
    if (!m || typeof m !== "object") return null;
    const { role, content } = m as Record<string, unknown>;
    if (role !== "user" && role !== "assistant") return null;
    if (
      typeof content !== "string" || content.trim().length === 0 ||
      content.length > LIMITS.messageChars
    ) return null;
    messages.push({ role, content });
  }

  const rawContext = b["context"] ?? null;
  let context: Record<string, unknown> | null = null;
  if (rawContext !== null) {
    if (typeof rawContext !== "object" || Array.isArray(rawContext)) {
      return null;
    }
    if (JSON.stringify(rawContext).length > LIMITS.contextChars) return null;
    context = rawContext as Record<string, unknown>;
  }

  // Coach chat needs the user's question last; analyses need the data.
  if (kind === "coach_chat") {
    if (messages.length === 0 || messages.at(-1)!.role !== "user") return null;
  } else if (context === null) {
    return null;
  }

  return { requestId, kind: kind as Kind, locale, messages, context };
}

export async function handleAiRequest(
  req: Request,
  deps: AiRequestDeps,
): Promise<Response> {
  const log = deps.log ?? (() => {});
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });

  const match = /^Bearer\s+(.+)$/i.exec(req.headers.get("authorization") ?? "");
  if (!match) return json(401, { error: "unauthorized" });

  let userId: string | null;
  try {
    userId = await deps.getUserId(match[1].trim());
  } catch {
    userId = null;
  }
  if (!userId) return json(401, { error: "unauthorized" });

  const parsed = parseBody(await req.text());
  if (!parsed) return json(400, { error: "invalid_body" });

  // Refuse before charging when the provider cannot be reached at all.
  if (!deps.providerConfigured) return json(503, { error: "not_configured" });

  let charge;
  try {
    charge = await deps.consume(userId, parsed.requestId, parsed.kind);
  } catch {
    log("ai_request", { kind: parsed.kind, outcome: "ledger_error" });
    return json(500, { error: "internal" });
  }
  if (charge.status === "duplicate") {
    log("ai_request", { kind: parsed.kind, outcome: "duplicate" });
    return json(409, { error: "duplicate_request", balance: charge.balance });
  }
  if (charge.status === "insufficient") {
    log("ai_request", { kind: parsed.kind, outcome: "insufficient" });
    return json(402, {
      error: "insufficient_credits",
      balance: charge.balance,
      weekly_allowance: charge.weekly_allowance,
    });
  }

  let text: string;
  try {
    text = (await deps.complete({
      kind: parsed.kind,
      locale: parsed.locale,
      messages: parsed.messages,
      context: parsed.context,
    })).trim();
    if (text.length === 0) throw new Error("empty answer");
  } catch {
    let balance = charge.balance;
    try {
      balance = (await deps.refund(userId, parsed.requestId)).balance;
    } catch {
      // The refund is retried by support from the log; never charge twice.
      log("ai_request", { kind: parsed.kind, outcome: "refund_failed" });
    }
    log("ai_request", { kind: parsed.kind, outcome: "provider_error" });
    return json(502, { error: "provider_error", balance });
  }

  log("ai_request", { kind: parsed.kind, outcome: "ok" });
  return json(200, {
    request_id: parsed.requestId,
    text: text.slice(0, LIMITS.answerChars),
    balance: charge.balance,
  });
}
