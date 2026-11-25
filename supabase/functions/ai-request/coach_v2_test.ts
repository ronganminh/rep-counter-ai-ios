// AI-1 coach v2 (L-D43): provider layer (mocked fetch, no network), output
// schema and fallback, limits, numbers-only context, safety prompt.
import {
  assert,
  assertEquals,
  assertFalse,
  assertStringIncludes,
} from "../_shared/assert.ts";
import contract from "../../contracts/credits.json" with { type: "json" };
import {
  type AiRequestDeps,
  type CreditState,
  handleAiRequest,
  KINDS_V2,
  limitReached,
  type ProviderPrompt,
} from "./handler.ts";
import { type HistoryRow, summarizeHistory } from "./coach_context.ts";
import {
  type AiProvider,
  ANTHROPIC_DEFAULT_MODEL,
  ANTHROPIC_DEFAULT_PLAN_MODEL,
  ANTHROPIC_VERSION,
  anthropicBody,
  type AnthropicConfig,
  completeWithAnthropic,
  completeWithFallback,
  providersFromEnv,
  supportsServerFallback,
} from "./providers.ts";
import { completeWithGroq } from "./provider.ts";
import { neutralPrompt, PT_RULES, systemPrompt } from "./prompts.ts";
import {
  fallbackText,
  JSON_SCHEMAS,
  parseJsonText,
  validateAnswer,
  validTarget,
} from "./schema.ts";

const edge = contract.edge_functions["ai-request"];

const chatPrompt: ProviderPrompt = {
  kind: "coach_chat",
  locale: "en",
  messages: [{ role: "user", content: "How many push-ups tomorrow?" }],
  context: null,
  version: 2,
};

const reviewJson = {
  summary: "Solid set, tempo slowed at the end.",
  fixes: ["Keep elbows at 45 degrees", "Breathe out on the push"],
  next_session: [{
    exercise_id: "pushup",
    sets: 3,
    reps: 11,
    seconds: null,
    rest_seconds: 90,
    change: "increase",
    note: "+1 rep per set",
  }],
};

const ok = (body: unknown, status = 200): typeof fetch => () =>
  Promise.resolve(new Response(JSON.stringify(body), { status }));

// ------------------------------------------------------------- Anthropic

Deno.test("anthropic: Messages API request with cached system prompt", async () => {
  let seen: { url: string; init: RequestInit } | null = null;
  const fetchFn: typeof fetch = (url, init) => {
    seen = { url: String(url), init: init! };
    return Promise.resolve(
      new Response(JSON.stringify({
        stop_reason: "end_turn",
        content: [{ type: "text", text: JSON.stringify(reviewJson) }],
      })),
    );
  };
  const prompt: ProviderPrompt = {
    kind: "workout_review",
    locale: "vi",
    messages: [],
    context: { workout: { reps: 30 } },
    version: 2,
  };
  const text = await completeWithAnthropic(
    prompt,
    { apiKey: "sk-test", model: ANTHROPIC_DEFAULT_MODEL },
    fetchFn,
  );
  assertEquals(JSON.parse(text), reviewJson);
  assertEquals(seen!.url, "https://api.anthropic.com/v1/messages");
  const h = seen!.init.headers as Record<string, string>;
  assertEquals(h["x-api-key"], "sk-test");
  assertEquals(h["anthropic-version"], ANTHROPIC_VERSION);
  assertFalse("authorization" in h);
  const body = JSON.parse(String(seen!.init.body));
  assertEquals(body.model, "claude-haiku-5-5");
  // Haiku has no server-side refusal fallback: no parameter, no beta header.
  assertFalse("fallbacks" in body);
  assertFalse("anthropic-beta" in h);
  assert(body.max_tokens <= 4_096, "small max_tokens");
  assertEquals(body.system.length, 1);
  assertEquals(body.system[0].cache_control, { type: "ephemeral" });
  assertStringIncludes(body.system[0].text, "TIẾNG VIỆT");
  assertEquals(body.output_config.format.type, "json_schema");
  assertEquals(body.output_config.format.schema, JSON_SCHEMAS.workout_review);
  assertEquals(body.output_config.effort, "low");
  assertFalse("temperature" in body, "sampling params are not sent");
  assertEquals(body.messages[0].role, "user");
  assertStringIncludes(body.messages[0].content, '"reps":30');
});

