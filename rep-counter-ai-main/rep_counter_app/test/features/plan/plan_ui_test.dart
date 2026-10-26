import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/features/plan/application/plan_repository.dart';
import 'package:rep_counter_app/features/plan/data/plan_store.dart';
import 'package:rep_counter_app/features/plan/domain/local_date.dart';
import 'package:rep_counter_app/features/plan/domain/plan_templates.dart';
import 'package:rep_counter_app/features/plan/domain/workout_plan.dart';
import 'package:rep_counter_app/features/plan/presentation/plan_home_card.dart';
import 'package:rep_counter_app/features/plan/presentation/plan_overview_page.dart';
import 'package:rep_counter_app/features/plan/presentation/plan_setup_page.dart';
import 'package:rep_counter_app/features/plan/presentation/session_detail_page.dart';
import 'package:rep_counter_app/features/workout/data/workout_record.dart';
import 'package:rep_counter_app/theme/app_theme.dart';
import 'package:rep_counter_app/widgets/app_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/l10n.dart';

/// PL-1b screens: setup with the default beginner plan, overview, session
/// detail, explicit rescheduling and recovery days, in EN and VI.

final monday = LocalDate(2026, 11, 2);

void main() {
  late DateTime now;
  late List<WorkoutRecord> history;
  late PlanRepository repo;
  var n = 0;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    now = DateTime(2026, 11, 2, 9);
    history = [];
    repo = PlanRepository(
        loadWorkouts: () async => history,
        now: () => now,
        newId: () => 'id${++n}');
  });

  Future<void> pump(WidgetTester tester, Widget home,
      {AppLanguage language = AppLanguage.en}) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final locale = LocaleController(language);
    addTearDown(locale.dispose);
    await tester.pumpWidget(LocaleScope(
      controller: locale,
      child: MaterialApp(
        theme: RepCoachTheme.dark(),
        locale: language.locale,
        supportedLocales: testSupportedLocales,
        localizationsDelegates: testLocalizationsDelegates,
        home: home,
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> activateDefault(WidgetTester tester) =>
      tester.runAsync(() => repo.activate(PlanTemplates.beginnerPlan(
          id: 'plan', startDate: monday, timezone: 'UTC', now: now)));

  testWidgets('1 setup creates the default Mon/Wed/Fri plan as a guest',
      (tester) async {
    await pump(tester, PlanSetupPage(repository: repo));
    expect(find.text("What's your main goal?"), findsOneWidget);
    await tester.tap(find.byKey(const Key('plan-setup-next')));
    await tester.pumpAndSettle();
    expect(find.text('How much do you train now?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('plan-setup-next')));
    await tester.pumpAndSettle();
    expect(find.text('When can you train?'), findsOneWidget);
    expect(find.text('3 sessions a week · Mon, Wed, Fri'), findsOneWidget);
    await tester.tap(find.byKey(const Key('plan-setup-next')));
    await tester.pumpAndSettle();
    // Four-week preview before anything is saved.
    expect(find.byKey(Key('plan-day-${monday.toIso()}')), findsOneWidget);
    expect(find.byKey(Key('plan-day-${monday.addDays(27).toIso()}')),
        findsOneWidget);
    expect(find.text('Full Body A'), findsOneWidget);
    expect((await tester.runAsync(() => PlanStore().load()))!.plans, isEmpty);

    await tester.scrollUntilVisible(
        find.byKey(const Key('plan-setup-next')), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plan-setup-next')));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    final snap = (await tester.runAsync(() => PlanStore().load()))!;
    final plan = snap.current!;
    expect(plan.selectedWeekdays, [1, 3, 5]);
    expect(plan.ownerId, isNull);
    expect(plan.progressiveOverload, isFalse);
  });

  testWidgets('2 days step: 2–6 days; 1 or 7 days cannot continue',
      (tester) async {
    await pump(tester, PlanSetupPage(repository: repo));
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byKey(const Key('plan-setup-next')));
      await tester.pumpAndSettle();
    }
    Future<void> toggle(int d) async {
      await tester.tap(find.byKey(Key('plan-day-chip-$d')));
      await tester.pumpAndSettle();
    }

    await toggle(3);
    await toggle(5);
    expect(find.byKey(const Key('plan-days-too-few')), findsOneWidget);
    AppButton nextButton() =>
        tester.widget<AppButton>(find.byKey(const Key('plan-setup-next')));
    expect(nextButton().onPressed, isNull, reason: '1 day cannot continue');
    await toggle(4);
    expect(find.text('2 sessions a week · Mon, Thu'), findsOneWidget);
    for (final d in [2, 3, 5, 6, 7]) {
      await toggle(d);
    }
    expect(find.byKey(const Key('plan-days-too-many')), findsOneWidget);
    expect(nextButton().onPressed, isNull, reason: '7 days cannot continue');
    await toggle(7);
    expect(find.text('6 sessions a week · Mon, Tue, Wed, Thu, Fri, Sat'),
        findsOneWidget);
    expect(nextButton().onPressed, isNotNull);
  });

  testWidgets('overview: calendar states, recovery days, missed offered a move',
      (tester) async {
    await activateDefault(tester);
    now = DateTime(2026, 11, 3, 9); // Tuesday: Monday's session is missed.
    await pump(tester, PlanOverviewPage(repository: repo));
    expect(find.text('Full Body · 3 days'), findsOneWidget);
    expect(find.text('Recovery day'), findsOneWidget,
        reason: 'today (Tuesday) is a recovery day');
    final missedBanner = find.textContaining("didn't happen");
    expect(missedBanner, findsOneWidget);
    expect(
        find.bySemanticsLabel(RegExp(r'^Mon, Nov 2, Missed')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Tue, Nov 3, Recovery, today')),
        findsOneWidget);
    expect(
        find.bySemanticsLabel(RegExp(r'^Wed, Nov 4, Planned')), findsOneWidget);

    // 8 explicit reschedule to Thursday (a recovery day → confirm).
    await tester.tap(find.text('Move'));
    await tester.pumpAndSettle();
    final thursday = monday.addDays(3);
    expect(find.text('Full Body B already planned'), findsOneWidget);
    await tester.tap(find.byKey(Key('reschedule-${thursday.toIso()}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reschedule-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('Thu, Nov 5 is a recovery day'), findsOneWidget);
    await tester.tap(find.byKey(const Key('recovery-warning-confirm')));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.text('Moved to Thu, Nov 5'), findsOneWidget);
    final snap = (await tester.runAsync(() => PlanStore().load()))!;
    final moved =
        snap.sessions.firstWhere((s) => s.scheduledLocalDate == thursday);
    expect(moved.originalScheduledDate, monday);
    expect(moved.state, SessionState.scheduled);
  });

  testWidgets('taken days cannot be picked; Keep as is changes nothing',
      (tester) async {
    await activateDefault(tester);
    now = DateTime(2026, 11, 3, 9);
    await pump(tester, PlanOverviewPage(repository: repo));
    await tester.tap(find.text('Move'));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(Key('reschedule-${monday.addDays(2).toIso()}')));
    await tester.pumpAndSettle();
    expect(find.text('Pick a day'), findsOneWidget,
        reason: 'Wednesday has Full Body B, so it cannot be selected');
    await tester.tap(find.byKey(const Key('reschedule-cancel')));
    await tester.pumpAndSettle();
    final snap = (await tester.runAsync(() => PlanStore().load()))!;
    expect(
        snap.sessions
            .firstWhere((s) => s.originalScheduledDate == monday)
            .state,
        SessionState.missed);
  });

  testWidgets('session detail: start uses the real flow; saved record links',
      (tester) async {
    await activateDefault(tester);
    final sessionId = (await tester.runAsync(repo.load))!.todaySession!.id;
    final started = <String>[];
    await pump(
        tester,
        SessionDetailPage(
            sessionId: sessionId,
            repository: repo,
            start: (context, plan, target) async {
              started.add(target.exerciseId);
              // The camera flow saves a WorkoutRecord on this day.
              history.add(WorkoutRecord(
                  id: 'w-${target.exerciseId}',
                  exerciseId: target.exerciseId,
                  exerciseName: target.exerciseId,
                  startedAt: now,
                  durationSeconds: 90,
                  reps: target.totalReps,
                  sets: target.sets,
                  targetReps: null,
                  poseFrames: 0,
                  readyFrames: 0,
                  lostFrames: 0));
            }));
    expect(find.byKey(const Key('session-state-scheduled')), findsOneWidget);
    await tester.tap(find.byKey(const Key('start-push_up')));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(started, ['push_up']);
    expect(find.byKey(const Key('session-state-partial')), findsOneWidget);
    expect(find.text('18/18 reps'), findsOneWidget,
        reason: 'progress comes from the saved record');
    for (final id in ['curl', 'overhead_extension']) {
      await tester.tap(find.byKey(Key('start-$id')));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
    }
    expect(find.byKey(const Key('session-state-completed')), findsOneWidget);
    expect(find.byKey(const Key('session-reschedule')), findsNothing,
        reason: 'a completed session cannot be moved');
  });

  testWidgets('skip asks first and marks skipped (not done)', (tester) async {
    await activateDefault(tester);
    final id = (await tester.runAsync(repo.load))!.sessions[1].id;
    await pump(tester, SessionDetailPage(sessionId: id, repository: repo));
    await tester.tap(find.byKey(const Key('session-skip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('skip-confirm')));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('session-state-skipped')), findsOneWidget);
    expect(find.byKey(const Key('start-push_up')), findsNothing);
  });

  testWidgets('recovery day: adding a workout warns and needs confirmation',
      (tester) async {
    await activateDefault(tester);
    now = DateTime(2026, 11, 3, 9);
    await pump(tester, PlanOverviewPage(repository: repo));
    await tester.tap(find.byKey(const Key('plan-open-recovery')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('recovery-title')), findsOneWidget);
    expect(find.textContaining('Next session · Wed, Nov 4'), findsOneWidget);
    await tester.tap(find.byKey(const Key('recovery-add-workout')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('recovery-warning-cancel')));
    await tester.pumpAndSettle();
    var snap = (await tester.runAsync(() => PlanStore().load()))!;
    expect(
        snap.sessions.where((s) => s.scheduledLocalDate == monday.addDays(1)),
        isEmpty);
    await tester.tap(find.byKey(const Key('recovery-add-workout')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('recovery-warning-confirm')));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    snap = (await tester.runAsync(() => PlanStore().load()))!;
    expect(
        snap.sessions.where((s) => s.scheduledLocalDate == monday.addDays(1)),
        hasLength(1));
  });

  testWidgets('17 Vietnamese: home card, overview and setup', (tester) async {
    await pump(tester, Scaffold(body: PlanHomeCard(repository: repo)),
        language: AppLanguage.vi);
    expect(find.text('Chưa có kế hoạch'), findsOneWidget);

    await activateDefault(tester);
    await pump(tester, PlanOverviewPage(repository: repo),
        language: AppLanguage.vi);
    expect(find.text('Kế hoạch'), findsOneWidget);
    expect(find.text('Hôm nay · T2, 2/11'), findsOneWidget);
    expect(find.text('Tăng cường đều đặn'), findsNothing);
    expect(find.text('Tập đều đặn · Người mới · 3 buổi/tuần'), findsOneWidget);
    expect(find.text('4 TUẦN TỚI'), findsOneWidget);

    await pump(tester, PlanSetupPage(repository: repo),
        language: AppLanguage.vi);
    expect(find.text('Mục tiêu chính của bạn là gì?'), findsOneWidget);
  });

  testWidgets('home card shows today\'s session', (tester) async {
    await activateDefault(tester);
    await pump(tester, Scaffold(body: PlanHomeCard(repository: repo)));
    expect(find.text('Today · Full Body A'), findsOneWidget);
  });
}
