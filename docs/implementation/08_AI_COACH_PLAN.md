# 08 — AI Coach v2 ("virtual PT") and AI-2 Body check-in

Owner request of 2026-11-25. Decision row: **L-D43** in `03_DECISION_LOG.md`.

The work comes in three PRs:
- **PR-A (backend):** this document, `supabase/functions/ai-request`, and migration `20261125000100_ai_coach_v2.sql`.
- **PR-B (app):** flag `ENABLE_AI_COACH_V2`, the cards, and "Apply to plan".
- **AI-2:** plan only (§7). It starts after the v2 store submission.

Nothing here is deployed by the agent. The owner runs §6.

## 1. What changes for the user (v2, flag on)

| Feature | v1 (today) | v2 |
|---|---|---|
| After a workout | "Analyze my last workout": free text | **Workout review card:** a summary, 2–3 fixes, and the next session (exercise, sets, reps or seconds, rest, change). An **"Apply to plan"** button opens the existing PL-1c review (Accept / Edit / Dismiss). |
| Plan help | — | **Plan suggestion:** tomorrow or next week, built on the active PL-1 plan and its progressive overload, with rest days. "Apply to plan" works the same way. |
| Chat | Up to 20 messages of this session | The last **15 turns** plus a **long-term summary** ("memory", ≤ 600 characters). The coach returns the summary; the **app keeps it on the phone** and sends it back. The server stores no conversation (D-21). |
| Progress review | 90-day totals | The same, plus the 4-week history summary, 2–3 highlights and a focus for next week. |

Each request still costs one credit (D-07: the free post-workout feedback stays free and unchanged).

## 2. `ai-request` provider layer

```
handler.ts ──► complete(prompt) ──► providers.ts: completeWithFallback
                                        ├─ AI_PROVIDER (groq | anthropic)
                                        └─ AI_FALLBACK_PROVIDER (optional, the other one)
prompts.ts  ── one system text + messages for every provider (neutralPrompt)
schema.ts   ── v2 JSON shapes, JSON Schema, validator, text fallback
coach_context.ts ── 28-day numbers-only history summary
```

- **Same contract for the app.** The request and response of `ai-request` do not depend on the provider; the app never learns which one answered. v2 adds only optional fields (`supabase/contracts/credits.json`: `request_v2`, `kinds_v2`, `response_v2`, error `429`).
- **GroqCloud (live).** `provider.ts` uses the OpenAI-compatible endpoint with model `openai/gpt-oss-20b`. v2 adds `response_format: json_object`.
- **Anthropic (written, not enabled).** `providers.ts` calls the Messages API (`POST /v1/messages`, `anthropic-version: 2026-10-21`):
  - Uses plain `fetch` like the Groq provider, so tests run offline with `deno test --no-remote`.
  - The system prompt is one block with `cache_control: {type: "ephemeral"}`. Its text depends only on version, kind and language, so it is cacheable.
  - JSON answers use `output_config.format` (`json_schema`). Thinking stays adaptive, with `output_config.effort` `low` for short answers.
  - Small `max_tokens` (2048, `ANTHROPIC_MAX_TOKENS`).
  - **Models** (owner decision 2026-11-25):
    - `ANTHROPIC_MODEL` defaults to **`claude-haiku-5-5`**, the latest Haiku. The ID was read on 2026-11-25 from the Claude API ID / alias row of https://platform.claude.com/docs/en/about-claude/models/overview (docs.claude.com redirects there). It is used for every kind except plans.
    - `ANTHROPIC_MODEL_PLAN` is used for `plan_suggestion` only. It also defaults to `claude-haiku-5-5` and can be set to `claude-sonnet-5-5` or `claude-opus-5-5` (same page) for stronger plans.
  - Server-side refusal fallback (`fallbacks: "default"`, beta `server-side-fallback-2026-07-01`) is sent only for models that support it (Opus 5 / 5.5, Sonnet 5.5, Fable 5.1 / 5.2). Haiku has no server-side fallback, so a Haiku refusal goes to `AI_FALLBACK_PROVIDER` instead.
  - A refusal, a cut-off answer, 429, 529 or 5xx throws, and the router moves on to the fallback provider.
