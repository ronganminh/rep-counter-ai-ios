# API_AND_BACKEND_GAP_ANALYSIS

RepCoach AI · Final C · 2026-10-22

> **Evidence base.** Facts in §1 are **VERIFIED** from source in `ronganminh/rep-counter-ai-ios` @ `3594d8a` (`rep-counter-ai-main/backend/`, `rep-counter-ai-main/contracts/`, mobile `AiFeedbackService`). No other backend repository is referenced by the mobile configuration or docs; the legacy engine repo `Juliolayme/rep-counter-ai` (private) was **not accessible** and is referenced only in `docs/CHUYEN_MAY.md:3`. Everything in §3–§6 is **PROPOSED** — no endpoint below §1 exists today. No secrets were copied; the only secret referenced by CI is `VPS_SSH_KEY` (by name).

## 1 · Verified backend (exists today)

| Item | Fact | Evidence |
|---|---|---|
| Runtime | Python 3 standard library `http.server.ThreadingHTTPServer`; no framework, **no database** | `backend/server.py` (438 lines) |
| AI provider | `GroqProvider` (default, env `AI_PROVIDER=groq`, `GROQ_MODEL` default `openai/gpt-oss-20b`); legacy `GeminiProvider` | `backend/ai_provider.py`, `backend/docs/groq-provider.md` |
| Deploy | nginx TLS vhost on a VPS, `limit_req` 10 r/min burst 10, systemd unit, manual deploy scripts | `backend/deploy/repcoach-ai.nginx`, `repcoach-backend.service`, `b7_apply.sh` |
| Auth | **None** — all routes unauthenticated | `server.py` |
| Tests | 94 Python tests (validation, security, privacy contract, deploy config…) | `backend/tests/` |

### Endpoints

| Method | Path | Auth | Request | Response | Classification |
|---|---|---|---|---|---|
| GET | `/health` | none | – | `200 {"status":"ok"}` | EXISTING API |
| GET | `/ready` | none | – | `200 {"status":"ready"}` / `503 {"status":"not_ready"}` | EXISTING API |
| GET | `/privacy-policy.html`, `/terms.html`, `/support.html` | none | – | static HTML | EXISTING API (legal/support pages; URLs are the source for `[PRIVACY_URL]`/`[TERMS_URL]`/`[SUPPORT_URL]` **once the owner confirms them**) |
| POST | `/v1/workout-feedback` | none (IP rate limit only) | JSON ≤ 16 384 B, `schema_version` 1 or 2 (v2 requires `consent_version`); fields `exercise`, `duration_seconds`, `reps`, `sets`, `target_reps`, `goal_reached`, `placement_score`, `pose_frames`, `pose_lost_frames`, `locale` (vi/en), quality fields (`flagged_reps`, `avg_rep_sec`, `avg_amplitude`, `amplitude_drop_percent`, `left_right_diff_percent`, `quality_score`, `has_enough_data`) — example `contracts/workout_feedback_v2.json` | `200 {"schema_version":1,"feedback":"…"}`; errors `{"error": INVALID_REQUEST(400) / 413 / 405 / AI_UNAVAILABLE(503) / AI_TIMEOUT(504) / AI_RESPONSE_INVALID(502) / SERVER_ERROR(500) / NOT_FOUND(404)}` | EXISTING API |

Mobile client: `AiFeedbackService` → `POST {AI_BASE_URL}/v1/workout-feedback`, 25 s timeout, HTTPS only, consent version `2026-10-01-groq`, offline `RuleBasedFeedback` fallback (VERIFIED).

## 2 · Feature-by-feature classification

