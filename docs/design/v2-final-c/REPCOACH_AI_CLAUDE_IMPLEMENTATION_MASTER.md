# REPCOACH AI v2 — CLAUDE CODE IMPLEMENTATION MASTER BRIEF

> **Purpose:** Implement the approved RepCoach AI v2 design into the existing production Flutter application and its real backend. This is a coding mission, **not** a new design exercise.
>
> **Primary design package:** `RepCoach-AI-Final-C-Design-Package.zip` (provided separately by the owner).
>
> **Primary mobile repository:** `https://github.com/ronganminh/rep-counter-ai-ios`
>
> **Legacy rep-counting reference:** `https://github.com/Juliolayme/rep-counter-ai` (read-only historical engine reference; may require access).

## 0 — Role, mandate and non-negotiables

Act as Principal Flutter Engineer, Backend/API Integration Engineer, Mobile QA Lead and Release Engineer. Produce working code, small reviewable PRs, tests, CI evidence and implementation documentation. Do **not** merely write a plan or reproduce mockups.

1. **Preserve the working camera/pose/rep-counting engine.** Do not replace production counting, HUD state, workout persistence or result transitions with fake numbers, demos or UI-only simulations. Accepted rep counts must remain monotonic. Keep camera and saved-record metrics consistent.
2. **Use the existing mobile repo and its current main branch.** Inspect actual code, CI, dependency versions, iOS/Android configuration and existing backend contracts first. Do not assume filenames or APIs from the design package are already implemented.
3. **Treat the Final C archive as design specification, not proof of runtime behavior.** It reported Canvas version 17, a 39-screen integrated demo, 33 planned PR-sized tasks, and design QA. The artifact's payment, login, push, camera, server and advertising flows are simulations; implement real integrations only against verified systems.
4. **Never delete or replace working functionality to imitate a prototype.** Refactor incrementally, retain backwards compatibility where appropriate, and preserve database migration paths.
5. **Security and privacy by default.** No keys or credentials in git, no hardcoded production prices or billing product IDs, no unapproved data collection, no AI data upload without applicable consent.
6. **Do not invent endpoint paths, OAuth setup, app IDs, store product IDs or approval status.** Mark missing infrastructure `BLOCKED` and implement interfaces/mocks limited to tests until prerequisites exist.
7. **One scoped task / one PR at a time.** Do not start downstream tasks when CI/prerequisites are incomplete. Do not merge failing PRs. For protected repo actions, use the owner's available authorization and branch protections; never bypass safeguards.
8. **Do not run deployment, purchase, irreversible account/data deletion, or production migration without explicit owner authorization.** A passing CI is not deployment consent.
9. **Support iOS and Android where the actual repository supports them.** Do not claim Android or iOS release readiness before their platform builds and tests pass.
10. **Communicate in Vietnamese** to the owner. Code, paths, identifiers and technical documentation may use English.

## 1 — Inputs and source-of-truth hierarchy

At kickoff, obtain/open:

- Final C ZIP (including `handoff/`, design source, evidence and manifest).
- `MASTER_DESIGN_HANDOFF.md`
- `SCREEN_TO_FLUTTER_MAPPING.md` and `SCREEN_INVENTORY.csv`
- `DESIGN_SYSTEM_TOKENS.json` and `COMPONENT_REGISTRY.md`
- `APP_NAVIGATION_MAP.md`
- `API_AND_BACKEND_GAP_ANALYSIS.md`
- `FLUTTER_IMPLEMENTATION_ROADMAP.md`
- `PRODUCT_DECISIONS.md`
- `FINAL_QA_REPORT.md`, `RELEASE_CHECKLIST.md`, `REPO_AUDIT.md`
- `l10n/app_en.arb`, `l10n/app_vi.arb`, localization audit and glossary.
- All current app and backend source, unit/widget/integration tests and GitHub Actions workflows.

**Authority when documents disagree:** (1) verified live production code + real backend/store contracts for *what currently works*; (2) explicitly approved product decisions for *intended behavior*; (3) current Final C design and navigation source for UI/UX; (4) older phases; (5) illustrative demo fixtures. Surface conflicts in a decision log; do not silently pick an answer where safety, billing or data loss is involved.

