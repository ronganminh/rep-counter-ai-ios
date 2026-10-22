# FINAL_QA_REPORT

RepCoach AI · Final C · Master design QA · 2026-10-22

> Environment: Playwright Chromium (headless) against local copies of the **live canvas snapshot** (v15) plus the Final C edits; fonts routed to local Google-Fonts copies (incl. Vietnamese subsets). Repository audit read-only. Web search/fetch were unavailable (organisation setting), so store-policy items are not verified. Simulated behaviour (camera counting, OS prompts, stores, push, backend) is labelled SIMULATED and is **not** evidence of production functionality.

## 1 · Acceptance criteria (Final C §18)

| # | Criterion | Result | Evidence |
|---|---|---|---|
| 1 | Approved design system documented | PASS | `DESIGN_SYSTEM_TOKENS.json` (values cross-checked with repo `lib/theme/*`), `COMPONENT_REGISTRY.md` |
| 2 | All active screens inventoried | PASS | 536 frames · 162 families · 31 boards → `SCREEN_INVENTORY.csv` (0 unmapped) |
| 3 | 22 integrated journeys verified | PASS | 118/118 checks at 393×852, also 118/118 at 375×667 and 430×932 |
| 4 | Integrated prototype still works | PASS | live-snapshot run 118/118 before edits; final build 118/118 + 67/67 |
| 5 | Design-to-Flutter mapping exists | PASS | `SCREEN_TO_FLUTTER_MAPPING.md` (+ per-frame CSV) |
| 6 | Backend gaps honestly documented | PASS | `API_AND_BACKEND_GAP_ANALYSIS.md` (verified: 1 AI endpoint + health/static; everything else PROPOSED) · legacy engine repo inaccessible (stated) |
| 7 | EN + VI resources exported | PASS | `l10n/app_en.arb`, `l10n/app_vi.arb` — 4,286 keys, 0 ICU/placeholder errors |
| 8 | Localization gaps clearly identified | PASS (localization QA itself = **PARTIAL**) | `l10n/UNTRANSLATED_STRINGS_AUDIT.md/.csv`: 3,311 machine-assisted keys need native review; 899 sample-data strings to parameterise |
| 9 | Critical destructive flows correct | PASS | A-01 scopes (FA suite 94/94, P9 86/86), prototype J19 + VI J19, account deletion separate (link to P9-11e verified) |
| 10 | No unresolved critical navigation defects | PASS | 3,573 hrefs + asset srcs (incl. Final C board and deliverable links), 0 broken; prototype source links 0 broken; deep-link fallbacks N10; 1 inert `href="#"` component specimen in Phase 9 handoff (not navigation) |
| 11 | Accessibility issues documented **and addressed** | **PARTIAL** | Documented (§6). Addressed in spec/tokens (D-24 hit areas, D-25 contrast, line-height), prototype has 0 a11y probe findings; existing phase boards keep 40 px chips and `text3`-on-card captions (not bulk-edited) |
| 12 | Real engine preservation explicit | PASS | `MASTER_DESIGN_HANDOFF.md` §14 (VERIFIED class/event names, mapping, regression plan); roadmap W-1 gates |
| 13 | All deliverable files exist and are valid | PASS | JSON/ARB parse, ICU check, CSV parse, Markdown present — see §9 |
| 14 | Portable archive passes integrity verification | PASS | `RepCoach-AI-Final-C-Design-Package.zip`: `unzip -t` OK, SHA-256 manifest re-verified after extraction (§9) |
| 15 | Existing source designs and backups preserved | PASS | Only 2 active files modified; `preFC` backups + full pre-Final-C snapshot in the archive; earlier `orig`/`preFB` backups untouched |

**Overall: PARTIAL — READY FOR DEVELOPMENT of the Foundation, Design System, Navigation, Camera & Workout UI, History and Plans tracks (no backend dependency).** Account, sync, AI Coach, social, billing and push tracks are designed and mapped but **BLOCKED on backend APIs and owner decisions** (D-12, D-14). Full readiness also needs: accessibility items closed (criterion 11) and native Vietnamese review.

## 2 · Test suites

