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
// v2 (L-D43, the app's ENABLE_AI_COACH_V2, body "version": 2): the virtual
// PT. Extra kinds (workout_review, plan_suggestion), the coach's own
// numbers-only history of the last 4 weeks (ai_coach_history), the app's
// long-term chat memory sent back by the app (never stored here), and a JSON
// answer validated by schema.ts with a text fallback. Per-user daily and
// monthly total limits (Edge Function settings) apply on top of credits.
// Logs carry the kind, outcome and provider only, never content.
//
// Pure request handling with injected dependencies (handler_test.ts);
// index.ts wires Supabase and the providers (providers.ts). Shapes:
// supabase/contracts/credits.json.
import { type HistoryRow, summarizeHistory } from "./coach_context.ts";
import type { Completion } from "./providers.ts";
import {
  answerText,
  fallbackText,
  parseJsonText,
  type StructuredAnswer,
  validateAnswer,
} from "./schema.ts";

export const KINDS = [
  "coach_chat",
  "advanced_analysis",
  "progress_review",
] as const;
/** Kinds a v2 request may use. */
export const KINDS_V2 = [
  "coach_chat",
  "workout_review",
  "plan_suggestion",
  "progress_review",
  "reminder_batch",
] as const;
export type Kind = typeof KINDS[number] | typeof KINDS_V2[number];
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
  /** 1 (default) free text; 2 the virtual PT with a JSON answer. */
  version?: 1 | 2;
}

export interface UsageCounts {
  /** Requests of this user today (UTC) that were charged and not refunded. */
  user_today: number;
  /** All users this month (UTC). */
  total_month: number;
}

export interface UsageLimits {
  /** 0 = no limit. */
  perUserDaily: number;
  monthlyTotal: number;
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
  /** Calls the provider(s); throws on any failure. Returns the answer text. */
  complete(prompt: ProviderPrompt): Promise<string | Completion>;
  /** Usage for the limits; required when any limit is set. */
  usage?(userId: string): Promise<UsageCounts>;
  limits?: UsageLimits;
  /** v2: the user's synced workouts of the last weeks (numbers only). */
  loadHistory?(userId: string): Promise<HistoryRow[]>;
  now?(): Date;
  log?(event: string, fields?: Record<string, unknown>): void;
}

