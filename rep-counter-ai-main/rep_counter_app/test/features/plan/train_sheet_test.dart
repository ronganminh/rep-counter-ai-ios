import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/exercise.dart';
import 'package:rep_counter_app/features/plan/application/plan_repository.dart';
import 'package:rep_counter_app/features/plan/domain/local_date.dart';
import 'package:rep_counter_app/features/plan/domain/plan_templates.dart';
import 'package:rep_counter_app/features/plan/domain/workout_plan.dart';
import 'package:rep_counter_app/features/plan/presentation/plan_today_sheet.dart';
import 'package:rep_counter_app/features/plan/presentation/session_detail_page.dart';
import 'package:rep_counter_app/features/workout/data/workout_record.dart';
import 'package:rep_counter_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/l10n.dart';

/// PL-2b: the Train sheet starts with today's planned session.

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

  Future<void> activate(WidgetTester tester) =>
      tester.runAsync(() => repo.activate(PlanTemplates.beginnerPlan(
          id: 'plan', startDate: monday, timezone: 'UTC', now: now)));

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
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();
  }

  Widget section(List<String> opened) => Scaffold(
      body: TodayPlanSection(repository: repo, onOpenSession: opened.add));

  testWidgets('no plan: nothing above the free workout', (tester) async {
    await pump(tester, section([]));
    expect(find.byKey(const Key('train-today-plan')), findsNothing);
    expect(find.text('Free workout'), findsNothing);
  });

  testWidgets('training day: today\'s session first, opens its detail',
      (tester) async {
    await activate(tester);
    final opened = <String>[];
    await pump(tester, section(opened));
    expect(find.text('Today · Full Body A'), findsOneWidget);
    expect(find.text('Free workout'), findsOneWidget);
    await tester.tap(find.byKey(const Key('train-today-open')));
    final view = (await tester.runAsync(repo.load))!;
    expect(opened, [view.todaySession!.id]);
  });

  testWidgets('VI copy', (tester) async {
    await activate(tester);
    await pump(tester, section([]), language: AppLanguage.vi);
    expect(find.text('Hôm nay · Full Body A'), findsOneWidget);
    expect(find.text('Bắt đầu buổi hôm nay'), findsOneWidget);
    expect(find.text('Tập tự do'), findsOneWidget);
  });

  testWidgets('done today: no start button, free workout still offered',
      (tester) async {
    await activate(tester);
    history.addAll([
      _record('w1', now, 'push_up', 18),
      _record('w2', now, 'curl', 30),
      _record('w3', now, 'overhead_extension', 20),
    ]);
    await pump(tester, section([]));
    expect(find.byKey(const Key('train-today-done')), findsOneWidget);
    expect(find.byKey(const Key('train-today-open')), findsNothing);
  });

  testWidgets('recovery day says so', (tester) async {
    await activate(tester);
    now = DateTime(2026, 11, 3, 9);
    await pump(tester, section([]));
    expect(find.byKey(const Key('train-today-recovery')), findsOneWidget);
  });

  testWidgets('paused plan: nothing shown', (tester) async {
    await activate(tester);
    await tester.runAsync(() => repo.setStatus(PlanStatus.paused));
    await pump(tester, section([]));
    expect(find.byKey(const Key('train-today-plan')), findsNothing);
  });

  testWidgets('sheet: open goes to the session; exercise sheet has no plan',
      (tester) async {
    await activate(tester);
    await pump(
        tester,
        Scaffold(
            body: Builder(
                builder: (context) => Column(children: [
                      TextButton(
                          onPressed: () => showPlanTodaySheet(context, pushUp,
                              repository: repo),
                          child: const Text('train')),
                      TextButton(
                          onPressed: () => showPlanTodaySheet(context, pushUp,
                              showPlan: false, repository: repo),
                          child: const Text('exercise')),
                    ]))));
    await tester.tap(find.text('exercise'));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('train-today-plan')), findsNothing);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.tap(find.text('train'));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('train-today-open')));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();
    expect(find.byType(SessionDetailPage), findsOneWidget);
  });
}

WorkoutRecord _record(String id, DateTime at, String exercise, int reps) =>
    WorkoutRecord(
      id: id,
      exerciseId: exercise,
      exerciseName: exercise,
      startedAt: at,
      durationSeconds: 60,
      reps: reps,
      sets: 1,
      targetReps: null,
      poseFrames: 0,
      readyFrames: 0,
      lostFrames: 0,
    );
