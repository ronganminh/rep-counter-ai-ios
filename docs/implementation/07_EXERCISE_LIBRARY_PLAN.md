# 07 · Exercise library (workout-free-videos): plan for PR A and PR B

Status: PLAN. The owner asked for this on 2026-11-05. Each part becomes its own small PR in a new session. Rules: open PRs only; no merge, deploy or release; no secrets; CI must be green.

## Source

- **Repository:** https://github.com/namnq/workout-free-videos. The README and `data/exercises.json` were read on 2026-11-05.
- **Content:** 57 exercises. Each has a looping 1280×720 H.264 MP4 of 4–8 s, no audio, with `faststart`. The whole set is about 28 MB, with SHA-256 checksums.
- **Data per exercise:** `id`, `slug`, `name`, `primaryMuscle`, `secondaryMuscles`, `equipment`, `level`, `type`, `jointStress`, `gear`, 3 English `cues`, and `translations`.
- **Translations:** `de`, `es`, `fr`, `it` and `ja`. **There is no `vi` for names or cues.** Vietnamese exists only for the muscle and equipment labels.
- **Licence:** CC0 1.0 (public domain), covering videos, data and code. No credit is required. We credit the source anyway, as a courtesy.
- **Hot-link:** jsDelivr with a pinned tag, for example `https://cdn.jsdelivr.net/gh/namnq/workout-free-videos@v2.0.0/media/video/<slug>.mp4`. Ids and slugs are stable.

## Match against the app's exercises

The app has four profiles (`lib/exercise.dart`): `push_up`, `pull_up` (locked: not visible in the store), `curl` and `overhead_extension`.

| App id | Library match | Fit |
|---|---|---|
| `push_up` | **none** (no push-up clip in the 57) | — |
| `pull_up` | `l02` `wide-grip-pull-up` (pull-up bar) | good: same movement; the grip is wide |
| `curl` | `b01` `standing-barbell-curl` (closest), or `b02` `incline-dumbbell-curl` | partial: a barbell, not a dumbbell; mark it "similar movement" |
| `overhead_extension` | **none** (`t02` is a lying EZ-bar skullcrusher) | — |

Consequences:

- **PR A** shows a clip for `pull_up` and `curl` only. `push_up` and `overhead_extension` keep the current guide, with no clip.
- **PR B** has a very small first smoke set: `l02` for pull-up, and possibly `b01` for curl. **There is no push-up clip**, so push-up counting cannot be smoke-tested from this library. The owner's long real videos are needed for that.

## PR A · Movement guide in the app

**Scope:** UI only. The exercise detail page (`ExerciseDetailPage`) and the pre-start screen of a workout (Train sheet / camera gate before `CameraPage` starts). No change to the camera, pose detection or the rep engine.

1. **Mapping.** A new `ExerciseGuideClip` table (`lib/features/exercises/data/exercise_guide_clips.dart`):
   - fields: `appId → {slug, sourceId, fit: exact|similar, cuesEn[3], cuesVi[3], cuesViReviewed: bool}`;
   - only `pull_up → l02` and `curl → b01`, with `fit: similar` for the curl.
2. **Cues.**
   - EN: copied from `exercises.json`.
   - VI: the library has none. Translate them, set `cuesViReviewed: false`, and show nothing different to users.
   - List the strings to review in this doc, so the owner can check them.
   - Put the strings in ARB files, keeping `lib/l10n` and the handoff copies identical.
3. **Loading the clips.** Recommendation: **bundle in assets only the clips the app uses** (2 files, about 0.5–1 MB in total; check the exact sizes when downloading), with their SHA-256 checksums recorded.

   | | Bundle in assets | Stream from jsDelivr (pinned tag) + cache |
   |---|---|---|
   | Size | adds about 1 MB to the app for 2 clips | 0 in the app |
   | Offline | works | first view needs network; after that, cache |
   | Privacy / App Store | no third-party request | a request to a CDN; mention it in the privacy notes |
   | Failure modes | none | CDN down, blocked network → fall back to text cues |
   | Updates | ship a new build | change the tag |

   Bundling wins for 2 clips. Revisit if the app grows to many exercises.
4. **Player.** `video_player` is already a dependency. Use an autoplay, muted, looping player that respects reduced motion: when motion is reduced, show the first frame and a play button. Add a semantic label for the clip.
5. **Credit.** Name the source and CC0 in `docs/` (a third-party notices file) and on the About / Licences screen, with the source repository link.
6. **Tests.**
   - Widget tests: the detail page shows the clip widget and 3 cues for `pull_up` and `curl`, in EN and VI. `push_up` shows no clip and no error.
   - Reduced motion shows the poster.
   - The asset exists, and its size and SHA-256 match the recorded values.
   - CI needs no network, because the clips are committed.

## PR B · Clips as the first counting smoke set (measure only)

**No change to the counting algorithm.**

1. **Clips:** `l02` (pull-up), plus `b01` (barbell curl) if the curl profile is worth a check. Each is 4–8 s.
2. **Ground truth:**
   - Count the reps by eye, watching frame by frame.
   - Record them in a new manifest `test/fixtures/clip_smoke_set.json` with fields `human_ground_truth`, `counted_by: "eye, sample clip"`, `source_id`, `slug`, `sha256` and `fit`.
   - A looping clip that starts mid-rep can show a partial rep at each end. Count only full reps, and note any partial ones.
3. **Replay:** run the existing replay harness (iOS `ios-ci.yml` and Android `android-replay.yml`) on the clip.
   - **CI blocker:** the harness takes a fixed fixture list and runs about 40 min to 2 h per video. A short clip needs a separate, fast job, for example `smoke-replay.yml` with a matrix over the manifest.
   - **Pull-up limit:** the harness opens the workout for the fixture's exercise, but `pull_up` is hidden from users. Check that the CI video mode can open a locked exercise. If it cannot, that needs a small harness-only change.
   - **Clip length:** a 4–8 s clip may be shorter than the app's ready, countdown and placement steps. Play the clip **looped N times** (for example 5 loops) and compare against N × the reps per loop.
4. **Report table** (PR description and a doc):

   | clip | real reps | app counted | right | missed | extra | reason |
   |---|---|---|---|---|---|---|

   "Reason" is filled from the CI debug log (`placement`, `gate`, `raw_l/raw_r`, `signal`, `head`). Examples: pose lost, camera angle, shallow, gate closed.
5. **Scope:** a separate fast replay set that never changes the baselines of the three reference videos.

## Open questions for the owner

- Should the curl use `b01` (barbell) as "similar movement", or show no clip until there is a dumbbell curl clip?
- Is it OK to bundle 2 clips (about 1 MB) in the app?
- Where should the credit go: an existing About / Licences screen, or a new one?
- Push-up has no clip. Should PR A show something else for push-ups (the current skeleton guide only), and should PR B wait for the owner's long videos?
