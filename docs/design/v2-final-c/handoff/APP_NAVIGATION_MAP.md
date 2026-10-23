# APP_NAVIGATION_MAP

RepCoach AI · Final C · 2026-10-22

> **Current Flutter (VERIFIED, `3594d8a`):** Navigator 1.0 (`Navigator.push/pushReplacement` + `MaterialPageRoute`), no named routes, no deep links, `AppShell` with a 3-destination `NavigationBar` (Train / History / Settings). **Target (approved design):** 5 tabs `Home | Exercises | Train | Progress | Profile`, Train is the prominent centre action. Route paths below are **PROPOSED**. The shared-state behaviour reference is the Final B integrated prototype (`RepCoach-AI-Final-B-Integrated-Prototype.dc.html`, 39 routes); separate canvas files do **not** share live state.

## 1 · Router recommendation (PROPOSED, needs tech-lead approval — PRODUCT_DECISIONS D-15)

Introduce `go_router` with a `StatefulShellRoute.indexedStack` for the 5 tabs, **incrementally**:
1. Wrap the existing screens first (no behaviour change); keep `CameraPage → ResultPage` as an imperative full-screen flow pushed on the root navigator (it already uses `pushReplacement`; keep it).
2. Add path-based routes only where deep links or `returnTo` are needed (inbox, invites, races, results, paywall, auth gate).
3. Keep `appRouteObserver` (Home refresh on `didPopNext`) working via `GoRouter(observers: …)`.

## 2 · Five-tab structure

| Tab | Root route | Children (PROPOSED paths) |
|---|---|---|
| Home | `/home` | `/home/inbox` · `/home/plan` · `/home/plan/day/:date` · `/home/plan/session/:sessionId` · `/home/plan/reschedule` (sheet) |
| Exercises | `/exercises` | `/exercises/:exerciseId` · `/exercises/:exerciseId/demo` |
| Train (centre) | `/train` (sheet over current tab) | starts the workout flow (root navigator) |
| Progress | `/progress` | `/progress/history` · `/progress/history/:workoutId` · `/progress/records` · `/progress/achievements` · `/progress/achievements/:id` · `/progress/streaks` · `/progress/compare` · `/progress/form` |
| Profile | `/profile` | `/profile/edit` · `/profile/friends` (+ `/find`, `/:userId`, `/leaderboard`, `/challenge/new`) · `/profile/membership` · `/profile/membership/restore` · `/profile/settings` (+ `/notifications`, `/voice`, `/calibration`, `/account`, `/language`) · `/profile/privacy` (+ `/export`, `/delete`, `/delete-account`) · `/profile/help` (+ `/contact`, `/about`, `/legal/:kind`) |

Root-navigator (full-screen, **no tab bar**): `/onboarding`, `/auth/*` (`welcome`, `gate?returnTo=`, `sign-in`, `sign-up`, `verify`, `merge`), `/workout/camera` (→ existing `CameraPage`), `/workout/manual`, `/workout/timer`, `/workout/recover`, `/workout/:sessionId/results` (→ `ResultPage`), `/workout/:sessionId/feedback`, `/share/:kind/:id` (→ `StoryPage`), `/pro`, `/pro/plans`, `/pro/status`, `/coach/chat`, `/coach/*`, `/races/:raceId`, `/challenges/:id`.

## 3 · Navigation tree

```
/ (startup gate: onboarding_v1? recovery draft? → FA-01)
├── /onboarding ──(continue as guest)──▶ /home
├── Shell (tab bar visible)
│   ├── /home ─┬─ bell ▶ /home/inbox ─▶ deep-link targets
│   │          ├─ profile pill ▶ /profile
│   │          ├─ Today card ▶ [Train flow]   · View plan ▶ /home/plan ▶ /home/plan/session/:id ▶ [Train flow]
│   │          ├─ AI Coach card ▶ /coach (account) ▶ /coach/chat ▶ paywall ▶ /pro
│   │          └─ Race card ▶ /profile/friends (account) ▶ /races/:id
│   ├── /exercises ▶ /exercises/:id ▶ [Train flow, free workout]
│   ├── (Train) ▶ sheet: today's plan · free workout · manual
│   ├── /progress ▶ history ▶ detail · records · achievements
│   └── /profile ▶ membership (P8) · restore · friends (P7) · notifications (P10) · settings (P9, language) · privacy (P9 + FA-08) · help (FA-12)
└── [Train flow] (root navigator, no tabs)
    camera explanation ▶ OS prompt ▶ CameraPage (positioning ▶ ready ▶ calibrating ▶ countdown ▶ active ⇄ paused/resting ▶ ending ▶ saving) ▶ ResultPage ▶ AI feedback · share · history
      └ denied ▶ camera off ▶ /workout/manual ▶ results          └ app killed ▶ next launch ▶ /workout/recover
```