Deno.test("anthropic: turns alternate, starting with the user", () => {
  const body = anthropicBody({
    kind: "coach_chat",
    locale: "en",
    messages: [
      { role: "user", content: "a" },
      { role: "assistant", content: "b" },
      { role: "user", content: "c" },
    ],
    context: { plan: 1 },
    version: 2,
  }, { apiKey: "k", model: "m" });
  const roles = body.messages.map((m) => m.role);
  assertEquals(roles, ["user", "assistant", "user"]);
  assertStringIncludes(body.messages[0].content, "Context");
  assertStringIncludes(body.messages[0].content, "\n\na");
  // v1 has no JSON schema.
  const v1 = anthropicBody({ ...chatPrompt, version: 1 }, {
    apiKey: "k",
    model: "m",
  });
  assertFalse("format" in v1.output_config);
});

Deno.test("anthropic: refusal, truncation, errors and empty answers throw", async () => {
  const cases: typeof fetch[] = [
    ok({ stop_reason: "refusal", content: [] }),
    ok({ stop_reason: "max_tokens", content: [{ type: "text", text: "{" }] }),
    ok({
      stop_reason: "end_turn",
      content: [{ type: "thinking", thinking: "" }],
    }),
    ok({ type: "error", error: { type: "overloaded_error" } }, 529),
    ok({ type: "error" }, 429),
    () => Promise.resolve(new Response("not json")),
  ];
  for (const f of cases) {
    let threw = false;
    try {
      await completeWithAnthropic(chatPrompt, { apiKey: "k", model: "m" }, f);
    } catch {
      threw = true;
    }
    assert(threw);
  }
  // Text blocks are joined; other blocks are ignored.
  const t = await completeWithAnthropic(
    chatPrompt,
    { apiKey: "k", model: "m" },
    ok({
      stop_reason: "end_turn",
      content: [
        { type: "thinking", thinking: "" },
        { type: "text", text: "A" },
        {
          type: "text",
          text: "B",
        },
      ],
    }),
  );
  assertEquals(t, "AB");
});

Deno.test("groq: v2 asks for a JSON object", async () => {
  let body: Record<string, unknown> = {};
  await completeWithGroq(
    chatPrompt,
    { apiKey: "k", model: "m" },
    (_u, init) => {
      body = JSON.parse(String(init!.body));
      return Promise.resolve(
        new Response(
          JSON.stringify({ choices: [{ message: { content: "{}" } }] }),
        ),
      );
    },
  );
  assertEquals(body.response_format, { type: "json_object" });
});

// ---------------------------------------------------------------- router

const fake = (
  name: "groq" | "anthropic",
  behaviour: () => Promise<string>,
  configured = true,
): AiProvider & { calls: number } => {
  const p = {
    name,
    configured,
    calls: 0,
    complete() {
      p.calls++;
      return behaviour();
    },
  };
  return p;
};

