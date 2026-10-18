# RepCoach AI — App Store Connect submission sheet

Copy-paste values for filling App Store Connect, field by field. Character counts
are shown as `(used/limit)`. Audience: the person (or Claude in Chrome) filling the
App Store Connect form. iPhone-only release, no account, no in-app purchase, free.

> Source of truth for product scope: `rep_counter_app/docs/APP_STORE_V1_RELEASE.md`.
> Only push-ups ship. Do **not** advertise pull-ups or any disabled exercise.
> AI provider in production is **GroqCloud** (not Gemini — the Play copy is stale).

---

## 0. Fixed identifiers (do not change)

| Field | Value |
|---|---|
| Bundle ID | `com.ronganminh.repCounterApp` |
| Apple Team ID | `NW22NWLTK4` |
| Version string | `1.0.0` |
| Build number | `6` |
| Platform | iOS — iPhone only |
| Minimum iOS | 15.5 |
| Primary language | English (U.S.) |

---

## 1. App Information

| Field | Value |
|---|---|
| **Name** (30) | `RepCoach AI: Rep Counter` (24/30) |
| **Subtitle** (30) | `On-device push-up counter` (25/30) |
| **Primary category** | Health & Fitness |
| **Secondary category** | Sports (optional — leave empty if unsure) |
| **Content Rights** | Does **not** contain, show, or access third-party content → **No** |
| **Age Rating** | 4+ (see §6) |

SKU (internal, not shown to users; any unique string): `repcoach-ai-ios-1`

---

## 2. Pricing and Availability

| Field | Value |
|---|---|
| **Price** | Free (Tier 0) |
| **Availability** | All countries and regions |
| **Pre-order** | No |
| Distribution | Public on the App Store |

---

## 3. Version 1.0.0 — App Store page

### Promotional text (170)
```
Count push-ups automatically with your iPhone camera. Pose detection runs on-device, set a goal, and get optional AI feedback after each workout.
```
(144/170)

### Description (4000)
```
Train with more structure using RepCoach AI, a camera-based push-up counter that runs pose detection directly on your iPhone.

DEVICE REQUIREMENTS
Rep counting needs an iPhone with a working front camera and enough space to place your full body in view. Accuracy can vary with camera angle, lighting, clothing, visibility, and device performance.

SET A GOAL AND START MOVING
Choose a target before each session, or skip the goal and train freely. RepCoach AI counts completed repetitions and celebrates when you reach your target.

REAL-TIME POSE GUIDANCE
Use the front camera and follow the on-screen body guide to position yourself. Pose detection analyzes body landmarks on your device to count push-ups and give useful form signals while you train.

PRIVATE BY DESIGN
Camera frames are processed on your device. The app does not upload your camera images or video. Workout history is stored locally on your iPhone and can be deleted at any time.

OPTIONAL AI FEEDBACK
After a workout you can choose to send a lightweight session summary — such as rep count, duration, goal, tempo, and movement-quality metrics — to our secure service and GroqCloud for written feedback. No camera images, video, audio, or face data are included. AI feedback may be inaccurate and should be treated as general fitness guidance. It is off by default and can be turned on or off in Settings.

TRACK YOUR PROGRESS
Review previous sessions, see whether you reached your goal, view your form score and tempo, and keep building a consistent routine.

CURRENT FEATURES
- On-device push-up counting
- Front-camera positioning guide
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
(~1950/4000)

### Keywords (100, comma-separated, no spaces after commas)
```
pushup,push-up,rep counter,reps,workout,fitness,exercise,home workout,calisthenics,pose,AI coach
```
(96/100)

### URLs
| Field | Value |
|---|---|
| **Support URL** | `https://repcoach-ai.duckdns.org/support.html` |
| **Marketing URL** (optional) | `https://repcoach-ai.duckdns.org/` |
| **Privacy Policy URL** | `https://repcoach-ai.duckdns.org/privacy-policy.html` |

### Version / copyright
| Field | Value |
|---|---|
| **Version** | `1.0.0` |
| **Copyright** | `2026 RỒNG ẨN MÌNH` |
| **What's New in This Version** | For first release this field is optional. If required: `First release of RepCoach AI.` |

### Build
Select build **1.0.0 (6)** after it finishes processing in TestFlight.

---

## 4. Screenshots (iPhone 6.7" — 1290 x 2796)