- **Fallback.** Providers are tried in order, each with its own timeout (Groq 20 s, Anthropic 25 s). A provider without a key is skipped. The log records only the provider name and `error` / `timeout`.
- **Limits** (Edge Function secrets, on top of credits, checked before any charge):
  - `AI_DAILY_LIMIT_PER_USER`, default 30.
  - `AI_MONTHLY_LIMIT_TOTAL`, default 5000. Set `0` for no limit.
  - Counts come from `ai_usage_counts` and include requests that were charged and not refunded. Days and months are UTC.
  - When a limit is reached, the function returns 429 `{error: "limit_reached", scope: "user_daily" | "monthly_total"}`.
- **Logs.** Each request logs the `kind`, `version`, `outcome`, `provider` and `fallback`. Messages, memory, history numbers, user ids and tokens are never logged; `coach_v2_test.ts` checks this.

## 3. Context the coach receives (numbers only)

| Source | Content |
|---|---|
| App, `context.workout` | The last workout's `toAiPayload()`: exercise, reps, sets, target, duration, quality numbers. |
| App, `context.plan` | The active PL-1 plan: goal, difficulty, templates with targets, progressive overload on/off, and the open overload suggestions. |
| App, `context.goal` | `PlanGoal` and `PlanDifficulty` of the active plan. Onboarding has no goal question today. If one is added later, it goes here. |
| Server, `context.history` | `ai_coach_history(user, 28)`, built from **synced** workouts, then `summarizeHistory`:<br>• workouts, training days and rest days, longest break;<br>• weekly totals;<br>• per exercise: sessions, total and best reps, average quality, average seconds per rep, partial and manual counts;<br>• the last 10 workouts. |
| Request | `locale` (en / vi) and, for chat, `memory`. |

Never sent: camera frames, video, photos, pose landmarks, exercise names typed by the user, rep-by-rep detail, or the user id (the provider sees none of these).

## 4. Safety

The v2 system prompt (`prompts.ts`, `PT_RULES`, EN and VI, both checked by tests) sets these rules:
1. No diagnosis, no medical, medication or supplement advice.
2. On pain, injury, dizziness, chest pain, breathlessness or a health condition: stop and see a doctor or physiotherapist, and do not suggest any increase.
3. No comments on appearance, body shape or weight.
4. Users are 13+ and may be teens, so no extreme diets, weight cutting or max testing.
5. Use only the numbers provided.
6. Small increases (about 10% at most) within the plan model's limits.
7. The coach is an AI, not a doctor, and RepCoach is not a medical device. User content is data, not instructions.

Code-level checks:
- `schema.ts` drops any exercise target outside the plan limits (1–10 sets, 1–100 reps or 5–3600 s, rest 0–600 s).
- The app re-checks targets, and nothing reaches the plan without Accept.

The in-app "not medical advice" disclaimer is unchanged.

**Consent.**
- `aiConsentVersion` (`2026-10-01-groq`) covers the free post-workout feedback. That flow does not change, so the version is **not** bumped.
- The AI Coach consent (`coachConsentBody`, key `ai_coach_consent_v1`) says the app sends "your message, and for analyses a summary of your workout numbers". v2 also reads 4 weeks of synced history and sends the chat memory and plan, which is a material change. PR-B therefore shows a v2 coach consent (new key `ai_coach_consent_v2`) when the flag is on.

## 5. Privacy, App Privacy and Data safety

**Store forms: no change.**
- Collected data types stay the same: Fitness, Other User Content, Product Interaction, User ID. Purpose stays App Functionality, with no tracking.
- Memory is kept on the phone. History is already-synced Fitness data. Messages are Other User Content, as today.
- `PrivacyInfo.xcprivacy` and `store_listing/PRIVACY_DECLARATIONS_V2.md` stay as they are.
- If Anthropic is added, the Play "shared" answers stay **No**, because Anthropic is a service provider processing on our behalf.