Deno.test("router: fallback provider on error or timeout", async () => {
  const logs: string[] = [];
  const log = (e: string, f?: Record<string, unknown>) =>
    logs.push(JSON.stringify({ e, ...f }));
  const primary = fake(
    "anthropic",
    () => Promise.reject(new Error("529 secret body")),
  );
  const backup = fake("groq", () => Promise.resolve("answer"));
  const out = await completeWithFallback(chatPrompt, [primary, backup], log);
  assertEquals(out, { text: "answer", provider: "groq", fallback: true });
  assertEquals(logs.length, 1);
  assertStringIncludes(logs[0], '"provider":"anthropic"');
  assertFalse(logs.join().includes("secret"), "no error text in logs");
  assertFalse(logs.join().includes("push-ups"), "no conversation in logs");

  const timeout = fake(
    "groq",
    () => Promise.reject(new DOMException("timed out", "TimeoutError")),
  );
  const second = fake("anthropic", () => Promise.resolve("late"));
  logs.length = 0;
  assertEquals(
    (await completeWithFallback(chatPrompt, [timeout, second], log)).provider,
    "anthropic",
  );
  assertStringIncludes(logs[0], '"outcome":"timeout"');

  // Primary answers: the fallback is never called.
  const a = fake("groq", () => Promise.resolve("x"));
  const b = fake("anthropic", () => Promise.resolve("y"));
  assertEquals(
    (await completeWithFallback(chatPrompt, [a, b])).fallback,
    false,
  );
  assertEquals(b.calls, 0);

  // Unconfigured providers are skipped; none left or all failing throws.
  const off = fake("anthropic", () => Promise.resolve("no"), false);
  assertEquals((await completeWithFallback(chatPrompt, [off, a])).text, "x");
  assertEquals(off.calls, 0);
  for (const list of [[off], [primary]]) {
    let threw = false;
    try {
      await completeWithFallback(chatPrompt, list);
    } catch {
      threw = true;
    }
    assert(threw);
  }
});

Deno.test("router: providers from the Edge Function secrets", () => {
  const env = (vars: Record<string, string>) => ({
    get: (k: string) => vars[k],
  });
  const names = (vars: Record<string, string>) =>
    providersFromEnv(env(vars)).map((p) => `${p.name}:${p.configured}`);
  assertEquals(names({ GROQ_API_KEY: "g" }), ["groq:true"]);
  assertEquals(names({}), ["groq:false"]);
  assertEquals(
    names({
      AI_PROVIDER: "anthropic",
      AI_FALLBACK_PROVIDER: "groq",
      GROQ_API_KEY: "g",
    }),
    ["anthropic:false", "groq:true"],
  );
  assertEquals(
    names({
      AI_PROVIDER: "groq",
      AI_FALLBACK_PROVIDER: "groq",
      GROQ_API_KEY: "g",
    }),
    ["groq:true"],
  );
  assertEquals(names({ AI_PROVIDER: "gemini", GROQ_API_KEY: "g" }), [
    "groq:true",
  ]);
});

// ---------------------------------------------------------------- schema

Deno.test("schema: targets follow the plan model's limits", () => {
  const base = reviewJson.next_session[0];
  assert(validTarget(base));
  assert(validTarget({ ...base, reps: null, seconds: 30 }));
  for (
    const bad of [
      { ...base, reps: null, seconds: null },
      { ...base, seconds: 30 },
      { ...base, sets: 0 },
      { ...base, sets: 11 },
      { ...base, reps: 101 },
      { ...base, reps: 2.5 },
      { ...base, reps: null, seconds: 4 },
      { ...base, rest_seconds: 601 },
      { ...base, change: "double" },
      { ...base, exercise_id: "Push Up!" },
      "pushup",
    ]
  ) assertEquals(validTarget(bad), null, JSON.stringify(bad));
  assertEquals(
    validTarget({ ...base, note: "x".repeat(500) })!.note.length,
    200,
  );
});