| Suite | Scope | Result |
|---|---|---|
| Final B journeys (`fbinteract.js`) | 22 journeys + B-01…B-15 checks, console, layout probe | **118/118** at 393×852 · 118/118 at 375×667 · 118/118 at 430×932 |
| Final C (`fcinteract.js`) | 12 negative paths + 7 journeys in Vietnamese + VI overflow probe + console | **67/67** at 393×852 · 67/67 at 375×667 |
| Phase 7 regression | social flows, links, unlabeled buttons | 51/51 |
| Phase 8 regression | premium flows, 84 hrefs | 54/54 |
| Phase 9 regression | auth/account incl. A-01 routing | 86/86 |
| Phase 10 regression | notifications, moved-session reminder | 73/73 |
| Final A regression | FA-01…FA-12 incl. delete scopes, expiry | 94/94 |
| Link audit | all static `href`/`src` across 32 active boards (incl. Final C) + prototype source links | 3,573 checked · 0 broken |
| Layout/console audit | every frame on every active board at canvas width | 0 console errors on 31 boards — §5 |
| Live read-back (canvas v16) | published prototype, Home and Final C board re-downloaded and re-tested | identical to source (whitespace-normalised) · 118/118 + 67/67 on the live copies |
| Font check | Barlow Condensed 600/800 + Inter 500/700 with Vietnamese | loaded, `document.fonts.check` true, VI subset files requested; repo TTFs contain VI glyphs |

## 3 · Integrated journeys

| # | Journey | Checks | Result | Screenshot |
|---|---|---|---|---|
| 1 | New user → onboarding → guest → first workout | 6 | PASS | Final B `fbqa/J01.png` |
| 2 | Camera denied → manual tracking | 4 | PASS | Final B `fbqa/J02.png` |
| 3 | Exercise library → train → results → history | 3 | PASS | Final B `fbqa/J03.png` |
| 4 | Workout interrupted → recovery | 3 | PASS | Final B `fbqa/J04.png` |
| 5 | Offline save → sync later | 5 | PASS | Final B `fbqa/J05.png` |
| 6 | Results → AI feedback | 3 | PASS | Final B `fbqa/J06.png` |
| 7 | Results → share preview | 5 | PASS | Final B `fbqa/J07.png` |
| 8 | Home → workout plan → scheduled workout | 4 | PASS | Final B `fbqa/J08.png` |
| 9 | Progress → personal records | 2 | PASS | Final B `fbqa/J09.png` |
| 10 | Progress → achievements | 2 | PASS | Final B `fbqa/J10.png` |
| 11 | AI Coach → credits → contextual paywall | 3 | PASS | Final B `fbqa/J11.png` |
| 12 | Guest → Friends → auth → return | 5 | PASS | Final B `fbqa/J12.png` |
| 13 | Guest data → account migration | 2 | PASS | Final B `fbqa/J13.png` |
| 14 | Friends → challenge invitation → head-to-head | 3 | PASS | Final B `fbqa/J14.png` |
| 15 | Social notification → challenge | 4 | PASS | Final B `fbqa/J15.png` |
| 16 | Pro discovery → purchase simulation | 2 | PASS | Final B `fbqa/J16.png` |
| 17 | Restore subscription | 4 | PASS | Final B `fbqa/J17.png` |
| 18 | Profile → Settings → language | 1 | PASS | Final B `fbqa/J18.png` |
| 19 | Profile → Privacy → delete history safely | 3 | PASS | Final B `fbqa/J19.png` |
| 20 | Notification → deep link → destination | 2 | PASS | Final B `fbqa/J20.png` |
| 21 | Profile → Help / Support | 3 | PASS | Final B `fbqa/J21.png` |
| 22 | Live workout → pause / resume → finish | 4 | PASS | Final B `fbqa/J22.png` |

## 4 · Negative paths (Final C)

| # | Path | Checks | Result | Screenshot |
|---|---|---|---|---|
| N1 | Camera tracking lost → counting paused → resumes | 4 | PASS | `evidence/N01.png` |
| N2 | Cloud sync failure → retry → synced once | 7 | PASS | `evidence/N02.png` |
| N3 | Duplicate save attempt → one record | 2 | PASS | `evidence/N03.png` |
| N4 | AI feedback disabled → turn on | 3 | PASS | `evidence/N04.png` |
| N5 | Expired session → sign in again → return | 4 | PASS | `evidence/N05.png` |
| N6 | Guest migration conflict → resolve | 4 | PASS | `evidence/N06.png` |
| N7 | Purchase pending (Ask to Buy) → approved | 3 | PASS | `evidence/N07.png` |
| N8 | Restore fails → retry → restored | 3 | PASS | `evidence/N08.png` |
| N9 | Notification permission denied → inbox works | 3 | PASS | `evidence/N09.png` |
| N10 | Expired notification deep link → fallback | 3 | PASS | `evidence/N10.png` |
| N11 | Incomplete workout (0 reps) → nothing saved | 3 | PASS | `evidence/N11.png` |
| N12 | App interruption → auto-pause → resume → finish | 4 | PASS | `evidence/N12.png` |

