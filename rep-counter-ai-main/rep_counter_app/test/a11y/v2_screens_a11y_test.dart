import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/exercise.dart';
import 'package:rep_counter_app/features/auth/application/auth_controller.dart';
import 'package:rep_counter_app/features/auth/presentation/auth_welcome_page.dart';
import 'package:rep_counter_app/features/auth/presentation/sign_in_page.dart';
import 'package:rep_counter_app/features/auth/presentation/sign_up_page.dart';
import 'package:rep_counter_app/features/plan/application/plan_repository.dart';
import 'package:rep_counter_app/features/plan/application/reminder_service.dart';
import 'package:rep_counter_app/features/plan/domain/local_date.dart';
import 'package:rep_counter_app/features/plan/domain/plan_templates.dart';
import 'package:rep_counter_app/features/plan/domain/reminder_planner.dart';
import 'package:rep_counter_app/features/plan/presentation/plan_overview_page.dart';
import 'package:rep_counter_app/features/plan/presentation/plan_setup_page.dart';
import 'package:rep_counter_app/features/plan/presentation/reminder_settings_page.dart';
import 'package:rep_counter_app/features/plan/presentation/session_detail_page.dart';
import 'package:rep_counter_app/features/workout/data/workout_draft_store.dart';
import 'package:rep_counter_app/features/workout/data/workout_record.dart';
import 'package:rep_counter_app/features/workout/domain/workout_mode.dart';
import 'package:rep_counter_app/features/workout/presentation/manual_log_page.dart';
import 'package:rep_counter_app/features/workout/presentation/recovery_page.dart';
import 'package:rep_counter_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_auth_repository.dart';
import '../support/l10n.dart';

/// Q-1b: code-level accessibility checks on the v2 screens added after
/// Q-1 (plans, reminders, manual entry): 48 dp / 44 pt targets, labelled
/// targets and text contrast, at text scale 1.0 and 2.0. Device checks
/// with VoiceOver / TalkBack stay UNVERIFIED.

class _NoPlatform implements ReminderPlatform {
  @override
  Future<ReminderPermission> permission() async => ReminderPermission.granted;
  @override
  Future<ReminderPermission> requestPermission() async =>
      ReminderPermission.granted;
  @override
  Future<Map<int, String?>> pending() async => {};
  @override
  Future<void> schedule(PlannedReminder r, String t, String b) async {}
  @override
  Future<void> cancel(int id) async {}
}

final monday = LocalDate(2026, 11, 2);

void main() {
  late PlanRepository repo;
  var n = 0;
  final now = DateTime(2026, 11, 2, 9);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repo = PlanRepository(
        loadWorkouts: () async => <WorkoutRecord>[],
        now: () => now,
        newId: () => 'id${++n}');
  });

  Future<void> check(WidgetTester tester, Widget page,
      {double scale = 1}) async {
    final handle = tester.ensureSemantics();
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final locale = LocaleController(AppLanguage.en);
    addTearDown(locale.dispose);
    await tester.pumpWidget(LocaleScope(
      controller: locale,
      child: MaterialApp(
        theme: RepCoachTheme.dark(),
        locale: AppLanguage.en.locale,
        supportedLocales: testSupportedLocales,
        localizationsDelegates: testLocalizationsDelegates,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!),
        home: page,
      ),
    ));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    if (scale == 1) {
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    }
    handle.dispose();
  }

  Future<String> activate(WidgetTester tester) async {
    await tester.runAsync(() => repo.activate(PlanTemplates.beginnerPlan(
        id: 'plan', startDate: monday, timezone: 'UTC', now: now)));
    return (await tester.runAsync(repo.load))!.todaySession!.id;
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('plan setup ×$scale', (tester) async {
      await check(tester, PlanSetupPage(repository: repo), scale: scale);
    });

    testWidgets('plan overview ×$scale', (tester) async {
      await activate(tester);
      await check(tester, PlanOverviewPage(repository: repo), scale: scale);
    });

    testWidgets('session detail ×$scale', (tester) async {
      final id = await activate(tester);
      await check(tester, SessionDetailPage(sessionId: id, repository: repo),
          scale: scale);
    });

    testWidgets('reminder explanation and settings ×$scale', (tester) async {
      await activate(tester);
      final view = (await tester.runAsync(repo.load))!;
      final service = ReminderService(platform: _NoPlatform(), now: () => now);
      await check(tester, ReminderSettingsPage(view: view, service: service),
          scale: scale);
      await tester.runAsync(
          () => ReminderPrefsStore().save(const ReminderPrefs(enabled: true)));
      await check(tester, ReminderSettingsPage(view: view, service: service),
          scale: scale);
    });

    testWidgets('manual entry ×$scale', (tester) async {
      await check(tester, const ManualLogPage(profile: pushUp), scale: scale);
    });

    testWidgets('recovery ×$scale', (tester) async {
      await check(
          tester,
          RecoveryPage(
              draft: WorkoutDraft(
            startedAt: DateTime.now().subtract(const Duration(minutes: 30)),
            updatedAt: DateTime.now().subtract(const Duration(minutes: 25)),
            exerciseId: 'push_up',
            exerciseName: 'Push-up',
            reps: 14,
            sets: 2,
            durationSeconds: 168,
            mode: WorkoutMode.targetReps,
            targetReps: 20,
          )),
          scale: scale);
    });

    testWidgets('auth welcome, sign in, sign up ×$scale', (tester) async {
      final auth = AuthController(FakeAuthRepository());
      await check(tester, AuthWelcomePage(controller: auth), scale: scale);
      await check(tester, SignInPage(controller: auth), scale: scale);
      await check(tester, SignUpPage(controller: auth), scale: scale);
    });
  }
}