Deno.test("schema: answers per kind, invalid items dropped", () => {
  const r = validateAnswer("workout_review", {
    ...reviewJson,
    fixes: ["a", "b", "c", "d", ""],
    next_session: [...reviewJson.next_session, {
      exercise_id: "squat",
      sets: 99,
    }],
  })!;
  assert("fixes" in r);
  assertEquals(r.fixes, ["a", "b", "c"]);
  assertEquals(r.next_session.length, 1);
  assertEquals(
    validateAnswer("workout_review", { summary: "s", fixes: [] }),
    null,
  );

  const plan = validateAnswer("plan_suggestion", {
    summary: "Two sessions",
    horizon: "next_week",
    sessions: [
      { day_offset: 1, focus: "Push", exercises: reviewJson.next_session },
      { day_offset: 9, focus: "Bad day", exercises: reviewJson.next_session },
      { day_offset: 3, focus: "Empty", exercises: [] },
    ],
  })!;
  assert("sessions" in plan);
  assertEquals(plan.sessions.map((s) => s.day_offset), [1]);
  assertEquals(
    validateAnswer("plan_suggestion", { summary: "s", horizon: "soon" }),
    null,
  );

  const chat = validateAnswer("coach_chat", {
    reply: "Do 3x10",
    memory: "m".repeat(900),
  })!;
  assert("memory" in chat);
  assertEquals(chat.memory.length, 600);
  assertEquals(validateAnswer("coach_chat", { memory: "m" }), null);
  assertEquals(validateAnswer("progress_review", [1]), null);
});

Deno.test("schema: JSON parsing and the text fallback", () => {
  assertEquals(parseJsonText('```json\n{"a":1}\n```'), { a: 1 });
  assertEquals(parseJsonText("nope"), undefined);
  assertEquals(fallbackText("Plain answer."), "Plain answer.");
  assertEquals(fallbackText('{"reply":"From JSON"}'), "From JSON");
  assertEquals(fallbackText('{"other":1}'), null);
  assertEquals(fallbackText("{broken"), null);
  assertEquals(fallbackText("   "), null);
});

Deno.test("schema: JSON Schemas close every object (structured outputs)", () => {
  const walk = (s: unknown): void => {
    if (!s || typeof s !== "object") return;
    const o = s as Record<string, unknown>;
    if (o.type === "object") {
      assertEquals(o.additionalProperties, false);
      assertEquals(
        [...(o.required as string[])].sort(),
        Object.keys(o.properties as object).sort(),
      );
    }
    for (const v of Object.values(o)) walk(v);
  };
  for (const k of KINDS_V2) {
    assert(JSON_SCHEMAS[k], k);
    walk(JSON_SCHEMAS[k]);
  }
});

// --------------------------------------------------------------- prompts

Deno.test("prompts: the virtual PT rules in both languages", () => {
  assertEquals(PT_RULES.en.length, PT_RULES.vi.length);
  const en = systemPrompt(2, "workout_review", "en");
  for (
    const s of [
      "diagnose",
      "doctor",
      "appearance",
      "13 or older",
      "not a medical device",
      "ENGLISH ONLY",
    ]
  ) {
    assertStringIncludes(en, s);
  }
  const vi = systemPrompt(2, "workout_review", "vi");
  for (
    const s of [
      "chẩn đoán",
      "bác sĩ",
      "ngoại hình",
      "13 tuổi",
      "thiết bị y tế",
      "TIẾNG VIỆT",
    ]
  ) {
    assertStringIncludes(vi, s);
  }
  // Cacheable: the system text has no user data and does not change per call.
  const a = neutralPrompt({ ...chatPrompt, context: { reps: 1 } });
  const b = neutralPrompt({ ...chatPrompt, context: { reps: 2 } });
  assertEquals(a.system, b.system);
  assertFalse(a.system.includes('reps":1'));
  assert(a.json);
  // An analysis without chat messages still ends with a user turn.
  const r = neutralPrompt({
    ...chatPrompt,
    kind: "progress_review",
    messages: [],
  });
  assertEquals(r.messages.at(-1)!.role, "user");
});

// --------------------------------------------------------------- context

