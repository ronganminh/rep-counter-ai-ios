import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/exercise.dart';
import 'package:rep_counter_app/features/plan/domain/local_date.dart';
import 'package:rep_counter_app/features/plan/domain/plan_templates.dart';
import 'package:rep_counter_app/features/plan/domain/workout_plan.dart';
import 'package:rep_counter_app/features/plan/presentation/session_detail_page.dart';
import 'package:rep_counter_app/features/workout/data/workout_history_store.dart';
import 'package:rep_counter_app/features/workout/domain/workout_mode.dart';
import 'package:rep_counter_app/features/workout/presentation/guided_timer_page.dart';
import 'package:rep_counter_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/l10n.dart';

/// W-4b guided timer: timed sets with rest, saved as a manual record with
/// the time actually held.

Future<void> _pump(WidgetTester tester, Widget home,
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
  await tester.pump();
}

Future<void> _seconds(WidgetTester tester, int n) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
}

/// Lets the history store finish writing outside the fake clock.
Future<void> _flush(WidgetTester tester) async {
  await tester
      .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pump();
}

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data!;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('sets, rest and a manual record of the time held',
      (tester) async {
    await _pump(
        tester,
        const GuidedTimerPage(
            profile: pushUp, sets: 2, seconds: 3, restSeconds: 2));
    expect(find.text('Guided timer · camera off'), findsOneWidget);
    expect(_text(tester, 'timer-title'), 'Set 1 of 2 · Push-up');
    expect(_text(tester, 'timer-clock'), '0:03');
    await _seconds(tester, 1);
    expect(_text(tester, 'timer-detail'), '0:01 of 0:03 · 2 s left');
    await _seconds(tester, 2);
    expect(_text(tester, 'timer-detail'), 'Rest before set 2');
    expect(find.byKey(const Key('timer-skip-rest')), findsOneWidget);
    await _seconds(tester, 2);
    expect(_text(tester, 'timer-title'), 'Set 2 of 2 · Push-up');
    await _seconds(tester, 3);
    await _flush(tester);
    expect(_text(tester, 'timer-detail'), 'Held 0:06 over 2 sets');
    final saved = (await tester.runAsync(WorkoutHistoryStore().load))!.single;
    expect(saved.manual, isTrue);
    expect(saved.reps, 0);
    expect(saved.sets, 2);
    expect(saved.durationSeconds, 6);
    expect(saved.mode, WorkoutMode.free);
    expect(saved.id, startsWith('timer-'));
  });

  testWidgets('+10 s, pause and done early save the actual time',
      (tester) async {
    await _pump(
        tester, const GuidedTimerPage(profile: pushUp, sets: 1, seconds: 5));
    await tester.tap(find.byKey(const Key('timer-add')));
    await tester.pump();
    expect(_text(tester, 'timer-clock'), '0:15');
    await _seconds(tester, 2);
    await tester.tap(find.byKey(const Key('timer-pause')));
    await tester.pump();
    await _seconds(tester, 5);
    expect(_text(tester, 'timer-detail'), '0:02 of 0:15 · 13 s left');
    await tester.tap(find.byKey(const Key('timer-done-early')));
    await tester.pump();
    await _flush(tester);
    final saved = (await tester.runAsync(WorkoutHistoryStore().load))!.single;
    expect(saved.durationSeconds, 2, reason: 'time held, not the target');
    expect(find.byKey(const Key('timer-close')), findsOneWidget);
  });

  testWidgets('leaving with time held asks first; discard saves nothing',
      (tester) async {
    await _pump(
        tester,
        Builder(
            builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) =>
                            const GuidedTimerPage(profile: pushUp))),
                child: const Text('open'))));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await _seconds(tester, 2);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Discard the time you held?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('timer-discard')));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byType(GuidedTimerPage), findsNothing);
    expect(await tester.runAsync(WorkoutHistoryStore().load), isEmpty);
  });

  testWidgets('VI copy', (tester) async {
    await _pump(tester, const GuidedTimerPage(profile: pushUp),
        language: AppLanguage.vi);
    expect(_text(tester, 'timer-title'), 'Set 1/2 · Hít đất');
    expect(find.text('Kết thúc sớm'), findsOneWidget);
  });

  testWidgets('a timed manual plan target opens the guided timer',
      (tester) async {
    final plan = PlanTemplates.beginnerPlan(
        id: 'p',
        startDate: LocalDate(2026, 11, 2),
        timezone: 'UTC',
        now: DateTime(2026, 11, 2));
    await _pump(
        tester,
        Builder(
            builder: (context) => TextButton(
                onPressed: () => startPlanTarget(
                    context,
                    plan,
                    const ExerciseTarget(
                        exerciseId: 'push_up',
                        sets: 2,
                        seconds: 30,
                        tracking: TrackingMode.manual)),
                child: const Text('go'))));
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(GuidedTimerPage), findsOneWidget);
    expect(_text(tester, 'timer-clock'), '0:30');
  });
}
