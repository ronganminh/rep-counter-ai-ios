// v2 coach context (L-D43): the user's last 2-4 weeks of synced workouts as
// a numbers-only summary (ai_coach_history in 20261125000100_ai_coach_v2.sql
// returns the rows). No names typed by the user, no frames, landmarks,
// photos or video: those never leave the phone.

export interface HistoryRow {
  started_at: string;
  exercise: string;
  reps: number;
  sets?: number;
  target_reps?: number;
  duration_seconds: number;
  manual?: boolean;
  partial?: boolean;
  quality_score?: number;
  avg_rep_sec?: number;
  cadence_consistency?: number;
  range_of_motion?: number;
  flagged_reps?: number;
}

export interface ExerciseSummary {
  sessions: number;
  total_reps: number;
  best_reps: number;
  avg_quality: number | null;
  avg_rep_sec: number | null;
  partial: number;
  manual: number;
}

export interface HistorySummary {
  days: number;
  workouts: number;
  training_days: number;
  rest_days: number;
  longest_break_days: number;
  weeks: { week_start: string; workouts: number; reps: number }[];
  by_exercise: Record<string, ExerciseSummary>;
  recent: HistoryRow[];
}

const DAY = 86_400_000;
const round1 = (n: number) => Math.round(n * 10) / 10;
const ymd = (d: Date) => d.toISOString().slice(0, 10);

function mondayOf(d: Date): string {
  const day = new Date(
    Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()),
  );
  const dow = (day.getUTCDay() + 6) % 7; // Monday = 0
  return ymd(new Date(day.getTime() - dow * DAY));
}

const avg = (xs: number[]) =>
  xs.length === 0 ? null : round1(xs.reduce((a, b) => a + b, 0) / xs.length);

/**
 * Summarises rows of the last [days] days before [now] (UTC days). Rows
 * outside the window or without a valid date are ignored.
 */
export function summarizeHistory(
  rows: HistoryRow[],
  now: Date,
  days = 28,
): HistorySummary {
  const from = now.getTime() - days * DAY;
  const live = rows
    .filter((r) => {
      const t = Date.parse(r.started_at);
      return Number.isFinite(t) && t >= from && t <= now.getTime() &&
        typeof r.exercise === "string" && Number.isFinite(r.reps);
    })
    .sort((a, b) => Date.parse(a.started_at) - Date.parse(b.started_at));

  const trainingDays = new Set(live.map((r) => r.started_at.slice(0, 10)));
  // Longest run of days without training, from the window start to today.
  let longest = 0, run = 0;
  for (let i = days - 1; i >= 0; i--) {
    const d = ymd(new Date(now.getTime() - i * DAY));
    run = trainingDays.has(d) ? 0 : run + 1;
    longest = Math.max(longest, run);
  }

  const weeks = new Map<string, { workouts: number; reps: number }>();
  const by = new Map<string, HistoryRow[]>();
  for (const r of live) {
    const w = mondayOf(new Date(r.started_at));
    const e = weeks.get(w) ?? { workouts: 0, reps: 0 };
    e.workouts++;
    e.reps += r.reps;
    weeks.set(w, e);
    by.set(r.exercise, [...(by.get(r.exercise) ?? []), r]);
  }

  const byExercise: Record<string, ExerciseSummary> = {};
  for (const [id, rs] of by) {
    byExercise[id] = {
      sessions: rs.length,
      total_reps: rs.reduce((a, r) => a + r.reps, 0),
      best_reps: Math.max(...rs.map((r) => r.reps)),
      avg_quality: avg(rs.flatMap((r) => r.quality_score ?? [])),
      avg_rep_sec: avg(rs.flatMap((r) => r.avg_rep_sec ?? [])),
      partial: rs.filter((r) => r.partial).length,
      manual: rs.filter((r) => r.manual).length,
    };
  }

  return {
    days,
    workouts: live.length,
    training_days: trainingDays.size,
    rest_days: days - trainingDays.size,
    longest_break_days: longest,
    weeks: [...weeks].map(([week_start, v]) => ({ week_start, ...v })),
    by_exercise: byExercise,
    // The last 10 workouts in detail (numbers only).
    recent: live.slice(-10),
  };
}
