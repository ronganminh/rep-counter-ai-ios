# 10 · AI Coach · PT ảo — app UI (screens 1–4)

Design: `docs/design/v2-final-c/aicoach/AI_COACH_PT_HANDOFF.md` (handoff 2026-11-25, D-29…D-41), evidence PNGs for AC-01…AC-04 next to it. Decision: L-D45. Backend: `ai-request` v2 from AI-1 (L-D43), GroqCloud on staging.

## Scope

| Screen | Frames | Where in the app | PR |
|---|---|---|---|
| Strings, flag, D-29 costs, shared widgets, consent (AC-03a), AI privacy rows (AC-05a: Body check-in shown OFF, not tappable) | — | `lib/features/coach/` · Settings › AI privacy | 1 |
| Coach's pick on Home | AC-01a–g | `CoachTodayCard` above the plan card on Home | 2 |
| Coach review after a workout | AC-02a–e | `CoachReviewPage` from Results (and from a saved workout) | 2 |
| Coach chat | AC-03b–f | `CoachChatPage` (Profile › AI Coach while the flag is on) | 3 |
| Next week in My plan | AC-04a–d | `CoachWeekCard` in `PlanOverviewPage` | 3 |
| Body check-in | AC-05b–g | **not built** (later release, D-37) | — |

Everything is behind `ENABLE_AI_COACH_V2` (off by default; `true` in `dart_defines.staging.example.json`) and needs AI credits (accounts + backend). With the flag off nothing in this folder is shown, and Home, Results, Plan, Profile and Settings are unchanged.

## Credits (D-29)

| Action | Shown | Charged by the server today |
|---|---|---|
| Coach's pick, once a day | free | nothing (no AI request: see stubs) |
| New suggestion | 1 | 1 (`plan_suggestion`) |
| Coach review | 1 | 1 (`workout_review`) |
| Chat message | 1 | 1 (`coach_chat`) |
| Pain safety reply | 0 | nothing (answered on the phone, no request) |
| Next-week suggestion | 2 | **1** (`plan_suggestion`; the ledger charges one credit per request) |

Amounts come from `CoachCost` and go into strings as `{credits}`.

## Client stubs (backend gaps — no endpoint was invented)

The handoff's `/v1/coach/{task}` contract (§4) is PROPOSED; the app uses the existing `ai-request` kinds only.

1. **Daily pick (AC-01a) — no free AI kind.** Every `ai-request` call is charged one credit, so the free once-a-day pick is built **on the phone** from the plan's next session and the saved workouts (no AI request, no credit, no reason sentence). "New suggestion" is a real AI request (`plan_suggestion`, horizon `tomorrow`, 1 credit) whose summary becomes the reason. Server gap: a `daily_pick` kind at cost 0, once per user per day.
2. **Review fields (AC-02a).** `workout_review` returns `summary`, `fixes[]`, `next_session[]`. "What went well" shows the summary; fix icons are generic; "Compared with last time" is computed on the phone from saved workouts (recorded numbers, not AI). Server gap: `strengths[]`, `fixes[].icon`, `trend[]`.
3. **Chat workout card and evidence (AC-03d).** `coach_chat` returns `reply` + `memory` only: no `workout_card`, no `evidence` dates, no `safety` flag. The card and the evidence line are not shown for AI replies. Server gap: `workout_card`, `evidence[]`, `safety`.
4. **Pain safety reply (AC-03e, D-34 DRAFT).** Pain words (EN/VI list on the phone) get the fixed template and a no-load session built on the phone, with **no request and no credit**. The server's PT prompt still refuses diagnosis for anything the list misses (L-D43).
5. **Week plan (AC-04a).** `plan_suggestion` (horizon `next_week`) proposes exercise targets per day offset; moving sessions or rest days is not in the schema. The card lists the plan's sessions next week with the targets the coach changed; applying a day writes that session's targets only. Server gap: `week_plan` with per-day current/suggested/moves and cost 2.
6. **Reset date.** The credits response has `week_start` (Monday UTC); "resets {date}" is the next Monday from it.

## Rules kept

- D-35: apply goes through Accept / Edit / Dismiss; Accept writes **only scheduled sessions** (`PlanRepository.editTargets`), logged workouts never change; Undo restores the previous targets.
- D-31: the pick is made on the first Home open of the day, cached for that day, never in the background.
- D-32: pick after 3 saved workouts; next week after 14 days of history.
- Training never waits: every coach state keeps "Start plan session" / the Train button.
- Targets ≥ 48 dp; captions `text2`; busy rings hold still under Reduce Motion; trend direction has words for screen readers.
- Strings: the 158 `pt*` keys of the handoff, EN source, VI machine-assisted (needs native review, D-41).
