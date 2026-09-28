import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rep_counter_app/app/app_shell.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/features/history/history_statistics.dart';
import 'package:rep_counter_app/features/legal/settings_page.dart';
import 'package:rep_counter_app/features/workout/data/calibration_store.dart';
import 'package:rep_counter_app/features/workout/data/workout_history_store.dart';
import 'package:rep_counter_app/features/workout/data/workout_record.dart';
import 'package:rep_counter_app/features/workout/domain/quality_thresholds.dart';
import 'package:rep_counter_app/features/workout/presentation/history_page.dart';
import 'package:rep_counter_app/theme/app_theme.dart';

WorkoutRecord record(String id, DateTime date, {int reps = 12}) =>
    WorkoutRecord(
      id: id,
      exerciseId: 'push_up',
      exerciseName: 'Hít đất',
      startedAt: date,
      durationSeconds: 90,
      reps: reps,
      sets: 1,
      targetReps: 20,
      poseFrames: 0,
      readyFrames: 0,
      lostFrames: 0,
    );
Future<void> pump(WidgetTester tester, Widget page, {double scale = 1}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final locale = LocaleController();
  addTearDown(locale.dispose);
  await tester.pumpWidget(LocaleScope(
      controller: locale,
      child: MaterialApp(
        theme: RepCoachTheme.dark(),
        home: page,
        builder: (_, child) => MediaQuery(
            data: MediaQueryData(
                size: const Size(393, 852),
                textScaler: TextScaler.linear(scale)),
            child: child!),
      )));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('month totals, streak crossing month boundary and 30-day range', () {
    final stats = HistoryStatistics([
      record('a', DateTime(2026, 10, 1), reps: 20),
      record('b', DateTime(2026, 9, 30)),
      record('c', DateTime(2026, 9, 30)),
      record('d', DateTime(2026, 9, 29)),
      record('old', DateTime(2026, 8, 1)),
    ], DateTime(2026, 10, 2));
    expect(stats.streak, 3);
    expect(stats.monthReps, 20);
    expect(stats.month.length, 1);
    expect(stats.dailyReps[DateTime(2026, 9, 30)], 24);
    expect(stats.recent.length, 4);
  });
  test('reset calibration preserves other exercises and history', () async {
    const store = CalibrationStore();
    const sample =
        CalibrationSnapshot(repHi: 140, repLo: 100, minAmplitude: 40);
    await store.save('push_up', sample);
    await store.save('pull_up', sample);
    await WorkoutHistoryStore().save(record('keep', DateTime.now()));
    await store.reset('push_up');
    expect(await store.load('push_up'), isNull);
    expect(await store.load('pull_up'), isNotNull);
    expect((await WorkoutHistoryStore().load()).single.id, 'keep');
  });
  testWidgets('history empty keeps filters and offers training',
      (tester) async {
    var opened = false;
    await pump(tester, HistoryPage(onTrain: () => opened = true));
    expect(find.text('Tất cả'), findsOneWidget);
    expect(find.text('Chưa có buổi tập nào'), findsOneWidget);
    await tester.tap(find.text('Tập ngay'));
    expect(opened, isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets('legacy records render real totals without fabricated form',
      (tester) async {
    await WorkoutHistoryStore()
        .save(record('legacy', DateTime.now(), reps: 17));
    await pump(tester, const HistoryPage(), scale: 2);
    expect(find.text('17 rep'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.textContaining('Form '), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('history deletion can be undone in the persistent store',
      (tester) async {
    await WorkoutHistoryStore().save(record('undo', DateTime.now()));
    await pump(tester, const HistoryPage());
    await tester.scrollUntilVisible(find.byType(PopupMenuButton<String>), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.vi.historyDeleteAction));
    await tester.pumpAndSettle();
    expect(await WorkoutHistoryStore().load(), isEmpty);
    await tester.tap(find.text('Hoàn tác'));
    await tester.pumpAndSettle();
    expect((await WorkoutHistoryStore().load()).single.id, 'undo');
  });
  testWidgets('delete all requires matching confirmation then clears stores',
      (tester) async {
    await WorkoutHistoryStore().save(record('delete', DateTime.now()));
    await pump(tester, const SettingsPage());
    await tester.scrollUntilVisible(find.text(S.vi.clearHistory), 250);
    await tester.tap(find.text(S.vi.clearHistory));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('delete-data')))
            .onPressed,
        isNull);
    await tester.enterText(find.byKey(const Key('delete-confirmation')), 'xoa');
    await tester.pump();
    await tester.tap(find.byKey(const Key('delete-data')));
    await tester.pumpAndSettle();
    expect(await WorkoutHistoryStore().load(), isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets('language choice updates and persists settings labels',
      (tester) async {
    await pump(tester, const SettingsPage());
    await tester.tap(find.byType(DropdownButton<AppLanguage>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppLanguage.en.label).last);
    await tester.pumpAndSettle();
    expect(find.text('SETTINGS'), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getString('app_language'),
        'en');
  });
  testWidgets('settings supports large text and keeps legal routes',
      (tester) async {
    await pump(tester, const SettingsPage(), scale: 2);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text(S.vi.privacyPolicy), 250);
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.vi.privacyPolicy));
    await tester.pumpAndSettle();
    expect(find.byType(BackButton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('calibration reset dialog clears only selected exercise',
      (tester) async {
    const store = CalibrationStore();
    const sample =
        CalibrationSnapshot(repHi: 140, repLo: 100, minAmplitude: 40);
    await store.save('push_up', sample);
    await store.save('pull_up', sample);
    await pump(tester, const CalibrationSettingsPage());
    await tester.tap(find.text('Đặt lại').first);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.text('Đặt lại')));
    await tester.pumpAndSettle();
    expect(await store.load('push_up'), isNull);
    expect(await store.load('pull_up'), isNotNull);
    // All four existing exercise profiles are now visible in Settings.
    expect(find.text('Chưa hiệu chỉnh'), findsNWidgets(3));
  });
  testWidgets('tabs reload saved history and show actual home summary',
      (tester) async {
    await pump(tester, const AppShell());
    await tester.tap(find.text('Lịch sử').last);
    await tester.pumpAndSettle();
    expect(find.text('Chưa có buổi tập nào'), findsOneWidget);
    await WorkoutHistoryStore().save(record('new', DateTime.now(), reps: 27));
    await tester.tap(find.text('Tập').last);
    await tester.pumpAndSettle();
    expect(find.text('27 rep'), findsOneWidget);
    await tester.tap(find.text('Lịch sử').last);
    await tester.pumpAndSettle();
    expect(find.text('27 rep'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