Deno.test("context: 4-week numbers-only summary with rest days", () => {
  const now = new Date("2026-11-25T12:00:00Z");
  const rows: HistoryRow[] = [
    {
      started_at: "2026-11-24T08:00:00Z",
      exercise: "pushup",
      reps: 30,
      sets: 3,
      duration_seconds: 300,
      quality_score: 80,
      avg_rep_sec: 1.5,
    },
    {
      started_at: "2026-11-22T08:00:00Z",
      exercise: "pushup",
      reps: 24,
      duration_seconds: 240,
      quality_score: 70,
      partial: true,
    },
    {
      started_at: "2026-11-20T08:00:00Z",
      exercise: "squat",
      reps: 40,
      duration_seconds: 400,
      manual: true,
    },
    {
      started_at: "2026-10-01T08:00:00Z",
      exercise: "squat",
      reps: 99,
      duration_seconds: 1,
    },
    {
      started_at: "not a date",
      exercise: "squat",
      reps: 1,
      duration_seconds: 1,
    },
  ];
  const s = summarizeHistory(rows, now);
  assertEquals(s.days, 28);
  assertEquals(s.workouts, 3);
  assertEquals(s.training_days, 3);
  assertEquals(s.rest_days, 25);
  assertEquals(s.longest_break_days, 22); // 29 Oct (window start) .. 19 Nov
  assertEquals(s.by_exercise.pushup.total_reps, 54);
  assertEquals(s.by_exercise.pushup.best_reps, 30);
  assertEquals(s.by_exercise.pushup.avg_quality, 75);
  assertEquals(s.by_exercise.pushup.partial, 1);
  assertEquals(s.by_exercise.squat.manual, 1);
  assertEquals(s.weeks.map((w) => w.week_start), ["2026-11-16", "2026-11-23"]);
  assertEquals(s.recent.at(-1)!.reps, 30);
});

// --------------------------------------------------------------- handler

function deps(over: Partial<AiRequestDeps> = {}) {
  let balance = 10;
  const charged = new Set<string>();
  const prompts: ProviderPrompt[] = [];
  const logs: string[] = [];
  const state = (): CreditState => ({
    balance,
    weekly_allowance: 10,
    week_start: "2026-11-23",
    pro: false,
  });
  const d: AiRequestDeps = {
    getUserId: () => Promise.resolve("user-1"),
    providerConfigured: true,
    consume(_u, id) {
      if (charged.has(id)) {
        return Promise.resolve({ ...state(), status: "duplicate" as const });
      }
      charged.add(id);
      balance--;
      return Promise.resolve({ ...state(), status: "charged" as const });
    },
    refund() {
      balance++;
      return Promise.resolve({ ...state(), refunded: true });
    },
    complete(p) {
      prompts.push(p);
      return Promise.resolve({
        text: JSON.stringify(reviewJson),
        provider: "groq",
        fallback: false,
      });
    },
    loadHistory: () =>
      Promise.resolve([{
        started_at: "2026-11-24T08:00:00Z",
        exercise: "pushup",
        reps: 30,
        duration_seconds: 300,
      }]),
    now: () => new Date("2026-11-25T12:00:00Z"),
    log: (e, f) => logs.push(JSON.stringify({ e, ...f })),
    ...over,
  };
  return { d, prompts, logs, balance: () => balance };
}

const v2 = (body: Record<string, unknown>) =>
  new Request("http://x/ai-request", {
    method: "POST",
    headers: { authorization: "Bearer good" },
    body: JSON.stringify({
      request_id: "r-1",
      locale: "en",
      version: 2,
      ...body,
    }),
  });

Deno.test("v2: workout review returns validated data and text", async () => {
  const f = deps();
  const res = await handleAiRequest(
    v2({
      kind: "workout_review",
      context: { workout: { reps: 30 }, plan: { goal: "strength" } },
    }),
    f.d,
  );
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(
    Object.keys(body).sort(),
    edge.response_v2.filter((k) => k !== "memory").sort(),
  );
  assertEquals(body.data.next_session[0].reps, 11);
  assertStringIncludes(body.text, "Solid set");
  assertStringIncludes(body.text, "• Keep elbows");
  assertEquals(f.balance(), 9);
  // The provider got the app's numbers, the history summary and the locale.
  const ctx = f.prompts[0].context!;
  assertEquals((ctx.workout as Record<string, number>).reps, 30);
  assertEquals((ctx.history as { workouts: number }).workouts, 1);
  assertEquals(ctx.locale, "en");
  assertEquals(f.prompts[0].version, 2);
});

