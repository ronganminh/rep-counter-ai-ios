# Third-party content bundled in the app

Fonts are listed with their own licences in `assets/fonts/`. This file lists media.

## Exercise demo videos

- **What:** `assets/guide/wide-grip-pull-up.mp4` and `assets/guide/standing-barbell-curl.mp4`, plus a first-frame poster (`.jpg`) made from each.
- **Source:** [namnq/workout-free-videos](https://github.com/namnq/workout-free-videos), tag `v2.0.0`.
- **Licence:** [CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/) (public domain dedication). No credit is required. The app names the source anyway in Settings › About › Exercise demo videos.
- **Checksums:** `assets/guide/README.md`, checked by `test/features/exercises/exercise_guide_test.dart`.
- **Use:** shown as a muted, looping demo on the pull-up and curl detail pages and in the Train sheet. Plan: `docs/implementation/07_EXERCISE_LIBRARY_PLAN.md` (PR A). The clips are never sent anywhere; the app makes no network request for them.
