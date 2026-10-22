import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/exercise.dart';
import 'package:rep_counter_app/features/exercises/presentation/exercise_detail_page.dart';
import 'package:rep_counter_app/features/exercises/presentation/exercise_picker_screen.dart';
import 'package:rep_counter_app/features/workout/data/workout_history_store.dart';
import 'package:rep_counter_app/features/workout/data/workout_record.dart';
import 'package:rep_counter_app/features/workout/presentation/goal_setup_page.dart';
import 'package:rep_counter_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/l10n.dart';

WorkoutRecord _record(String id, String exerciseId, int reps) => WorkoutRecord(
      id: id,
      exerciseId: exerciseId,
      exerciseName: exerciseId,
      startedAt: DateTime(2026, 10, 1),
      durationSeconds: 60,
      reps: reps,
      sets: 1,
      targetReps: null,
      poseFrames: 0,
      readyFrames: 0,
      lostFrames: 0,
    );

Future<void> _pump(WidgetTester tester, Widget page,
    {AppLanguage language = AppLanguage.vi,
    Size size = const Size(393, 852),
    double scale = 1}) async {
  tester.view.physicalSize = size;
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
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!),
      home: page,
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('search folds Vietnamese diacritics and case', () {
    expect(foldVietnamese('Hít đất'), 'hit dat');
    expect(matchesExerciseQuery('Hít đất', 'HIT DAT'), isTrue);
    expect(matchesExerciseQuery('Hít đất', 'đất'), isTrue);
    expect(matchesExerciseQuery('Squat', '  '), isTrue);
    expect(matchesExerciseQuery('Squat', 'lunge'), isFalse);
  });

  test('ExerciseStats counts only the given exercise', () {
    final stats = ExerciseStats.from([
      _record('a', 'push_up', 12),
      _record('b', 'push_up', 31),
      _record('c', 'pull_up', 99),
    ], 'push_up');
    expect(stats.workouts, 2);
    expect(stats.bestReps, 31);
    final none = ExerciseStats.from(const [], 'push_up');
    expect(none.workouts, 0);
    expect(none.bestReps, isNull);
  });

  testWidgets('search narrows the library and shows an empty state',
      (tester) async {
    await _pump(tester, const ExercisePickerScreen());
    await tester.enterText(find.byKey(const Key('exercise-search')), 'hit dat');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('exercise-push_up')), findsOneWidget);
    expect(find.byKey(const Key('exercise-squat')), findsNothing);

    await tester.enterText(find.byKey(const Key('exercise-search')), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('Không có kết quả cho “zzz”'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('detail shows real records and starts the existing setup',
      (tester) async {
    final store = WorkoutHistoryStore();
    await store.save(_record('a', 'push_up', 18));
    await store.save(_record('b', 'push_up', 27));
    await store.save(_record('c', 'pull_up', 40));
    await _pump(tester, const ExerciseDetailPage(profile: pushUp));
    expect(
        find.descendant(
            of: find.byKey(const Key('exercise-best')),
            matching: find.text('27')),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const Key('exercise-workouts')),
            matching: find.text('2')),
        findsOneWidget);
    await tester.tap(find.byKey(const Key('exercise-start')));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<GoalSetupContent>(find.byType(GoalSetupContent))
            .profile
            .id,
        'push_up');
  });

  testWidgets('detail without history shows a dash, not a fake record',
      (tester) async {
    await _pump(tester, const ExerciseDetailPage(profile: pushUp));
    expect(
        find.descendant(
            of: find.byKey(const Key('exercise-best')),
            matching: find.text('—')),
        findsOneWidget);
  });

  for (final language in AppLanguage.values) {
    testWidgets('library and detail fit 375x667 at 2.0x · ${language.code}',
        (tester) async {
      await _pump(tester, const ExercisePickerScreen(),
          language: language, size: const Size(375, 667), scale: 2);
      expect(tester.takeException(), isNull);
      await _pump(tester, const ExerciseDetailPage(profile: pushUp),
          language: language, size: const Size(375, 667), scale: 2);
      expect(tester.takeException(), isNull);
    });
  }
}
