# 01 · Task dependencies and PR sequence

Source of truth for task IDs and acceptance criteria: `docs/design/v2-final-c/handoff/FLUTTER_IMPLEMENTATION_ROADMAP.md` (33 tasks). This file only adds the dependency graph, eligibility and the actual PR order. Where it differs from the roadmap or the brief, the reason is stated in §4.

## 1 · The 33 tasks

| ID | Title (short) | Depends on (roadmap) | Extra gate | Status (2026-10-29, main `1b417ce`) |
|---|---|---|---|---|
| F-1 | gen-l10n infrastructure | — | — | DONE (merged) |
| F-2 | Build metadata + config placeholders | F-1 | D-14 values stay unresolved (defaults = shipping values) | DONE (merged) |
| F-3 | Local DB for workouts + migration | F-1 | D-16 approved 2026-10-23 (L-D16) | DONE (merged) |
| F-4 | Workout draft persistence | F-3 | D-06 (12 h, proposed) | DONE (merged, Resume merged) |
| DS-1 | Theme tokens to Final C | — | D-25, D-26 | DONE (merged) |
| DS-2 | Shared widgets | DS-1, F-1 | D-24 | DONE (merged) |
| N-1 | 5-tab shell | DS-2 | D-15 (router) | DONE (merged, no go_router) |
| N-2 | Deep links + `returnTo` | N-1 | D-15; universal-link domain | NEXT (no backend): in-app link router for `repcoach://` destinations + reminder-notification tap → session, with the §5 fallbacks. Universal links BLOCKED (needs `apple-app-site-association` / `assetlinks.json` hosted on the D-14 domain and an owner decision on the scheme) |
| A-1 | Auth + guest state machine | N-2 | **D-12** decided: Supabase Auth, Apple + Google + email | Client + Supabase repository + delete-account merged, behind `ENABLE_ACCOUNTS` (off). Go-live BLOCKED on owner device checks D1–D11 and deploying `delete-account` |
| A-2 | Guest → account merge | A-1, F-3 | backend sync API | BLOCKED (sync backend). Will add interface + fake behind a flag; schema in 06 |
| E-1 | Exercises tab | N-1 | D-28 | DONE (merged) |
| W-1 | HUD restyle (no engine change) | DS-2 | replay CI mandatory | DONE (merged) |
| W-2 | Hold-to-finish, Back sheet, idempotent finish | W-1 | — | DONE (merged) |
| W-3 | Results v2 + AI card states + share toggles | W-1 | — | DONE (merged) |
| W-4 | Manual tracking + guided timer | W-1, F-3 | D-18 | Manual entry DONE (merged). **Guided timer NEXT** (no backend, L-D18 deferred it) |
| W-5 | Recovery screen | F-4 | D-06 | DONE (merged) |
| PL-1 | Multi-day plan | N-1 | PL-1 decided (owner 2026-10-26) | DONE (PL-1a/b/c merged) |
| PL-2 | Reschedule missed session | PL-1 | — | DONE inside PL-1b (reschedule sheet, history unchanged, reminder follows: `plan_schedule_test`, `plan_repository_test`, `reminder_test`). **Train sheet shows today's planned session: NEXT** |
| H-1 | Progress tab split from History | N-1 | D-05 | DONE (merged) |
| H-2 | Delete scopes + tombstones | H-1, F-3, A-1 | account scope needs backend | Phone scope exists (Settings › clear history on this phone). Account / both scopes BLOCKED (sync backend); tombstones designed in 06 |
| AI-1 | Credits ledger client | A-1 | backend credits API, D-08 | BLOCKED (credits backend, D-08). Interface + fake behind a flag; schema in 06 |
| AI-2 | Coach chat + contextual paywall | AI-1, P-1 | backend | BLOCKED (AI-1, P-1) |
| G-1 | Server XP / achievements sync / challenges | A-1 | backend XP | BLOCKED (XP backend). Interface + fake; schema in 06 |
| S-1 | Friends, requests, block/report | A-1 | backend social | BLOCKED (social backend). Interface + fake; schema in 06 |
| S-2 | Races, leaderboards | S-1 | backend | BLOCKED (S-1) |
| P-1 | StoreKit / Play Billing + server verification | A-1 | **D-13, D-14**, backend verify | BLOCKED (D-13 prices/product IDs, store accounts, server verification). Interface + fake behind `billingEnabled` (off) |
| P-2 | Membership / restore / rewarded ads | P-1 | ad SDK + policy | BLOCKED (P-1, ad SDK + policy) |
| NT-1 | Local reminders + permission flow | PL-1 | D-19 | DONE (merged; 5.1.1(iv) rules L-D24 merged) |
| NT-2 | Push + inbox + deep links | NT-1, N-2 | backend push, APNs/FCM config | BLOCKED (push backend, APNs/FCM). Interface + fake |
| L-1 | Migrate inline strings to ARB keys | F-1 | — | PARTIAL: 267 `context.tr` calls left in 30 files; more slices possible (no backend) |
| L-2 | Native VI review + parameterise sample strings | L-1 | native reviewer | DEFERRED by owner (L-D14) |
| Q-1 | Accessibility pass | DS-2 | device VoiceOver/TalkBack | PARTIAL: code-level pass on new screens NEXT; device VoiceOver/TalkBack UNVERIFIED |
| Q-2 | Release readiness gate | all | owner authorisation | Prepare the gate only (readiness script + checklist for v2); **no release** |

