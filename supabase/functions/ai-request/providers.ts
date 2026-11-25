// Provider layer for ai-request (L-D43): one interface, two providers
// (GroqCloud in provider.ts, Anthropic below), chosen by the Edge Function
// secret AI_PROVIDER, with an optional fallback provider on error or
// timeout. The app never sees which provider answered: the request and
// response of ai-request stay the same.
//
// Keys and models are Edge Function secrets only (supabase secrets set ...):
// GROQ_API_KEY / GROQ_MODEL, ANTHROPIC_API_KEY / ANTHROPIC_MODEL. They are
// never in the app, never in the repository.
import type { ProviderPrompt } from "./handler.ts";
import { neutralPrompt } from "./prompts.ts";
import { JSON_SCHEMAS } from "./schema.ts";
import { type GroqConfig, groqProvider } from "./provider.ts";

export type ProviderName = "groq" | "anthropic";

export interface ProviderOptions {
  signal?: AbortSignal;
}

export interface AiProvider {
  name: ProviderName;
  /** Whether its key is set; an unconfigured provider is never called. */
  configured: boolean;
  /** Returns the answer text; throws on any failure (status, timeout, refusal). */
  complete(prompt: ProviderPrompt, options?: ProviderOptions): Promise<string>;
}

// ---------------------------------------------------------------- Anthropic

export interface AnthropicConfig {
  apiKey: string;
  model: string;
  /** Output budget, kept small: coaching answers are short. */
  maxTokens?: number;
  /** output_config.effort; "low" suits short chat-style answers. */
  effort?: "low" | "medium" | "high";
  timeoutMs?: number;
}

export const ANTHROPIC_DEFAULT_MODEL = "claude-opus-5-5";
export const ANTHROPIC_VERSION = "2026-10-21";
const ANTHROPIC_ENDPOINT = "https://api.anthropic.com/v1/messages";
// Server-side refusal fallback (routes by refusal category), recommended
// for this model family.
const ANTHROPIC_BETA = "server-side-fallback-2026-07-01";
const MAX_RESPONSE_BYTES = 262_144;

/** Messages API body: cached system block, alternating user/assistant turns. */
export function anthropicBody(prompt: ProviderPrompt, config: AnthropicConfig) {
  const p = neutralPrompt(prompt);
  // The API expects turns to start with the user and alternate; merge any
  // consecutive turns of the same role (e.g. context + first question).
  const messages: { role: "user" | "assistant"; content: string }[] = [];
  for (const m of p.messages) {
    const last = messages.at(-1);
    if (last && last.role === m.role) last.content += `\n\n${m.content}`;
    else messages.push({ role: m.role, content: m.content });
  }
  if (messages[0]?.role !== "user") {
    messages.unshift({ role: "user", content: "(conversation so far)" });
  }
  const schema = p.json ? JSON_SCHEMAS[prompt.kind] : undefined;
  return {
    model: config.model,
    max_tokens: config.maxTokens ?? 2_048,
    // The system text depends only on version, kind and locale, so it is
    // cached across users (prompt caching, ephemeral).
    system: [
      { type: "text", text: p.system, cache_control: { type: "ephemeral" } },
    ],
    messages,
    output_config: {
      effort: config.effort ?? "low",
      ...(schema ? { format: { type: "json_schema", schema } } : {}),
    },
    fallbacks: "default",
  };
}

