# Movement demo clips (plan 07, PR A)

Source: [namnq/workout-free-videos](https://github.com/namnq/workout-free-videos), tag `v2.0.0`, files `media/video/<slug>.mp4`.
Licence: **CC0 1.0** (public domain) for videos, data and code. No credit is required; the app credits the source anyway (Settings › About › Exercise demo videos).

| App exercise | Library id | Slug | Fit | Bytes | SHA-256 (MP4, identical to `data/exercises.json`) |
|---|---|---|---|---|---|
| `pull_up` | `l02` | `wide-grip-pull-up` | exact | 419675 | `36cd4dd2c16527e1fc191e5f771a72dd28e4c4e66f8ad29b4af003c2f6ff4e93` |
| `curl` | `b01` | `standing-barbell-curl` | similar (barbell, not dumbbells) | 410834 | `f4b18a0452de7b5fc10fe7fc8dd73ccda67204bd0bab788aef3bfcafe5f2b182` |

The MP4 files are the library files, byte for byte (1280×720 H.264, 24 fps, no audio; 5.8 s and 8 s).

Posters (`<slug>.jpg`) are the first frame of each clip, made with
`ffmpeg -i <slug>.mp4 -vf scale=640:-1 -frames:v 1 -q:v 4 <slug>.jpg`:

| Poster | Bytes | SHA-256 |
|---|---|---|
| `wide-grip-pull-up.jpg` | 36809 | `82a9288620bbfef5fd80abebbe1a24c3eb8895f8495bfad7a23668a204c78ef7` |
| `standing-barbell-curl.jpg` | 29849 | `cd1e9aec8bfe322b2d178207af6c33299da11a4dd9720ddc7d25219700a68455` |

`test/features/exercises/exercise_guide_test.dart` checks the MP4 sizes and checksums. This README is not bundled in the app (the pubspec lists the four files one by one).
