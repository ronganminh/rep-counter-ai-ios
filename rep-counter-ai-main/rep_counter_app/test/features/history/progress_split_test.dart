import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/features/workout/data/workout_history_store.dart';
import 'package:rep_counter_app/features/workout/data/workout_record.dart';
import 'package:rep_counter_app/features/workout/presentation/history_page.dart';
import 'package:rep_counter_app/theme/app_theme.dart';
import 'package:rep_counter_app/widgets/product_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/l10n.dart';

WorkoutRecord _record(String id, int reps) => WorkoutRecord(
      id: id,
      exerciseId: 'push_up',
      exerciseName: 'Hít đất',
      startedAt: DateTime.now(),
      durationSeconds: 60,
      reps: reps,
      sets: 1,
      targetReps: 20,
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

String _metric(WidgetTester tester, String label) {
  final card = find.ancestor(
      of: find.text(label.toUpperCase()), matching: find.byType(MetricCard));
  return tester.widget<MetricCard>(card).value;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Progress shows analytics but no session rows', (tester) async {
    await WorkoutHistoryStore().save(_record('a', 20));
    await WorkoutHistoryStore().save(_record('b', 15));
    await _pump(tester, const ProgressPage());
    expect(find.text('TIẾN BỘ'), findsOneWidget);
    expect(_metric(tester, 'Tổng rep'), '35');
    expect(_metric(tester, 'Buổi tập'), '2');
    expect(find.byType(ListTile), findsNothing);
    expect(find.byKey(const Key('open-history-list')), findsOneWidget);
  });

  testWidgets('History list shows sessions without analytics', (tester) async {
    await WorkoutHistoryStore().save(_record('a', 20));
    await _pump(tester, const HistoryListPage());
    expect(find.byType(MetricCard), findsNothing);
    expect(find.text('20 rep'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing,
        reason: 'root here; Back appears only when pushed');
  });

  testWidgets(
      'deleting in History recalculates Progress totals and keeps achievements',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      // An already-earned badge must survive history deletion (D-05).
      'earned_achievements_v1': ['firstWorkout'],
    });
    await WorkoutHistoryStore().save(_record('a', 20));
    await WorkoutHistoryStore().save(_record('b', 15));
    await _pump(tester, const ProgressPage());
    expect(_metric(tester, 'Tổng rep'), '35');

    await tester.tap(find.byKey(const Key('open-history-list')));
    await tester.pumpAndSettle();
    expect(find.byType(BackButton), findsOneWidget);
    final row = find.ancestor(
        of: find.text('20 rep'), matching: find.byType(Dismissible));
    await tester.drag(row, const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('20 rep'), findsNothing);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(_metric(tester, 'Tổng rep'), '15');
    expect(_metric(tester, 'Buổi tập'), '1');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('earned_achievements_v1'), ['firstWorkout']);
  });

  testWidgets('empty Progress offers training', (tester) async {
    var opened = false;
    await _pump(tester, ProgressPage(onTrain: () => opened = true));
    await tester.ensureVisible(find.text('Tập ngay'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tập ngay'));
    expect(opened, isTrue);
  });

  for (final language in AppLanguage.values) {
    testWidgets('Progress and History fit 375x667 at 2.0x · ${language.code}',
        (tester) async {
      await WorkoutHistoryStore().save(_record('a', 20));
      for (final page in const [ProgressPage(), HistoryListPage()]) {
        await _pump(tester, page,
            language: language, size: const Size(375, 667), scale: 2);
        await tester.drag(find.byType(ListView).first, const Offset(0, -2000));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }
}
