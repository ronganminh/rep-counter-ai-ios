# AI Coach · PT ảo — design handoff

RepCoach AI v2 · 2026-11-25 · builds on Final C (tokens `DESIGN_SYSTEM_TOKENS.json`, components `COMPONENT_REGISTRY.md`, both unchanged).

Boards: `RepCoach-AI-v2-AI-Coach-PT.dc.html` (screens 1–4) and `RepCoach-AI-v2-AI-Coach-Body-Check-in.dc.html` (screen 5), canvas page **AI Coach · PT ảo**. Every frame is drawn in English — the **source and primary** language (left) — and Vietnamese — **secondary, machine-assisted, needs native review** (right, anchor `-vi`, badge "VI · NEEDS REVIEW") (D-41). Dark theme only (D-03). All numbers are SAMPLE DATA from the canonical user (Oct 20 workout, Thu Oct 22 morning).

## 1 · Scope and principles

1. Coach reads **summaries only**: reps, sets, pace/tempo flags, quality (form score), 2–4 weeks of history, the plan, the goal. Never video, photos (except the opt-in body check-in), keypoints, name or contacts.
2. The model answers in **structured JSON** (§4); the app renders known fields only. Invalid output = error state, no charge.
3. Every Coach action uses AI credits (D-29). Basic post-workout feedback on Results stays free (D-07); safety replies and failures are free.
4. Training never waits for Coach: every state keeps a startable plan session.
5. AI text sits next to recorded numbers and evidence dates; it is labelled with the Coach chip.
6. Locked screens are not changed. New entries are new cards/routes; H1 Home stays as the fallback (D-30).

## 2 · Frames and states

| Frame | Name | Route | Height | Notes |
|---|---|---|---|---|
| AC-01a | Home · Coach pick ready | `/home (tab 0)` | 1060 | **Route:** /home (tab 0) · replaces the H1 "Today · AI suggested" card while AI Coach is on (D-30) · **Data:** Coach JSON `daily_pick`: session, reason (1 sentence), evidence dates. SAMPLE = P4-04a "Full body B · adjusted" · **Credits:** Free once a day; "New suggestion" = 1 credit (D-29) · **Actions:** Start → plan session flow (P2-07a) · Edit → AC-01f · Skip → AC-01g · **A11y:** Card = region "Coach's pick for today"; reason is plain text, not colour; 56/48 px targets |
| AC-01b | Home · not enough data | `/home (tab 0)` | 852 | **State:** < 3 saved workouts (D-32). No AI call, no credit · **Action:** Camera workout → exercise flow |
| AC-01c | Home · generating | `/home (tab 0)` | 852 | **State:** Request in flight; plan session stays startable (training never waits) · **Motion:** Static skeleton + spinner ring; with Reduce Motion the ring does not rotate. `aria-live=polite` reads the status once |
| AC-01d | Home · new suggestion, no AI credits | `/home (tab 0)` | 1240 | **State:** Today's pick is free once a day (D-29). Tapping "New suggestion" with 0 credits sends no request; the current pick stays usable · **Paywall:** "See options" only on tap (P8-05a); never red (registry #29) |
| AC-01e | Home · offline | `/home (tab 0)` | 852 | **State:** Offline: no cached pick → plan session. A pick made earlier today stays visible offline (cache 1 day) · **Banner:** registry #12 warn tone |
| AC-01f | Edit today · sheet | `/home · sheet` | 852 | **Pattern:** Same options as P4-04b (locked) · bottom sheet registry #10 · **Credits:** Editing never calls AI |
| AC-01g | Home · pick skipped | `/home (tab 0)` | 852 | **State:** Skip hides the pick for today only; plan unchanged; Undo restores it (no new AI call) |
| AC-02a | Coach review · ready | `/workout/:id/coach-review` | 1330 | **Route:** /workout/:id/coach-review (root navigator, no tab bar) · entry from Results (FA-03a) "Coach review" · **Data:** Coach JSON `session_review`: strengths ≤3 · fixes 2–3 (icon + 1 line) · trend vs last time · next session. SAMPLE = Oct 20 canonical workout · **Credits:** 1 credit (D-29, confirmed). Basic feedback on Results stays free (D-07) · **A11y:** Trend rows carry "up/down/no comparison" as screen-reader text; arrows are not the only signal |
| AC-02b | Coach review · generating | `/workout/:id/coach-review` | 852 | **State:** Generating · workout already saved · skeleton (static) |
| AC-02c | Coach review · failed, retry | `/workout/:id/coach-review` | 852 | **State:** Timeout / provider error / invalid JSON → no charge (D-09, D-33). Retry reuses requestId |
| AC-02d | Apply to plan · Accept / Edit / Dismiss | `/workout/:id/coach-review · sheet` | 852 | **Flow:** Existing Accept / Edit / Dismiss from Phase 4: Edit opens P4-04b; Accept writes the plan session; Dismiss closes. Logged workouts never change (D-35) |
| AC-02e | Coach review · no AI credits | `/workout/:id/coach-review` | 852 | **State:** 0 credits: no request; disabled button stays readable (aria-disabled), "See options" on tap |
| AC-03a | AI Coach consent | `/coach/consent` | 1000 | **Rule:** Explain first, never forced (Final C §7 modal rules + P4-08a). "Not now" keeps training fully usable · **Copy:** Lists exactly what is sent: summaries only — no video, photos, keypoints · **Gate:** Account required for chat (D-11) → auth gate first if guest |
| AC-03b | Coach chat · quick questions | `/coach/chat` | 852 | **Route:** /coach/chat (root navigator) · **Chips:** 3 brief chips + 1 Phase 4 chip; each is a 44 px link that sends the question · **Credits:** Chip shows remaining (SAMPLE 6 of 10); 1 per message (D-29) |
| AC-03c | Coach chat · thinking | `/coach/chat` | 852 | **State:** Thinking: composer disabled, dots static under Reduce Motion, `aria-live` status |
| AC-03d | Coach chat · reply with workout card | `/coach/chat` | 940 | **Data:** Coach JSON `chat_reply` with optional `workout_card` → "Apply to today" writes today's session (same as AC-02d Accept) · **Evidence:** Every reply lists the saved workouts it used |
| AC-03e | Coach chat · pain safety reply | `/coach/chat` | 1010 | **Safety:** Pain intent → fixed safety template first (no diagnosis), then an optional no-load session. No credit · **Status:** DRAFT copy, pending legal/medical review (D-34). Does not block development; ship behind a remote string |
| AC-03f | Coach chat · no AI credits | `/coach/chat` | 852 | **State:** remaining = 0: chips and composer disabled with reason; reset date from entitlement (SAMPLE Sun, Oct 25) |
| AC-04a | Plan · Coach suggests next week | `/home/plan` | 1170 | **Route:** /home/plan (Home stack, tab bar visible). No separate Plan tab — 5 tabs stay (D-01, D-36) · **Data:** Coach JSON `week_plan`: 7 days, current vs suggested, reason per change, linked moves. SAMPLE = Phase 2 week template · **Credits:** 2 per generation (D-29) · **Actions:** Apply per day (44 px) · Apply all → AC-04c · Keep my plan dismisses for this week · **A11y:** Rendered as a table (row headers = days); changed rows use text + icon, not colour alone |
| AC-04b | Plan · one day applied | `/home/plan` | 1170 | **State:** One day applied → "Applied · Undo"; count in Apply all updates; toast registry #13 |
| AC-04c | Apply all · confirm | `/home/plan · sheet` | 852 | **Confirm:** Lists every change; reminders move with sessions (Phase 10 rule) |
| AC-04d | Plan · not enough history / offline | `/home/plan` | 852 | **State:** < 14 days of history (D-32) or offline: no request, plan unchanged |
| AC-05a | AI privacy · Body check-in off | `/profile/settings/ai-privacy` | 852 | **Route:** /profile/settings/ai-privacy (extends P4-08e). Body check-in is OFF by default and ships in a later release (D-37) |
| AC-05b | Body check-in · separate consent | `/coach/body-check-in/consent` | 960 | **Rule:** Separate consent; Agree and Not now are equal in size and colour (5.1.1 — store text not re-verified this session) · **Copy:** Provider named: Anthropic (Claude), not used for training; RepCoach keeps no photo; text result only; 3 credits (D-29, D-38) · **Age:** 18+ self-confirmation required; Agree stays aria-disabled until checked (shown checked). Profile age < 18, if known, hides the row (D-37) |
| AC-05c | Body check-in · how to take the photo | `/coach/body-check-in/guide` | 900 | **Guide:** Stand straight · light · clothes/shirtless OK · no nudity, only you · **Capture:** Take photo or Choose from library (D-37) → preview AC-05g |
| AC-05g | Body check-in · photo preview | `/coach/body-check-in/*` | 852 | **State:** Preview before anything is sent; Retake or Analyse. Moderation runs first on Analyse (D-40) |
| AC-05d | Body check-in · analysing | `/coach/body-check-in/analysing` | 852 | **State:** Upload + analysis; preview blurred; Cancel aborts and discards |
| AC-05e | Body check-in · result | `/coach/body-check-in/result` | 1010 | **Data:** Coach JSON `body_checkin`: overview, ≤3 focus groups, 4-week outline. Schema forbids measurements, weight, body-fat, diagnosis (D-39) · **Storage:** Text result on this phone; delete any time |
| AC-05f | Body check-in · photo not usable | `/coach/body-check-in/rejected` | 852 | **Trigger:** Moderation blocked the photo (genitals, sexual content, child, no body) or quality too low · **Tone:** Neutral, one generic message for every reason; photo discarded; no credit (D-40) |