Also covered by existing suites: camera denied (J2), incomplete workout / interruption (J4, FA-10), offline save (J5), AI request failed (J6), no credits (J11), guest social access (J12), history deletion (J19, FA-08), account deletion (P9-11e flow, P9 suite), permission denied camera (J2).

Vietnamese journeys: J8, J12, J16, J19, J21, J22, N2 — `evidence/VI-*.png` (393×852) and `evidence/375-VI-J08.png`.

## 5 · Visual QA per board (layout audit at canvas width)

`scroll-below-fold` = content intentionally inside a scroll area (not a defect). Other categories are reported in full.

| Board | Frames | Findings |
|---|---|---|
| Main | 0 | none |
| RepCoach-AI-App-Icon | 1 | none |
| RepCoach-AI-App-Store-Screenshots-EN | 5 | content-clipped-y 4, text-outside-frame 74 |
| RepCoach-AI-Camera | 5 | none |
| RepCoach-AI-Design-System | 1 | none |
| RepCoach-AI-Final-A-Components-and-Handoff | 0 | none |
| RepCoach-AI-Final-A-Missing-Screens | 23 | scroll-below-fold 1 |
| RepCoach-AI-Final-A-Missing-Screens-Data-and-Support | 31 | none |
| RepCoach-AI-Final-B-Integrated-Prototype | 1 | scroll-below-fold 26 |
| RepCoach-AI-Final-B-Integration-Docs | 0 | none |
| RepCoach-AI-Flow | 1 | none |
| RepCoach-AI-HUD | 10 | none |
| RepCoach-AI-History-Settings | 8 | text-outside-frame 54, small-target 1 |
| RepCoach-AI-Home | 6 | content-clipped-y 1, small-target 2 |
| RepCoach-AI-Onboarding | 5 | none |
| RepCoach-AI-Results | 3 | none |
| RepCoach-AI-v2-Home-Exercises | 13 | small-target 3 |
| RepCoach-AI-v2-Phase-10-Handoff | 0 | none |
| RepCoach-AI-v2-Phase-10-Notifications | 39 | scroll-below-fold 115 |
| RepCoach-AI-v2-Phase-10-Notifications-Settings-and-Recovery | 48 | scroll-below-fold 148 |
| RepCoach-AI-v2-Phase-2-Workout-Plans | 29 | none |
| RepCoach-AI-v2-Phase-3-Dashboard-Analytics | 25 | small-target 8 |
| RepCoach-AI-v2-Phase-4-Personalized-AI-Coach | 35 | small-target 15, text-outside-frame 3 |
| RepCoach-AI-v2-Phase-5-Gamification-Challenges | 29 | content-clipped-y 2, small-target 3 |
| RepCoach-AI-v2-Phase-6-Real-time-Voice-Coach | 35 | small-target 22, content-clipped-y 2 |
| RepCoach-AI-v2-Phase-7-Social-and-Competition | 38 | small-target 27 |
| RepCoach-AI-v2-Phase-8-Handoff | 0 | none |
| RepCoach-AI-v2-Phase-8-Premium-and-Monetization | 65 | none |
| RepCoach-AI-v2-Phase-9-Account-and-Profile | 40 | scroll-below-fold 205 |
| RepCoach-AI-v2-Phase-9-Auth | 40 | none |
| RepCoach-AI-v2-Phase-9-Handoff | 0 | none · inert specimen link 1 |

Interpretation: App Store screenshots (`text-outside-frame`) and v1 History-Settings (horizontal chip rows) are **intentional**, pre-existing and out of scope (unchanged per brief). `small-target` = 40 px chips/segments (D-24). `content-clipped-y` 2–7 px = Barlow line-height 0.9 numerals (V-9, cosmetic).