**Verification:** Extract the ZIP into a temp workspace; verify archive integrity and `ASSET_MANIFEST.json` fingerprints where supported; record the archive checksum and git HEAD. Do not use the ZIP as a substitute for repository inspection. Keep it unmodified as reference.

## 2 — First execution: audit, then baseline PR

Before coding, perform a targeted repository audit:

- Flutter/Dart/Gradle/Xcode/Pods versions, build targets, flavors, env management, signing boundaries.
- Router/navigation, current theme/widgets, camera session controller, pose and rep algorithms, result and local-save flows.
- Auth, sync, API client, Groq/AI backend, entitlements/credits, social, billing and notifications *as actually implemented*.
- Existing localization, semantic labels, dynamic text support and permissions.
- Android/iOS CI, device/simulator replay fixtures and release workflows.
- Available backend repo, deployed API contract, versioned endpoints, migrations and data ownership.

Deliver `docs/implementation/00_BASELINE_AUDIT.md` with an evidence-backed matrix:

`Feature | Design source | Verified code path | State (implemented/partial/missing/unknown) | Backend dependency | Risk | Proposed task`

Also create a dependency graph and proposed PR sequence matching the **actual** 33 tasks from the ZIP, with any necessary changes explained. Start with a small baseline PR only after the audit. If the ZIP is unavailable, clearly request it rather than inventing its contents; proceed only with safe inspection.

## 3 — Delivery milestones / PR order

Read and reconcile the ZIP's own roadmap. The following is a suggested order, **not** an instruction to overwrite its verified plan. Keep PRs atomic and reviewable; split if necessary.

| Wave | Outcome | Hard dependencies / guardrails |
|---|---|---|
| W0 Baseline | Repository audit, tests and fixtures, design mapping, CI status | No behavior changes; verify actual repo state |
| W1 Design foundations | Tokens, fonts, icon language, canonical reusable Flutter widgets, accessibility fixes | Do not rewrite functioning workout logic |
| W2 Navigation + launch | Five tabs Home/Exercises/Train/Progress/Profile, startup/onboarding, auth guards, deep-link contract | Existing camera entry remains functional |
| W3 Core workout | Exercises, plans, camera HUD skin, pause/resume, hold-to-finish, results, offline save, History | Protect real engine and persistence; replay tests required |
| W4 Account + profile | Guest, real auth based on verified provider, safe guest migration, Profile/Settings, deletion routing | No silent local data loss; endpoints/provider credentials must exist |
| W5 Insights + AI | Analytics, achievements, feedback with consent, advanced AI and credits | AI failure must never block saving; idempotent billing/usage |
| W6 Social | Friends, challenges, leaderboard, blocking/reporting/privacy | Server verification for competition and entitlements |
| W7 Monetization | Paywall, StoreKit/Play Billing, receipt verification, restore, usage, optional ads | Store policy and product configuration; no fake paid status |
| W8 Notifications | Inbox, local reminders, push where configured, deep links, quiet hours | OS permission, logout/account switch protection |
| W9 Localization + release | English/Vietnamese resources, accessibility, full regressions, security/privacy, release candidates | iOS + Android QA, no unresolved critical bugs |

For each PR include: scope; approved screen IDs; existing/new files; screenshots (before/after as relevant); actual backend dependency; migration implications; tests; CI links; rollback strategy; and remaining limitations. Mark `READY FOR REVIEW` only when acceptance criteria pass.

## 4 — Canonical app shell and design contract

**Visual identity:** accent `#C8FF2E`, dark base `#0B0B0C`, Barlow Condensed headlines/metrics, Inter UI text, original PushPro cards, radii, spacing and Lucide style. Use exact tokens from ZIP where available; never make up unsupported values.

**Five tabs:** `Home | Exercises | Train | Progress | Profile`. Train remains central/prominent. Profile opens the Phase 9 Profile root, not Friends directly. Home bell opens Phase 10 Inbox. Deep links and auth gateways return to the intended destination; no dead ends.

**Sample fixture consistency only** (not hardcoded production figures): pre-workout: 14 workouts and `227/500` October push-ups; after accepted 35-rep workout: 15 workouts, 627 total reps, `262/500`, 10-day historical streak and Level 4 `395/500` XP; 6:05 holds, 2h55 activity, 323 all-time camera push-ups. Fixture transitions must be deterministic. Real screens derive from real repositories, not static demo numbers.