| Feature | Classification | Notes |
|---|---|---|
| Basic post-workout AI feedback | **EXISTING API** (needs extension for accounts) | Works anonymously today. To meter fairly and attach to accounts: add optional `Authorization`, `Idempotency-Key` (= workout clientId) and `requestId`. Basic feedback stays **free** (PROPOSED product rule). |
| Advanced analysis / coach chat / progress review | **NEW API PROPOSED** | Credit-metered; idempotent by `requestId`. |
| Usage & credits | **NEW API PROPOSED** | Server ledger (grant/consume/hold/release); client never computes balance. Free 10 / Pro 60 per week, rewarded-ad cap 3/day are **PROPOSED** values. |
| Purchase verification | **NEW API PROPOSED** + external services | App Store Server API (+ App Store Server Notifications v2 webhook), Google Play Developer API (+ Real-time Developer Notifications via Pub/Sub). Lemon Squeezy webhooks **web only**. |
| Entitlements | **NEW API PROPOSED** | Server-authoritative; client cache ≤ 7 days offline (PROPOSED). Pro is never enabled before verification. |
| Workout synchronisation | **NEW API PROPOSED** | Batch upsert keyed by client-generated UUID; tombstones for deletes. |
| User profiles | **NEW API PROPOSED** | Requires an auth provider (decision pending — see PRODUCT_DECISIONS D-12). |
| Friends / requests / blocking / reporting | **NEW API PROPOSED** | |
| Leaderboards | **NEW API PROPOSED** | Server aggregates of camera-counted reps only. |
| Challenges / races / XP | **NEW API PROPOSED** | XP and challenge progress server-authoritative; awards idempotent by `(userId, sourceId)`. |
| Notifications (push) | **NEW API PROPOSED** | Device token registry, server-sent events → APNs/FCM. Local reminders need **NO BACKEND**. |
| AI feedback ready notification | **NEW API PROPOSED** | Only if feedback becomes async. |
| Account deletion | **NEW API PROPOSED** | Async job, status polling, retention per policy. Required before any account system ships. |
| Data export | **NO BACKEND REQUIRED** today (local CSV/JSON export exists) → **NEW API PROPOSED** for cloud data once accounts exist. |
| Workout history deletion (account scope) | **NEW API PROPOSED** | Phone scope exists locally (VERIFIED `SettingsPage._deleteData`). |
| Support contact | **EXISTING API NEEDS EXTENSION** | Static `/support.html` exists; a ticket endpoint is PROPOSED (or mailto to `[SUPPORT_EMAIL]`). |
| Plans, reminders, recovery drafts, calibration, voice settings | **NO BACKEND REQUIRED** (local-first); plan sync optional later. |

## 3 · Proposed contracts (illustrative, PROPOSED — not implemented)

```ts
// Common
type ClientId = string;            // UUIDv4 generated on device at workout creation; never re-issued by the server
type IdempotencyKey = string;      // header Idempotency-Key; same key → same stored response, no second charge/award
interface ApiError { error: 'INVALID_REQUEST'|'UNAUTHENTICATED'|'FORBIDDEN'|'NOT_FOUND'|'CONFLICT'|'RATE_LIMITED'|'PAYMENT_REQUIRED'|'SERVER_ERROR'; requestId: string; retryAfterSec?: number; }

// Sync — POST /v1/sync/batch   (auth: Bearer)
interface WorkoutUpsert {
  clientId: ClientId; exerciseId: 'push_up'|'pull_up'|'squat'|string; startedAt: string /* ISO-8601 */; durationSeconds: number;
  reps: number; sets: number; source: 'camera'|'manual'|'timer';   // manual reps are never counted as camera-verified
  heldSeconds?: number; partial?: boolean; planSessionId?: string; quality?: Record<string, number>;
  updatedAt: string; deleted?: boolean /* tombstone */;
}
interface SyncBatchRequest { deviceId: string; items: WorkoutUpsert[]; }
interface SyncBatchResponse { results: { clientId: ClientId; status: 'created'|'unchanged'|'updated'|'conflict'|'deleted'; serverVersion: number }[]; }

// Guest upgrade — POST /v1/account/upgrade/dry-run
interface DryRunRequest { manifest: { clientId: ClientId; updatedAt: string; reps: number }[]; }
interface DryRunResponse { matched: number; fresh: number; conflicts: { clientId: ClientId; local: {reps:number}; server: {reps:number} }[]; }

// Credits — GET /v1/credits ; POST /v1/coach/messages (Idempotency-Key required)
interface Credits { allowance: number; remaining: number; bonus: number; resetsAt: string; tier: 'free'|'pro'; }
interface CoachMessageRequest { requestId: string; text: string; locale: 'en'|'vi'; }
interface CoachMessageResponse { requestId: string; reply: string; charged: boolean; credits: Credits; }

// Purchases — POST /v1/purchases/verify
interface VerifyRequest { platform: 'ios'|'android'; productId: string /* [PRODUCT_ID_*] */; transactionId?: string /* iOS */; purchaseToken?: string /* Android */; }
interface Entitlement { tier: 'free'|'pro'; status: 'active'|'grace'|'billing_retry'|'expired'|'revoked'|'pending'; expiresAt?: string; verifiedAt: string; source: 'app_store'|'google_play'|'web'; }

// Account — DELETE /v1/me  → 202 { jobId } ; GET /v1/me/deletion/{jobId} → { status: 'requested'|'processing'|'completed'|'failed' }
// Export — POST /v1/me/export → 202 { jobId } ; download link requires recent re-authentication
// Push — POST /v1/devices { token, platform, locale, categories[] }
// Social — GET /v1/friends, POST /v1/friends/requests, POST /v1/friends/requests/{id}/accept|decline, POST /v1/blocks, POST /v1/reports
// Races — POST /v1/races { opponentId, metric:'pushups_camera'|'plank_timer', days }, POST /v1/races/{id}/accept|decline, GET /v1/races/{id}
// XP — GET /v1/me/xp ; awards are server-side events keyed (userId, sourceType, sourceId) → reopening a notification never awards twice
```

