# 07 · Exercise library (workout-free-videos): plan for PR A and PR B

Status: PLAN — owner decisions recorded (see the end). The owner asked for this on 2026-11-05. Each part becomes its own small PR in a new session. Rules: open PRs only; no merge, deploy or release; no secrets; CI must be green.

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

## Owner decisions (2026-11-05)

1. **Curl clip:** use `b01` `standing-barbell-curl`, labelled "minh hoạ với tạ đòn" (EN: "shown with a barbell").
2. **Loading:** bundle the clips in the app (about 1 MB). No CDN streaming.
3. **Credit:** put the source and CC0 on the existing About / Licences screen. Do not add a new screen.
4. **Push-up:** keep the current skeleton guide. Push-up counting will be tested on the owner's long real videos, not on this library.

## PR A status: Vietnamese strings to review

PR A adds these strings to `app_vi.arb` (and the handoff copy). The library has no Vietnamese, so the cues are our own translation (`cuesViReviewed: false` in `exercise_guide_clips.dart`; the ARB description says "needs review"). Nothing different is shown to users. Please check them:

| Key | EN (from the library for cues) | VI (to review) |
|---|---|---|
| `guideCuePullUp1` | Start from a dead hang | Bắt đầu từ tư thế treo thẳng tay |
| `guideCuePullUp2` | Pull the chest toward the bar | Kéo ngực về phía xà |
| `guideCuePullUp3` | Lower all the way each rep | Mỗi rep đều hạ người xuống hết |
| `guideCueCurl1` | Elbows stay pinned to the sides | Khuỷu tay giữ sát hai bên người |
| `guideCueCurl2` | Curl without leaning back | Cuốn lên mà không ngả người ra sau |
| `guideCueCurl3` | Lower all the way to full extension | Hạ xuống đến khi duỗi thẳng tay |
| `guideClipTitle` | How it's done | Cách thực hiện |
| `guideClipBarbellNote` | Shown with a barbell | Minh hoạ với tạ đòn |
| `guideClipPullUpLabel` | Looping demo video: wide-grip pull-up, seen from behind | Video mẫu lặp lại: kéo xà tay rộng, nhìn từ phía sau |
| `guideClipCurlLabel` | Looping demo video: standing barbell curl | Video mẫu lặp lại: đứng cuốn tạ đòn |
| `guideClipPlay` / `guideClipPause` | Play / Pause demo video | Phát / Tạm dừng video mẫu |
| `settingsDemoVideosTitle` | Exercise demo videos | Video mẫu động tác |
| `settingsDemoVideosBody` | The pull-up and curl demo videos come from workout-free-videos by namnq, released under CC0 1.0 (public domain). No credit is required; we credit the source anyway. | Video mẫu kéo xà và cuốn tạ lấy từ bộ workout-free-videos của namnq, phát hành theo CC0 1.0 (phạm vi công cộng). Nguồn này không yêu cầu ghi công; chúng tôi vẫn ghi nguồn. |
| `settingsDemoVideosOpen` | Open source page | Mở trang nguồn |

When reviewed, update `app_vi.arb` (both copies) and set `cuesViReviewed: true`.

## PR B status: clip smoke set (measure only)

- **Manifest:** `test/fixtures/clip_smoke_set.json`. Both clips have **1 full rep per loop** with no partial rep, because the loop seam is at the start position (hang / arms extended). They are counted by eye, frame by frame (`counted_by: "eye, sample clip"`). Each is replayed **10 loops → 10 real reps**.
- **Job:** `.github/workflows/smoke-replay.yml`. It runs on `workflow_dispatch` and on PRs that change its own files.
  1. It downloads each clip from jsDelivr at the pinned tag and verifies its size and SHA-256.
  2. It loops the clip and re-encodes it all-intra (`ffmpeg -stream_loop 9 … -g 1`). The source has a single keyframe, and the iOS extractor (`AVAssetImageGenerator`, default tolerance) snaps to keyframes, so a `-c copy` loop gave iOS the same frame at every sample.
  3. It replays the clip on the iOS Simulator and the Android emulator (`tool/ci_ios_clip_replay.sh`, `tool/ci_android_replay.sh`).
  4. `tool/report_clip_smoke.py` writes the table to the job summary.
- **Failures:** no job fails on a count. A job fails only when the harness breaks: there is no result, or the replay opened another exercise.
- **Locked exercise:** CI video mode now takes `REPCOACH_CI_VIDEO_EXERCISE` (default `push_up`). `ciVideoProfile` searches all engine profiles, so the locked pull-up opens. The start line reports `exercise=<id>`, and the report checks it.
- **Unchanged:** the three reference replays and `video_ground_truth.json`.
- **Results:** in the PR B description, from the smoke run.

## Owner recording: dumbbell curl (`clip-real-curl-img0967`, measure only)

- **Source:** `IMG_0967.MOV`, filmed by the project owner, on Google Drive (`1ZKjGD59kJ1dfNaNAwEE9P3TUEIGaG0zw`). It is **not** in the repo: the manifest keeps the link, 2,047,522,941 bytes and SHA-256 `51484f0a278348ed0a28d5206498f85ebea0738abbf37eb6a6bdc85deeb71289`. 693.9 s, H.264 1920×1080 stored with a 90° rotation (portrait 1080×1920), ~60 fps.
- **View:** front, portrait, phone low on the floor about 2 m away and looking slightly up. While standing, the frame runs from the head to mid-shin; dumbbells at the hips sit near the left and right edges and the curled dumbbell rises to the face. Between sets the owner walks out, sits side-on on a chair in the background, kneels with the back to the camera or stretches. The clip starts and ends on a torso close-up while the phone is handled.
- **Ground truth:** 4 sets of alternating curls, **65 single-arm curls** (19 / 14 / 16 / 16). The app counts each arm (`TwoArmMerger`), so one arm going up and down is one rep. Counted **by eye by the agent** on 2 fps contact sheets, using a 10 fps motion trace as a pointer, with timestamps ±0.5 s. **Not yet checked by a person** (`human_reviewed: false`). Each rep's time and side are in the manifest.
- **Rep Annotator:** no tool of that name exists in this repo or on any branch. The per-rep timestamps in the manifest are the annotation.
- **Replay input:** CI re-encodes the verified source all-intra at 5 fps, 720×1280 (~290 MB). This matches the replay sampling (one frame every 200 ms, at most 480 px wide), so each sample is an exact frame on iOS and Android.
- **Report:** `report_clip_smoke.py` adds a per-set table: real / app / right / missed / extra, ready → first countable sample, first count, stuck, the main not-countable status, and the frames each required landmark spent outside the guide or missing. It also lists reps added during rest. The landmark tally comes from CI-only `out=`/`miss=` fields that `_runCiVideo` adds to the 5 s status line.
- **Results:** in the PR description, from the smoke run.