Keep Guest, authenticated Free, Pro entitlement, AI credits, sync status and notification permissions as **separate state machines**.

## 5 — Camera/workout engine acceptance contract (highest priority)

Preserve the existing session lifecycle and real pose pipeline. Capture screenshots and tests without changing counting algorithms except in an independently approved bugfix PR.

Required flows:

1. Exercise selection → camera permission → positioning/calibration → countdown → live HUD → real reps/holds → pause/resume → hold to finish → ResultPage → local persist → History.
2. Permission denied → manual/timed mode when genuinely supported; no false `camera verified` badge.
3. Workout can be completed and locally saved without AI/backend/network.
4. Network/AI failures cannot erase or double-save a workout. Failed sync leaves a durable pending state with safe idempotent retry.
5. Interrupted session recovery: proposed local snapshot window 12 hours, subject to confirmation, without discarding already-saved records.
6. Accepted rep count must never decrease after rest; HUD count, saved `WorkoutRecord` and ResultPage must match.
7. No paywall, rewarded ad or modal interrupts an active camera workout.

CI: keep short deterministic video replays and the existing production CameraPage path coverage. Where available, verify both historically used pushup clips with duration, processed frames, monotonic count, saved count, ResultPage count, errors. Prefer shorter fixtures for frequent PR CI and a fuller replay suite for milestone/release verification. Label incomplete video/device validation honestly.

## 6 — Data, account, privacy and monetization

**Offline-first:** write workout locally before cloud attempt; stable IDs, pending operation queue, idempotent retries, conflict resolution and explicit guest-to-account migration. Workouts must not disappear on logout, reconnect or account switch. Keep account deletion separate from local-history deletion and cloud-workout deletion.

**Deletion routing:** `Delete workouts from your account` MUST NOT open `Delete account`; each requires an appropriate distinct confirmation. Approved **design proposal**: ordinary workout-history deletion adjusts metrics but retains previously earned XP/achievements; server may correct fraudulent/duplicate competitive results. Validate against backend semantics before enabling live deletion.

**AI:** applicable explicit AI consent before user-generated media/sensitive data transfer. Basic post-workout feedback remains free under the approved *design assumption*; premium coach/progress analysis consumes credits only where verified. Retry must not double-consume credits. Provider and quota details come from backend, not mock UI.

**Billing:** implement native iOS StoreKit / Google Play Billing where configured; confirm with current platform/store rules before release. Never use simulated purchase success as real entitlement. Server verifies receipt/store transaction and controls entitlement; restore/reconciliation and refund/expiration states required. Lemon Squeezy is web-specific unless verified otherwise. Rewarded ads only after policy and SDK approval.

**Proposed values, not approved configuration:** 10 Free / 60 Pro AI requests weekly, 3 rewarded ads/day on Android, up to 7-day offline entitlement cache, 12-hour workout recovery. Track in `PRODUCT_DECISIONS.md` and obtain product/backend decision before hardcoding.

**Legal/support placeholders:** use verified production values for support email/URL, Terms, Privacy Policy, store IDs, app version/build. Otherwise leave marked config TODO and do not publish release candidates implying these are real.

## 7 — Localization, accessibility and polish gates

The Final C report states 4,286 ARB keys, including approximately 3,311 machine-assisted Vietnamese translations requiring human review and 899 sample-data strings needing placeholders. Treat these counts as a report to verify, not proof of finished localization.

- Integrate `app_en.arb`, `app_vi.arb` with stable semantic keys and Flutter l10n generation.
- Convert user names, counts, dates, prices and dynamic labels into interpolated parameters, not translated sample literals.
- Human-review high-impact auth, camera, results, AI consent, billing, privacy, deletion and error copy first; track remaining strings explicitly.
- Render relevant journeys in both languages at small and large text scales; validate diacritics and overflow.
- Repair known legacy accessibility defects: 40px interactive chips (target at least 44pt) and caption foreground measured at 4.36:1 (target at least 4.5:1 for normal text). Support screen readers, focus, reduced motion and keyboard behavior.
- Do not report accessibility/localization fully PASS while documented issues remain.

