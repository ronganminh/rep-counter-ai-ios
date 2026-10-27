import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/features/plan/application/plan_repository.dart';
import 'package:rep_counter_app/features/plan/domain/local_date.dart';
import 'package:rep_counter_app/features/plan/domain/overload_advisor.dart';
import 'package:rep_counter_app/features/plan/domain/plan_templates.dart';
import 'package:rep_counter_app/features/plan/domain/workout_plan.dart';
import 'package:rep_counter_app/features/plan/presentation/overload_page.dart';
import 'package:rep_counter_app/features/workout/data/workout_record.dart';
import 'package:rep_counter_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/l10n.dart';

/// PL-1 rule 5: progressive overload is optional, OFF by default, and only
/// ever proposed; the user accepts, edits or dismisses.

final monday = LocalDate(2026, 11, 2);

WorkoutRecord rec(String id, DateTime at, String ex, int reps,
        {int seconds = 60}) =>
    WorkoutRecord(
      id: id,
      exerciseId: ex,
      exerciseName: ex,
      startedAt: at,
      durationSeconds: seconds,
      reps: reps,
      sets: 1,
      targetReps: null,
      poseFrames: 0,
      readyFrames: 0,
      lostFrames: 0,
    );

void main() {
  late DateTime now;
  late List<WorkoutRecord> history;
  late PlanRepository repo;
  var n = 0;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    now = DateTime(2026, 11, 2, 9);
    history = [];
    repo = PlanRepository(
        loadWorkouts: () async => history,
        now: () => now,
        newId: () => 'id${++n}');
    await repo.activate(PlanTemplates.beginnerPlan(
        id: 'plan', startDate: monday, timezone: 'UTC', now: now));
  });

  /// Completes Full Body A on [day] (all targets met by recorded reps).
  void doneA(LocalDate day, String tag, {int push = 18}) {
    final at = DateTime(day.year, day.month, day.day, 9);
    history.addAll([
      rec('$tag-p', at, 'push_up', push),
      rec('$tag-c', at, 'curl', 30),
      rec('$tag-o', at, 'overhead_extension', 20),
    ]);
  }

  // Full Body A falls on Mon Nov 2 and Mon Nov 9 (A, B, C, A, …).
  Future<PlanView> twoCompleteA() async {
    doneA(monday, 'a1');
    now = DateTime(2026, 11, 9, 9);
    await repo.load();
    doneA(monday.addDays(7), 'a2');
    now = DateTime(2026, 11, 10, 9);
    return (await repo.load())!;
  }

  test('14 off by default: no suggestion even with strong history', () async {
    final view = await twoCompleteA();
    expect(view.plan.progressiveOverload, isFalse);
    expect(OverloadAdvisor.suggest(view.plan, view.sessions, view.workouts),
        isEmpty);
  });

  test('opted in: two complete sessions → a small explained step', () async {
    await twoCompleteA();
    final view = (await repo.setProgressiveOverload(true))!;
    final s = OverloadAdvisor.suggest(view.plan, view.sessions, view.workouts)
        .where((x) => x.kind == SuggestionKind.increase)
        .toList();
    final push = s.firstWhere((x) => x.current.exerciseId == 'push_up');
    expect(push.templateId, PlanTemplates.fullBodyA);
    expect(push.current.reps, 6);
    expect(push.proposed.reps, 7, reason: '6 + max(1, 10%) — not +2');
    expect(push.proposed.sets, push.current.sets);
    expect(push.evidence, 2);
    final curl = s.firstWhere((x) => x.current.exerciseId == 'curl');
    expect(curl.proposed.reps, 11);
    expect(view.sessions.first.exerciseTargets.first.reps, 6,
        reason: 'turning it on changes nothing by itself');
  });

  test('insufficient or incomplete history suggests keeping the target',
      () async {
    doneA(monday, 'a1');
    now = DateTime(2026, 11, 3, 9);
    await repo.load();
    final view = (await repo.setProgressiveOverload(true))!;
    final s = OverloadAdvisor.suggest(view.plan, view.sessions, view.workouts);
    final a = s.where((x) => x.templateId == PlanTemplates.fullBodyA);
    expect(a.every((x) => x.kind == SuggestionKind.maintain), isTrue);
    expect(a.every((x) => x.proposed == x.current), isTrue);
    expect(s.where((x) => x.templateId == PlanTemplates.fullBodyC), isEmpty,
        reason: 'no history for Full Body C yet');
  });

  test('a partial latest session resets the streak to maintain', () async {
    doneA(monday, 'a1');
    now = DateTime(2026, 11, 9, 9);
    await repo.load();
    doneA(monday.addDays(7), 'a2', push: 10); // push-up target not met
    now = DateTime(2026, 11, 10, 9);
    await repo.load();
    final view = (await repo.setProgressiveOverload(true))!;
    final push =
        OverloadAdvisor.suggest(view.plan, view.sessions, view.workouts)
            .firstWhere((x) => x.current.exerciseId == 'push_up');
    expect(push.kind, SuggestionKind.maintain);
  });

  test('duration targets step by time, separately from reps', () {
    const hold = ExerciseTarget(exerciseId: 'push_up', sets: 1, seconds: 45);
    expect(OverloadAdvisor.step(hold).seconds, 50);
    expect(OverloadAdvisor.step(hold).reps, isNull);
    const big = ExerciseTarget(exerciseId: 'push_up', sets: 1, seconds: 120);
    expect(OverloadAdvisor.step(big).seconds, 135);
    const reps = ExerciseTarget(exerciseId: 'curl', sets: 3, reps: 20);
    expect(OverloadAdvisor.step(reps).reps, 22);
    expect(OverloadAdvisor.step(reps).seconds, isNull);
  });

  group('15 accept / edit / dismiss', () {
    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(393, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final locale = LocaleController(AppLanguage.en);
      addTearDown(locale.dispose);
      await tester.pumpWidget(LocaleScope(
          controller: locale,
          child: MaterialApp(
              theme: RepCoachTheme.dark(),
              supportedLocales: testSupportedLocales,
              localizationsDelegates: testLocalizationsDelegates,
              home: OverloadPage(repository: repo))));
      await tester.pumpAndSettle();
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
    }

    const pushKey = '${PlanTemplates.fullBodyA}-0';

    testWidgets('off: toggle shown, no suggestions; on: suggestions appear',
        (tester) async {
      await tester.runAsync(twoCompleteA);
      await pump(tester);
      expect(
          tester
              .widget<SwitchListTile>(find.byKey(const Key('overload-toggle')))
              .value,
          isFalse);
      expect(find.byKey(const Key('suggestion-$pushKey')), findsNothing);
      await tester.tap(find.byKey(const Key('overload-toggle')));
      await settle(tester);
      expect(find.byKey(const Key('suggestion-$pushKey')), findsOneWidget);
      expect(find.text('3 × 6 reps → 3 × 7 reps'), findsOneWidget);
    });

    testWidgets('accept changes upcoming sessions only', (tester) async {
      await tester.runAsync(() async {
        await twoCompleteA();
        await repo.setProgressiveOverload(true);
      });
      await pump(tester);
      await tester.tap(find.byKey(const Key('accept-$pushKey')));
      await settle(tester);
      final view = (await tester.runAsync(repo.load))!;
      expect(view.plan.template(PlanTemplates.fullBodyA)!.targets[0].reps, 7);
      final done = view.sessions
          .where((s) => s.state == SessionState.completed)
          .toList();
      expect(done, hasLength(2));
      expect(done.every((s) => s.exerciseTargets[0].reps == 6), isTrue,
          reason: 'completed sessions keep their targets');
      final nextA = view.sessions.firstWhere((s) =>
          s.workoutTemplateId == PlanTemplates.fullBodyA &&
          s.scheduledLocalDate.isAfter(view.today));
      expect(nextA.exerciseTargets[0].reps, 7);
      expect(find.byKey(const Key('suggestion-$pushKey')), findsNothing,
          reason: 'evidence was for 6 reps; 7 needs new sessions');
    });

    testWidgets('edit applies the user\'s own value', (tester) async {
      await tester.runAsync(() async {
        await twoCompleteA();
        await repo.setProgressiveOverload(true);
      });
      await pump(tester);
      await tester.tap(find.byKey(const Key('edit-$pushKey')));
      await tester.pumpAndSettle();
      // Proposed 7; the user raises it to 8 before accepting.
      await tester.tap(find.descendant(
          of: find.byKey(const Key('target-0-reps')),
          matching: find.byKey(const Key('plus'))));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('targets-save')));
      await settle(tester);
      final view = (await tester.runAsync(repo.load))!;
      expect(view.plan.template(PlanTemplates.fullBodyA)!.targets[0].reps, 8);
    });

    testWidgets('dismiss hides it and changes nothing', (tester) async {
      await tester.runAsync(() async {
        await twoCompleteA();
        await repo.setProgressiveOverload(true);
      });
      await pump(tester);
      await tester.tap(find.byKey(const Key('dismiss-$pushKey')));
      await settle(tester);
      expect(find.byKey(const Key('suggestion-$pushKey')), findsNothing);
      final view = (await tester.runAsync(repo.load))!;
      expect(view.plan.template(PlanTemplates.fullBodyA)!.targets[0].reps, 6);
      expect(view.plan.version, 1, reason: 'no plan edit happened');
    });
  });
}
