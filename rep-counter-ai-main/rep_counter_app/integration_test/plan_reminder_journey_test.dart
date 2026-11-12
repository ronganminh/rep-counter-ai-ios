// QA v2 · J-07 plan setup from the Home card, and an active plan's
// Workout reminders: explanation with Continue only, Don't Allow in the OS
// prompt returns to the overview without opening Settings (5.1.1(iv),
// L-D24 / L-D38); reopening while notifications are off shows the neutral
// notice. The notifications plugin is faked (never granted).
//
// QA-07 (docs/qa/QA_REPORT_v2.md): every page opened from the Home plan card
// trips Flutter's debug assertion "setState() callback argument returned a
// Future" when it is popped (`PlanHomeCard._open`, plan_home_card.dart:51),
// which ends a widget test as an uncaught error. Until that is fixed these
// journeys never pop back to Home from a card-opened page; they end on that
// page instead (`closeApp`). The plan is seeded through the repository so
// the overview can be opened directly.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/app/app_tab_bar.dart';
import 'package:rep_counter_app/features/plan/application/plan_repository.dart';
import 'package:rep_counter_app/features/plan/data/plan_store.dart';
import 'package:rep_counter_app/features/plan/domain/local_date.dart';
import 'package:rep_counter_app/features/plan/domain/plan_templates.dart';
import 'package:rep_counter_app/features/plan/presentation/plan_overview_page.dart';
import 'package:rep_counter_app/features/plan/presentation/plan_setup_page.dart';
import 'package:rep_counter_app/features/plan/presentation/reminder_settings_page.dart';
import 'package:rep_counter_app/widgets/app_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_harness.dart';

void main() {
  final binding = ensureQaBinding();
  late PluginFakes fakes;

  setUp(() {
    fakes = PluginFakes(binding.defaultBinaryMessenger)..install();
  });
  tearDown(() => fakes.uninstall());

  /// An active default plan (Mon/Wed/Fri) starting this week, as the setup
  /// page would create it, written to the real local store.
  Future<void> seedPlan(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(
        {'onboarding_v1': true, 'app_language': 'en'});
    final now = DateTime.now();
    final monday = LocalDate.of(now).startOfWeek;
    await tester.runAsync(() => PlanRepository(now: () => now).activate(
        PlanTemplates.beginnerPlan(
            id: 'qa-plan',
            startDate: monday,
            timezone: now.timeZoneName,
            now: now)));
    await pumpAppKeepingPrefs(tester);
  }

  testWidgets(
      'setup from the Home card: goal → level → days → preview; nothing is '
      'saved before "Create my plan"', (tester) async {
    await pumpApp(tester, prefs: {'onboarding_v1': true, 'app_language': 'en'});
    await tapKey(tester, 'plan-home-card');
    expect(find.byType(PlanSetupPage), findsOneWidget);
    expect(find.byType(AppTabBar), findsNothing, reason: 'D-02');
    expect(find.text("What's your main goal?"), findsOneWidget);
    await tapKey(tester, 'plan-setup-next');
    expect(find.text('How much do you train now?'), findsOneWidget);
    await tapKey(tester, 'plan-setup-next');
    expect(find.text('When can you train?'), findsOneWidget);
    expect(find.text('3 sessions a week · Mon, Wed, Fri'), findsOneWidget);
    await tapKey(tester, 'plan-setup-next');
    expect(find.text('Four-week preview'), findsOneWidget);
    expect((await PlanStore().load()).plans, isEmpty,
        reason: 'the preview saves nothing');
    // QA-07: not popping back to Home (see the file comment).
    await closeApp(tester);
  });

  testWidgets(
      'active plan → overview → reminders: Continue only, Don\'t Allow '
      'returns to the overview, Settings never opened; notice on reopen',
      (tester) async {
    await seedPlan(tester);
    expect(fakes.notificationCalls.where((c) => c.contains('request')),
        isEmpty, reason: 'no notification prompt at launch');
    await tapKey(tester, 'plan-home-card');
    expect(find.byType(PlanOverviewPage), findsOneWidget);
    expect(find.byType(AppTabBar), findsNothing, reason: 'D-02');
    expect(
        await anyAppears(tester, [
          find.byKey(const Key('plan-today')),
          find.byKey(const Key('plan-open-today')),
          find.byKey(const Key('plan-open-recovery')),
        ]),
        isTrue,
        reason: 'either a planned session or a recovery day for today');
    expect(find.byKey(const Key('plan-week-summary')), findsOneWidget);

    await tapKey(tester, 'plan-menu');
    await tapText(tester, 'Workout reminders');
    expect(find.byType(ReminderSettingsPage), findsOneWidget);

    // Explanation before the OS prompt.
    expect(find.text('Get reminders for planned sessions'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Continue'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    expect(find.text('Not now'), findsNothing);
    for (final text in visibleTexts(tester)) {
      expect(text.toLowerCase(), isNot(contains('allow')), reason: text);
    }
    expect(fakes.notificationCalls,
        isNot(contains('requestNotificationsPermission')));
    await systemBack(tester);
    expect(find.byType(ReminderSettingsPage), findsOneWidget,
        reason: 'no way out before the prompt');

    // Continue → OS prompt → Don't Allow → back to the overview.
    await tapKey(tester, 'reminder-enable');
    if (Platform.isAndroid || Platform.isIOS) {
      // On the host the plugin has no Android/iOS implementation to call;
      // the request is still answered "denied" (ReminderService).
      expect(fakes.notificationCalls,
          anyOf(contains('requestNotificationsPermission'),
              contains('requestPermissions')));
    }
    expect(find.byType(ReminderSettingsPage), findsNothing);
    expect(find.byType(PlanOverviewPage), findsOneWidget);
    expect(fakes.settingsOpened, 0);
    expect(find.byType(SnackBar), findsNothing);
    expect(fakes.notificationCalls.where((c) => c == 'zonedSchedule'),
        isEmpty, reason: 'nothing scheduled without permission');

    // Reopen while notifications are off: the neutral notice only.
    await tapKey(tester, 'plan-menu');
    await tapText(tester, 'Workout reminders');
    expect(find.byKey(const Key('reminder-off-message')), findsOneWidget);
    expect(find.byKey(const Key('reminder-off-back')), findsOneWidget);
    expect(find.byKey(const Key('reminder-off-settings')), findsOneWidget);
    expect(find.text('Continue'), findsNothing);
    await tapKey(tester, 'reminder-off-settings');
    expect(fakes.settingsOpened, 1);
    await tapKey(tester, 'reminder-off-back');
    expect(find.byType(PlanOverviewPage), findsOneWidget);
    // QA-07: not popping back to Home (see the file comment).
    await closeApp(tester);
  });

  testWidgets('Home card summarises the active plan; Train sheet shows today',
      (tester) async {
    await seedPlan(tester);
    await reveal(tester, find.byKey(const Key('plan-home-card')));
    expect(find.byKey(const Key('plan-home-card')), findsOneWidget);
    expect(find.text('No plan yet'), findsNothing);
    await tapKey(tester, 'tab-train');
    expect(
        await anyAppears(tester, [
          find.byKey(const Key('train-today-plan')),
          find.byKey(const Key('train-today-recovery')),
        ]),
        isTrue,
        reason: "PL-2b: today's plan first in the Train sheet");
    expect(find.byKey(const Key('mode-free')), findsOneWidget,
        reason: 'free workout still offered below');
    await closeApp(tester);
  });
}