## 2 · Dependency graph

```mermaid
graph LR
  F1[F-1 gen-l10n] --> F2[F-2 config]
  F1 --> F3[F-3 local DB]
  F1 --> DS2[DS-2 widgets]
  F1 --> L1[L-1 strings]
  DS1[DS-1 tokens] --> DS2
  DS2 --> N1[N-1 5 tabs]
  DS2 --> W1[W-1 HUD]
  DS2 --> Q1[Q-1 a11y]
  N1 --> N2[N-2 deep links]
  N1 --> E1[E-1 exercises]
  N1 --> H1[H-1 progress]
  N1 --> PL1[PL-1 plans]
  PL1 --> PL2[PL-2 reschedule]
  PL1 --> NT1[NT-1 reminders]
  W1 --> W2[W-2 finish/exit]
  W1 --> W3[W-3 results]
  W1 --> W4[W-4 manual]
  F3 --> W4
  F3 --> F4[F-4 drafts] --> W5[W-5 recovery]
  L1 --> L2[L-2 VI review]
  N2 --> A1[A-1 auth]
  A1 --> A2[A-2 merge]
  F3 --> A2
  H1 --> H2[H-2 delete scopes]
  A1 --> H2
  A1 --> AI1[AI-1 credits] --> AI2[AI-2 coach]
  A1 --> G1[G-1 XP]
  A1 --> S1[S-1 friends] --> S2[S-2 races]
  A1 --> P1[P-1 billing] --> P2[P-2 membership]
  P1 --> AI2
  NT1 --> NT2[NT-2 push]
  N2 --> NT2
  classDef blocked fill:#3a1f1f,stroke:#ff5a5f,color:#fff;
  class A1,A2,H2,AI1,AI2,G1,S1,S2,P1,P2,NT2,L2 blocked;
```

## 3 · PR sequence actually executed

PRs are stacked because the owner is away and nothing is merged: each PR's base is the previous task branch, stated in its description. When the owner merges bottom-up, GitHub retargets the next PR to `main`.

| # | Task | Branch | Base |
|---|---|---|---|
| 0 | W0 baseline docs | `claude/nifty-pascal-mcj79r` | `main` |
| 1 | DS-1 | `claude/v2-ds1-tokens` | #0 |
| 2 | F-1 | `claude/v2-f1-gen-l10n` | #1 |
| 3 | F-2 | `claude/v2-f2-build-config` | #2 |
| 4 | DS-2 | `claude/v2-ds2-shared-widgets` | #3 |
| 5 | N-1 | `claude/v2-n1-five-tabs` | #4 |
| 6+ | E-1 → H-1 → W-1 → W-2 → W-3 → PL-1 → PL-2 → NT-1 → L-1 (slices) → Q-1 | `claude/v2-<id>-<slug>` | previous |

