# RepCoach AI · Final C design package

Final design delivery for **RepCoach AI v2**: master design QA, English/Vietnamese localization and developer handoff. Prepared 2026-10-22 from the Claude Design workspace "RepCoach AI" (canvas v15 baseline + Final C edits) and a read-only audit of `ronganminh/rep-counter-ai-ios` @ `3594d8a`.

**Status: PARTIAL.** The no-backend implementation tracks are ready for development. See `FINAL_QA_REPORT.md` §1 for the 15 acceptance criteria. No production code was written.

## Start here

1. `MASTER_DESIGN_HANDOFF.md`: the product, design principles, state machines, and the **camera engine protection rules**.
2. `SCREEN_TO_FLUTTER_MAPPING.md` and `SCREEN_INVENTORY.csv`: maps every screen to its route, widget, state, backend dependency, status and priority.
3. `FLUTTER_IMPLEMENTATION_ROADMAP.md`: 33 PR-sized tasks.
4. `DESIGN_SYSTEM_TOKENS.json` and `COMPONENT_REGISTRY.md`.
5. `APP_NAVIGATION_MAP.md` and `API_AND_BACKEND_GAP_ANALYSIS.md`.
6. `l10n/`: `app_en.arb` and `app_vi.arb` (drop into `lib/l10n/` and use gen-l10n), plus the glossary and the untranslated-strings audit.
7. `PRODUCT_DECISIONS.md` and `RELEASE_CHECKLIST.md`: owner decisions and store and compliance items.
8. `FINAL_QA_REPORT.md`, `CHANGE_LOG.md` and `REPO_AUDIT.md` (+ `repo_audit.json`): QA results, Final C edits and the repository audit.

## Labels used everywhere

- **VERIFIED**: read from code or from the canvas in this session.
- **PROPOSED**: a design assumption that needs owner sign-off.
- **REQUIRES VERIFICATION**: depends on backend, legal or store policy.
- **SIMULATED**: prototype-only behaviour. The camera, OS prompts, stores, push and backend are all simulated in the prototype.

## Unresolved configuration (never invented)

These values must come from their owners:

- `[Annual price]`, `[Monthly price]`: from the store SDK at runtime
- `[PRODUCT_ID_*]`
- `[SUPPORT_EMAIL]`, `[SUPPORT_URL]`
- `[TERMS_URL]`, `[PRIVACY_URL]`: the backend already serves `/terms.html` and `/privacy-policy.html`; the owner must confirm these are canonical
- `[APP_VERSION] ([BUILD_NUMBER])`: from build metadata
- `[TICKET_REFERENCE]`

## Archive layout (`RepCoach-AI-Final-C-Design-Package.zip`)

```
README.md                      this file (copy)
ASSET_MANIFEST.json            every file with size + SHA-256
handoff/                       all deliverables above (+ evidence/ screenshots)
design-source/project/         editable Claude Design source (.dc.html), canvas.json, Final B QA images — as published after Final C
snapshots/pre-final-c/project/ immutable copy of the live canvas before any Final C edit (v15)
qa/tools/                      Playwright test scripts (fbinteract.js, fcinteract.js, phase suites, inventory, layout check)
generators/                    Python/JS generators for the Final B/C files and ARB build (reproducible)
```

No secrets, API keys, signing files or credentials are included. The repository audit records only that `VPS_SSH_KEY` exists as a CI secret name.

## Viewing the design source offline

The `.dc.html` files are Claude Design documents. They render in the Claude Design canvas, which provides the runtime they load as `./support.js`. That runtime is not redistributed in this archive, so open the files in the Claude Design workspace for full interactivity. The Markdown, JSON, ARB and CSV deliverables need no runtime.