Deno.test("v2: chat memory goes in and comes back; nothing is logged", async () => {
  const f = deps({
    complete(p) {
      f.prompts.push(p);
      return Promise.resolve({
        text: JSON.stringify({
          reply: "Try 3x12.",
          memory: "Goal: 50 push-ups",
        }),
        provider: "groq" as const,
        fallback: false,
      });
    },
  });
  const messages = Array.from({ length: 29 }, (_, i) => ({
    role: i % 2 === 0 ? "user" : "assistant",
    content: `turn ${i}`,
  }));
  const res = await handleAiRequest(
    v2({
      kind: "coach_chat",
      messages,
      memory: "Knees hurt on deep squats last month",
    }),
    f.d,
  );
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.text, "Try 3x12.");
  assertEquals(body.memory, "Goal: 50 push-ups");
  assertEquals(
    f.prompts[0].context!.memory,
    "Knees hurt on deep squats last month",
  );
  assertEquals(f.prompts[0].messages.length, 29);
  const all = f.logs.join("\n");
  for (
    const s of ["Knees", "turn", "3x12", "50 push-ups", "user-1", "pushup"]
  ) {
    assertFalse(all.includes(s), s);
  }
  assertStringIncludes(all, '"provider":"groq"');
});

Deno.test("v2: text fallback, or refund when nothing is usable", async () => {
  const text = deps({
    complete: () => Promise.resolve("Rest tomorrow, then 3x10."),
  });
  const r1 = await handleAiRequest(v2({ kind: "workout_review" }), text.d);
  assertEquals(r1.status, 200);
  const b1 = await r1.json();
  assertEquals(b1.text, "Rest tomorrow, then 3x10.");
  assertEquals(b1.data, null);
  assertStringIncludes(text.logs.join(), "ok_text_fallback");

  const junk = deps({
    complete: () => Promise.resolve('{"unexpected": true}'),
  });
  const r2 = await handleAiRequest(v2({ kind: "plan_suggestion" }), junk.d);
  assertEquals(r2.status, 502);
  assertEquals(junk.balance(), 10, "refunded");
});

Deno.test("v2: missing history does not fail the request", async () => {
  const f = deps({ loadHistory: () => Promise.reject(new Error("db down")) });
  const res = await handleAiRequest(
    v2({ kind: "workout_review", context: { workout: {} } }),
    f.d,
  );
  assertEquals(res.status, 200);
  assertEquals(f.prompts[0].context!.history, null);
  assertStringIncludes(f.logs.join(), "history_unavailable");
});

Deno.test("v2: kinds and fields are refused on v1 and checked on v2", async () => {
  const v1 = (body: Record<string, unknown>) =>
    new Request("http://x", {
      method: "POST",
      headers: { authorization: "Bearer good" },
      body: JSON.stringify({ request_id: "r-1", ...body }),
    });
  for (
    const req of [
      v1({ kind: "workout_review", context: {} }),
      v1({
        kind: "coach_chat",
        messages: [{ role: "user", content: "q" }],
        memory: "m",
      }),
      v2({ kind: "advanced_analysis", context: {} }),
      v2({
        kind: "coach_chat",
        messages: [{ role: "user", content: "q" }],
        memory: "m".repeat(1001),
      }),
      v2({
        kind: "coach_chat",
        messages: [{ role: "user", content: "q" }],
        memory: 5,
      }),
      v2({
        kind: "coach_chat",
        messages: Array.from(
          { length: 31 },
          () => ({ role: "user", content: "q" }),
        ),
      }),
      v2({ kind: "workout_review", version: 3 }),
    ]
  ) {
    const f = deps();
    assertEquals((await handleAiRequest(req, f.d)).status, 400);
    assertEquals(f.balance(), 10);
  }
  assertEquals([...KINDS_V2], edge.kinds_v2);
});

