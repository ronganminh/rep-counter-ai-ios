# App Review demo accounts

Two sign-in accounts for store review: one for Apple (App Store Connect →
App Review Information → **Sign-in required**) and one for Google Play (Play
Console → App content → **App access**). Each has 5 saved workouts, an active
plan and a full week of AI credits, so the reviewer sees the camera rep
counter, Results, My plan and AI Coach without training for two weeks first.

| Store | Email | Password |
|---|---|---|
| App Store | `reviewer-apple@repcoach-ai.duckdns.org` | printed by the script, never stored |
| Google Play | `reviewer-google@repcoach-ai.duckdns.org` | printed by the script, never stored |

The domain is the one already used for the privacy, support and
account-deletion pages. No mailbox is needed: the accounts are created with
the email already confirmed, and nothing in the review flow sends email.
Another owned domain can be used with `DEMO_EMAIL_DOMAIN`.

## Before you run it

- The review build must have accounts on and point at the same Supabase
  project you seed: `ENABLE_ACCOUNTS`, `ENABLE_CLOUD_SYNC`,
  `ENABLE_AI_CREDITS` and, for the AI Coach screens, `ENABLE_AI_COACH_V2`
  set to `true` (as in `dart_defines.staging.example.json`). With accounts
  off, the store listing must say "no sign-in" and these accounts are not
  needed.
- Email + password sign-in is already in the app (Profile → Sign in →
  email and password); nothing else to turn on. The Supabase project must
  allow email sign-in (Authentication → Providers → Email: enabled; "Confirm
  email" may stay on, the script confirms the demo addresses itself).
- You need the project's **service role key** (Supabase → Project Settings
  → API Keys → `service_role` / secret key). It can create and change any
  user: keep it in your terminal only. Do not put it in the repo, a
  `.env` file in the repo, CI, chat or a ticket.

## Run (on the owner's machine)

Python 3.9+ only, no packages. From the repository root:

```bash
export REPCOACH_ENV=staging
```

```bash
export SUPABASE_URL=https://<project-ref>.supabase.co
```

```bash
read -rs SUPABASE_SERVICE_ROLE_KEY && export SUPABASE_SERVICE_ROLE_KEY
```

(`read -rs` keeps the key out of your shell history; paste it and press
Enter.)

```bash
python3 tool/seed_demo_accounts.py
```

For production use `REPCOACH_ENV=prod` and the production URL and key; the
script then asks you to type `prod` before it changes anything. When an
env value is missing, or `REPCOACH_ENV` is not `staging` / `prod`, it stops
before any request.

At the end it prints, once:

```text
Done. Copy these now; they are not saved anywhere.
  [apple] reviewer-apple@repcoach-ai.duckdns.org  password: ••••••••  (created, 5 workouts, 1 plan, 10 AI credits)
  [google] reviewer-google@repcoach-ai.duckdns.org  password: ••••••••  (created, 5 workouts, 1 plan, 10 AI credits)
AI Coach consent is not set: the reviewer sees the consent screen.
```

Paste each password straight into App Store Connect / Play Console, then
clear the terminal and unset the key:

```bash
unset SUPABASE_SERVICE_ROLE_KEY
```

**Run it again before every submission** (and after a rejection, before
you reply). It is idempotent: existing accounts get a **new password**
(update both consoles), the demo workouts and plan are rewritten around the
new date, and AI credits are topped up again. Add `--reset` to also remove
anything recorded during an earlier review (other workouts and plans of
the two demo users only):

```bash
python3 tool/seed_demo_accounts.py --reset
```

`--print-docs` prints the seed data as JSON without any network or env
(used by the app's contract test).

## What each account has

- **5 saved workouts** in the last 15 days (push-up × 3, dumbbell curl × 2,
  3 sets each, with form scores), at noon local time (`DEMO_TIMEZONE`,
  default `America/Los_Angeles`). Enough for Coach's pick (3 workouts, D-32)
  and for "Coach · next week" (14 days of history, D-32).
- **1 active plan**, "Full Body · 6 days" (the default Full Body A/B/C
  templates), training every day except the weekday before the run, so the
  next 6 days all have a planned session and Coach's pick shows on Home.
- **AI credits full**: the weekly allowance (10 on the free tier), topped up
  with an `admin_adjust` ledger row when the reviewer used some.
- **AI Coach consent: not given.** Consent is stored on the phone, never on
  the server, so a fresh install shows the "Turn on AI Coach?" screen.
- Workouts and plan go in through the same sync functions the app uses
  (`sync_push_workouts`, `sync_push_plans`) while signed in as the demo user,
  and appear on the phone a few seconds after sign-in.

## App Store Connect

App → App Store tab → the version → **App Review Information**:

- **Sign-in required**: on.
- **User name**: `reviewer-apple@repcoach-ai.duckdns.org`
- **Password**: the `[apple]` password from the last run.
- **Notes**: the reviewer notes below.
- Contact information: the owner's.

## Google Play Console

App → Policy and programs → **App content** → **App access**:

- "All or some functionality in my app is restricted": selected.
- Add instructions: name "Demo account"; **Username**
  `reviewer-google@repcoach-ai.duckdns.org`; **Password** the `[google]`
  password from the last run; "Any other information required to access
  the app": the reviewer notes below.
- "Allow Android to use the credentials you provide for performance and
  app compatibility testing": on.

## Reviewer notes (paste as is, EN)

```text
RepCoach counts exercise repetitions with the phone camera. Pose estimation
runs on the device; no video or image ever leaves the phone. An account is
optional: training, counting and history work without one.

Sign in: Profile tab > Sign in > enter the email and password above.
This demo account already has 5 saved workouts, an active training plan
and a full week of AI credits.

1) Camera rep counter: Train tab (or Home > "Start plan session"). Allow the
   camera, place the phone about 2 m away so your whole body is visible,
   choose Push-up or Dumbbell curl and start. Reps are counted on screen
   and read aloud; Results shows reps, sets and form scores. You can also
   aim the camera at a video of someone doing push-ups.
2) History and plan: the Progress tab lists the saved workouts; My plan
   (from Home) shows this week's sessions.
3) AI Coach (optional, uses AI credits): Profile > AI Coach. The app first
   asks for consent ("Turn on AI Coach?") and explains that workout
   summaries (numbers only: exercise, reps, sets, duration, form scores)
   are sent to our server, which uses a third-party AI model provider.
   After consent: Home shows "Coach's pick" for today, Results shows
   "Coach review", Profile > AI Coach opens the chat, and My plan offers
   "Coach · next week". Changes to the plan are only made after the user
   taps Accept, and can be undone. The coach gives general fitness
   guidance, not medical advice; questions about pain get a fixed safety
   answer that recommends a health professional.
4) Account deletion: Profile > Delete account (in the app), or
   https://repcoach-ai.duckdns.org/delete-account.html.

The password-reset email cannot be received for this demo address; please
use the password above.
```

## Troubleshooting

- `error: ... -> 401/403` on `/auth/v1/admin/users`: the key is not the
  service role key of that project.
- `error: ... -> 400` on `/auth/v1/token`: email sign-in is disabled in the
  project (Authentication → Providers → Email).
- The reviewer sees no workouts: the build points at another Supabase
  project than the one seeded, or cloud sync is off in that build.
- Coach's pick missing on Home: AI Coach consent not given yet (expected
  until step 3), or the run is more than 6 days old (run the script again).
