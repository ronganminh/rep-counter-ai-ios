// GroqCloud provider for ai-request: the OpenAI-compatible chat endpoint the
// existing feedback backend uses (backend/ai_provider.py, same default
// model). The key lives only in the Edge Function secrets (GROQ_API_KEY).
import type { ChatMessage, ProviderPrompt } from "./handler.ts";
import { neutralPrompt } from "./prompts.ts";
import type { AiProvider, ProviderOptions } from "./providers.ts";

export interface GroqConfig {
  apiKey: string;
  model: string;
  timeoutMs?: number;
}

export const DEFAULT_MODEL = "openai/gpt-oss-20b";
const ENDPOINT = "https://api.groq.com/openai/v1/chat/completions";
const MAX_RESPONSE_BYTES = 65_536;

export function buildMessages(prompt: ProviderPrompt): {
  role: "system" | ChatMessage["role"];
  content: string;
}[] {
  const p = neutralPrompt(prompt);
  return [{ role: "system", content: p.system }, ...p.messages];
}

export async function completeWithGroq(
  prompt: ProviderPrompt,
  config: GroqConfig,
  fetchFn: typeof fetch = fetch,
  options: ProviderOptions = {},
): Promise<string> {
  const json = (prompt.version ?? 1) === 2;
  const res = await fetchFn(ENDPOINT, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${config.apiKey}`,
    },
    body: JSON.stringify({
      model: config.model,
      messages: buildMessages(prompt),
      temperature: 0.6,
      max_completion_tokens: json ? 1_200 : 700,
      // v2 answers are one JSON object (validated in schema.ts).
      ...(json ? { response_format: { type: "json_object" } } : {}),
    }),
    signal: options.signal ?? AbortSignal.timeout(config.timeoutMs ?? 20_000),
  });
  if (!res.ok) throw new Error(`provider ${Math.floor(res.status / 100)}xx`);
  const raw = await res.text();
  if (raw.length > MAX_RESPONSE_BYTES) throw new Error("provider too large");
  const data = JSON.parse(raw) as {
    choices?: { message?: { content?: unknown } }[];
  };
  const content = data.choices?.[0]?.message?.content;
  if (typeof content !== "string") throw new Error("provider invalid");
  return content;
}

export function groqProvider(
  config: GroqConfig,
  fetchFn: typeof fetch = fetch,
): AiProvider {
  return {
    name: "groq",
    configured: config.apiKey.length > 0,
    complete: (prompt, options) =>
      completeWithGroq(prompt, config, fetchFn, options),
  };
}