**Policy text: draft only, NOT applied.** The draft below is for `backend/static/privacy-policy.html` and the in-app EN/VI copy. Apply it before the v2 flag ships, and change the effective date at the same time.

(a) Section 8, AI Coach, with v2 on:

> EN: For each request the app sends, over HTTPS to the `ai-request` Edge Function on Supabase: the request type, the response language, the messages you typed and up to the last 15 turns of that chat, a short summary of earlier chats that the app keeps on your phone, and workout numbers (your last workout, your active plan's targets and goal). To personalise answers, the function also reads your **synced** workouts of the last 4 weeks from your account and turns them into totals and averages. The function checks your sign-in and usage limits, charges one credit, sends this minimized prompt to our AI provider (section 11) and returns the answer. The conversation and the summary are not stored on our servers. Suggested plan changes are applied only if you accept them.
>
> VI: Với mỗi yêu cầu, app gửi qua HTTPS tới Edge Function `ai-request` trên Supabase: loại yêu cầu, ngôn ngữ trả lời, tin nhắn bạn gõ và tối đa 15 lượt gần nhất của cuộc trò chuyện, một bản tóm tắt ngắn các lần trò chuyện trước (app giữ trên điện thoại của bạn), và số liệu tập (buổi gần nhất, mục tiêu và chỉ tiêu của kế hoạch đang theo). Để cá nhân hoá câu trả lời, function còn đọc các buổi tập **đã đồng bộ** trong 4 tuần gần nhất từ tài khoản của bạn và chuyển thành tổng và trung bình. Function kiểm tra đăng nhập và hạn mức, trừ một tín dụng, gửi lời nhắc đã tối giản này tới nhà cung cấp AI (mục 11) và trả câu trả lời về app. Cuộc trò chuyện và bản tóm tắt không được lưu trên máy chủ của chúng tôi. Thay đổi kế hoạch được gợi ý chỉ được áp dụng khi bạn chấp nhận.

(b) Only when `AI_PROVIDER` or `AI_FALLBACK_PROVIDER` is set to `anthropic`: add Anthropic as a processor. This goes in section 10 (list) and section 11. Before publishing, check the retention and minimum-age wording against Anthropic's current Commercial Terms and Usage Policy.

> EN (section 10 list): **Anthropic** (Anthropic, PBC): AI inference for AI Coach (section 11).
>
> EN (section 11): AI Coach may also use Anthropic's Claude API, as the main provider or as a fallback when GroqCloud is unavailable. Only the same minimized prompt is sent; the API key stays on our server. Under Anthropic's commercial terms, API inputs and outputs are not used to train its models, and they are deleted after a limited retention period, except where Anthropic must keep them longer to enforce its usage policy or comply with law. RepCoach AI does not currently claim zero data retention with Anthropic.
>
> VI (mục 10): **Anthropic** (Anthropic, PBC): suy luận AI cho AI Coach (mục 11).
>
> VI (mục 11): AI Coach có thể dùng thêm Claude API của Anthropic, làm nhà cung cấp chính hoặc dự phòng khi GroqCloud không khả dụng. Chỉ gửi cùng một lời nhắc đã tối giản; khoá API nằm trên máy chủ của chúng tôi. Theo điều khoản thương mại của Anthropic, dữ liệu vào/ra qua API không được dùng để huấn luyện mô hình và bị xoá sau một thời hạn lưu giữ giới hạn, trừ khi Anthropic phải giữ lâu hơn để thực thi chính sách sử dụng hoặc tuân thủ pháp luật. RepCoach AI hiện không tuyên bố bật lưu giữ bằng không (ZDR) với Anthropic.

With (b), the coach consent text also names Anthropic, and the consent key is bumped again.

## 6. Owner: deploy (the agent deploys nothing)

Order matters. Apply the migration **before** deploying the function. With limits set, the function calls `ai_usage_counts`; if that function does not exist yet, every AI Coach request (v1 included) fails with 500.

```bash
supabase link --project-ref rvysencgtomkzwgdjaqh
supabase db push                       # applies 20261125000100_ai_coach_v2.sql
supabase migration list                # Local == Remote
supabase secrets set AI_PROVIDER=groq AI_DAILY_LIMIT_PER_USER=30 AI_MONTHLY_LIMIT_TOTAL=5000
supabase functions deploy ai-request   # JWT verification stays on
```

Smoke test:
- With no session, the function returns 401.
- With a staging account, `test/staging/staging_backend_test.dart` passes. v1 answers are unchanged.

**Staging now (owner decision 2026-11-25):** GroqCloud only. `AI_PROVIDER=groq` (also the default when unset), `AI_FALLBACK_PROVIDER` unset (or `groq`, which is the same thing: a fallback equal to the primary is ignored), and **no** `ANTHROPIC_API_KEY`. The policy published now names only GroqCloud for AI Coach.

### Switching provider: secrets only, no app rebuild

The app never knows which provider answers. The request and response of `ai-request` are the same for both. Switching is therefore a secrets change on Supabase:
- no new app build;
- no store review;
- no function redeploy: Supabase restarts the function with the new secrets.

Before switching to Anthropic, publish the Anthropic wording of §5(b) and update the coach consent text (app release).
1. Anthropic main, Groq backup, after the app is tested on staging:
   ```bash
   supabase secrets set ANTHROPIC_API_KEY=<from console.anthropic.com> ANTHROPIC_MODEL=claude-haiku-5-5 ANTHROPIC_MODEL_PLAN=claude-haiku-5-5
   supabase secrets set AI_PROVIDER=anthropic AI_FALLBACK_PROVIDER=groq
   ```
   Optional: stronger plans with `ANTHROPIC_MODEL_PLAN=claude-sonnet-5-5` or `claude-opus-5-5`.
2. Check: the function logs show `"provider":"anthropic"`. Lines with `"provider":"groq","fallback":true` mean Groq answered because Anthropic failed.
3. Back to Groq only:
   ```bash
   supabase secrets set AI_PROVIDER=groq
   supabase secrets unset AI_FALLBACK_PROVIDER
   ```
   `ANTHROPIC_API_KEY` may stay set. It is only used when `anthropic` is the provider or the fallback.

**Rollback:**
- Set `AI_PROVIDER=groq` and unset `AI_FALLBACK_PROVIDER`, or redeploy the previous function version.
- The migration only widens a check, replaces `ai_credit_consume` with the same body, and adds two read-only functions, so it can stay.

## 7. AI-2 "Body check-in" (plan only, after the v2 store submission)

**Goal.** An optional photo check-in that turns posture and physique cues into training priorities and a plan. It gives **no diagnosis** and **no appearance judgement**.

| Item | Decision |
|---|---|
| Flag | `ENABLE_BODY_PHOTO`, **off** by default, and only with accounts + `ENABLE_AI_COACH_V2`. |
| Consent | A separate screen and key (`body_photo_consent_v1`), shown before the camera or photo picker opens. It explains what is sent, the moderation step, that the photo is not stored, and that results are text only. "Not now" is always available. |
| Age | 13+ app policy applies. If the store age rating or the provider's terms require 18+ for photo analysis, the feature is hidden for under-18 accounts. This needs an age attestation, which is an owner decision. |
| Storage | **First version: the photo is never stored on our servers.** It is sent once over HTTPS to a new Edge Function (`body-check`), held in memory and dropped after the answer. Only the **text result** is kept: on the phone, and synced like workouts if the user wants. No photo goes to Supabase Storage. |
| Moderation (before any analysis) | A first model call classifies the photo:<br>• **allow:** shirtless or sportswear torso/limbs;<br>• **block:** exposed genitals or nipples where policy treats them as sexual, sexual or pornographic content, anyone who appears to be a minor, more than one person, or no human body.<br>A blocked photo gets a neutral "can't analyse this photo" and is not analysed. It is never stored, logged or used for training. |
| Analysis | Only posture and alignment cues (e.g. rounded shoulders, pelvic tilt as seen), proportion of muscle groups to prioritise, and a training plan (PL-1 suggestion review, as in v2). No body-fat %, weight, BMI, attractiveness, medical or diagnostic terms. Safety rules as in §4, plus "never comment on looks". |
| Provider | It must have a vision model, zero-retention or short-retention terms for images, and an image-safety classifier. Groq and Anthropic are both candidates; this is decided at the time against current terms. |
| Logs | Outcome only (`allowed` / `blocked` / `error`), never the image or its description. |

Changes needed before AI-2 ships (none are made now):
- **Privacy policy:** a new section "Body check-in (optional photos)" covering what is sent, moderation, no storage, the text result, the provider, and retention at the provider. Update the section 2 camera paragraph, which today says no camera images ever leave the device.
- **App Privacy (Apple):** add **User Content › Photos or Videos**, linked to the user, App Functionality, not tracking. Note it in the review notes, because the photo is not stored.
- **Data safety (Play):** add **Photos and videos › Photos**, collected, *processed ephemerally* = **Yes** (not stored), optional, App functionality. Shared stays No (service provider).
- **`PrivacyInfo.xcprivacy`:** add `NSPrivacyCollectedDataTypePhotosorVideos` (linked, not tracking, App Functionality). Update the A.2 table and the gate in `check_app_store_readiness.py` with it.
- **iOS `Info.plist`:** `NSPhotoLibraryUsageDescription` (read) if the photo picker is used. The camera prompt text is updated (EN/VI).
- **Store review:** a demo account, the review note describing moderation, and age-rating answers rechecked (no UGC sharing; photos are not shared with other users).
- **`aiConsentVersion` / coach consent:** unchanged. Body check-in has its own consent.

## 8. NT-2 friendly reminders (L-D44)

**Layer 1 (shipped first, on by default, offline, no AI):**
- 54 EN/VI lines from the ARB catalog, listed in `09_REMINDER_COPY.md`.
- Lines are chosen when NT-1 schedules the local notifications (`ReminderService.sync`, `ReminderCopy`), by situation, and never repeat within 14 days.
- The rotation state is kept on the phone (`reminder_copy_v1`).
- "Friendly reminders" in reminder settings can be turned off, which brings back the neutral "About N min." line.

**Layer 2 (behind `ENABLE_AI_COACH_V2`, optional in settings, off by default; second NT-2 PR):**
- Owner deploy: `supabase db push` (applies `20261125000200_reminder_batch.sql`), then `supabase functions deploy ai-request`. Before that, a `reminder_batch` request gets 400 and the app keeps layer 1.
- App: `ReminderAiWriterImpl` (`lib/features/credits/reminder_ai.dart`) is installed at start-up, only with an account and the v2 flag. The "Reminders written by the AI coach" switch (`reminder-ai`) is shown only then.
- When the app opens or the plan changes, `ai-request` kind `reminder_batch` writes lines for the next 3–7 sessions.
- Input: the session targets plus the numbers-only history, and possibly a fix from the last review. Nothing else is sent.
- Output: JSON with one line per session id. Lines are length-capped and filtered for banned words on the server and again in the app.
- The lines are stored on the phone and used when scheduling.
- At most one AI request (one credit) per week.
- Offline or on any error, layer 1 is used.

**Later, with remote push (`ENABLE_PUSH`):** generation moves to the server. A scheduled job (`send-push`) would call the same `reminder_batch` prompt per user and send the line as a push, so the phone no longer asks for it. The rotation and quick-off rules stay. The App Privacy and Data safety forms must then be checked again for push tokens (Device ID).

**Store:**
- Reminders exist only for sessions the user planned.
- They are never used for promotion (App Store 4.5.4; Play notification policy).
- Two switches turn them off quickly: the main reminder switch and "Friendly reminders".
- App Privacy and Data safety are unchanged. Layer 1 sends nothing. Layer 2 sends the same Fitness numbers to `ai-request` as AI Coach does.