### State machines (PROPOSED)

```
CoachPick:   noData ─(3 workouts)→ idle ─(first Home open, online; free)→ generating → ready ─skip→ skipped ─undo→ ready
             ready ─new suggestion (1 credit)→ generating · ready ─new suggestion, credits=0→ regenBlocked (pick stays) · generating → failed(no charge) · idle ─offline→ offline(plan fallback)
CoachReview: offer → generating → ready ─apply→ applySheet(accept|edit→P4-04b|dismiss) · generating → failed → (retry same requestId) · offer ─credits=0→ noCredits
CoachChat:   consentNeeded → empty → thinking → reply(+workoutCard) | safetyReply | failed(P4-06d) ; credits=0 → paused
CoachWeek:   noData(<14 days) | offline → ready → partiallyApplied → applied ; undo per day
BodyCheckIn: off → consent(18+ confirmed, agree|notNow) → guide → capture|library → preview → moderation → analysing → result | rejected(discarded, no charge) ; delete result → off
```

## 3 · Components used (from COMPONENT_REGISTRY, no new tokens)

| New composite | Built from registry | Notes |
|---|---|---|
| Coach pick card | #3 Card (accent border), #2 Button primary 56 + secondary 48, list rows | reason block uses `accentTintSoft`; Start is the only primary |
| Review blocks (strengths / fixes / trend / next) | #3 Card r16, #34 caption, icon tiles r8 | trend direction is text for screen readers, never colour only |
| Chat bubbles + workout card | #3, #2, #8 Text input, #7 chips (48 px) | composer disabled while thinking and at 0 credits; card buttons stacked full width |
| Credits chip | #29 | grey when 0, never red |
| Week table | #3, inline Apply buttons 48 px, #13 toast | `role=table`, day row headers |
| Apply sheets | #10 bottom sheet | Accept / Edit / Dismiss mirrors P4-04a/b |
| Status heroes / banners | #14, #12 | failure, offline, no credits, rejected photo |
| Equal consent buttons | #2 secondary variant `equal` (52 px, same fill) | body check-in only (5.1.1) |

## 4 · AI contract (PROPOSED)