## 6 · Accessibility QA

| ID | Finding | Severity | Status |
|---|---|---|---|
| A11Y-01 | Filter chips / segments 40 px (P3–P7, v1 Home sheet "Xong") | MEDIUM | Spec: 48 dp hit area (D-24); canvas unchanged |
| A11Y-02 | `text3` #7C7C82 on cards 4.36:1 (< 4.5 for body) | LOW–MEDIUM | Spec: use `text2` on surfaces or lighten (D-25) |
| A11Y-03 | `textDisabled` never carries information | INFO | Rule in tokens |
| A11Y-04 | Prototype: unlabeled buttons, overflow, clipped text, <44 targets on 34 end screens (EN), 19 end screens (VI) | — | 0 findings |
| A11Y-05 | Live regions: rep counter, sync, status banners; modals `role=dialog` | — | Present in prototype; ARB includes screen-reader labels |
| A11Y-06 | Reduced motion | — | `prefers-reduced-motion` disables animations in all v2/Final files; Flutter rule in tokens |
| A11Y-07 | Dynamic Type / text scale | UNVERIFIED in canvas | Required in Flutter goldens (roadmap DS-2) |
| A11Y-08 | VoiceOver/TalkBack on device | UNVERIFIED | Needs device testing during implementation |

Contrast (measured): text 17.84:1, text2 7.65:1, text3 4.74:1 on bg / 4.36:1 on surface, accent 16.68:1, onAccent on accent 16.68:1.

## 7 · Data consistency

- Canonical sample verified on Home, Progress, Results, History, Plans, AI Coach (credits), Achievements (8/12), Friends/race (35 vs 52), Pro, Profile (LV 4 · 395/500), Notifications (October 500 262/500 after; 227/500 before) — prototype assertions + cross-board scan.
- Fixed: Home H1 pre-workout XP 340 → 370 (C-03). No other XP, October 500, workout-count or credit value conflicts found.
- Rules verified in prototype: manual reps never counted as camera / for challenges (J2); duplicate saves blocked (N3); one AI charge per request (J11); XP not re-awarded on reopening a notification (N10 inspector unchanged); Pro only after verification (J16, N7, N8); hypothetical demo runs tagged "not the canonical sample".

## 8 · Font-loading investigation (Final B open item)

Root cause: test infrastructure. The local font stylesheet used by the harness (`mig/serve/vf/fonts.css`) contains absolute URLs `http://localhost:8790/vf/...`; when a page was served from port 8792 the browser blocked those cross-origin font files (no CORS header). Production canvas pages load `fonts.googleapis.com` directly and are unaffected. Fix: harness serves font files with `access-control-allow-origin: *` for any local origin (C-01). Result: 0 font/console errors on all 31 boards; Vietnamese subsets load. Not verifiable here: live Google Fonts fetch (blocked by the sandbox egress proxy).

## 9 · Deliverable validation

See `ASSET_MANIFEST.json` for every file with size and SHA-256. Checks: all `.json`/`.arb` parse; ARB ICU validation (formatjs parser) 0 errors; key parity EN/VI; CSV files parse; archive `unzip -t` + post-extraction SHA-256 comparison.

## 10 · Known issues & deferred items

1. Localization: native VI review of 3,311 keys; 899 sample-data strings to parameterise; 28 VI variant conflicts to choose.
2. Accessibility A11Y-01/02 on existing phase boards (spec-level fix only).
3. Store policy items not verified (no web access) — `RELEASE_CHECKLIST.md`.
4. Unresolved configuration: prices, product IDs, support email, Terms/Privacy URLs (backend pages exist; owner to confirm), app version/build, auth provider.
5. Legacy engine repo `Juliolayme/rep-counter-ai` not accessible; mobile repo states the engine is vendored in `rep_counter_app`.
6. App Store screenshots still show the v1 3-tab UI (not modified per brief).
7. Separate canvas files do not share live state; the integrated prototype is the shared-state reference.

## 11 · Test limitations

- Headless Chromium only; no iOS/Android devices, no real camera, stores, push or backend.
- Canvas viewer rendering verified by read-back of published files, not by driving the claude.ai canvas UI.
- Alternate states inside phase-file JavaScript were inventoried by literal extraction (not by visiting every state).
