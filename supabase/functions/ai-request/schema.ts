// v2 structured answers (L-D43): JSON shapes per kind, a strict validator,
// and a text fallback when a provider returns something else.
//
// The validator keeps only what the app can apply: exercise targets follow
// the plan model's own limits (ExerciseTarget: 1-10 sets, 1-100 reps or
// 5-3600 seconds, exactly one of reps / seconds), invalid items are dropped,
// strings are trimmed and capped. The app re-checks targets before anything
// reaches a plan (suggestion review: Accept / Edit / Dismiss).
import type { Kind } from "./handler.ts";

export type Change = "increase" | "maintain" | "decrease";

export interface TargetSuggestion {
  exercise_id: string;
  sets: number;
  reps: number | null;
  seconds: number | null;
  rest_seconds: number;
  change: Change;
  note: string;
}

export interface WorkoutReview {
  summary: string;
  fixes: string[];
  next_session: TargetSuggestion[];
}

export interface PlanSuggestion {
  summary: string;
  horizon: "tomorrow" | "next_week";
  sessions: {
    day_offset: number;
    focus: string;
    exercises: TargetSuggestion[];
  }[];
}

export interface ProgressReview {
  summary: string;
  highlights: string[];
  focus_next_week: string;
}

export interface ChatAnswer {
  reply: string;
  memory: string;
}

export type StructuredAnswer =
  | WorkoutReview
  | PlanSuggestion
  | ProgressReview
  | ChatAnswer;

export const CAPS = {
  text: 1_200,
  item: 300,
  note: 200,
  memory: 600,
  fixes: 3,
  highlights: 3,
  exercises: 8,
  sessions: 7,
} as const;

// JSON Schema for providers that enforce it (Anthropic output_config.format):
// every object closed, every property required (nullable where optional).
const target = {
  type: "object",
  additionalProperties: false,
  required: [
    "exercise_id",
    "sets",
    "reps",
    "seconds",
    "rest_seconds",
    "change",
    "note",
  ],
  properties: {
    exercise_id: { type: "string" },
    sets: { type: "integer" },
    reps: { anyOf: [{ type: "integer" }, { type: "null" }] },
    seconds: { anyOf: [{ type: "integer" }, { type: "null" }] },
    rest_seconds: { type: "integer" },
    change: { type: "string", enum: ["increase", "maintain", "decrease"] },
    note: { type: "string" },
  },
} as const;

const strings = { type: "array", items: { type: "string" } } as const;

export const JSON_SCHEMAS: Partial<Record<Kind, Record<string, unknown>>> = {
  workout_review: {
    type: "object",
    additionalProperties: false,
    required: ["summary", "fixes", "next_session"],
    properties: {
      summary: { type: "string" },
      fixes: strings,
      next_session: { type: "array", items: target },
    },
  },
  plan_suggestion: {
    type: "object",
    additionalProperties: false,
    required: ["summary", "horizon", "sessions"],
    properties: {
      summary: { type: "string" },
      horizon: { type: "string", enum: ["tomorrow", "next_week"] },
      sessions: {
        type: "array",
        items: {
          type: "object",
          additionalProperties: false,
          required: ["day_offset", "focus", "exercises"],
          properties: {
            day_offset: { type: "integer" },
            focus: { type: "string" },
            exercises: { type: "array", items: target },
          },
        },
      },
    },
  },
  progress_review: {
    type: "object",
    additionalProperties: false,
    required: ["summary", "highlights", "focus_next_week"],
    properties: {
      summary: { type: "string" },
      highlights: strings,
      focus_next_week: { type: "string" },
    },
  },
  coach_chat: {
    type: "object",
    additionalProperties: false,
    required: ["reply", "memory"],
    properties: { reply: { type: "string" }, memory: { type: "string" } },
  },
};

const TARGET_SHAPE =
  '{"exercise_id": string, "sets": 1-10, "reps": 1-100 or null, ' +
  '"seconds": 5-3600 or null (exactly one of reps / seconds), ' +
  '"rest_seconds": 0-600, "change": "increase"|"maintain"|"decrease", ' +
  '"note": string}';

/** The shape spelled out in the system prompt (for providers without schemas). */
export function outputShape(kind: Kind): string {
  switch (kind) {
    case "workout_review":
      return `{"summary": string, "fixes": [2-3 strings], "next_session": [${TARGET_SHAPE}]}`;
    case "plan_suggestion":
      return `{"summary": string, "horizon": "tomorrow"|"next_week", ` +
        `"sessions": [{"day_offset": 1-7, "focus": string, "exercises": [${TARGET_SHAPE}]}]}`;
    case "progress_review":
      return `{"summary": string, "highlights": [2-3 strings], "focus_next_week": string}`;
    default:
      return `{"reply": string, "memory": string}`;
  }
}

const isObj = (v: unknown): v is Record<string, unknown> =>
  !!v && typeof v === "object" && !Array.isArray(v);

const str = (v: unknown, cap: number): string | null => {
  if (typeof v !== "string") return null;
  const t = v.trim();
  return t.length === 0 ? null : t.slice(0, cap);
};