export const LIMITS = {
  bodyBytes: 65_536,
  messages: 20,
  /** v2 chat keeps the last 15 turns (user + assistant). */
  messagesV2: 30,
  messageChars: 2_000,
  contextChars: 16_000,
  memoryChars: 1_000,
  answerChars: 4_000,
  historyDays: 28,
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
  version: 1 | 2;
  memory: string | null;
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

  const version = b["version"] ?? 1;
  if (version !== 1 && version !== 2) return null;
  const kinds: readonly string[] = version === 2 ? KINDS_V2 : KINDS;
  const kind = b["kind"];
  if (typeof kind !== "string" || !kinds.includes(kind)) return null;

  const locale = b["locale"] ?? "en";
  if (locale !== "en" && locale !== "vi") return null;

  const messages: ChatMessage[] = [];
  const rawMessages = b["messages"] ?? [];
  const maxMessages = version === 2 ? LIMITS.messagesV2 : LIMITS.messages;
  if (!Array.isArray(rawMessages) || rawMessages.length > maxMessages) {
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

  // v2 only: the long-term chat summary the app keeps (D-21: not stored here).
  const rawMemory = b["memory"] ?? null;
  if (rawMemory !== null && (version !== 2 || typeof rawMemory !== "string")) {
    return null;
  }
  const memory = typeof rawMemory === "string" && rawMemory.trim()
    ? rawMemory.trim()
    : null;
  if (memory !== null && memory.length > LIMITS.memoryChars) return null;

  // Coach chat needs the user's question last; v1 analyses need the data
  // (v2 analyses also read the user's synced history).
  if (kind === "coach_chat") {
    if (messages.length === 0 || messages.at(-1)!.role !== "user") return null;
  } else if (context === null && version === 1) {
    return null;
  } else if (
    kind === "reminder_batch" &&
    (context === null || !Array.isArray(context["sessions"]))
  ) {
    // NT-2 layer 2: the upcoming sessions to word.
    return null;
  }

  return {
    requestId,
    kind: kind as Kind,
    locale,
    messages,
    context,
    version,
    memory,
  };
}

/** Which limit a request would exceed, or null. */
export function limitReached(
  usage: UsageCounts,
  limits: UsageLimits,
): "user_daily" | "monthly_total" | null {
  if (limits.monthlyTotal > 0 && usage.total_month >= limits.monthlyTotal) {
    return "monthly_total";
  }
  if (limits.perUserDaily > 0 && usage.user_today >= limits.perUserDaily) {
    return "user_daily";
  }
  return null;
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

  const fields = { kind: parsed.kind, version: parsed.version };

  // Per-user daily and monthly total limits, before anything is charged.
  const limits = deps.limits ?? { perUserDaily: 0, monthlyTotal: 0 };
  if (limits.perUserDaily > 0 || limits.monthlyTotal > 0) {
    let scope: ReturnType<typeof limitReached>;
    try {
      if (!deps.usage) throw new Error("usage not wired");
      scope = limitReached(await deps.usage(userId), limits);
    } catch {
      log("ai_request", { ...fields, outcome: "usage_error" });
      return json(500, { error: "internal" });
    }
    if (scope) {
      log("ai_request", { ...fields, outcome: "limit_reached", scope });
      return json(429, { error: "limit_reached", scope });
    }
  }

  let charge: CreditState & { status: string };
  try {
    charge = await deps.consume(userId, parsed.requestId, parsed.kind);
  } catch {
    log("ai_request", { ...fields, outcome: "ledger_error" });
    return json(500, { error: "internal" });
  }
  if (charge.status === "duplicate") {
    log("ai_request", { ...fields, outcome: "duplicate" });
    return json(409, { error: "duplicate_request", balance: charge.balance });
  }
  if (charge.status === "insufficient") {
    log("ai_request", { ...fields, outcome: "insufficient" });
    return json(402, {
      error: "insufficient_credits",
      balance: charge.balance,
      weekly_allowance: charge.weekly_allowance,
    });
  }

  // v2: the coach's context = the app's numbers + the synced history summary
  // + the memory the app keeps. A missing history does not fail the request.
  let context = parsed.context;
  if (parsed.version === 2) {
    let history: ReturnType<typeof summarizeHistory> | null = null;
    if (deps.loadHistory) {
      try {
        history = summarizeHistory(
          await deps.loadHistory(userId),
          deps.now?.() ?? new Date(),
          LIMITS.historyDays,
        );
      } catch {
        log("ai_request", { ...fields, outcome: "history_unavailable" });
      }
    }
    context = {
      ...(parsed.context ?? {}),
      history,
      locale: parsed.locale,
      ...(parsed.memory ? { memory: parsed.memory } : {}),
    };
  }

  let raw: string;
  let provider: string | undefined;
  let fallback = false;
  try {
    const out = await deps.complete({
      kind: parsed.kind,
      locale: parsed.locale,
      messages: parsed.messages,
      context,
      version: parsed.version,
    });
    if (typeof out === "string") raw = out;
    else ({ text: raw, provider, fallback } = out);
    raw = raw.trim();
    if (raw.length === 0) throw new Error("empty answer");
  } catch {
    return await refundAndFail();
  }

  let text = raw;
  let data: StructuredAnswer | null = null;
  let outcome = "ok";
  if (parsed.version === 2) {
    data = validateAnswer(parsed.kind, parseJsonText(raw));
    if (data) {
      text = answerText(parsed.kind, data);
    } else {
      // Not the JSON we asked for: show plain text if there is any.
      const plain = fallbackText(raw);
      if (!plain) return await refundAndFail("invalid_answer");
      text = plain;
      outcome = "ok_text_fallback";
    }
  }

  log("ai_request", { ...fields, outcome, provider, fallback });
  const body: Record<string, unknown> = {
    request_id: parsed.requestId,
    text: text.slice(0, LIMITS.answerChars),
    balance: charge.balance,
  };
  if (parsed.version === 2) {
    body.data = data;
    if (data && "memory" in data && data.memory) body.memory = data.memory;
  }
  return json(200, body);

  async function refundAndFail(reason = "provider_error") {
    const uid = userId!, requestId = parsed!.requestId;
    let balance = charge.balance;
    try {
      balance = (await deps.refund(uid, requestId)).balance;
    } catch {
      // The refund is retried by support from the log; never charge twice.
      log("ai_request", { ...fields, outcome: "refund_failed" });
    }
    log("ai_request", { ...fields, outcome: reason });
    return json(502, { error: "provider_error", balance });
  }
}
