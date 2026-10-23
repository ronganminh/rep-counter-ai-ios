# UNTRANSLATED_STRINGS_AUDIT

RepCoach AI · Final C · 2026-10-22 · full row-level list: `UNTRANSLATED_STRINGS_AUDIT.csv` (4,336 rows)

## Verdict: localization QA = **PARTIAL**

Every visible string in the default state of the 31 active boards has an EN **and** VI value, and the ARB files are complete and valid. QA stays PARTIAL for three reasons, though. **3,311 keys carry machine-assisted translations that need native review.** 899 design strings embed sample data and must be parameterised before shipping. Alternate states rendered only by each phase file's JavaScript were inventoried by literal extraction, so coverage of those states is high but not proven exhaustive.

## Numbers

| Measure | Value |
|---|---|
| ARB keys (`app_en.arb` = `app_vi.arb`) | **4,286** · ICU parse errors 0 · placeholder mismatches 0 · identical key sets |
| Canonical implementation keys (ICU plurals/placeholders) | 151 |
| Existing human-written pairs (shipping `S` class, inline `context.tr`, Final B/C prototype, phase handoff tables) | 824 |
| Design strings EN→VI, machine-assisted, **need native review** | 2,968 |
| v1 Vietnamese source strings — VI preserved verbatim, EN added, **EN needs review** | 136 |
| Gap-pass strings (static + alternate-state logic), **need review** | 207 |
| Static visible strings (per-frame occurrences, default state) | 7,074 translatable · **7,071 covered (99.96 %)** · skipped as non-translatable: name/product 268, date 78, symbol 123, number 27, system keypad mock 16, placeholder 29 |
| Remaining uncovered static strings | 3 — design annotations on canvas frames, not app UI |

## Exact remaining items

| Category | Count | Action |
|---|---|---|
| uncovered-static (design annotation, not app UI) | 3 | None for the app; annotation only |
| excluded-unchanged | 11 | Names/codes/placeholders — no translation |
| excluded-non-UI | 53 | Not shipped (debug/log/design notes) |
| excluded-truncated fragment | 12 | Re-extract the full sentence from the phase file when that screen is built (an apostrophe split the literal) |
| prototype-composite → canonical ICU key | 19 | Implement with the canonical key (e.g. `recoveryBody`, `mergeSummary`, `resultsNewRecord`) |
| vi-variant-conflict (same EN, different VI) | 28 | Reviewer picks one VI wording; kept value follows source priority (shipping app > prototype > design) |
| sample-data-needs-parameterising | 899 | Replace literal sample values with ICU placeholders when the screen is built (`description` flags each key) |
| machine-assisted-needs-native-review | 3,311 | Native VI reviewer signs off (roadmap L-2) |

## Source preservation

- The original v1 Vietnamese strings are **not** overwritten. They are kept verbatim as VI values, with keys deduplicated on the Vietnamese text, and English was added next to them. The shipping app's `S.vi` and the inline `context.tr` Vietnamese are carried over unchanged as `existing`.
- Where the same English had different Vietnamese in different sources, the higher-priority source wins and the alternative is listed as a `vi-variant-conflict` row. Nothing was silently discarded.

## Checks performed

Diacritics (all VI values NFC), Barlow Condensed and Inter Vietnamese glyph rendering, VI text expansion in 7 integrated journeys + 12 negative paths at 393×852 and 375×667 (0 overflow), dynamic text through ICU placeholders, dates/times (VI 24-hour, `T3, 20/10`), numerals (VI decimal comma), currency (never translated; the `{price}` placeholder comes from the store SDK), pluralisation (EN `=1/other`, VI `other`), screen-reader labels (`notifBellLabel`, `workoutRepCounterLabel`, `navTabsLabel`), error copy, notification copy, subscription terms (`proRenewalDisclosure`, needs legal review), long button labels.