Folder: `store_listing/assets/screenshots/app-store/`
Upload in this order (one 6.7" set covers larger iPhones automatically):

1. `01-count-every-rep.png`
2. `02-smarter-feedback.png`
3. `03-share-your-wins.png`
4. `04-see-your-progress.png`
5. `05-your-data.png`

> If App Store Connect demands a 6.9" set (1320 x 2868) instead, ask the repo owner —
> the source art is 2580 x 5592 and will be re-exported to fit.
> No App Preview video is required.

---

## 5. App Privacy (data collection questionnaire)

Open **App Privacy → Edit**. Answers below reflect the shipped build.

### Does this app collect data?
**Yes** (only the optional AI-feedback summary leaves the device).

### Data types — declare ONLY this one:

**Health & Fitness → Fitness**
- Collected: **Yes**
- Linked to the user's identity: **No** (there is no account or user ID)
- Used for tracking: **No**
- Purpose: **App Functionality**
- Notes for your own record: sent only when the user turns on / consents to AI
  feedback; payload = exercise type, completed reps, target reps, duration, tempo,
  movement-quality metrics, rule-based observations. Used to generate the written
  feedback response; not used for ads or tracking.

### Do NOT declare these (they never leave the device):
Camera images / video, pose landmarks, audio, photos, face data, local workout
history, contacts, location, name, email, payment info, advertising identifiers,
browsing or search history, messages.

### Tracking
- "Data Used to Track You": **None**
- The app does **not** use third-party analytics, ads, or crash SDKs.

### ⚠️ One thing to verify before you submit
If the production web server (nginx) retains client **IP addresses** in access logs
for more than transient operation, Apple may expect an **Identifiers → (Device ID/
coarse)** or **Diagnostics** declaration. The current nginx uses a privacy-safe log
format and does not log request bodies. If you keep IP logging minimal/rotated for
security only, "not collected" is defensible. Decide and keep the privacy policy
consistent. (This is the only grey area.)

---

## 6. Age Rating questionnaire

Answer **None / No** to every content question → results in **4+**.

Key answers:
- Cartoon or Fantasy Violence: None
- Realistic Violence / Prolonged Graphic Violence: None
- Sexual Content or Nudity: None
- Profanity or Crude Humor: None
- Alcohol, Tobacco, or Drug Use or References: None
- Mature/Suggestive Themes, Horror, Gambling: None
- Medical/Treatment Information: None
- Unrestricted Web Access: **No**
- Contests: No
- Made for Kids / Kids category: **No** (not a kids app)

---

## 7. App Review Information

| Field | Value |
|---|---|
| **Sign-in required** | **No** (uncheck "Sign-in required") |
| **Contact — First name** | _<repo owner to fill>_ |
| **Contact — Last name** | _<repo owner to fill>_ |
| **Contact — Phone** | _<repo owner to fill>_ |
| **Contact — Email** | `ronganminh221@gmail.com` |
| **Demo account** | Not needed (no login) |
| **Attachment** | Optional: a short screen recording of a real push-up session |

### Notes for the reviewer (paste)
```
RepCoach AI counts push-ups using on-device pose detection with the iPhone's front camera. No account or login is required — open the app, pick the Push-up exercise, set or skip a goal, then start. Counting requires a real person doing push-ups within the camera's view, with the phone placed low and facing the user.

Privacy: camera frames are processed only on-device; the app never uploads camera images, video, audio, or face data. "RepCoach AI feedback" is optional and off by default; when enabled it sends only a text summary of the finished workout (exercise, reps, duration, tempo, movement-quality metrics) to our backend and GroqCloud and needs an internet connection. It degrades gracefully offline.

This release ships push-ups only. Workout history is stored locally and can be deleted in Settings → Delete all history.

Privacy Policy: https://repcoach-ai.duckdns.org/privacy-policy.html
Support: https://repcoach-ai.duckdns.org/support.html
```

---

## 8. Export Compliance

Already declared in Info.plist (`ITSAppUsesNonExemptEncryption = false`), so App Store
Connect should **not** prompt. If it does:
- "Does your app use encryption?" → **Yes** (standard HTTPS only)
- "Does it qualify for the exemptions?" → **Yes** → results in no export docs needed.

---

## 9. Content Rights & Advertising Identifier (IDFA)

- Content rights (third-party content): **No**
- Does this app use the Advertising Identifier (IDFA)? **No**

---

## 10. Final submit checklist

- [ ] Build 1.0.0 (6) uploaded and finished processing
- [ ] Screenshots (5 × 1290×2796) uploaded in order
- [ ] Name, subtitle, promo text, description, keywords filled
- [ ] Support + Privacy URLs set (both return 200 — verified)
- [ ] App Privacy: Fitness / not linked / App Functionality; tracking None
- [ ] Age rating 4+
- [ ] App Review notes pasted, sign-in unchecked, contact filled
- [ ] Pricing Free, availability all regions
- [ ] Click **Add for Review** → **Submit**