## 4 · Auth gates (guards)

| Destination | Guest | Signed in, session expired | Signed in |
|---|---|---|---|
| Train, history, progress, exercises, settings, help, local export, phone-history delete | allowed | allowed (local) | allowed |
| Friends, invites, races, leaderboards, AI Coach chat, Pro purchase, cloud export, account delete, account-scope history delete | → `/auth/gate?returnTo=<dest>` | → re-auth sheet, `returnTo` kept, local data kept | allowed |
| Basic AI feedback on results | allowed (consent required; anonymous today) | allowed | allowed |

Rules: the gate never blocks training; after sign-in, if the device has guest workouts → `/auth/merge` (dry-run, conflicts) → then `returnTo`. Signing in never changes notification permission or entitlement.

## 5 · Deep-link destinations (push / inbox)

| Link (PROPOSED scheme `repcoach://` + universal links) | Destination | Fallback when stale/missing |
|---|---|---|
| `repcoach://plan/session/{sessionId}` | session preview | "Already completed today" (no new session) — Final B J20 |
| `repcoach://races/{raceId}` | head-to-head | "Race ended" summary |
| `repcoach://invites/{inviteId}` | invite | "This invite has expired · nothing was started" — Final C N10 |
| `repcoach://friends/requests` | friends (requests) | friends list |
| `repcoach://workouts/{workoutId}/feedback` | AI feedback | workout detail |
| `repcoach://challenges/{id}` | challenge detail | challenges list |
| `repcoach://membership` | membership / billing issue | profile |
| `repcoach://inbox` | inbox | home |
Guest + account-only target → auth gate with `returnTo`. During a live workout, pushes are **held** and delivered on Results (never over the HUD).

## 6 · Back-stack rules

1. Tab tap → that tab's root; re-tapping the active tab pops to root. Each tab keeps its own stack (indexed stack).
2. System Back / swipe-back pops within the tab; at a tab root Android Back goes to Home, then exits.
3. Deep link from a push → one-step stack (destination over the tab root it belongs to).
4. Auth gate "Not now" → back to the origin; success → `returnTo` replaces the gate.
5. Results "Done" → Home root (stack cleared); "History" → `/progress/history/:id`.

## 7 · Modal rules

- Sheets (Train sheet, reschedule, plan select, share sheet, discard confirm) are dismissible by drag/scrim unless destructive-confirm is in progress.
- Paywalls, rewarded ads and upgrade prompts **never** appear during an active workout or over results-saving; contextual paywall only after an explicit user action (e.g. asking AI Coach with 0 credits).
- OS permission prompts are always preceded by a pre-permission screen; "Not now" never triggers the OS prompt.
- Destructive flows (delete history scopes, delete account) are full-screen, no tab bar, typed confirmation.

## 8 · Workout navigation exceptions

- HUD (`CameraPage` active/paused/resting) is a full-screen route; **no tab bar, no toasts, no paywall, no push banner** above it.
- Tabs are inert while a workout is live or paused.
- Leaving mid-workout requires: hold-to-finish (1 s) → save; or Back → sheet (Continue · Save & leave · Discard… with confirm).
- App backgrounded → auto-pause + camera release (VERIFIED existing `_suspendCamera`); returning stays paused until the user resumes.
- Process killed → next launch shows Recovery (Resume / Save partial / Discard), 12 h window PROPOSED and configurable; never silently discard; one record only.
- Results replace the camera route (`pushReplacement`, VERIFIED) so Back from Results cannot reopen the HUD.