Live status per PR is kept in `03_DECISION_LOG.md` (§ PR log).

## 4 · Deviations from the roadmap and the brief

1. **DS-1 before F-1.** Both have no prerequisites; the owner asked for design foundations first. Order of the two does not change any dependency.
2. **N-1 without `go_router`.** D-15 is only PROPOSED. The 5-tab shell keeps Navigator 1.0 with a single root navigator (tab roots swapped in place, pushes full screen), which is reversible and keeps `CameraPage → ResultPage` on the root navigator. Per-tab stacks and the router decision move to N-2, where deep links actually need them.
3. **F-2 does not replace shipping legal values with placeholders.** The repo already ships a support email and privacy URL; replacing them with `[SUPPORT_EMAIL]` would break the live feedback/legal links. They become overridable `--dart-define` defaults and stay listed as "owner to confirm" (D-14). Product IDs default to empty (billing off).
4. **F-3, F-4, W-4, W-5 are held** for an explicit D-16 decision: moving every user's workout history to a new store is a data migration, which the owner asked not to run unattended. Everything that does not need it proceeds.
5. **L-1 is split** into several PRs by feature folder (394/395 call sites is too large for one reviewable PR).
6. **Q-1** delivers code-level fixes (hit areas, contrast tokens, semantics) only; VoiceOver/TalkBack/Dynamic Type on devices stay UNVERIFIED.
7. **Brief wave W2 "auth guards"** cannot ship before A-1; they are not built.
8. **W-1 (HUD restyle) was held for design source**, because the first archive had no HUD frames. The owner then supplied `design-source/project/*.dc.html` and `handoff/evidence/*.png` (copied unmodified to `docs/design/v2-final-c/`). W-1 and the visual part of W-3 are therefore unblocked, view layer only. **W-2 went first** because its acceptance criteria are behavioural (quick-tap hint, 1 s hold, Back sheet, discard confirm, single finish) and do not depend on the restyle; W-1/W-3 are stacked on top of it.

## 5 · Work order after the merge train (2026-10-29)

No backend needed, one small PR each, in dependency order:

1. **PL-2b** Train sheet: today's planned session first (start it with the plan targets), then free workout and manual. Recovery days and a done session say so.
2. **N-2a** In-app link router: `repcoach://plan/session/{id}`, `workouts/{id}/feedback`, `inbox`, `membership`, `friends/requests`, `races/{id}`, `invites/{id}`, `challenges/{id}` → destination or the §5 fallback; reminder notification tap opens the session (never over a live workout). No OS-level URL registration yet.
3. **W-4b** Guided timer (camera off): timed sets with rest, saved as a manual timed record.
4. **Q-1b** Accessibility pass on the v2 screens added since Q-1 (plans, reminders, auth, recovery, manual): semantics labels, 48 dp targets, text scale 2.0.
5. **Q-2a** Release gate preparation for v2: readiness checks (5.1.1(iv) copy, version row, no `[PLACEHOLDER]`), RELEASE_CHECKLIST statuses. No release.
6. **06** `docs/implementation/06_SUPABASE_SCHEMA_PROPOSAL.md`: Postgres + RLS + Edge Functions for sync, tombstones, credits, XP, social, entitlements, push tokens. Proposal only; no tables are created.
7. **Backend seams** (behind flags, off, with in-memory fakes and tests): sync (A-2), credits (AI-1), XP (G-1), social (S-1), entitlements (P-1), push registration (NT-2).

BLOCKED until the owner decides or provides something: universal links (domain files), A-1 go-live (device checks + `delete-account` deploy), sync / credits / XP / social / push backends (approve 06 first), billing (D-13 prices, product IDs, store setup), ads (SDK + policy), L-2 (native review).

