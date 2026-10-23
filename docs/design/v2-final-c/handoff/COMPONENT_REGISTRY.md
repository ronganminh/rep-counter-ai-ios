# COMPONENT_REGISTRY

RepCoach AI · canonical component registry · Final C · 2026-10-22

**Limitation (stated plainly):** Claude Design `.dc.html` files cannot import live shared components from each other. Every phase file carries its own copy of the markup produced by the shared Python generator helpers (Phase 8 `lib.py` → Phase 9 `c9.py` → Phase 10 `c10.py` → Final A `cfa.py`), so phases 8–10, Final A and Final B are *generated from one source*, while v1 and Phases 2–7 were authored separately. Final C therefore consolidates the **specification and the Flutter mapping**; it does not claim the canvas files share live components. Tokens: `DESIGN_SYSTEM_TOKENS.json`.

Columns: **Canonical source** = the design reference to copy · **Flutter** = existing widget (VERIFIED in repo `3594d8a`) or PROPOSED widget · **Superseded** = variants that must not be implemented.

| # | Component | Canonical source | Inputs / variants | States | Interactions & a11y | Flutter | Superseded / deprecated |
|---|---|---|---|---|---|---|---|
| 1 | **App tab bar** | Final B prototype `tabbar_dyn` | 5 items, `Train` centre (52 px lime disc, −22 px, 5 px bg ring), labels 11/600 | active (accent), inactive (text3), hidden | `aria-current=page`; inert during live workout; tap active tab → pop to root | `AppTabScaffold` + `TrainTabButton` (PROPOSED) replacing `AppShell` `NavigationBar` (VERIFIED, 3 tabs) | v1 3-tab bar (Tập/Lịch sử/Cài đặt); repo `NavigationBar` default style |
| 2 | **Button** | Phase 8 `btn()` | primary 56 · secondary 48 · ghost 44 · danger · disabled; full/compact; icon leading | default, pressed (120 ms), disabled (`aria-disabled`), loading | one primary per screen; destructive never primary until confirmed | Material `FilledButton`/`OutlinedButton` themed in `app_theme.dart` (VERIFIED theme exists); add `AppButton` wrapper (PROPOSED) | ad-hoc pill buttons in v1 with 40–52 px heights |
| 3 | **Card** | Phase 8 `card()` | surface, r16, 1 px border; accent-border variant | — | — | `Card` theme / `MetricCard` (VERIFIED `widgets/product_ui.dart`) | — |
| 4 | **List row** | Phase 8 `lrow()` / Final B `rowb()` | icon tile 36/r10, title 15/600, sub 12/500, chevron or trailing control; first/divided | default, pressed, disabled | whole row is the target (≥56 px) | `SettingsRow` (VERIFIED) | — |
| 5 | **Switch row** | Final B `srow()` | 52×32 visual, **56×44 hit area** | on/off/disabled | `role=switch`, label = row title | `SwitchListTile` themed; `SettingsRow` + `Switch` (VERIFIED pattern) | Phase 10 `switch_row` without enlarged hit area |
| 6 | **Segmented control** | Phase 10 `seg()` | 2–4 options, 44 px items | selected/unselected | `radiogroup` / `radio` | `SegmentChip` (VERIFIED) → `SegmentedButton` themed | — |
| 7 | **Chip / filter chip** | Phase 8 `chip()` (status), P4–P7 filter chips | status tones; filter chips 40 visual | selected | **hit area ≥ 48 dp** (D-24) | `ChoiceChip`/`FilterChip` with `materialTapTargetSize: padded` | 40 px chips without padded hit area (P3–P7) |
| 8 | **Text input** | Phase 9 `field()` | label above, 52 px field, r14, helper/error line, trailing action (eye) | default, focus (accent), error (danger + icon), ok, disabled | `aria-describedby` helper; autofill hints | `TextField` themed | — |
| 9 | **Type-to-confirm** | Final A FA-08e/f/g · Final B clear | word (DELETE / XÓA), scope text | locked → unlocked (case-insensitive) → working → done/failed/partial | button `aria-disabled` until match | `TypeToConfirmField` (PROPOSED) generalising `_DeleteDataDialog` (VERIFIED in `settings_page.dart`) | v1 S3 dialog visuals |
| 10 | **Bottom sheet** | Phase 8 `scrim_sheet()` | r28 top, grabber, 10/20/34 padding | open/closing | `role=dialog`, focus trap, drag/scrim dismiss (not for destructive) | `showModalBottomSheet` themed (VERIFIED usage) | — |
| 11 | **OS permission prompt** | Phase 10 `os_card` (simulated) | — | — | platform-rendered; always after a pre-permission screen | `permission_handler` (VERIFIED) | — |
| 12 | **Banner** | Phase 8 `banner()` | tones ok/warn/err/lime/neutral; title + body; optional action | — | `role=status` | `AppBanner` (PROPOSED) | various per-phase inline notices |
| 13 | **Toast** | Final B overlay / FA-11 | icon + text + close 44 | visible/auto-dismiss (4 s, proposed) | never over HUD; above tab bar | `ScaffoldMessenger` SnackBar themed (PROPOSED style) | — |
| 14 | **Status hero** | Phase 8 `status_hero()` | 96 icon disc, 26/700 title, body | empty, error, success, pending | one recovery action | `StatusHero` (PROPOSED) | — |
| 15 | **Stat tile** | Final B `stat()` / v2 Home | label, Barlow 30 value, sub | loading skeleton | tabular numbers | `MetricCard` (VERIFIED) | — |
| 16 | **Progress meter / challenge card** | Final B `octcard()` | 8 px track, accent fill, value/target, pace text | behind/on pace/complete | text equivalent of the bar | `ChallengeMeter` (PROPOSED) | — |
| 17 | **Hero ring / app mark** | Phase 8 `hero_ring()`, App Icon | sizes 110–168 | — | decorative (`aria-hidden`) | `CustomPainter` (PROPOSED); icon assets VERIFIED `assets/icon` | — |
| 18 | **Loading** | Phase 8 `spin()` + shimmer | spinner 20–36, skeleton rows | — | `role=status` text | `CircularProgressIndicator` themed | — |
| 19 | **Sync status badge** | FA-11 · Final B Home chip | guest-only / pending n / offline n / failed / synced | — | text, not colour only | `SyncStatusBadge` (PROPOSED) | — |
| 20 | **HUD counter** | v1 HUD + Final B HUD | Barlow 120 (v2) / 200 (repo hero) | live, paused, tracking-lost, holding | `aria-live` "N reps counted" | **`WorkoutHud`** (VERIFIED `widgets/workout_hud.dart`) — bind to `WorkoutUiState` | any UI-only counter |
| 21 | **Hold-to-finish** | v1 HUD A3 → FA-10a | 76 disc, 1 s fill, quick-tap hint | idle/holding/complete | pointer down/up; reduced-motion = static fill | inside `WorkoutHud` (VERIFIED `AppMotion.holdToEnd = 1 s`) → extract `HoldToFinishButton` (PROPOSED) | tap-to-finish |
| 22 | **Glass HUD button** | `cfa.glass_btn` | 64 disc + label | — | ≥72 px wide target | in `WorkoutHud` | — |
| 23 | **Privacy badge** | `cfa.privacy_badge` | "On-device" shield | — | — | `PrivacyBadge` (PROPOSED) | — |
| 24 | **Tracking-lost banner** | Final C HUD | top banner at y 300 | — | `role=status`; no rep decrement | from `PlacementStatus` / `RepAbortReason` (VERIFIED) | — |
| 25 | **Rep feedback pill** | repo | countedClean/Warning/placementInterrupted/poseLost | — | — | `RepFeedbackPill` (VERIFIED) | — |
| 26 | **Result hero + AI feedback card** | FA-03 / FA-05 / Final B results | total, push-ups, held, time, record, sync line | AI: idle/loading/ready/failed/off/consent | AI card says "doesn't use AI credits" | `ResultHero`, `ResultFeedbackCard` (VERIFIED) | — |
| 27 | **Auth gate** | Phase 9 P9-01e · Final B gateway | reason text, returnTo, providers | guest/expired | never blocks training | `AuthGateView` (PROPOSED) | — |
| 28 | **Merge preview** | P9-06b · Final C conflict | local/matched/new counts, conflict picker | preview/conflict/working/done | backup blocked until conflict resolved | `MergePreview` (PROPOSED) | — |
| 29 | **Credits chip / usage meter** | P8-05 | n / max, ledger rows | low (grey, never red) / zero | — | `CreditsChip` (PROPOSED) | — |
| 30 | **Plan card (Pro)** | P8-03 / Final B pro | price from SDK, period, badge | selected (2 px accent border) | `radio` | `ProPlanCard` (PROPOSED) | hard-coded prices |
| 31 | **Inbox row** | Phase 10 `nrow` | category icon, title, sub, time, unread dot | unread/read | whole row; deep link | `InboxRow` (PROPOSED) | — |
| 32 | **In-app push banner** | Final B overlay | app mark, title, body, dismiss | — | held during workouts | `InAppNotificationBanner` (PROPOSED) | — |
| 33 | **Avatar** | Phase 9 `avatar()` | initials, sizes 32–64 | — | decorative with name nearby | `CircleAvatar` themed | — |
| 34 | **Section caption** | Phase 8 `cap()` | 12/600 uppercase +6% tracking | — | — | `SectionLabel` (VERIFIED) | — |
| 35 | **Version row** | A-02 | `[APP_VERSION] ([BUILD_NUMBER])` from build metadata | — | — | `package_info_plus` (PROPOSED dep) | "1.0.0 (42)", "2.0.0 (proposed)" |

