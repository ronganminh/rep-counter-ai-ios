# 02 · Release risk register

Scale: Likelihood / Impact = L(ow) · M(edium) · H(igh). Status: OPEN · MITIGATING · CLOSED · ACCEPTED.

| ID | Risk | L | I | Mitigation | Owner | Status |
|---|---|---|---|---|---|---|
| R-01 | UI work on HUD/Results changes rep counts or breaks the camera→result→save path | M | H | Never edit `_onFrame`, `_consumePose`, `_handle`, `rep_counter.dart`, `rep_tracker.dart`, `placement.dart`, `pose_mapper.dart`; every PR touching the workout folder must keep the iOS replay matrix green with unchanged baselines | Mobile | MITIGATING |
| R-02 | Replay baselines are regression baselines, not truth (`human_ground_truth: null`) | H | M | Keep labelled honestly; add human counts before claiming accuracy | Product | OPEN |
| R-03 | Accounts, sync, credits, billing, social and push have no backend or auth provider | H | H | Tasks marked BLOCKED; only typed interfaces + test doubles; features stay off in production | Owner + Backend | OPEN |
| R-04 | AI endpoint is unauthenticated (IP rate limit only) on a duckdns host | M | M | Keep basic feedback free and anonymous; add auth/quotas before credits (AI-1) | Backend | OPEN |
| R-05 | Workout history capped at 100 records in SharedPreferences; no `clientId` | H | M | F-3 with migration tests and a retained prefs copy, after D-16 approval | Mobile | OPEN (decision) |
| R-06 | 3,311 machine-assisted VI strings + 899 sample-data strings in ARB | H | M | Ship only keys actually used; L-2 native review before release; keep existing human VI copy verbatim | Product | OPEN |
| R-07 | Material widgets show English in VI (no `flutter_localizations`) | H | L | F-1 | Mobile | MITIGATING |
| R-08 | Accessibility: 40 px chips, `text3` captions 4.36:1 on cards | H | M | DS-1/DS-2/Q-1 (48 dp hit areas, `text2` on surfaces); device screen-reader tests UNVERIFIED | Mobile | MITIGATING |
| R-09 | Hard-coded version string drifts from build (happened before `5a61ab8`) | M | L | F-2 reads `package_info_plus` | Mobile | MITIGATING |
| R-10 | Legal/support values not confirmed canonical (D-14) | M | M | Keep shipping values; owner confirms before release | Owner | OPEN |
| R-11 | iOS has no `diag` flavor; bundle IDs differ between iOS and Android | L | M | Document; matters for IAP/push config later | Mobile | ACCEPTED |
| R-12 | `camera_page.dart` (1.5k lines) mixes view and engine glue | H | M | W-1 limits edits to view code; any extraction is a separate, engine-owner-reviewed PR | Mobile | OPEN |
| R-13 | Stacked PRs: long chain waiting for review; later PRs conflict if early ones change | M | M | Small PRs, rebase-free merges bottom-up | Owner | OPEN |
| R-14 | New dependencies (`flutter_localizations`, `intl`, `package_info_plus`, local notifications) affect iOS Pods / Android build | M | M | Only add per roadmap; iOS unsigned release build + replay in CI on each PR | Mobile | MITIGATING |
| R-15 | Store policy items (account deletion, IAP, Sign in with Apple, rewarded ads, privacy labels) unverified | M | H | Q-2 with current official docs before any submission; nothing is submitted while the owner is away | Owner + Legal | OPEN |
| R-16 | Real-device validation (camera, voice, haptics, notifications) not possible in CI | H | M | Mark UNVERIFIED; owner device pass before release | Owner | OPEN |
| R-17 | Recovery drafts (F-4) write on the frame hot path | M | M | Debounced writes after accepted reps only; frame-budget comparison in replay | Mobile | OPEN (task held) |