const int = (v: unknown, min: number, max: number): number | null =>
  typeof v === "number" && Number.isInteger(v) && v >= min && v <= max
    ? v
    : null;

const strList = (v: unknown, cap: number, max: number): string[] =>
  Array.isArray(v)
    ? v.map((s) => str(s, cap)).filter((s): s is string => s !== null).slice(
      0,
      max,
    )
    : [];

export function validTarget(v: unknown): TargetSuggestion | null {
  if (!isObj(v)) return null;
  const id = v["exercise_id"];
  if (typeof id !== "string" || !/^[a-z0-9_]{1,40}$/.test(id)) return null;
  const sets = int(v["sets"], 1, 10);
  const reps = v["reps"] == null ? null : int(v["reps"], 1, 100);
  const seconds = v["seconds"] == null ? null : int(v["seconds"], 5, 3600);
  if (sets === null) return null;
  if (
    (v["reps"] != null && reps === null) ||
    (v["seconds"] != null && seconds === null)
  ) {
    return null;
  }
  if ((reps === null) === (seconds === null)) return null; // exactly one
  const rest = int(v["rest_seconds"] ?? 60, 0, 600);
  const change = v["change"];
  if (rest === null) return null;
  if (change !== "increase" && change !== "maintain" && change !== "decrease") {
    return null;
  }
  return {
    exercise_id: id,
    sets,
    reps,
    seconds,
    rest_seconds: rest,
    change,
    note: str(v["note"], CAPS.note) ?? "",
  };
}

const targets = (v: unknown): TargetSuggestion[] =>
  Array.isArray(v)
    ? v.map(validTarget).filter((t): t is TargetSuggestion => t !== null)
      .slice(0, CAPS.exercises)
    : [];

/** Validates a parsed answer for a kind; null when it cannot be used. */
export function validateAnswer(
  kind: Kind,
  v: unknown,
): StructuredAnswer | null {
  if (!isObj(v)) return null;
  switch (kind) {
    case "workout_review": {
      const summary = str(v["summary"], CAPS.text);
      const fixes = strList(v["fixes"], CAPS.item, CAPS.fixes);
      if (!summary || fixes.length === 0) return null;
      return { summary, fixes, next_session: targets(v["next_session"]) };
    }
    case "plan_suggestion": {
      const summary = str(v["summary"], CAPS.text);
      const horizon = v["horizon"];
      if (!summary || (horizon !== "tomorrow" && horizon !== "next_week")) {
        return null;
      }
      const sessions = Array.isArray(v["sessions"])
        ? v["sessions"].flatMap((s) => {
          if (!isObj(s)) return [];
          const day = int(s["day_offset"], 1, 7);
          const exercises = targets(s["exercises"]);
          if (day === null || exercises.length === 0) return [];
          return [{
            day_offset: day,
            focus: str(s["focus"], CAPS.item) ?? "",
            exercises,
          }];
        }).slice(0, CAPS.sessions)
        : [];
      return { summary, horizon, sessions };
    }
    case "progress_review": {
      const summary = str(v["summary"], CAPS.text);
      if (!summary) return null;
      return {
        summary,
        highlights: strList(v["highlights"], CAPS.item, CAPS.highlights),
        focus_next_week: str(v["focus_next_week"], CAPS.item) ?? "",
      };
    }
    case "coach_chat": {
      const reply = str(v["reply"], CAPS.text * 2);
      if (!reply) return null;
      return { reply, memory: str(v["memory"], CAPS.memory) ?? "" };
    }
    default:
      return null;
  }
}

/** Parses provider text as JSON, tolerating a ```json fence around it. */
export function parseJsonText(raw: string): unknown {
  const t = raw.trim().replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/, "");
  try {
    return JSON.parse(t);
  } catch {
    return undefined;
  }
}

/** Plain text the app can show for any answer (the v1 `text` field). */
export function answerText(kind: Kind, a: StructuredAnswer): string {
  if (kind === "coach_chat") return (a as ChatAnswer).reply;
  const lines: string[] = [];
  if ("summary" in a) lines.push(a.summary);
  if ("fixes" in a) lines.push(...a.fixes.map((f) => `• ${f}`));
  if ("highlights" in a) lines.push(...a.highlights.map((h) => `• ${h}`));
  if ("focus_next_week" in a && a.focus_next_week) {
    lines.push(a.focus_next_week);
  }
  return lines.join("\n");
}

/**
 * Text fallback when the answer is not valid JSON for the kind: the first
 * readable string field of a JSON object, else the raw text when it is not
 * JSON at all. Null means nothing usable (the request is refunded).
 */
export function fallbackText(raw: string): string | null {
  const parsed = parseJsonText(raw);
  if (parsed === undefined) {
    const t = raw.trim();
    return t.length > 0 && !t.startsWith("{") && !t.startsWith("[") ? t : null;
  }
  if (isObj(parsed)) {
    for (const k of ["reply", "summary", "text", "answer"]) {
      const s = str(parsed[k], CAPS.text * 2);
      if (s) return s;
    }
  }
  return null;
}