## 8 — Backend/API traceability

Generate a verified API table: `Screen/feature | Request | Endpoint | Auth | Actual request/response type | Repo source evidence | Status | Error/retry policy`.

Every endpoint is one of `VERIFIED EXISTING`, `EXTENSION REQUIRED`, `PROPOSED NEW`, `LOCAL ONLY`, `UNKNOWN/BLOCKED`.

Do not invent real endpoint paths. If backend repo/service cannot be accessed, implement injectable typed interfaces and test doubles; keep user-facing feature explicitly gated/disabled in production until server verification is complete. Distinguish UI mocks from live integrations.

Protect credentials through secrets configuration, Keychain/Keystore, environment-specific setup and CI secrets. Do not log bearer tokens, private workout videos, raw AI conversations or receipts.

## 9 — Testing and CI acceptance per PR

Minimum relevant checks per task:

- `flutter analyze` and formatting/lints using repo conventions.
- Unit tests for domain/state/repository changes.
- Widget/golden/snapshot or screenshot tests of changed screens and EN/VI text overflow as appropriate.
- Integration/navigation tests including back-stack/deep links for changed routes.
- Replay and workout persistence tests whenever Camera/HUD/Results/save flows are touched.
- API contract tests for real backend changes; permission, denied, offline, retry and cancellation paths.
- iOS and Android build checks when supported, with failures honestly documented.
- Accessibility checks for tappable regions, semantic text, focus and contrast.
- App Store/Play billing, permissions, privacy compliance verified near release with current official docs.

No `PASS` without command output or linked CI run. If unable to run simulator or provision credentials, mark `UNVERIFIED` and explain the concrete requirement.

Stop on failing CI, diagnose root cause, fix within scoped PR and re-run. Merge only after green required checks, code review rules and user authorization where needed. Never fabricate screenshots, CI links or test results.

## 10 — Definition of done / launch boundaries

A wave is DONE when all its PRs are merged (where authorized), implementation mappings and docs updated, tests pass, and known product/backend dependencies have explicit status. **Design ready** is not **production ready**.

App-store release additionally requires real-device end-to-end validation, verified authentication and deletion, accurate privacy disclosures, legal/support links, store billing product configuration and entitlement verification, performance/privacy review, translations signed off, accessibility issues fixed and release-build evidence. Do not auto-submit/publish.

## 11 — Required response after every task

Report in Vietnamese using this compact format:

```
TASK: <ID and title>
BASE: <main SHA>    BRANCH: <branch>
IMPLEMENTED: <concise scoped changes, actual files>
DESIGN MAPPING: <screen IDs>
TESTS/CI: <commands, run links, pass/fail and evidence>
BACKEND/STORE DEPENDENCIES: <verified/proposed/blocked>
RISKS & REGRESSIONS: <explicit>
PR: <URL, status, merged/not merged>
NEXT ELIGIBLE TASK: <ID and prerequisites>
```

Do not claim that async work will proceed while not actually executing it. If running autonomously is supported in the user's authorized environment, proceed to the next task only after prerequisites and branch/merge approvals are satisfied. Otherwise stop with a clear next task.

## 12 — FIRST COMMAND TO EXECUTE NOW

1. Confirm accessible GitHub repository and current `main` HEAD.
2. Locate and open `RepCoach-AI-Final-C-Design-Package.zip` and verify its manifest.
3. Read the **actual** 33-task roadmap and mapping files, summarize any discrepancies with this brief.
4. Run current project baseline tests and inspect available GitHub Actions.
5. Inspect real backend access and API contracts without assuming connectivity.
6. Write `docs/implementation/00_BASELINE_AUDIT.md`, `docs/implementation/01_TASK_DEPENDENCIES.md` and a concise release-risk register.
7. Open a focused initial audit/baseline PR only if authorized; no sweeping rewrite.
8. Begin the first eligible implementation PR after prerequisites pass. Report test and CI evidence; preserve the camera engine.

**BEGIN IMPLEMENTATION: AUDIT THE LIVE REPOSITORIES AND FINAL C ZIP FIRST. THEN DELIVER WORKING, REVIEWABLE PRS IN DEPENDENCY ORDER.**