```ts
// POST /v1/coach/{task}   Authorization · Idempotency-Key = requestId
// task: daily-pick | session-review | messages | week-plan | body-check-in
CoachContext {
  schema_version: 1, locale: "en" | "vi", today: "2026-10-22",
  goal: { id, title, target },                // e.g. 15 push-ups in one set
  plan: { id, week, sessions: [{ date, title, exercises[] }] },
  history_days: 14..28,
  history: [{ date, exercise_id, source: "camera"|"manual"|"timer",
              sets: [{ reps, target, hold_s?, fast_reps, tempo_flags[] }],
              form_score?, duration_s }],
  message?: string                            // chat only
}  // never video, photos, keypoints, name, contacts

DailyPick   { type:"daily_pick", session:{ title, est_min,
              exercises:[{ exercise_id, sets, reps?|hold_s?, rest_s,
              tracking:"camera"|"manual"|"timer" }] },
              reason (≤160 chars), evidence:[date] }
SessionReview { type:"session_review", strengths:[≤3 text],
              fixes:[2..3 { icon:"timer"|"gauge"|"depth"|"pace", text }],
              trend:[{ metric, direction:"up"|"down"|"same"|"none", text }],
              next_session:{ date, plan_session_id, changes:[...] } }
ChatReply   { type:"chat_reply", text, safety:"none"|"pain"|"medical",
              workout_card?: DailyPick.session, evidence:[date] }
WeekPlan    { type:"week_plan", week, days:[7 { date, current, suggested,
              changed, reason?, linked_to? }] }
BodyCheckIn { type:"body_checkin", overview, focus_groups:[≤3],
              plan_4w:[4 text] }   // numeric body fields rejected
Moderation  { allowed:boolean, reason?:"genitals"|"sexual"|"minor"|
              "no_person"|"quality" }   // runs before analysis; reason
              // is logged as a code only, never shown verbatim
Response envelope { requestId, charged, credits:{ remaining, allowance,
              resetsAt }, data | error }
```

Validation: exercise IDs must exist in the library; `tracking: camera` only for engine-supported exercises (D-28, push-up today); reps/sets are integers within plan limits; text fields length-capped; `body_checkin` rejects any numeric body field. Locale = app language; the model writes AI text in that language. Endpoints and credits: API_AND_BACKEND_GAP_ANALYSIS §9.

## 5 · Credits (D-29, CONFIRMED by owner 2026-11-25)

| Action | Credits |
|---|---|
| Basic feedback on Results | 0 (D-07) |
| Coach's pick on Home | 0 once a day · new suggestion 1 |
| Coach review | 1 |
| Chat message | 1 · safety reply 0 |
| Next-week suggestion | 2 |
| Body check-in | 3 · blocked photo 0 |
| Failed / invalid / cancelled | 0 |

Allowances stay as D-08 (Free 10 / Pro 60 per week, proposed). Reset date always comes from the entitlement response. Credit amounts are passed to strings as `{credits}` so they can change server-side.

## 6 · Accessibility and motion (render QA: AI_COACH_QA_REPORT.md)

- Same contrast rules as Final C; card body copy uses `text2`/`textMuted` (D-25).
- Touch targets ≥ 48 × 48 dp for every control (chips, inline Apply, Undo, banner links included).
- Generating/thinking: static skeleton, ring and dots; nothing animates under Reduce Motion; one `aria-live=polite` announcement.
- Icons always paired with text; trend arrows have screen-reader words (up / down / no comparison).
- Consent and safety copy are real text (no images); the body check-in guide silhouette is decorative.
- Dynamic Type: cards grow vertically; buttons wrap to two lines rather than truncate (VI is ~20–35 % longer).

## 7 · Decision log (owner review 2026-11-25)

| ID | Decision | Status |
|---|---|---|
| D-29 | AI credits: basic Results feedback free (D-07) · Coach review 1 · each chat message 1 · next-week suggestion 2 · Home "Coach's pick" free once a day, a new suggestion 1 · body check-in 3 · safety replies and failed/invalid requests 0. Allowances stay D-08. | CONFIRMED |
| D-30 | Coach's pick card replaces the H1 "Today · AI suggested" card only when AI Coach is on and consented; otherwise H1 is unchanged. | PROPOSED |
| D-31 | Daily pick is made on the first Home open of the day when online (free, D-29) and cached for that day; never generated in the background. A new suggestion needs 1 credit. | PROPOSED |
| D-32 | Minimum data: daily pick after 3 saved workouts; next-week suggestion after 14 days of history. | PROPOSED |
| D-33 | AI receives summaries only (reps, sets, pace, quality, 2–4 weeks history, plan, goal) and must return schema-valid JSON; anything else is an error with no charge. | PROPOSED |
| D-34 | Pain or injury messages get the fixed safety reply in AC-03e (no diagnosis, see a professional) plus an optional no-load session; no credit. Current wording is a DRAFT; development proceeds. | DRAFT · PENDING LEGAL/MEDICAL REVIEW |
| D-35 | "Apply to plan" reuses the Phase 4 Accept / Edit / Dismiss flow (P4-04a/b); logged workouts never change; Undo after apply. | CONFIRMED |
| D-36 | Next-week suggestion lives in Home › My plan (/home/plan). No new Plan tab — the five tabs stay (D-01). | CONFIRMED |
| D-37 | Body check-in: off by default, later release, separate consent with equal choices; 18+ for this feature only (self-confirmation on the consent screen; the app stays 13+); camera capture and photo library both allowed. | CONFIRMED |
| D-38 | Body check-in vision provider: Anthropic Claude API (API data not used for training). RepCoach does not store the photo. Before launch, legal confirms Anthropic retention terms for API inputs and the privacy-policy text. | CONFIRMED · retention terms to verify |
| D-39 | Body check-in result: overview, ≤3 focus groups, 4-week outline. No measurements, weight, body fat, diagnosis or appearance judgement. Text stored on device only. | PROPOSED |
| D-40 | Moderation before analysis: shirtless and sportswear allowed; blocked = exposed genitals, sexual content, children, no human body. Blocked photos are discarded, never analysed, never charged; neutral copy. Legal defines the handling/reporting process if child sexual abuse material is detected. | CONFIRMED · CSAM process to define |
| D-41 | Language: English is the source and primary frame; Vietnamese is the secondary translation, marked "needs review" like Final C. | CONFIRMED |