export async function completeWithAnthropic(
  prompt: ProviderPrompt,
  config: AnthropicConfig,
  fetchFn: typeof fetch = fetch,
  options: ProviderOptions = {},
): Promise<string> {
  const res = await fetchFn(ANTHROPIC_ENDPOINT, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-api-key": config.apiKey,
      "anthropic-version": ANTHROPIC_VERSION,
      "anthropic-beta": ANTHROPIC_BETA,
    },
    body: JSON.stringify(anthropicBody(prompt, config)),
    signal: options.signal ?? AbortSignal.timeout(config.timeoutMs ?? 25_000),
  });
  // 429 rate limit, 529 overloaded, 5xx: all go to the fallback provider.
  if (!res.ok) throw new Error(`provider ${Math.floor(res.status / 100)}xx`);
  const raw = await res.text();
  if (raw.length > MAX_RESPONSE_BYTES) throw new Error("provider too large");
  const data = JSON.parse(raw) as {
    stop_reason?: string;
    content?: { type?: string; text?: unknown }[];
  };
  // A refusal or a cut-off answer is not usable (and may not match the schema).
  if (data.stop_reason === "refusal") throw new Error("provider refusal");
  if (data.stop_reason === "max_tokens") throw new Error("provider truncated");
  const text = (data.content ?? [])
    .filter((b) => b.type === "text" && typeof b.text === "string")
    .map((b) => b.text as string)
    .join("");
  if (text.trim().length === 0) throw new Error("provider invalid");
  return text;
}

export function anthropicProvider(
  config: AnthropicConfig,
  fetchFn: typeof fetch = fetch,
): AiProvider {
  return {
    name: "anthropic",
    configured: config.apiKey.length > 0,
    complete: (prompt, options) =>
      completeWithAnthropic(prompt, config, fetchFn, options),
  };
}

// ------------------------------------------------------------------ router

export interface Completion {
  text: string;
  provider: ProviderName;
  /** True when the primary failed and the fallback answered. */
  fallback: boolean;
}

/**
 * Tries the configured providers in order (primary, then fallback); each
 * gets its own timeout. Throws when none answered. Errors are not logged
 * here with any content: only the provider names reach the caller's log.
 */
export async function completeWithFallback(
  prompt: ProviderPrompt,
  providers: AiProvider[],
  log: (event: string, fields?: Record<string, unknown>) => void = () => {},
): Promise<Completion> {
  const usable = providers.filter((p) => p.configured);
  if (usable.length === 0) throw new Error("no provider");
  for (const [i, p] of usable.entries()) {
    try {
      return {
        text: await p.complete(prompt),
        provider: p.name,
        fallback: i > 0,
      };
    } catch (e) {
      log("ai_provider", {
        provider: p.name,
        outcome: e instanceof DOMException && e.name === "TimeoutError"
          ? "timeout"
          : "error",
      });
    }
  }
  throw new Error("all providers failed");
}

// ------------------------------------------------------------------ config

export interface ProviderEnv {
  get(name: string): string | undefined;
}

const name = (v: string | undefined): ProviderName | null =>
  v === "groq" || v === "anthropic" ? v : null;

/**
 * Providers in call order from the Edge Function secrets:
 * AI_PROVIDER (groq | anthropic, default groq), AI_FALLBACK_PROVIDER
 * (optional, the other one), and each provider's key / model.
 */
export function providersFromEnv(
  env: ProviderEnv,
  fetchFn: typeof fetch = fetch,
): AiProvider[] {
  const groq: GroqConfig = {
    apiKey: env.get("GROQ_API_KEY") ?? "",
    model: env.get("GROQ_MODEL") || "openai/gpt-oss-20b",
  };
  const effort = env.get("ANTHROPIC_EFFORT");
  const anthropic: AnthropicConfig = {
    apiKey: env.get("ANTHROPIC_API_KEY") ?? "",
    model: env.get("ANTHROPIC_MODEL") || ANTHROPIC_DEFAULT_MODEL,
    maxTokens: Number(env.get("ANTHROPIC_MAX_TOKENS")) || 2_048,
    effort: effort === "medium" || effort === "high" ? effort : "low",
  };
  const all: Record<ProviderName, AiProvider> = {
    groq: groqProvider(groq, fetchFn),
    anthropic: anthropicProvider(anthropic, fetchFn),
  };
  const primary = name(env.get("AI_PROVIDER")) ?? "groq";
  const fallback = name(env.get("AI_FALLBACK_PROVIDER"));
  return fallback && fallback !== primary
    ? [all[primary], all[fallback]]
    : [all[primary]];
}
