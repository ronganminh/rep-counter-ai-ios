# 03 · Implementation decision log

Decisions taken while the owner is away. Each one is the safest reversible option; none changes the rep engine, production backend, store configuration or user data. The owner can overturn any row; the "Reverse by" column says how.

| ID | Open item | Decision taken (interim) | Why | Reverse by | Owner sign-off needed |
|---|---|---|---|---|---|
| L-D01 | D-15 router (`go_router`) | Not introduced in N-1. 5-tab shell uses Navigator 1.0 with one nested `Navigator` per tab | Smallest change; keeps camera → results imperative flow untouched | Swap the shell's nested navigators for `StatefulShellRoute` in N-2 | Mobile tech lead |
| L-D02 | D-16 local DB | Not started. F-3/F-4/W-4/W-5 held | It migrates every user's history; owner asked not to run migrations unattended | Approve D-16 + package choice (drift or sqflite) | Mobile tech lead |
| L-D03 | D-12 auth provider | None chosen; A-1/A-2 BLOCKED | No provider, endpoint or app ID exists | Owner chooses provider and provides backend | Product + Legal |
| L-D04 | D-14 support email / Terms / Privacy URLs | Keep the values already shipping (`LegalConfig`) as defaults, overridable with `--dart-define`; mark "owner to confirm" | Replacing them with placeholders would break live links; inventing new ones is forbidden | Pass different `--dart-define` values or edit `AppConfig` | Product + Legal |
| L-D05 | D-14 product IDs, prices | Empty by default → billing UI not built | No product configuration exists | Provide IDs in config when P-1 starts | Product + Finance |
| L-D06 | D-24 chip size | Keep 40 px visual where designs use it, enforce ≥ 48 dp hit area | Matches token file and `AppSpacing.minTouch` | — | Design |
| L-D07 | D-25 `text3` contrast | Add `AppColors.textMuted` / keep `text3` value; body-size captions on cards use `text2` (existing token) | No new colour value invented | Lighten `text3` instead if Design picks that option | Design |
| L-D08 | D-26 Barlow Condensed 600/700 | Bundle SemiBold (600) and Bold (700) next to the existing ExtraBold (800). Files from `google/fonts` `ofl/barlowcondensed`; the bundled ExtraBold has the identical SHA-256 there, so all three come from the same release (OFL, licence already in repo) | Designs use all three weights; restricting designs would change approved screens | Remove the two font entries from `pubspec.yaml` | Design + Mobile |
| L-D09 | D-23 confirm word | `DELETE` (EN) and `XÓA` (VI), case-insensitive, both accepted in either language | Superset is safe; v1 already used XÓA | Restrict accepted words | Product |
| L-D10 | D-06 recovery window | Not implemented yet (needs F-3/F-4) | — | — | Product + Mobile |
| L-D11 | Screen side padding 20 (design) vs 24 (repo) | New v2 widgets use 20; existing screens keep 24 until restyled | Avoids visual churn in untouched screens | Change `AppSpacing.screenPadding` | Design |
| L-D12 | ARB import scope | F-1 imports the full Final C ARB (4,286 keys) unchanged so keys stay stable; only reviewed keys are used in UI | Keeps the handoff the single source; unused keys have no runtime effect | Prune keys later | Product |

## PR log

| PR | Task | Branch | Base | CI | State |
|---|---|---|---|---|---|
| (filled in as PRs are opened) | | | | | |