Brief references corrected: credits live in D-07/D-08 (D-12 = auth provider); "PL-1/PL-1c" does not exist — plan = Phase 2 (P2-04a, P2-05), Accept/Edit/Dismiss = P4-04a/b, consent rule = Final C nav §7 + P4-08a.

## 8 · Strings (EN / VI)

158 new keys were added to `l10n/app_en.arb` and `l10n/app_vi.arb` (prefix `pt`, placeholders declared). 31 existing keys are reused (tabs, Back, Cancel, exercise and session names, disclaimer). Rows marked **AI** are model output or sample data shown on the boards: they are not ARB keys, because the model answers in the app language. Rows marked **intl** are dates formatted with `intl`. Vietnamese is machine-assisted against the glossary and needs native review like the rest of the ARB.

| Key | Kind | EN | VI |
|---|---|---|---|
| `ptHomeDate` | intl | Thursday, Oct 22 | Thứ Năm, 22/10 |
| `ptHomeGreeting` | ARB | Good morning, {name} | Chào buổi sáng, {name} |
| `ptTodayCardCap` | ARB | Coach's pick · today | Coach đề xuất · hôm nay |
| `ptAiChip` | ARB | Coach | Coach |
| `ptTodayTitle` | AI | Full body B · adjusted | Full body B · đã điều chỉnh |
| `ptTodayMeta` | ARB | {exercises} exercises · {sets} sets · about {minutes} min | {exercises} bài · {sets} set · khoảng {minutes} phút |
| `ptTodayReason` | AI | On Tuesday you held 12 push-ups for two sets, so push-ups stay at 3 × 12 and lunges ease back in. | Thứ Ba bạn giữ được 12 rep hít đất ở hai set, nên giữ 3 × 12 và tập lại chùng chân nhẹ nhàng. |
| `pushUpName` | reused | Push-up | Hít đất |
| `commonHomeCameraCount` | reused | Camera count | Đếm bằng camera |
| `ptMinRest` | ARB | rest {s} s | nghỉ {s} giây |
| `commonHomeSquat` | reused | Squat | Squat |
| `commonHomeManualLog` | reused | Manual log | Ghi thủ công |
| `legacyExercisePickerLunge` | reused | Lunge | Chùng chân |
| `commonFaPlank` | reused | Plank | Plank |
| `commonHomeGuidedTimer` | reused | Guided timer | Hẹn giờ có hướng dẫn |
| `ptStart` | ARB | Start | Bắt đầu |
| `ptCreatedToday` | ARB | Made this morning from your last {weeks} weeks · free once a day | Tạo sáng nay từ {weeks} tuần gần nhất · miễn phí 1 lần/ngày |
| `ptRegenerate` | ARB | New suggestion · 1 AI credit | Đề xuất khác · 1 lượt AI |
| `ptEdit` | ARB | Edit | Chỉnh |
| `ptSkip` | ARB | Skip | Bỏ qua |
| `navHome` | reused | Home | Trang chủ |
| `navExercises` | reused | Exercises | Bài tập |
| `navTrain` | reused | Train | Tập |
| `navProgress` | reused | Progress | Tiến bộ |
| `navProfile` | reused | Profile | Hồ sơ |
| `ptNoDataTitle` | ARB | Coach needs a few workouts first | Coach cần thêm vài buổi tập |
| `ptNoDataBody` | ARB | After {needed} saved workouts, Coach suggests a session each day from your reps, sets and pace. | Sau {needed} buổi tập đã lưu, Coach sẽ đề xuất buổi tập mỗi ngày dựa trên rep, set và nhịp của bạn. |
| `ptNoDataProgress` | ARB | {done} of {needed} workouts saved | Đã lưu {done}/{needed} buổi tập |
| `ptNoDataCta` | ARB | Start a camera workout | Tập với camera |
| `ptQuickCamera` | ARB | Quick camera workout | Tập nhanh với camera |
| `ptExerciseLibrary` | ARB | Exercise library | Thư viện bài tập |
| `ptMyPlan` | ARB | My plan · week {week} | Kế hoạch · tuần {week} |
| `ptGenerating` | ARB | Coach is planning today… | Coach đang lên buổi tập hôm nay… |
| `ptGeneratingBody` | ARB | Reading your saved workouts. You can start your plan session now. | Đang đọc các buổi tập đã lưu. Bạn vẫn có thể tập theo kế hoạch ngay. |
| `ptStartPlanInstead` | ARB | Start plan session | Tập theo kế hoạch |
| `ptRegenNoCreditsTitle` | ARB | A new suggestion needs 1 AI credit | Đề xuất khác cần 1 lượt AI |
| `ptRegenNoCreditsBody` | ARB | Today's pick stays free. Credits reset {date}. | Đề xuất hôm nay vẫn miễn phí. Lượt AI làm mới vào {date}. |
| `ptSeeOptions` | ARB | See options | Xem lựa chọn |
| `ptOfflineTitle` | ARB | You're offline | Bạn đang ngoại tuyến |
| `ptOfflineBody` | ARB | Coach's pick needs a connection. Training works offline and saves on this phone. | Đề xuất của Coach cần kết nối mạng. Bạn vẫn tập được và buổi tập lưu trên máy. |
| `ptFromPlan` | ARB | From your plan · today | Theo kế hoạch · hôm nay |
| `ptPlanChip` | ARB | Plan | Kế hoạch |
| `commonNotifFullBodyB` | reused | Full body B | Full body B |
| `ptPlanMeta` | ARB | {exercises} exercises · {sets} sets · about {minutes} min | {exercises} bài · {sets} set · khoảng {minutes} phút |
| `ptEditTitle` | ARB | Edit today's session | Chỉnh buổi tập hôm nay |
| `ptEditOpt1` | ARB | Use the suggestion | Dùng đề xuất |
| `ptEditOpt1Sub` | AI | 8 sets · about 20 min · 1 set of lunges | 8 set · khoảng 20 phút · 1 set chùng chân |
| `ptEditOpt2` | ARB | Keep as planned | Giữ như kế hoạch |
| `ptEditOpt2Sub` | AI | Full body B · 9 sets · about 22 min | Full body B · 9 set · khoảng 22 phút |
| `ptEditOpt3` | AI | Make it shorter | Rút ngắn |
| `ptEditOpt3Sub` | AI | Push-ups and plank only · 5 sets · about 12 min | Chỉ hít đất và plank · 5 set · khoảng 12 phút |
| `ptEditOpt4` | AI | Swap lunges for glute bridges | Đổi chùng chân sang cầu mông |
| `ptEditOpt4Sub` | AI | Same sets · manual log | Giữ số set · tự ghi |
| `ptEditNoCharge` | ARB | Editing never uses AI credits. | Chỉnh sửa không dùng lượt AI. |
| `commonCancel` | reused | Cancel | Hủy |
| `commonSave` | reused | Save | Lưu |
| `ptSkippedTitle` | ARB | Skipped today's pick | Đã bỏ qua đề xuất hôm nay |
| `ptSkippedBody` | ARB | Your plan isn't changed. Coach suggests again tomorrow. | Kế hoạch không thay đổi. Ngày mai Coach sẽ đề xuất lại. |
| `commonUndo` | reused | Undo | Hoàn tác |
| `ptTrainAnyway` | ARB | Train anyway | Vẫn tập |
| `ptSkippedToast` | ARB | Skipped for today | Đã bỏ qua hôm nay |
| `ptReviewTitle` | ARB | Coach review | Nhận xét của Coach |
| `ptReviewBackResults` | ARB | Back to results | Về kết quả |
| `ptReviewWhen` | intl | Tue, Oct 20 · 17:40 | T3, 20/10 · 17:40 |
| `commonFaPushCoreBuilder` | reused | Push & core builder | Push & core builder |
| `coachRecorded` | reused | Recorded | Đã ghi nhận |
| `ptReviewRecorded` | AI | 55 reps · 1:15 held · form 82 | 55 rep · giữ 1:15 · tư thế 82 |
| `ptStrengths` | ARB | What went well | Điểm mạnh |
| `ptStrength1` | AI | All 7 sets done. | Hoàn thành đủ 7 set. |
| `ptStrength2` | AI | Fast push-up reps dropped to 1, from 4 on Oct 13. | Rep hít đất quá nhanh giảm còn 1, từ 4 rep hôm 13/10. |
| `ptFixes` | ARB | Fix next time | Cần sửa lần sau |
| `ptFix1` | AI | Plank set 2 stopped at 0:35. Hold the full 0:40. | Plank set 2 dừng ở 0:35. Cố giữ đủ 0:40. |
| `ptFix2` | AI | Push-up set 3 reached 11 of 12. Take the full 90 s rest first. | Set 3 hít đất đạt 11/12 rep. Nghỉ đủ 90 giây trước set này. |
| `ptTrend` | ARB | Compared with last time | So với lần trước |
| `ptTrend1` | AI | Camera push-ups 35 · best yet (was 34 on Oct 8) | Hít đất qua camera 35 · cao nhất (trước là 34 hôm 8/10) |
| `ptTrendUp` | ARB | up | tăng |
| `ptTrend2` | AI | Fast reps 1 · down from 4 (Oct 13) | Rep quá nhanh 1 · giảm từ 4 (13/10) |
| `ptTrendDown` | ARB | down | giảm |
| `ptTrend3` | AI | Plank 1:15 of 1:20 · no earlier plank to compare | Plank 1:15/1:20 · chưa có buổi trước để so |
| `ptTrendSame` | ARB | no comparison | chưa so sánh |
| `ptNextSession` | ARB | Next session | Buổi kế tiếp |
| `ptNextTitle` | AI | Thu, Oct 22 · Full body B | T5, 22/10 · Full body B |
| `ptNextBody` | AI | Keep push-ups at 3 × 12. Lunges 1 × 10 instead of 2 × 10. | Giữ hít đất 3 × 12. Chùng chân 1 × 10 thay vì 2 × 10. |
| `ptApplyToPlan` | ARB | Apply to plan | Áp dụng vào kế hoạch |
| `coachGeneralFitnessGuidanceNot` | reused | General fitness guidance, not medical advice. AI can be wrong. | Hướng dẫn tập luyện chung, không phải lời khuyên y khoa. AI có thể sai. |
| `ptUsedOneCredit` | ARB | 1 AI credit used | Đã dùng 1 lượt AI |
| `ptAskFollowUp` | ARB | Ask a follow-up | Hỏi thêm Coach |
| `ptReviewGenerating` | ARB | Coach is reviewing your workout… | Coach đang nhận xét buổi tập… |
| `ptReviewSaved` | ARB | Your workout is saved. This usually takes a few seconds. | Buổi tập đã được lưu. Thường chỉ mất vài giây. |
| `ptReviewErrorTitle` | ARB | Couldn't create the review | Chưa tạo được nhận xét |
| `ptReviewErrorBody` | ARB | Your workout is saved. No AI credit was used. | Buổi tập đã được lưu. Không dùng lượt AI nào. |
| `aiCoachChargedOnce` | reused | Retry uses the same request, so you’re charged once at most. | Thử lại dùng cùng yêu cầu, nên bạn chỉ bị tính tối đa một lần. |
| `commonRetry` | reused | Try again | Thử lại |
| `ptApplySheetTitle` | ARB | Apply to {weekday}? | Áp dụng cho {weekday}? |
| `ptApplySheetBody` | ARB | {session} on {date} changes like this: | {session} ngày {date} sẽ thay đổi như sau: |
| `ptDiffSame` | ARB | no change | giữ nguyên |
| `ptDiffLunge` | AI | 2 × 10 → 1 × 10 | 2 × 10 → 1 × 10 |
| `ptApplySheetNote` | ARB | Logged workouts are never changed. You can undo after applying. | Các buổi đã ghi không bị thay đổi. Bạn có thể hoàn tác sau khi áp dụng. |
| `ptAccept` | ARB | Accept | Đồng ý |
| `ptDismiss` | ARB | Dismiss | Bỏ qua |
| `ptReviewNoCreditsTitle` | ARB | Coach review needs 1 AI credit | Nhận xét của Coach cần 1 lượt AI |
| `ptReviewNoCreditsBody` | ARB | Basic feedback on the results screen stays free. Credits reset {date}. | Nhận xét cơ bản ở màn kết quả vẫn miễn phí. Lượt AI làm mới vào {date}. |
| `ptGetReview` | ARB | Get Coach review | Nhận xét chi tiết |
| `ptUsesOneCredit` | ARB | Uses 1 AI credit | Dùng 1 lượt AI |
| `navClose` | reused | Close | Đóng |
| `ptConsentTitle` | ARB | Turn on AI Coach? | Bật AI Coach? |
| `ptConsentBody` | ARB | To plan and review your training, the app sends workout summaries to the RepCoach server, which uses a third-party AI model provider. | Để lên kế hoạch và nhận xét buổi tập, ứng dụng gửi tóm tắt buổi tập đến máy chủ RepCoach, nơi dùng nhà cung cấp mô hình AI bên thứ ba. |
| `ptSent` | ARB | Sent | Được gửi |
| `ptSent1` | ARB | Reps, sets, pace and form score | Rep, set, nhịp và điểm tư thế |
| `ptSent2` | ARB | Last 2–4 weeks of workout summaries | Tóm tắt buổi tập 2–4 tuần gần nhất |
| `ptSent3` | ARB | Your plan and goal | Kế hoạch và mục tiêu của bạn |
| `ptNeverSent` | ARB | Never sent | Không bao giờ gửi |
| `ptNever1` | ARB | Video or photos | Video hoặc ảnh |
| `ptNever2` | ARB | Your face or body keypoints | Khuôn mặt hoặc điểm khung xương |
| `ptNever3` | ARB | Name or contacts | Tên hoặc danh bạ |
| `ptConsentCredits` | ARB | Coach answers, reviews and plans use AI credits. Basic feedback after a workout stays free. | Câu trả lời, nhận xét và kế hoạch của Coach dùng lượt AI. Nhận xét cơ bản sau buổi tập vẫn miễn phí. |
| `ptConsentOff` | ARB | You can turn this off in Profile at any time. Saying no never blocks training. | Bạn có thể tắt trong Hồ sơ bất cứ lúc nào. Từ chối không ảnh hưởng đến việc tập. |
| `ptTurnOn` | ARB | Turn on AI Coach | Bật AI Coach |
| `commonNotNow` | reused | Not now | Để sau |
| `ptChatTitle` | ARB | AI Coach | AI Coach |
| `navBack` | reused | Back | Quay lại |
| `ptCreditsLeft` | ARB | {n} of {max} left | Còn {n}/{max} |
| `ptChatSub` | ARB | Reads workout summaries · can't see your camera | Đọc tóm tắt buổi tập · không xem camera |
| `ptChatEmptyTitle` | ARB | Ask your coach | Hỏi Coach |
| `ptChatEmptyBody` | ARB | Answers come from your saved workouts, your plan and your goal. | Câu trả lời dựa trên các buổi tập đã lưu, kế hoạch và mục tiêu của bạn. |
| `ptChipToday` | ARB | What should I train today? | Hôm nay tập gì? |
| `ptChipPain` | ARB | My shoulder hurts | Tôi đau vai |
| `ptChipNextWeek` | ARB | How should I progress next week? | Tuần sau tăng thế nào? |
| `ptChipLast` | ARB | How was my last workout? | Buổi trước thế nào? |
| `commonSend` | reused | Send | Gửi |
| `ptComposer` | ARB | Ask about your training | Hỏi về việc tập luyện |
| `ptEachMessage` | ARB | Each message uses 1 AI credit | Mỗi tin nhắn dùng 1 lượt AI |
| `ptThinking` | ARB | Coach is thinking… | Coach đang suy nghĩ… |
| `ptThinkingSub` | ARB | Reading your saved workouts | Đang đọc các buổi tập đã lưu |
| `ptReplyToday` | AI | Full body B, adjusted. You're rested after Wednesday's recovery day, and Tuesday's push-ups were steady. | Full body B, đã điều chỉnh. Bạn đã có ngày phục hồi hôm thứ Tư và hít đất thứ Ba khá ổn định. |
| `ptWorkoutCardCap` | ARB | Suggested session | Buổi tập đề xuất |
| `ptApplyToday` | ARB | Apply to today | Áp dụng cho hôm nay |
| `ptFromWorkouts` | ARB | From your workouts | Từ các buổi tập của bạn |
| `ptEvidenceToday` | AI | Oct 13, 15, 20 · plan week 2 | 13, 15, 20/10 · tuần 2 kế hoạch |
| `coachGluteBridge` | reused | Glute bridge | Cầu mông |
| `ptReplyPain1` | ARB | I can't assess pain. If it's sharp, doesn't ease, or started with an injury, stop and see a doctor or physiotherapist. | Coach không thể đánh giá cơn đau. Nếu đau nhói, không đỡ hoặc bắt đầu sau chấn thương, hãy dừng tập và gặp bác sĩ hoặc chuyên viên vật lý trị liệu. |
| `ptReplyPain2` | ARB | If you still want to train today, here is a session without push-ups or planks. | Nếu bạn vẫn muốn tập hôm nay, đây là buổi tập không có hít đất hay plank. |
| `ptPainCardTitle` | AI | Lower body · no shoulder load | Thân dưới · không tải lên vai |
| `ptPainCardMeta` | ARB | {exercises} exercises · {sets} sets · about {minutes} min | {exercises} bài · {sets} set · khoảng {minutes} phút |
| `ptPainNoCharge` | ARB | Safety replies don’t use AI credits | Câu trả lời về an toàn không dùng lượt AI |
| `ptChatOutTitle` | ARB | You've used this week's AI credits | Bạn đã dùng hết lượt AI tuần này |
| `ptChatOutBody` | ARB | Workouts, counting, plans and basic feedback still work. Messages return when credits reset. | Tập luyện, đếm rep, kế hoạch và nhận xét cơ bản vẫn hoạt động. Tin nhắn mở lại khi làm mới lượt. |
| `ptDateSunOct25` | intl | Sun, Oct 25 | CN, 25/10 |
| `ptResetsOn` | ARB | Resets {date} | Làm mới {date} |
| `ptChatPaused` | ARB | Messages paused until reset | Tạm dừng tin nhắn đến khi làm mới |
| `ptPlanTitle` | ARB | My plan | Kế hoạch |
| `ptPlanName` | AI | Strength foundations · week 2 of 6 | Strength foundations · tuần 2/6 |
| `ptWeekCap` | ARB | Coach · next week | Coach · tuần sau |
| `ptWeekTitle` | ARB | Week {week} · {range} | Tuần {week} · {range} |
| `ptWeekSub` | AI | 3 changes suggested · 4 sessions stay the same | Đề xuất 3 thay đổi · 4 buổi giữ nguyên |
| `daySun25` | intl | Sun 25 | CN 25 |
| `ptApplyDay` | ARB | Apply {day} | Áp dụng {day} |
| `ptApply` | ARB | Apply | Áp dụng |
| `ptW1` | AI | Rest · moved to Sat | Nghỉ · dời sang T7 |
| `ptW1Why` | AI | Sunday's session was missed last week. | Buổi Chủ nhật tuần trước đã bị lỡ. |
| `commonPlansFullBody` | reused | Full body A | Full body A |
| `commonFaLowerBody` | reused | Lower body A | Lower body A |
| `ptNoChange` | ARB | No change | Giữ nguyên |
| `dayMon26` | intl | Mon 26 | T2 26 |
| `dayTue27` | intl | Tue 27 | T3 27 |
| `ptW3` | AI | Push-ups 3 × 13 | Hít đất 3 × 13 |
| `ptW3Why` | AI | +1 rep per set: two sets of 12 held on Oct 20. | +1 rep mỗi set: giữ được 2 set 12 rep hôm 20/10. |
| `commonNotifRecoveryDay` | reused | Recovery day | Ngày phục hồi |
| `dayWed28` | intl | Wed 28 | T4 28 |
| `dayThu29` | intl | Thu 29 | T5 29 |
| `ptW5` | AI | Lunges back to 2 × 10 | Chùng chân trở lại 2 × 10 |
| `ptW5Why` | AI | Thursday’s 1 × 10 is a step back in. | Buổi thứ Năm 1 × 10 là bước tập lại. |
| `plansRestDay` | reused | Rest day | Ngày nghỉ |
| `dayFri30` | intl | Fri 30 | T6 30 |
| `ptLinked` | ARB | Moves together with Sun | Đi kèm với CN |
| `ptW7` | AI | Full body A · moved from Sun | Full body A · dời từ CN |
| `plansFreeDay` | reused | Free day | Ngày trống |
| `daySat31` | intl | Sat 31 | T7 31 |
| `ptApplyAll` | ARB | Apply all ({n} changes) | Áp dụng tất cả ({n} thay đổi) |
| `ptKeepWeek` | ARB | Keep my plan | Giữ kế hoạch hiện tại |
| `ptWeekMade` | ARB | Made {date} · {credits} AI credits used | Tạo {date} · đã dùng {credits} lượt AI |
| `ptApplied` | ARB | Applied | Đã áp dụng |
| `ptAppliedToast` | ARB | {weekday} updated | Đã cập nhật {weekday} |
| `ptApplyAllTitle` | ARB | Apply {n} changes to week {week}? | Áp dụng {n} thay đổi cho tuần {week}? |
| `ptApplyAllNote` | ARB | Reminders move with their sessions. Logged workouts are never changed. | Nhắc nhở sẽ dời theo buổi tập. Các buổi đã ghi không bị thay đổi. |
| `ptWeekNoDataTitle` | ARB | Not enough history yet | Chưa đủ lịch sử tập |
| `ptWeekNoDataBody` | ARB | Coach suggests next week after 2 weeks of workouts. Your plan for week 3 is ready as it is. | Coach đề xuất tuần sau khi bạn có 2 tuần tập. Kế hoạch tuần 3 vẫn sẵn sàng như hiện tại. |
| `ptWeekNoDataProgress` | ARB | {days} of {needed} days tracked | Đã ghi nhận {days}/{needed} ngày |
| `ptBodyAiCoachRow` | ARB | AI Coach | AI Coach |
| `ptBodyAiCoachSub` | ARB | Workout summaries only | Chỉ tóm tắt buổi tập |
| `ptBodyRow` | ARB | Body check-in | Body check-in |
| `ptBodyRowSub` | ARB | Off · uses a photo · later release | Tắt · dùng ảnh · phát hành sau |
| `ptBodyBeta` | ARB | LATER | SẮP CÓ |
| `ptBodySettingsTitle` | ARB | AI privacy | Quyền riêng tư AI |
| `ptBodyRowNote` | ARB | Body check-in stays off until you turn it on and agree to its own consent. | Body check-in luôn tắt cho đến khi bạn bật và đồng ý với điều khoản riêng. |
| `ptBodyConsentTitle` | ARB | Body check-in uses a photo | Body check-in dùng ảnh của bạn |
| `ptBodyConsentLead` | ARB | Coach can suggest which muscle groups to focus on from one full-body photo. | Coach có thể gợi ý nhóm cơ nên ưu tiên từ một ảnh toàn thân. |
| `ptBodyC1` | ARB | Your photo is sent to our AI provider, Anthropic (Claude), only to be analysed. It isn’t used to train AI models. | Ảnh được gửi đến nhà cung cấp AI là Anthropic (Claude) chỉ để phân tích, không dùng để huấn luyện mô hình AI. |
| `ptBodyC2` | ARB | RepCoach doesn’t keep the photo on its servers. Only the text result is saved, on this phone. | RepCoach không lưu ảnh trên máy chủ. Chỉ lưu kết quả dạng chữ trên máy của bạn. |
| `ptBodyC3` | ARB | No measurements, weight, body fat or diagnosis. | Không đo số đo, cân nặng, tỷ lệ mỡ hay chẩn đoán. |
| `ptBodyC4` | ARB | You can delete the result at any time. | Bạn có thể xóa kết quả bất cứ lúc nào. |
| `ptBodyCost` | ARB | Each check-in uses {credits} AI credits. | Mỗi lần check-in dùng {credits} lượt AI. |
| `ptBodyAge` | ARB | I confirm I’m 18 or older | Tôi xác nhận mình từ 18 tuổi trở lên |
| `ptBodyAgeNote` | ARB | Body check-in is for adults only. The rest of RepCoach stays available. | Body check-in chỉ dành cho người từ 18 tuổi. Các tính năng khác của RepCoach vẫn dùng bình thường. |
| `ptAgree` | ARB | Agree | Đồng ý |
| `ptBodyGuideTitle` | ARB | Taking your photo | Cách chụp ảnh |
| `ptBodyG1` | ARB | Stand straight, whole body in frame | Đứng thẳng, toàn thân trong khung hình |
| `ptBodyG2` | ARB | Even, bright light · plain background | Đủ sáng, đều · nền đơn giản |
| `ptBodyG3` | ARB | Training clothes or shirtless are fine | Mặc đồ tập hoặc cởi trần đều được |
| `ptBodyG4` | ARB | Keep genitals covered · no sexual content · only you in frame | Che kín vùng kín · không nội dung khiêu dâm · chỉ có bạn trong ảnh |
| `ptBodyGuideNote` | ARB | Each photo is checked first. Nothing is analysed until you tap Analyse. | Mỗi ảnh được kiểm tra trước. Ảnh chỉ được phân tích khi bạn chạm Phân tích. |
| `ptTakePhoto` | ARB | Take photo | Chụp ảnh |
| `ptChooseLibrary` | ARB | Choose from library | Chọn từ thư viện |
| `ptBodyPreviewTitle` | ARB | Check your photo | Kiểm tra ảnh |
| `ptBodyPreviewNote` | ARB | Analysing uses {credits} AI credits. A photo that can’t be used is never charged. | Phân tích dùng {credits} lượt AI. Ảnh không dùng được sẽ không bị tính lượt. |
| `ptRetake` | ARB | Retake | Chụp lại |
| `ptAnalyse` | ARB | Analyse | Phân tích |
| `ptBodyAnalysing` | ARB | Analysing your photo… | Đang phân tích ảnh… |
| `ptBodyAnalysingSub` | ARB | Checked, then analysed once. RepCoach keeps only the text result. | Đã kiểm tra, sau đó phân tích một lần. RepCoach chỉ giữ kết quả dạng chữ. |
| `ptBodyResultTitle` | ARB | Your check-in | Kết quả check-in |
| `ptBodyOverview` | ARB | Overview | Tổng quan |
| `ptBodyOverviewText` | AI | Balanced build with an upright stance. Upper body and core are the best focus for your 15-push-up goal. | Vóc dáng cân đối, tư thế đứng thẳng. Thân trên và cơ core là trọng tâm phù hợp cho mục tiêu 15 rep hít đất. |
| `ptBodyFocus` | ARB | Focus muscle groups | Nhóm cơ ưu tiên |
| `ptBodyF1` | AI | Chest & triceps | Ngực & tay sau |
| `ptBodyF2` | AI | Core | Core |
| `ptBodyF3` | AI | Glutes | Mông |
| `ptBody4w` | ARB | Suggested 4 weeks | Gợi ý 4 tuần |
| `ptBodyWk1` | AI | Week 1 · push-ups 3 × 12 · plank 2 × 0:40 | Tuần 1 · hít đất 3 × 12 · plank 2 × 0:40 |
| `ptBodyWk2` | AI | Week 2 · push-ups 3 × 13 · glute bridge 2 × 12 | Tuần 2 · hít đất 3 × 13 · cầu mông 2 × 12 |
| `ptBodyWk3` | AI | Week 3 · push-ups 3 × 14 · plank 2 × 0:45 | Tuần 3 · hít đất 3 × 14 · plank 2 × 0:45 |
| `ptBodyWk4` | AI | Week 4 · try 15 in one set · lighter volume | Tuần 4 · thử 15 rep trong một set · giảm khối lượng |
| `ptBodyNoMeasure` | ARB | No measurements or diagnosis. Not medical advice. | Không đo số đo, không chẩn đoán. Không phải lời khuyên y khoa. |
| `ptBodyStored` | ARB | Photo not kept · text result saved on this phone | Không giữ ảnh · kết quả dạng chữ lưu trên máy |
| `ptDeleteResult` | ARB | Delete result | Xóa kết quả |
| `ptBodyRejectTitle` | ARB | We couldn't use this photo | Chưa dùng được ảnh này |
| `ptBodyRejectBody` | ARB | That happens. A photo works best with your whole body in frame, even light, and only you in the picture. | Chuyện này bình thường. Ảnh tốt nhất khi thấy toàn thân, đủ sáng và chỉ có bạn trong ảnh. |
| `ptBodyRejectPolicy` | ARB | Every photo is checked before analysis. Photos showing genitals, sexual content, children, or no person can’t be analysed. | Mọi ảnh đều được kiểm tra trước khi phân tích. Ảnh lộ vùng kín, có nội dung khiêu dâm, có trẻ em hoặc không có người sẽ không được phân tích. |
| `ptBodyRejectNote` | ARB | The photo was discarded. No AI credit was used. | Ảnh đã bị hủy. Không dùng lượt AI nào. |

## 9 · Not in this delivery

- No production code. No change to tokens, registry or locked screens.
- Body check-in is designed for a later release. Confirmed: Anthropic Claude as vision provider, 18+ for the feature, camera + library, moderation before analysis, 3 credits. Still to verify before launch: provider retention terms in the privacy policy (D-38) and the legal process if child sexual abuse material is detected (D-40).
- Pain safety reply (AC-03e) ships as a DRAFT string pending legal/medical review (D-34); development is not blocked.
- Store-policy text (5.1.1) was not re-fetched in this session; the equal-choice consent follows the Final C rule set.

