# RepCoach AI — Google Play v2.0 update sheet

Step-by-step + copy-paste values to publish the **v2.0.0** update on Google Play.
All store content below is in **English**. Audience: the person (or Claude in Chrome)
filling the Play Console.

> App: **RepCoach AI: Đếm Hít Đất** · package `com.ronganminh.repcoach`
> Current live release: **versionCode 3 (1.0.1)**. New upload is **versionCode 7**, which is
> higher than 3 → Play will accept it. Push-ups only; do not advertise other exercises.

---

## 0. The build to upload

| Field | Value |
|---|---|
| File | `rep-counter-ai-main/rep_counter_app/build/app/outputs/bundle/storeRelease/app-store-release.aab` |
| Size | ~99 MB |
| versionName | `2.0.0` |
| versionCode | `7` |
| Flavor | `store` (no screen-record permission) |
| Signing | upload key `repcoach-upload` (same key as v1 — verified) |

---

## 1. Create the production release

Play Console → **RepCoach AI → Release → Production → Create new release**
(or use **Testing → Closed testing** first if you want to test before going live).

1. **App bundles**: upload the `.aab` above. Confirm it shows **Version code 7 / 2.0.0**.
2. **Release name** (internal, not shown to users): `2.0.0 (7)`
3. **Release notes** → paste per language (see §2).
4. **Next → Review release → Start rollout to Production** (choose % rollout or 100%).

---

## 2. Release notes ("What's new") — max 500 chars/language

### English (en-US)
```
Version 2.0
- More accurate push-up counting: false reps are ignored while you rest between sets.
- New lightweight count-only mode.
- Form score and per-set tempo breakdown after each workout.
- Stability and user-experience improvements.
```

### Vietnamese (vi) — keep the existing language too
```
Phiên bản 2.0
- Đếm hít đất chính xác hơn: bỏ qua rep giả khi bạn đang nghỉ giữa các set.
- Chế độ chỉ-đếm gọn nhẹ.
- Điểm form và nhịp độ (tempo) chi tiết sau mỗi buổi tập.
- Cải thiện độ ổn định và trải nghiệm.
```

> Enter notes for **every** active language, or Play warns. If only VI is configured,
> add the English text under the en-US language if you also publish English (see §3).

---

## 3. Store listing (English content)

> The current main listing is Vietnamese. To show English, go to
> **Grow → Store presence → Store listing**, pick/add language **English (United States)**,
> and fill the fields below. If you only want to refresh screenshots, jump to §4.

| Field | Value (chars) |
|---|---|
| **App name** (30) | `RepCoach AI: Rep Counter` (24) |
| **Short description** (80) | `Count push-ups with your camera, set goals, and get AI workout feedback.` (72) |

### Full description (4000)
```
Train with more structure using RepCoach AI, a camera-based push-up counter that runs pose detection directly on your Android phone.

DEVICE REQUIREMENTS
Rep counting needs an Android phone with a working front camera and enough space to place your full body in view. Accuracy can vary with camera angle, lighting, clothing, visibility, and device performance.

SET A GOAL AND START MOVING
Choose a target before each session, or skip the goal and train freely. RepCoach AI counts completed repetitions and celebrates when you reach your target.

REAL-TIME POSE GUIDANCE
Use the front camera and follow the on-screen body guide to position yourself. On-device pose detection analyzes body landmarks to count push-ups and give useful form signals while you train. A posture gate ignores false reps while you rest between sets.

PRIVATE BY DESIGN
Camera frames are processed on your device. The app does not upload your camera images or video. Workout history is stored locally on your phone and can be deleted at any time.

OPTIONAL AI FEEDBACK
After a workout you can choose to send a lightweight session summary — such as rep count, duration, goal, tempo, and movement-quality metrics — to our secure service and GroqCloud for written feedback. No camera images, video, audio, or face data are included. AI feedback may be inaccurate and should be treated as general fitness guidance. It is off by default and can be turned on or off in Settings.

TRACK YOUR PROGRESS
Review previous sessions, see whether you reached your goal, view your form score and tempo, and keep building a consistent routine.

CURRENT FEATURES
- On-device push-up counting
- Front-camera positioning guide
- Count-only mode
- Optional rep goals and goal celebration
- Form score and tempo breakdown after each set
- Local workout history and progress calendar
- Optional, consent-based AI session feedback
- Vietnamese and English interface

IMPORTANT SAFETY NOTICE
RepCoach AI is a general fitness tool, not a medical device. It does not provide medical advice, diagnosis, treatment, cure, or prevention of any condition. Stop exercising if you feel pain, dizziness, or unusual discomfort. Consult a qualified healthcare professional before starting a new exercise program, especially if you have an injury or health condition.

Support: ronganminh221@gmail.com
Privacy Policy: https://repcoach-ai.duckdns.org/privacy-policy.html
```

### Listing contact / URLs
| Field | Value |
|---|---|
| Support email | `ronganminh221@gmail.com` |
| Website | `https://repcoach-ai.duckdns.org/` |
| Privacy Policy | `https://repcoach-ai.duckdns.org/privacy-policy.html` |

---

## 4. Screenshots (phone) — new iPhone-style set

Folder: `store_listing/assets/screenshots/play-v2/`
These are **1398 × 2796** (exactly 2:1 — Play's max ratio; the original 1290×2796 is too tall
for Play, so thin #0B0B0C bars were added on the sides and are invisible on the dark design).

Upload 2–8, in this order:
1. `01-count-every-rep.png`
2. `02-smarter-feedback.png`
3. `03-share-your-wins.png`
4. `04-see-your-progress.png`
5. `05-your-data.png`

> Replace the old green screenshots with these. Phone screenshots: PNG, ≤ 8 MB each,
> each side 320–3840 px, longer:shorter ≤ 2:1 (these are exactly 2:1 ✓).

### Also update (new ring-logo branding)
The app icon was changed from the old green figure to the new lime ring logo, so update
these on Play too, or the store will mismatch the installed app icon:
- **App icon (512×512)**: `store_listing/assets/app-icon-512.png`
- **Feature graphic (1024×500)**: `store_listing/assets/feature-graphic-1024x500.png`

---

## 5. Data safety — no change needed

v2 does not add new data collection (the posture gate and count-only mode are on-device
logic only). The existing Data safety declaration still holds: optional Fitness summary for
AI feedback; camera frames, video and pose landmarks stay on device.

> Only revisit Data safety if you later add analytics, crash reporting, accounts, cloud
> history, ads, or video upload.

---

## 6. Submit checklist

- [ ] app-store-release.aab uploaded, shows versionCode 7 / 2.0.0
- [ ] Release name `2.0.0 (7)`
- [ ] Release notes filled for every active language (EN + VI)
- [ ] (Optional) English store listing: name, short + full description
- [ ] Screenshots replaced with the 5 play-v2 images (1398×2796)
- [ ] Privacy Policy URL present and loading
- [ ] Review release → **Start rollout to Production**
