// The AI provider behind ai-request: GroqCloud's OpenAI-compatible chat
// endpoint, as the existing feedback backend uses (backend/ai_provider.py,
// same default model). The key lives only in the Edge Function secrets.
import type { ChatMessage, Kind, Locale, ProviderPrompt } from "./handler.ts";

export interface GroqConfig {
  apiKey: string;
  model: string;
  timeoutMs?: number;
}

export const DEFAULT_MODEL = "openai/gpt-oss-20b";
const ENDPOINT = "https://api.groq.com/openai/v1/chat/completions";
const MAX_RESPONSE_BYTES = 65_536;

// General fitness guidance only; the same safety rules as the free
// feedback prompt (backend/ai_provider.py).
const SAFETY = {
  en: "You are RepCoach, a friendly strength coach. Answer in ENGLISH ONLY. " +
    "Give general fitness guidance, never medical advice or diagnoses; if " +
    "the user mentions pain, injury or a health condition, tell them to " +
    "stop and ask a qualified professional. Use only the numbers provided " +
    "and never recompute rep counts or scores. Keep it short and practical.",
  vi:
    "Bạn là RepCoach, HLV thể hình thân thiện. Chỉ trả lời bằng TIẾNG VIỆT. " +
    "Chỉ đưa lời khuyên thể dục chung, không chẩn đoán hay tư vấn y khoa; nếu " +
    "người dùng nhắc tới đau, chấn thương hay bệnh lý, khuyên họ dừng tập và " +
    "hỏi chuyên gia. Chỉ dùng số liệu được cung cấp, không tự tính lại số rep " +
    "hay điểm. Trả lời ngắn gọn, thực tế.",
} as const;

const TASK: Record<Kind, Record<Locale, string>> = {
  coach_chat: {
    en: "Answer the user's latest question about their training.",
    vi: "Trả lời câu hỏi mới nhất của người dùng về việc tập luyện.",
  },
  advanced_analysis: {
    en: "Analyse the workout data in the context: what went well, what to " +
      "watch, and one or two concrete tips for next time.",
    vi: "Phân tích số liệu buổi tập trong ngữ cảnh: điểm tốt, điểm cần chú ý " +
      "và một hai lời khuyên cụ thể cho buổi sau.",
  },
  progress_review: {
    en: "Review the progress over the period in the context: trends, " +
      "consistency, and a realistic focus for the coming week.",
    vi:
      "Đánh giá tiến bộ trong giai đoạn ở ngữ cảnh: xu hướng, độ đều đặn và " +
      "một trọng tâm thực tế cho tuần tới.",
  },
};

export function buildMessages(prompt: ProviderPrompt): {
  role: "system" | ChatMessage["role"];
  content: string;
}[] {
  const system = `${SAFETY[prompt.locale]} ${TASK[prompt.kind][prompt.locale]}`;
  const out: { role: "system" | ChatMessage["role"]; content: string }[] = [
    { role: "system", content: system },
  ];
  if (prompt.context) {
    out.push({ role: "user", content: JSON.stringify(prompt.context) });
  }
  out.push(...prompt.messages);
  return out;
}

export async function completeWithGroq(
  prompt: ProviderPrompt,
  config: GroqConfig,
  fetchFn: typeof fetch = fetch,
): Promise<string> {
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
      max_completion_tokens: 700,
    }),
    signal: AbortSignal.timeout(config.timeoutMs ?? 20_000),
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
