# SCREEN_TO_FLUTTER_MAPPING

RepCoach AI · Final C · 2026-10-22

> Target repo: `ronganminh/rep-counter-ai-ios` @ `3594d8a` (Flutter app `rep-counter-ai-main/rep_counter_app`, package `rep_counter_app` 2.0.0+8). Repo facts are **VERIFIED** from source (see `REPO_AUDIT.md`). Route names, new pages, controllers and API paths are **PROPOSED** unless the "Existing Flutter" column names a file.

## Status legend

| Status | Meaning |
|---|---|
| EXISTS-REPLACE-VISUAL | Screen exists in Flutter; restyle to the v2 design. Keep behaviour and tests. |
| PARTIAL | Some behaviour exists (named in the last column); the design adds states/flows. |
| ENGINE | Must bind to the production camera/pose/rep engine. Never replace with a UI-only counter. |
| NEW | No Flutter implementation yet. |
| DESIGN-ONLY | Canvas, marketing or simulator artefact; no app screen. |

Priority: **P0** core loop + shell + l10n infrastructure · **P1** progress, plans, account basics, sync · **P2** AI coach, social, premium, notifications · **P3** extras.

## Family mapping (all 536 frames are covered; per-frame rows in `SCREEN_INVENTORY.csv`)

| Source | Design ID | Screen family | Route (PROPOSED) | Page / widget | State / controller | Data | Backend | Status | Priority | Existing Flutter (VERIFIED) |
|---|---|---|---|---|---|---|---|---|---|---|
| v2 Home + Exercises | H1–H2 | Home (today, streak, LV, October 500, week) | /home (tab 0) | HomeScreen → HomeTab (PROPOSED rename; keep HomeScreen file) | HomeController (PROPOSED, ChangeNotifier) | WorkoutHistoryStore, plan, challenge, XP | NEW API PROPOSED: GET /v1/me/summary (when signed in) | EXISTS-REPLACE-VISUAL | P0 | features/home/presentation/home_screen.dart |
| v2 Home + Exercises | P1–P3 | Exercise library, categories, search | /exercises (tab 1) | ExerciseLibraryPage (PROPOSED) reusing ExercisePickerScreen grid | ExerciseCatalog (static, feature flags) | ExerciseProfile list | NO BACKEND REQUIRED | PARTIAL | P1 | features/exercises/presentation/exercise_picker_screen.dart |
| v2 Home + Exercises | P4–P5 | Exercise detail + demonstration | /exercises/:exerciseId | ExerciseDetailPage (PROPOSED); exercise_help_sheet reused | stateless | ExerciseProfile, PRs | NO BACKEND REQUIRED | PARTIAL | P1 | features/workout/presentation/exercise_help_sheet.dart |
| v2 Home + Exercises | P6–P7 | Camera positioning guide + preparation | (inside CameraPage) | CameraPage phases positioning/ready/calibrating/countdown | WorkoutController + WorkoutUiPhase | PlacementStatus, GuideZone | NO BACKEND REQUIRED | ENGINE | P0 | lib/camera_page.dart, lib/placement.dart |
| v2 Home + Exercises | P8 | Squat HUD | (CameraPage, exerciseId=squat) | WorkoutHud | WorkoutController | ExerciseProfile squat | NO BACKEND REQUIRED | NEW (engine profile missing; squat is a placeholder) | P3 | exercise.dart (no squat profile) |
| v2 Home + Exercises | P9 / P9b | Guided timer + manual log | /workout/timer · /workout/manual | GuidedTimerPage, ManualLogPage (PROPOSED) | ManualWorkoutController (PROPOSED) | WorkoutRecord(source: manual) (PROPOSED field) | NO BACKEND REQUIRED | NEW | P1 | — |
| v2 Home + Exercises | P10 | Completion summary (1.10) | /workout/:sessionId/results | ResultPage | ResultController | WorkoutRecord | EXISTING API: POST /v1/workout-feedback | EXISTS-REPLACE-VISUAL | P0 | result_page.dart |
| Phase 2 Plans | P2-01–03 | Plan setup: goal, level, availability | /plans/setup | PlanSetupFlow (PROPOSED) | PlanSetupController | TrainingPlan (PROPOSED model) | NEW API PROPOSED: POST /v1/plans (optional, local-first) | NEW | P1 | plan_today_sheet.dart (single-session goal only) |
| Phase 2 Plans | P2-04–06 | Plan overview, weekly calendar, day detail | /home/plan · /home/plan/day/:date | PlanOverviewPage, PlanDayPage (PROPOSED) | PlanController | TrainingPlan, ScheduledSession | NEW API PROPOSED: GET/PUT /v1/plans/current | NEW | P1 | — |
| Phase 2 Plans | P2-07–10 | Plan session: camera set, set tracker, rest, pause | (CameraPage with routine) | CameraPage + RoutineRestOverlay + WorkoutHud | WorkoutController (routine mode) | RoutineSnapshot | NO BACKEND REQUIRED | ENGINE + PARTIAL (routines exist) | P0 | features/routine/*, camera_page.dart |
| Phase 2 Plans | P2-11 | Workout completion | /workout/:sessionId/results | ResultPage | ResultController | WorkoutRecord | EXISTING API: POST /v1/workout-feedback | EXISTS-REPLACE-VISUAL | P0 | features/workout/presentation/result_page.dart |
| Phase 2 Plans | P2-12 | Missed session → reschedule | /home/plan/reschedule (sheet) | RescheduleSheet (PROPOSED) | PlanController | ScheduledSession.movedFrom | NO BACKEND REQUIRED (local) / plan sync if signed in | NEW | P2 | — |
| Phase 3 Progress | P3-01 | Progress overview | /progress (tab 3) | ProgressPage (PROPOSED; split from HistoryPage) | ProgressController over progress_statistics | WorkoutHistoryStore | NO BACKEND REQUIRED / sync for multi-device | PARTIAL | P0 | history_page.dart, progress_statistics.dart |
| Phase 3 Progress | P3-02–04 | Weekly stats, monthly calendar, exercise progress | /progress/week · /progress/calendar · /progress/exercise/:id | existing trend bars + heatmap widgets, restyled | ProgressController | progress_statistics | NO BACKEND REQUIRED | PARTIAL | P1 | history_page.dart |
| Phase 3 Progress | P3-05 | Personal records | /progress/records | PersonalRecordsPage (PROPOSED) | WorkoutPersonalRecordStore | records | NO BACKEND REQUIRED | PARTIAL (logic exists) | P1 | domain/workout_personal_records.dart |
| Phase 3 Progress | P3-06 | Form score trends | /progress/form | FormTrendPage (PROPOSED); form_score_details reused | ProgressController | WorkoutQuality | NO BACKEND REQUIRED | PARTIAL | P2 | widgets/form_score_details.dart |
| Phase 3 Progress | P3-07–08 | Workout history list + detail (incl. partial) | /progress/history · /progress/history/:workoutId | HistoryPage list → HistoryListPage; ResultPage(readOnly) | HistoryController (PROPOSED wrapper) | WorkoutHistoryStore (delete/undo exists) | NO BACKEND REQUIRED / sync delete tombstones | EXISTS-REPLACE-VISUAL | P0 | history_page.dart, result_page.dart |
| Phase 3 Progress | P3-09–10 | Consistency/streaks, compare + highlights | /progress/streaks · /progress/compare | StreakPage, ComparePage (PROPOSED) | ProgressController | history | NO BACKEND REQUIRED | NEW | P2 | — |
| Phase 4 AI Coach | P4-01 | AI Coach overview | /coach | CoachHomePage (PROPOSED) | CoachController | insights, credits | NEW API PROPOSED: GET /v1/coach/overview | NEW | P2 | — |
| Phase 4 AI Coach | P4-02 | AI workout feedback | (ResultPage card) · /workout/:id/feedback | ResultFeedbackCard / FeedbackCard | ResultController (ResultFeedbackPhase) | WorkoutRecord.toAiPayload | EXISTING API: POST /v1/workout-feedback | EXISTS-REPLACE-VISUAL | P0 | widgets/result_feedback_card.dart, ai_feedback_service.dart |
| Phase 4 AI Coach | P4-03–05, P4-07 | Progress analysis, next workout, goals, insight detail | /coach/analysis · /coach/next · /coach/goals · /coach/insight/:id | pages (PROPOSED) | CoachController | history summary | NEW API PROPOSED: POST /v1/coach/analysis (credit-metered, requestId) | NEW | P2 | — |
| Phase 4 AI Coach | P4-06 | Coach chat (empty/active/failed/limit) | /coach/chat | CoachChatPage (PROPOSED) | CoachChatController | messages, credits ledger | NEW API PROPOSED: POST /v1/coach/messages (Idempotency-Key) | NEW | P2 | — |
| Phase 4 AI Coach | P4-08 | AI consent | (dialog/sheet) | ai_consent.dart dialogs | AiPreferences | consent version | NO BACKEND REQUIRED | EXISTS-REPLACE-VISUAL | P0 | features/ai/presentation/ai_consent.dart |
| Phase 4 AI Coach | P4-09–10 | AI usage + network/failure states | /coach/usage | AiUsagePage (PROPOSED); failure states reuse AiFeedbackFailure | CreditsController (PROPOSED) | credits balance | NEW API PROPOSED: GET /v1/credits | PARTIAL (failure enum only) | P2 | ai_feedback_service.dart |
| Phase 5 Gamification | P5-01–05 | Challenges: discovery, detail, join, progress, complete | /challenges · /challenges/:id | ChallengesPage, ChallengeDetailPage (PROPOSED) | ChallengeController | challenge progress (server-authoritative) | NEW API PROPOSED: GET /v1/challenges, POST /v1/challenges/:id/join | NEW (Time Challenge mode is different) | P2 | domain/workout_mode.dart (timed) |
| Phase 5 Gamification | P5-06 | XP + level | /profile/level | LevelPage (PROPOSED) | XpController | XP ledger | NEW API PROPOSED: GET /v1/me/xp (server-authoritative) | NEW | P2 | — |
| Phase 5 Gamification | P5-07–09 | Achievements, detail, milestones | /progress/achievements · /progress/achievements/:id | AchievementsPage (PROPOSED) + AchievementEarnedCard | AchievementService | earned_achievements_v1 (6 local) | NO BACKEND REQUIRED / sync later | PARTIAL | P1 | features/achievements/* |
| Phase 5 Gamification | P5-10 | Streak + motivation | /progress/streaks | StreakPage (shared with P3-09) | ProgressController | history | NO BACKEND REQUIRED | NEW | P2 | — |
| Phase 6 Voice Coach | P6-01–03, P6-08–09 | Voice Coach intro, settings, voice/language, audio a11y, personalization | /profile/settings/voice | VoiceSettingsPage (extend VoiceCadencePage) | TrainingPreferences | training_* prefs | NO BACKEND REQUIRED | PARTIAL | P2 | features/legal/voice_cadence_page.dart, core/services/training_preferences.dart |
| Phase 6 Voice Coach | P6-04–06 | Live voice overlay, guidance, rest coaching | (CameraPage overlay) | WorkoutHud + WorkoutFeedback (TTS) | WorkoutFeedback / SpeechDriver | engine events RepCompleted / RepAborted | NO BACKEND REQUIRED | ENGINE + PARTIAL | P2 | core/services/workout_feedback.dart |
| Phase 6 Voice Coach | P6-07, P6-10 | Coaching history, speech unavailable | /profile/settings/voice/history | pages (PROPOSED) | WorkoutFeedback | local | NO BACKEND REQUIRED | PARTIAL (speech-unavailable message exists) | P3 | camera_page.dart tr("Không có giọng đọc…") |
| Phase 7 Social | P7-01–04 | Friends, find, profile, requests | /profile/friends · /profile/friends/find · /profile/friends/:userId | FriendsPage etc. (PROPOSED) | FriendsController | friends graph | NEW API PROPOSED: /v1/friends* | NEW | P2 | — |
| Phase 7 Social | P7-05 | Weekly leaderboard | /profile/friends/leaderboard | LeaderboardPage (PROPOSED) | LeaderboardController | server aggregates (camera-counted only) | NEW API PROPOSED: GET /v1/leaderboards/weekly | NEW | P2 | — |
| Phase 7 Social | P7-06–08 | Challenge a friend, head-to-head, result | /profile/friends/challenge/new · /races/:raceId | pages (PROPOSED) | RaceController | races | NEW API PROPOSED: /v1/races* | NEW | P2 | — |
| Phase 7 Social | P7-09 | Share achievement | /share/:kind/:id | StoryPage (extend) | stateless | record | NO BACKEND REQUIRED | PARTIAL | P2 | features/share/story_page.dart |
| Phase 7 Social | P7-10 | Social privacy, block/report | /profile/settings/social-privacy | SocialPrivacyPage (PROPOSED) | FriendsController | privacy prefs | NEW API PROPOSED: PUT /v1/me/privacy, POST /v1/reports, POST /v1/blocks | NEW | P2 | — |
| Phase 8 Premium | P8-01–04 | Pro intro, Free vs Pro, plan selection, contextual paywalls | /pro · /pro/plans (modal) | ProPage, PlanSelectionSheet (PROPOSED) | EntitlementController | ProductDetails from store SDK | NEW API PROPOSED: GET /v1/entitlements | NEW | P2 | — |
| Phase 8 Premium | P8-05–06 | AI credits + rewarded ads (Android) | /coach/usage · (sheet) | CreditsSheet, RewardedAdOffer (PROPOSED) | CreditsController | credit ledger | NEW API PROPOSED: GET /v1/credits, POST /v1/ads/reward/verify (SSV) | NEW | P3 | — |
| Phase 8 Premium | P8-07 | Purchase + verification states | (store sheet) → /pro/status | PurchaseFlow (PROPOSED) on in_app_purchase | PurchaseController | PurchaseDetails | NEW API PROPOSED: POST /v1/purchases/verify (App Store Server API / Play Developer API) | NEW | P2 | — |
| Phase 8 Premium | P8-08–10 | Manage subscription, membership in Profile, restore | /profile/membership · /profile/membership/restore | MembershipPage, RestorePage (PROPOSED) | EntitlementController | entitlement cache (≤7 days, proposed) | NEW API PROPOSED: POST /v1/purchases/restore | NEW | P2 | — |
| Phase 9 Auth | P9-01 | Welcome / account-required gateway | /auth/welcome · /auth/gate?returnTo= | AuthGatePage (PROPOSED) | AuthController | returnTo | NEW API PROPOSED: auth provider | NEW | P1 | onboarding_page.dart (no auth) |
| Phase 9 Auth | P9-02–05 | Sign in, create account, verification, social sign-in | /auth/sign-in · /auth/sign-up · /auth/verify | pages (PROPOSED) | AuthController (state machine guest→authenticated) | session tokens (secure storage) | NEW API PROPOSED: auth provider — choice REQUIRES VERIFICATION | NEW | P1 | — |
| Phase 9 Auth | P9-06 | Guest upgrade + merge (dry-run, conflicts) | /auth/merge | GuestMergePage (PROPOSED) | MigrationController | local workouts with clientId | NEW API PROPOSED: POST /v1/account/upgrade/dry-run, POST /v1/sync/batch | NEW | P1 | — |
| Phase 9 Account | P9-07–08 | Profile tab + edit profile | /profile (tab 4) · /profile/edit | ProfilePage (PROPOSED) | ProfileController | profile | NEW API PROPOSED: GET/PATCH /v1/me | NEW (Settings tab exists instead) | P0 (tab shell) / P1 (account content) | app_shell.dart |
| Phase 9 Account | P9-09 | Settings hub | /profile/settings | SettingsPage (existing, restyle + regroup) | LocaleController, TrainingPreferences | prefs | NO BACKEND REQUIRED | EXISTS-REPLACE-VISUAL | P0 | features/legal/settings_page.dart |
| Phase 9 Account | P9-10 | Account + security | /profile/settings/account | AccountSecurityPage (PROPOSED) | AuthController | sessions/devices | NEW API PROPOSED: /v1/me/sessions | NEW | P2 | — |
| Phase 9 Account | P9-11 | Privacy, export, delete scopes, delete account | /profile/privacy · /profile/privacy/export · /profile/privacy/delete-account | PrivacyPage (PROPOSED) + ExportDataSheet (existing) + DeleteAccountPage (PROPOSED) | PrivacyController | local + cloud | NEW API PROPOSED: POST /v1/me/export, DELETE /v1/me (async) | PARTIAL (local export + local delete exist) | P1 | export_data_sheet.dart, settings_page.dart _deleteData |
| Phase 9 Account | P9-12 | Session expired, sync status, offline, errors | (global banners) | SessionBanner (PROPOSED) | AuthController, SyncController | token refresh | NEW API PROPOSED: refresh token endpoint | NEW | P1 | — |
| Phase 10 Notifications | P10-01 | Notification center (inbox) | /home/inbox | InboxPage (PROPOSED) | InboxController | local + server inbox | NEW API PROPOSED: GET /v1/inbox, POST /v1/inbox/read | NEW | P2 | — |
| Phase 10 Notifications | P10-02, P10-12 | Permission intro, denied recovery | (sheet) /profile/settings/notifications | NotificationPermissionSheet (PROPOSED) | NotificationPermissionController | OS permission state | NO BACKEND REQUIRED | NEW | P2 | — |
| Phase 10 Notifications | P10-03–04 | Workout reminders, smart reminders | /profile/settings/notifications/reminders | ReminderSettingsPage (PROPOSED) | ReminderScheduler (flutter_local_notifications, PROPOSED) | plan schedule | NO BACKEND REQUIRED (local scheduling) | NEW | P2 | — |
| Phase 10 Notifications | P10-05–08 | AI-ready, challenge, friend, payment notifications | (push → deep link) | push templates | PushRouter (PROPOSED) | FCM/APNs token | NEW API PROPOSED: POST /v1/devices (push token), server push events | NEW | P2 | — |
| Phase 10 Notifications | P10-09–10 | Notification settings, quiet hours | /profile/settings/notifications | NotificationSettingsPage (PROPOSED) | NotificationPrefs | prefs (+server for push categories) | EXISTING API NEEDS EXTENSION: PUT /v1/me/notification-prefs (new) | NEW | P2 | — |
| Phase 10 Notifications | P10-11 | Deep-link simulator (design tool) | — | — | — | — | NO BACKEND REQUIRED | DESIGN-ONLY (use for deep-link test matrix) | — | — |
| Final A | FA-01 | Launch: splash, init, restore, failure | / (startup) | RepCounterApp startup (main.dart) + StartupGate (PROPOSED) | AppInitializer (PROPOSED) | prefs, recovery draft | NO BACKEND REQUIRED | PARTIAL (onboarding gate) | P0 | main.dart |
| Final A | FA-02 | First workout bridge, camera explanation/denied | /onboarding → /workout | OnboardingPage + CameraPermissionView | WorkoutController | permission | NO BACKEND REQUIRED | PARTIAL | P0 | onboarding_page.dart, widgets/camera_permission_view.dart |
| Final A | FA-03 | Free-mode results + save states | /workout/:sessionId/results | ResultPage | ResultController | WorkoutRecord | EXISTING API: POST /v1/workout-feedback | EXISTS-REPLACE-VISUAL | P0 | result_page.dart |
| Final A | FA-04 | Saving, offline save, sync pending/failed, duplicates | (results + global badge) | SyncStatusBadge (PROPOSED) | SyncController (PROPOSED) + WorkoutHistoryStore | clientId per record | NEW API PROPOSED: POST /v1/sync/batch (idempotent by clientId) | PARTIAL (local save only) | P1 | workout_history_store.dart |
| Final A | FA-05 | AI card states (queued, disabled, consent, allowance, retry) | (ResultPage) | ResultFeedbackCard | ResultController | ResultFeedbackPhase | EXISTING API: POST /v1/workout-feedback | PARTIAL | P0 | result_feedback_card.dart |
| Final A | FA-06 | Share preview + outcomes | /share/workout/:id | StoryPage (extend with toggles) | stateless | record | NO BACKEND REQUIRED | PARTIAL | P1 | story_page.dart |
| Final A | FA-07 | History delete, undo 5 s, offline, multi-device | /progress/history | HistoryListPage | WorkoutHistoryStore.delete/restore | tombstones (PROPOSED for sync) | NO BACKEND REQUIRED / sync tombstones | PARTIAL (delete+undo exist) | P0 | history_page.dart |
| Final A | FA-08 | Delete data hub: phone / account / both; account separate | /profile/privacy/delete | DeleteDataHubPage + TypeToConfirm (existing _DeleteDataDialog pattern) | PrivacyController | local + cloud | NEW API PROPOSED: DELETE /v1/workouts (account scope) | PARTIAL (phone scope exists) | P1 | settings_page.dart _DeleteDataDialog |
| Final A | FA-09 | Calibration reset, no person, tracking unavailable, denied | /profile/settings/calibration · (CameraPage) | CalibrationSettingsPage + CameraPage states | CalibrationStore, WorkoutController | CalibrationSnapshot | NO BACKEND REQUIRED | ENGINE + EXISTS-REPLACE-VISUAL | P0 | settings_page.dart CalibrationSettingsPage |
| Final A | FA-10 | Hold to finish, Back, discard, partial save, lifecycle, recovery | (CameraPage) · /workout/recover | WorkoutHud hold + exit dialog; RecoveryPage (PROPOSED) | WorkoutController + WorkoutDraftStore (PROPOSED) | in-progress draft | NO BACKEND REQUIRED | PARTIAL (hold, pause, exit, lifecycle exist; recovery NEW) | P0 | camera_page.dart, workout_hud.dart |
| Final A | FA-11 | Toasts, banners, sync badges, empty, retry, access denied | (global) | AppToast, AppBanner, StatusHero (PROPOSED in widgets/product_ui.dart) | — | — | NO BACKEND REQUIRED | PARTIAL | P0 | widgets/product_ui.dart |
| Final A | FA-12 | Help, FAQ, contact, report, about, legal | /profile/help · /profile/help/contact · /profile/about | HelpPage (PROPOSED) + LegalPage (existing) | SupportController | diagnostics (reviewable) | EXISTING API NEEDS EXTENSION: backend serves /support.html today; contact endpoint NEW PROPOSED POST /v1/support/tickets | PARTIAL (legal pages) | P1 | legal_page.dart, backend/static/support.html |
| Final B | FB-00 | Integrated prototype (39 routes, shared state) | reference only | — | Reference for route graph, guards and state machines | — | — | DESIGN-ONLY (behaviour reference) | — | — |
| v1 Foundation | Onboarding A1–A3, B1 | Onboarding + camera pre-permission | /onboarding | OnboardingPage | prefs onboarding_v1 | — | NO BACKEND REQUIRED | IMPLEMENTED (v1) | P0 (restyle to v2) | features/legal/onboarding_page.dart |
| v1 Foundation | Home A0–A2, B1–B3 | v1 Home, exercise picker, goal sheet | /home (superseded by v2 H1) | HomeScreen, ExercisePickerScreen, PlanTodaySheet | — | — | NO BACKEND REQUIRED | IMPLEMENTED (v1) · superseded visually by v2 | P0 | home_screen.dart, plan_today_sheet.dart |
| v1 Foundation | Camera C0–C4 | Positioning, ready, calibrating, countdown | (CameraPage) | CameraPage | WorkoutUiPhase positioning→countdown | engine | NO BACKEND REQUIRED | ENGINE / IMPLEMENTED | P0 | camera_page.dart |
| v1 Foundation | HUD A0–F1, Z | HUD live/goal/lost/hold/free/paused/goal reached/over goal/saved | (CameraPage) | WorkoutHud | WorkoutUiState | engine | NO BACKEND REQUIRED | ENGINE / IMPLEMENTED | P0 | widgets/workout_hud.dart |
| v1 Foundation | Results R1–R2, S1 | Results reached/stopped early, story | /workout/:id/results · /share/workout/:id | ResultPage, StoryPage | ResultController | record | EXISTING API: POST /v1/workout-feedback | IMPLEMENTED (v1) | P0 | result_page.dart, story_page.dart |
| v1 Foundation | History-Settings H1–H3, S1–S3, C1 | History, detail, empty, settings, calibration, delete, AI consent | /progress/history · /profile/settings | HistoryPage, SettingsPage, ai_consent | — | — | NO BACKEND REQUIRED | IMPLEMENTED (v1) | P0 | history_page.dart, settings_page.dart |
| v1 Foundation | Design System, Flow, App Icon, App Store screenshots | Design system specimen, click-through, icon, store art | — | — | — | — | — | DESIGN-ONLY | — | assets/icon, play/, store_listing/ |

## Summary

| Status | Families |
|---|---|
| NEW | 31 |
| PARTIAL | 22 |
| EXISTS-REPLACE-VISUAL | 8 |
| ENGINE | 6 |
| IMPLEMENTED | 4 |
| DESIGN-ONLY | 3 |

| Priority | Families |
|---|---|
| P0 | 25 |
| P1 | 17 |
| P2 | 26 |
| P3 | 3 |
| — | 3 |

## Screens already present in Flutter

- `OnboardingPage`, `AppShell` (3 tabs → becomes the 5-tab shell), `HomeScreen`, `ExercisePickerScreen`, `PlanTodaySheet`/`GoalSetupPage`, `RoutineListSection`/`RoutineEditorPage`, `CameraPage` (+ `WorkoutHud`, `RoutineRestOverlay`, `CameraPermissionView`), `ResultPage` (+ `ResultHero`, `ResultFeedbackCard`, `FormScoreDetails`, `RepPaceChart`, `TimedChallengeResult`), `StoryPage`, `HistoryPage`, `SettingsPage`, `VoiceCadencePage`, `CalibrationSettingsPage`, `LegalPage`, `ExportDataSheet`, AI consent dialogs, `LocalVideoTestPage` (debug only).

## Needing visual replacement only

- Home, Results, History list/detail, Settings, AI consent, calibration, onboarding, HUD chrome (not the engine), story share.

## Entirely new

- 5-tab shell destinations Exercises/Progress/Profile, plans (multi-day), challenges/XP, AI Coach chat/analysis/credits, social, premium/billing, auth/guest upgrade/merge, cloud sync, inbox/notifications/reminders, recovery after process kill, help/contact.

## Duplicate or obsolete in Flutter

- `enum WorkoutPhase` (domain/workout_state.dart) is referenced only by tests; the live UI uses `WorkoutUiPhase`. Keep tests green; do not build new UI on `WorkoutPhase`.
- `ENABLE_AI_FEEDBACK` flag is declared but unused (feature_flags.dart).
- History tab hosts progress analytics; Final C splits it into Progress (tab 4) with History as a child route. Do not keep two progress screens.
- `design-handoff/` (Sep 29) describes a 3-tab app; it is superseded by this handoff for layout, but its engine/state notes remain valid.

## Missing navigation integrations

- No named routes / deep links today (Navigator 1 `MaterialPageRoute`). Notification deep links, auth `returnTo`, and Profile/Progress tabs need a router (see `APP_NAVIGATION_MAP.md`).
- No route from Home to inbox/profile; no Profile tab; Settings is a tab today (becomes Profile → Settings).

## Platform-specific screens

- iOS: StoreKit purchase sheet, Ask to Buy pending, Manage subscription (App Store), Sign in with Apple (if any third-party login ships).
- Android: Play Billing sheet, rewarded ad offer (opt-in, cap 3/day proposed), system Back on HUD (FA-10).
- Web only: Lemon Squeezy checkout (never inside the mobile apps).

## Reusable widgets (canonical, see COMPONENT_REGISTRY.md)

- Existing: `SectionLabel`, `SettingsGroup`, `SettingsRow`, `SegmentChip`, `MetricCard` (widgets/product_ui.dart), `WorkoutHud`, `RepFeedbackPill`, `ResultHero`, `ResultFeedbackCard`, `AchievementEarnedCard`, `CameraPermissionView`.
- New (PROPOSED): `AppTabScaffold`, `TrainTabButton`, `StatTile`, `ChallengeMeter`, `SyncStatusBadge`, `AppBanner`, `AppToast`, `StatusHero`, `TypeToConfirmField`, `HoldToFinishButton` (extract from HUD), `PrivacyBadge`, `AuthGateView`, `MergePreview`, `CreditsChip`, `ProPlanCard`, `InboxRow`, `PushBanner` (in-app).
