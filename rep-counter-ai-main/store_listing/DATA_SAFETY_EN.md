# Google Play Data Safety — Suggested Answers

These answers describe the current MVP. Recheck them whenever analytics, crash reporting, authentication, cloud history, ads, or video upload is added.

## Data collection and security

- Does your app collect or share any required user data types? **Yes**
- Is all collected user data encrypted in transit? **Yes**, provided the production backend uses HTTPS only.
- Do you provide a way for users to request deletion? **Not applicable for server data if the backend does not retain workout summaries.** Users can delete local workout records inside the app or clear app data.
- Is data collection optional? **Yes.** A workout summary leaves the device only when the user explicitly requests AI feedback or consents to automatic feedback for newly saved workouts. Automatic feedback defaults off and can be disabled in Settings.

## Declare this collected data type

### Health and fitness → Fitness info

- Collected: **Yes**
- Shared: **No**, if your backend and Google Gemini act only as service providers processing data on your behalf and do not use it for independent purposes.
- Processing: **Ephemeral**, if the summary is used only to produce the response and is not stored afterward.
- Required or optional: **Optional**
- Purposes:
  - **App functionality**
  - **Personalization**

Examples in the payload: completed repetitions, target repetitions, workout duration, movement-quality metrics, and rule-based observations.

## Data that currently stays on the device

Do not declare the following as collected if the released build truly never transmits them off-device:

- Camera frames
- Imported test videos
- MediaPipe pose landmarks
- Local workout history

## Currently not collected

- Name, email address, or account credentials
- Precise or approximate location
- Contacts
- Photos or videos
- Audio
- Payment information
- Advertising identifiers
- Messages or files

## Checks before submission

- Confirm the production server does not log request bodies.
- Review reverse-proxy and hosting access logs; IP-address retention may change the declaration.
- Confirm Gemini data handling under the exact Google API plan and terms used in production.
- If Firebase Analytics, Crashlytics, sign-in, cloud sync, ads, or user-uploaded videos are added, complete a fresh Data safety audit.
- Keep the privacy policy consistent with the released binary and backend behavior.

