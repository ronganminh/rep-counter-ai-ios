# AI Coach · PT ảo — render QA report

RepCoach AI v2 · 2026-11-25 · boards `RepCoach-AI-v2-AI-Coach-PT.dc.html` (AC-01…AC-04) and `RepCoach-AI-v2-AI-Coach-Body-Check-in.dc.html` (AC-05).

## Method

- Headless Chromium (Playwright) with the real fonts (Inter 400–700, Barlow Condensed 600–800, latin + vietnamese subsets from Fontsource, routed in place of Google Fonts), dark colour scheme, `prefers-reduced-motion: reduce`.
- Every phone frame (29 frames × EN/VI = 58) rendered at its design width **393 px** and again forced to **375 px** → **116 frame renders**.
- Checks per frame (script `qa/acqa.js`, raw results `ai_coach_render_qa.json`):
  1. **Text overflow** — any text box outside the frame; any button/link whose label is wider or taller than the control.
  2. **Clipping** — content column or bottom sheet taller than its box (frames with a sheet: the screen behind the scrim is allowed to scroll).
  3. **Truncation** — text cut by `overflow:hidden` / ellipsis (screen-reader-only labels excluded).
  4. **Contrast** — WCAG 2.1 AA: 4.5:1 for text < 24 px (< 18.66 px bold), 3:1 above; background composited through translucent layers; disabled controls exempt; text hidden under a scrim skipped.
  5. **Touch targets** — every visible link, button, input, label-wrapped radio/checkbox and switch ≥ **48 × 48 px** (48 dp).
  6. Page errors, running animations under Reduce Motion, unlabeled controls.

## Results

| Run | Frames | Overflow | Clipped | Truncated | Contrast fails | Targets < 48 | Page errors | Animations | Unlabeled |
|---|---|---|---|---|---|---|---|---|---|
| First pass (before fixes) | 116 | 0 | 0* | 0* | 32 | 76 | 0 | — | — |
| After fixes (published) | 116 | **0** | **0** | **0** | **0** | **0** | **0** | **0** | **0** |

\* First-pass "clipped/truncated" hits were harness false positives (screen behind a sheet; screen-reader-only spans) and the harness was corrected. A visual review of the first pass then found one real defect the harness did not yet detect — the VI label "Áp dụng cho hôm nay" wrapped to three lines inside a 48 px button at 375 px. The "label taller/wider than control" check was added, proven on a reproduction, and the final run is clean.

## Defects fixed

| # | Defect | Frames | Fix |
|---|---|---|---|
| Q-1 | "No change" caption `#7C7C82` on card = 4.36:1 (same issue as D-25) | AC-04a, AC-04b | `#A1A1A6` (7.0:1) |
| Q-2 | Disabled-composer hint `#5C5C62` = 2.96:1 | AC-03c, AC-03f | hint stays `#A1A1A6`; only the input/button show disabled |
| Q-3 | Targets 44 px (chips, "See options", inline Apply, toast Undo, Delete result) and 40 px (row Undo) | AC-01g, AC-02e, AC-03b, AC-03f, AC-04a, AC-04b, AC-05e | all raised to ≥ 48 × 48 |
| Q-4 | VI "Áp dụng cho hôm nay" wrapped to 3 lines in a 48 px button (2-column grid) | AC-03d, AC-03e | card buttons stacked full width |

## Evidence

`evidence/393-en-<frame>.png` (English at design width) and `evidence/375-vi-<frame>.png` (Vietnamese at the narrow width) for all 29 frames.

## Not covered

- Native iOS/Android Dynamic Type and VoiceOver/TalkBack runs (needs the Flutter build; goldens listed in COMPONENT_REGISTRY guidance).
- The Vietnamese copy is machine-assisted and still needs native review (D-41) — render QA proves fit, not wording.
- Canvas-only annotations (FOLD marker, frame labels) are not part of the app UI and were not checked.