## 4 · Security considerations

- Add authentication before any per-user data: short-lived access token + refresh token in Keychain/Keystore (`flutter_secure_storage`, PROPOSED). Never log tokens; diagnostics exclude tokens, passwords, billing and camera data (A-06).
- Keep `/v1/workout-feedback` rate-limited; add per-user quotas server-side once accounts exist (client counters are display-only).
- Purchase verification only server-to-server; never trust client receipts for entitlement. Replay-safe by transactionId / purchaseToken.
- Rewarded-ad credit only after server-side verification (SSV) of a server-issued nonce; duplicate callbacks are no-ops.
- Social: block/report endpoints, privacy defaults (friends-only), no public profiles by default (Phase 7).
- Account deletion: re-authentication, async job, revoke sessions on all devices, retention per Privacy Policy (not invented here).
- Transport: HTTPS only (already enforced in `AiFeedbackService`), HSTS on nginx.

## 5 · Sync requirements

1. Local-first: every workout is saved to the device store before any network call (today: SharedPreferences JSON, 100-record cap — **must move to a proper local DB before sync** to remove the cap; PROPOSED drift/sqflite).
2. Each record carries `clientId` assigned at workout start (Final B fix: duplicate finishes are blocked by clientId).
3. Upload in batches; retries reuse the same `clientId`; server returns stored result (no duplicates).
4. Deletes are tombstones; a phone-only delete keeps the account copy and blocks re-download.
5. Conflicts (same clientId, different content) surface in the merge UI (FA/Final C N6); never silently double count.
6. Guest namespace kept until merge succeeds; merge is a dry-run first.

## 6 · Billing integration

| Platform | Mechanism | Products | Verification | Status |
|---|---|---|---|---|
| iOS | StoreKit 2 via `in_app_purchase` (PROPOSED package) | `[PRODUCT_ID_PRO_MONTHLY]`, `[PRODUCT_ID_PRO_ANNUAL]` | App Store Server API + Server Notifications v2 | NOT IMPLEMENTED |
| Android | Google Play Billing via `in_app_purchase` | same placeholders | Play Developer API + RTDN | NOT IMPLEMENTED |
| Web | Lemon Squeezy checkout + webhooks | web plans | webhook signature | NOT IMPLEMENTED · web only |

Prices are never hard-coded or translated: UI shows `ProductDetails.price` from the store SDK. Product IDs, prices, trial terms and approval status are **unresolved configuration**.

## 7 · Notification architecture

- **Local (no backend):** workout reminders scheduled from the plan with `flutter_local_notifications` (PROPOSED), quiet hours, recovery days skipped, moved sessions keep their reminder.
- **Remote (backend):** friend requests, race updates, challenge completion, payment issues, AI-ready → APNs/FCM via a push service; per-category preferences server-side.
- Deep links: every push carries a route + entity id; expired/missing entities resolve to a safe fallback (Final C N10).
- Permission is independent of auth (signing in never enables notifications).

## 8 · Platform dependencies

ML Kit pose detection (on-device), camera, TTS (`flutter_tts`), share (`share_plus`), Photos save (`gal`), url_launcher, audioplayers — all VERIFIED in pubspec. To add (PROPOSED): router (`go_router`), local DB, secure storage, `in_app_purchase`, `flutter_local_notifications`, `firebase_messaging` (or APNs direct), `package_info_plus`, `flutter_localizations` + `intl` (gen-l10n), auth SDK (provider TBD).