Deno.test("limits: per-user daily and monthly total, before any charge", async () => {
  assertEquals(
    limitReached({ user_today: 29, total_month: 10 }, {
      perUserDaily: 30,
      monthlyTotal: 100,
    }),
    null,
  );
  assertEquals(
    limitReached({ user_today: 30, total_month: 10 }, {
      perUserDaily: 30,
      monthlyTotal: 100,
    }),
    "user_daily",
  );
  assertEquals(
    limitReached({ user_today: 0, total_month: 100 }, {
      perUserDaily: 30,
      monthlyTotal: 100,
    }),
    "monthly_total",
  );
  assertEquals(
    limitReached({ user_today: 999, total_month: 999 }, {
      perUserDaily: 0,
      monthlyTotal: 0,
    }),
    null,
  );

  const busy = deps({
    limits: { perUserDaily: 30, monthlyTotal: 5000 },
    usage: () => Promise.resolve({ user_today: 30, total_month: 10 }),
  });
  const res = await handleAiRequest(v2({ kind: "workout_review" }), busy.d);
  assertEquals(res.status, 429);
  assertEquals(await res.json(), {
    error: "limit_reached",
    scope: "user_daily",
  });
  assertEquals(edge.errors["429"], "limit_reached");
  assertEquals(busy.balance(), 10, "nothing charged");
  assertEquals(busy.prompts.length, 0);

  const broken = deps({
    limits: { perUserDaily: 30, monthlyTotal: 0 },
    usage: () => Promise.reject(new Error("db")),
  });
  assertEquals(
    (await handleAiRequest(v2({ kind: "workout_review" }), broken.d)).status,
    500,
  );
  assertEquals(broken.balance(), 10);

  const fine = deps({
    limits: { perUserDaily: 30, monthlyTotal: 5000 },
    usage: () => Promise.resolve({ user_today: 3, total_month: 10 }),
  });
  assertEquals(
    (await handleAiRequest(v2({ kind: "workout_review" }), fine.d)).status,
    200,
  );
});

Deno.test("anthropic: plan_suggestion uses ANTHROPIC_MODEL_PLAN", async () => {
  assertEquals(ANTHROPIC_DEFAULT_MODEL, "claude-haiku-5-5");
  assertEquals(ANTHROPIC_DEFAULT_PLAN_MODEL, "claude-haiku-5-5");
  const config: AnthropicConfig = {
    apiKey: "k",
    model: "claude-haiku-5-5",
    planModel: "claude-sonnet-5-5",
  };
  const plan: ProviderPrompt = {
    kind: "plan_suggestion",
    locale: "en",
    messages: [],
    context: { horizon: "tomorrow" },
    version: 2,
  };
  const p = anthropicBody(plan, config);
  assertEquals(p.model, "claude-sonnet-5-5");
  assertEquals((p as Record<string, unknown>).fallbacks, "default");
  const r = anthropicBody({ ...plan, kind: "workout_review" }, config);
  assertEquals(r.model, "claude-haiku-5-5");
  assertFalse("fallbacks" in r);
  // Unset plan model: the main model.
  assertEquals(
    anthropicBody(plan, { apiKey: "k", model: "claude-haiku-5-5" }).model,
    "claude-haiku-5-5",
  );
  // The beta header follows the model actually used.
  let headers: Record<string, string> = {};
  await completeWithAnthropic(plan, config, (_u, init) => {
    headers = init!.headers as Record<string, string>;
    return Promise.resolve(
      new Response(JSON.stringify({
        stop_reason: "end_turn",
        content: [{ type: "text", text: "{}" }],
      })),
    );
  });
  assertEquals(headers["anthropic-beta"], "server-side-fallback-2026-07-01");

  for (
    const m of ["claude-opus-5-5", "claude-sonnet-5-5", "claude-fable-5-2"]
  ) {
    assert(supportsServerFallback(m), m);
  }
  for (const m of ["claude-haiku-5-5", "claude-sonnet-5", "claude-haiku-4-5"]) {
    assertFalse(supportsServerFallback(m), m);
  }
});

