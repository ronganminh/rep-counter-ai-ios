# CHANGE_LOG · Final C

RepCoach AI · 2026-10-22 · baseline = live canvas version 15 (`1792679976-e72b`), byte-compared before any edit (44 tracked files identical or whitespace-only to the Final B publish; 0 concurrent user edits).

Every modified active file has an untouched copy on the Backups page named `*.preFC-2026-10-22.dc.html`. The full pre-Final-C project is also included verbatim in the portable archive under `snapshots/pre-final-c/project/`.

| ID | File | Change | Reason (verified defect / requirement) | Verification |
|---|---|---|---|---|
| C-01 | — (test harness, not a design file) | Playwright font routing now serves `/vf/*.woff2` with CORS from any local origin | Final B "font-loading failures" were a **test-infrastructure** issue: the local `fonts.css` hard-codes `http://localhost:8790/vf/...`, so pages served from another port were CORS-blocked. Production pages load Google Fonts directly | 0 console errors on all 31 boards (inventory run); 118/118 incl. console check on the live snapshot served from a different port |
| C-02 | `RepCoach-AI-Final-B-Integrated-Prototype.dc.html` | Vietnamese aligned to the glossary: rep unit "rep" (was "lần"), "set" (was "hiệp"), "Streak", "Huy hiệu" (was "Thành tích"), Progress tab "Tiến bộ" (was "Tiến độ"), "Xóa" (was "Xoá"), "October 500" kept as product name | Consistency with the shipping app's `S.vi` (source of truth for existing VI terms) | VI journeys J8/J12/J16/J19/J21/J22/N2 pass; tests updated to "Tiến bộ" |
| C-03 | `RepCoach-AI-v2-Home-Exercises.dc.html` (H1) | LV card `340 / 500 XP`, bar 68 % → `370 / 500 XP`, bar 74 % | Data integrity: H1 is the pre-workout state (14 workouts, streak 9, 227/500); canonical XP before the +25 XP workout is 370 (395 after). Every other board already used 395 post-workout | Cross-board XP scan: only canonical values remain |
| C-04 | Prototype logic | Session `clientId` assigned at workout start; `save()` accepts only live/paused/interrupted sessions; second save of the same session is blocked | Verified defect: two finish events in one tick created a second record (`w-1020-b`) | N3 "Duplicate save attempt → one record" passes (15 workouts · 627 reps, server 15) |
| C-05 | Prototype logic + markup | 12 negative-path journeys (N1–N12) with UI states: tracking-lost banner (no rep counting, nothing subtracted), sync failure banner + Retry, AI-feedback-off state + Settings toggle, expired session re-auth with `returnTo`, merge conflict picker (upload blocked until resolved), Ask-to-Buy pending, restore verification failure, notification-denied, expired invite fallback, empty workout, app background auto-pause | Final C §13 negative paths | 67/67 Final C checks (393×852 and 375×667) |
| C-06 | Prototype panels | Journey-language switch (EN / VI) applied at journey start; new simulation controls; inspector rows Session / Tracking / AI feedback / Journey language; header note linking Final C | Final C §5 "demonstrate switching language across meaningful integrated journeys" | 7 journeys run in Vietnamese |
| C-07 | Prototype VI labels | Stat label "Reps" → "Rep" (was "Lần") on Home, Progress, workout detail | Found in Final C evidence review | Re-run 118/118 + 67/67 |
| C-08 | New `RepCoach-AI-Final-C-Handoff.dc.html` | Final C board: acceptance status, deliverables, tokens, components, mapping summary, engine protection, localization, QA evidence, decisions | Final C §2 dedicated page | Layout check, link check |
| C-09 | `canvas.json` | New page "Final C · Design QA & Developer Handoff" (after Final B); Final C board; 2 `preFC` backups appended on the Backups page; built from the live v15 index (no older index reused) | Final C §2 | Read-back after publish |
| C-10 | New project files `finalc/**` | All handoff deliverables (Markdown, JSON, ARB, CSV) and `finalc/evidence/*.png` published next to the canvas | Final C §17 | ZIP integrity + read-back |

**Not changed (by decision):** v1 Vietnamese boards (source preserved), App Store screenshots (no separately approved task), Phases 2–10 and Final A files (40 px chips and caption contrast are handled in the spec — D-24/D-25 — because a bulk rewrite of approved screens was judged unsafe), Final B docs board (historical record; superseded by Final C).

## AI Coach · PT ảo · 2026-11-25

Baseline: live canvas version `1795572370-fefd`; every Final C file compared by SHA-256 with `ASSET_MANIFEST.json` before editing (unchanged). **No locked screen was modified.**

| ID | File | Change | Reason |
|---|---|---|---|
| C-11 | New `RepCoach-AI-v2-AI-Coach-PT.dc.html` | Screens 1–4: 22 frames × EN/VI | Owner brief (AI Coach · PT ảo) |
| C-12 | New `RepCoach-AI-v2-AI-Coach-Body-Check-in.dc.html` | Screen 5: 7 frames × EN/VI | Owner brief, built after 1–4 |
| C-13 | `canvas.json` | New page "AI Coach · PT ảo" after Final C with the two boards and a title note; launch opens this page | Owner review on canvas |
| C-14 | `finalc/*` docs | Appended sections to APP_NAVIGATION_MAP, PRODUCT_DECISIONS (D-29–D-41), SCREEN_INVENTORY (+58 rows), SCREEN_TO_FLUTTER_MAPPING, API_AND_BACKEND_GAP_ANALYSIS; 158 new ARB keys in app_en/app_vi; new `aicoach/AI_COACH_PT_HANDOFF.md`; manifest regenerated | Handoff like Final C |

| C-15 | Both AI Coach boards | Owner decisions applied: credits (D-29) on Home pick (free once a day + "New suggestion · 1 credit"), AC-01d redefined as "new suggestion, no credits", next week 2 credits, body check-in 3; Anthropic Claude named in body consent (D-38); 18+ self-confirmation (D-37); camera + library and new preview frame AC-05g; moderation copy (D-40); AC-03e badged DRAFT (D-34); EN primary / VI needs-review badges (D-41) | Owner review 2026-11-25 |
| C-16 | Both AI Coach boards | Render-QA fixes: "No change" text #7C7C82 → #A1A1A6 (4.36 → 7.0:1); disabled-composer hint #5C5C62 → #A1A1A6; chips, banner links, inline Apply, Undo, toast and Delete-result targets 44/40 → 48 px; chat workout-card buttons stacked (VI label wrapped to 3 lines in a 48 px button) | AI_COACH_QA_REPORT.md |

Not changed: design tokens, component registry, all Phase 1–10, Final A/B/C boards.