## Real visual inconsistencies found (Final C audit) and disposition

| # | Inconsistency | Where | Severity | Disposition |
|---|---|---|---|---|
| V-1 | Home H1 pre-workout XP showed 340/500 (canonical 370) | v2 Home H1 | HIGH (data) | **Fixed** in canvas (CHANGE_LOG C-03) |
| V-2 | Prototype Vietnamese used "lần", "Thành tích", "Tiến độ", "Xoá", translated "October 500" | Final B prototype | MEDIUM (l10n) | **Fixed** (C-02) |
| V-3 | 40 px filter chips / segments below 44 | P3, P4, P5, P6, P7, v1 Home sheets | MEDIUM (a11y) | Spec fix D-24 (hit area 48 dp in Flutter); canvas unchanged (bulk rewrite of approved phases judged unsafe) |
| V-4 | `text3` captions on cards 4.36:1 | many | LOW–MEDIUM (a11y) | D-25 |
| V-5 | Screen side padding 20 (design) vs 24 (repo `AppSpacing.screenPadding`) | all v2 | LOW | Tokens: use 20 for v2 screens (proposed) |
| V-6 | Radius 10 and 14 used in design, absent from `AppRadius` | v2 | LOW | Add tokens (proposed) |
| V-7 | HUD counter size 120 (v2) vs repo hero 200 | HUD | LOW | Keep repo engine HUD sizing configurable; v2 frame shows 120 with banners — verify on device |
| V-8 | Barlow Condensed 600/700 used, only 800 bundled | all | LOW | D-26 |
| V-9 | Barlow line-height 0.9 clips 3–7 px of numerals in some overflow-hidden boxes | P5-04a, P5-06a, P6-04a, P6-06a, v1 Home B2 | LOW (cosmetic) | Use line-height ≥ 1.0 for Barlow in Flutter (`TextStyle.height` + `leadingDistribution: even`), especially for Vietnamese stacked diacritics |

## Flutter widget implementation guidance

1. Put tokens in `lib/theme/*` (already present — extend, don't fork): add `textMuted #C9C9CE`, `info #8AB4FF`, radius 10/14, motion `sheet 280`/`page 300` (all marked proposed in the token file).
2. Build new shared widgets in `lib/widgets/` next to `product_ui.dart`; each takes a `Semantics` label and supports `MediaQuery.textScaler` up to 2.0 without truncating primary actions.
3. Camera/HUD widgets are **views of `WorkoutUiState`** only; they never own counting logic.
4. All strings via `AppLocalizations.of(context)` (gen-l10n from `app_en.arb`/`app_vi.arb`); remove inline `context.tr('vi','en')` progressively (394 call sites, VERIFIED).
5. Golden tests per component in EN and VI at 393×852 and 375×667, text scale 1.0 and 1.3.