Deno.test("router: Anthropic models from the secrets", () => {
  const env = (vars: Record<string, string>) => ({
    get: (k: string) => vars[k],
  });
  const body = (vars: Record<string, string>, kind: ProviderPrompt["kind"]) => {
    let sent: Record<string, unknown> = {};
    const [p] = providersFromEnv(
      env({ AI_PROVIDER: "anthropic", ANTHROPIC_API_KEY: "k", ...vars }),
      (_u, init) => {
        sent = JSON.parse(String(init!.body));
        return Promise.resolve(new Response("{}", { status: 500 }));
      },
    );
    return p.complete({ ...chatPrompt, kind, messages: [], context: {} }).catch(
      () => sent.model,
    );
  };
  return Promise.all([
    body({}, "workout_review").then((m) => assertEquals(m, "claude-haiku-5-5")),
    body({}, "plan_suggestion").then((m) =>
      assertEquals(m, "claude-haiku-5-5")
    ),
    body({ ANTHROPIC_MODEL_PLAN: "claude-opus-5-5" }, "plan_suggestion").then(
      (m) => assertEquals(m, "claude-opus-5-5"),
    ),
    body({ ANTHROPIC_MODEL_PLAN: "claude-opus-5-5" }, "coach_chat").then((m) =>
      assertEquals(m, "claude-haiku-5-5")
    ),
  ]).then(() => {});
});

// ------------------------------------------------- NT-2 reminder_batch

Deno.test("reminder_batch: needs sessions; lines cleaned and capped", async () => {
  const f = deps({
    complete: () =>
      Promise.resolve(JSON.stringify({
        lines: [
          {
            session_id: "s1",
            text: "  Keep your elbows in today,  easy pace. ",
          },
          { session_id: "s2", text: "Don't be lazy, hurry up!" },
          { session_id: "s3", text: "x".repeat(121) },
          { session_id: "s4", text: "Two emoji 🔥🔥" },
          { session_id: "s5", text: "Buy premium for better plans" },
          { session_id: "s1", text: "Duplicate session" },
          { session_id: "bad id!", text: "Fine text" },
          { session_id: "s6", text: "Weekend session 💪 at your pace." },
        ],
      })),
  });
  const res = await handleAiRequest(
    v2({
      kind: "reminder_batch",
      context: { sessions: [{ session_id: "s1", in_days: 1 }] },
    }),
    f.d,
  );
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.data.lines, [
    { session_id: "s1", text: "Keep your elbows in today, easy pace." },
    { session_id: "s6", text: "Weekend session 💪 at your pace." },
  ]);
  // Without sessions the request is refused before any charge.
  for (const context of [null, {}, { sessions: "s1" }]) {
    const g = deps();
    const r = await handleAiRequest(
      v2({ kind: "reminder_batch", context }),
      g.d,
    );
    assertEquals(r.status, 400);
    assertEquals(g.balance(), 10);
  }
  // Nothing usable → refund.
  const junk = deps({
    complete: () =>
      Promise.resolve(
        JSON.stringify({ lines: [{ session_id: "s1", text: "diet tips" }] }),
      ),
  });
  assertEquals(
    (await handleAiRequest(
      v2({ kind: "reminder_batch", context: { sessions: [] } }),
      junk.d,
    )).status,
    502,
  );
  assertEquals(junk.balance(), 10);
});

Deno.test("reminder_batch: prompt rules in both languages", () => {
  const en = systemPrompt(2, "reminder_batch", "en");
  for (
    const s of [
      "never blaming",
      "never hurrying",
      "no promotion",
      "100 characters",
    ]
  ) {
    assertStringIncludes(en, s);
  }
  const vi = systemPrompt(2, "reminder_batch", "vi");
  for (
    const s of ["không trách móc", "không hối thúc", "không quảng cáo", "100"]
  ) {
    assertStringIncludes(vi, s);
  }
  assert(JSON_SCHEMAS.reminder_batch);
});
