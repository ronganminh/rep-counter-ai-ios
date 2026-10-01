import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/features/history/progress_statistics.dart';
import 'package:rep_counter_app/features/workout/data/workout_record.dart';
import 'package:rep_counter_app/features/workout/domain/workout_mode.dart';
import 'package:rep_counter_app/features/workout/presentation/history_page.dart';
import 'package:rep_counter_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

WorkoutQuality quality(int score, {bool enough = true}) => WorkoutQuality(
      flaggedReps: 0,
      avgRepSeconds: 1.5,
      avgAmplitude: 50,
      amplitudeDropPercent: 0,
      leftRightDiffPercent: 0,
      qualityScore: score,
      rangeOfMotion: score,
      cadenceConsistency: score,
      leftRightBalance: score,
      poseAlignment: score,
      hasEnoughData: enough,
    );

WorkoutRecord record({
  required String id,
  required DateTime at,
  String exerciseId = 'push_up',
  int reps = 10,
  int duration = 60,
  int? target,
  WorkoutMode mode = WorkoutMode.free,
  int? challenge,
  WorkoutQuality? workoutQuality,
}) =>
    WorkoutRecord(
      id: id,
      exerciseId: exerciseId,
      exerciseName: exerciseId,
      startedAt: at,
      durationSeconds: duration,
      reps: reps,
      sets: 1,
      targetReps: target,
      poseFrames: 100,
      readyFrames: 90,
      lostFrames: 10,
      mode: mode,
      challengeSeconds: challenge,
      quality: workoutQuality,
    );

void main() {
  group('ProgressStatistics', () {
    final now = DateTime(2026, 10, 1, 23, 30);

    test('7D includes the local-day boundary and excludes older/future data', () {
      final stats = ProgressStatistics(
        records: [
          record(id: 'inside', at: DateTime(2026, 9, 25, 0, 1), reps: 12),
          record(id: 'old', at: DateTime(2026, 9, 24, 23, 59), reps: 99),
          record(id: 'future', at: DateTime(2026, 10, 2), reps: 88),
        ],
        now: now,
        range: ProgressRange.days7,
        exerciseId: 'push_up',
      );
      expect(stats.records.map((r) => r.id), ['inside']);
      expect(stats.totalReps, 12);
    });

    test('exercise filter and range are applied together', () {
      final stats = ProgressStatistics(
        records: [
          record(id: 'push', at: DateTime(2026, 9, 30), reps: 20),
          record(
            id: 'pull',
            at: DateTime(2026, 9, 30),
            exerciseId: 'pull_up',
            reps: 30,
          ),
        ],
        now: now,
        range: ProgressRange.days30,
        exerciseId: 'push_up',
      );
      expect(stats.sessions, 1);
      expect(stats.totalReps, 20);
    });

    test('average form excludes unavailable or insufficient scores', () {
      final stats = ProgressStatistics(
        records: [
          record(
            id: 'a',
            at: DateTime(2026, 9, 30),
            workoutQuality: quality(80),
          ),
          record(
            id: 'b',
            at: DateTime(2026, 9, 29),
            workoutQuality: quality(100),
          ),
          record(
            id: 'insufficient',
            at: DateTime(2026, 9, 28),
            workoutQuality: quality(0, enough: false),
          ),
          record(id: 'legacy', at: DateTime(2026, 9, 27)),
        ],
        now: now,
        range: ProgressRange.days30,
        exerciseId: 'push_up',
      );
      expect(stats.averageForm, 90);
    });

    test('goals reached only counts truthful target-rep goals', () {
      final stats = ProgressStatistics(
        records: [
          record(
            id: 'goal',
            at: DateTime(2026, 9, 30),
            reps: 20,
            target: 20,
            mode: WorkoutMode.targetReps,
          ),
          record(
            id: 'miss',
            at: DateTime(2026, 9, 29),
            reps: 19,
            target: 20,
            mode: WorkoutMode.targetReps,
          ),
          record(
            id: 'timed',
            at: DateTime(2026, 9, 28),
            reps: 31,
            mode: WorkoutMode.timed,
            challenge: 60,
          ),
        ],
        now: now,
        range: ProgressRange.days30,
        exerciseId: 'push_up',
      );
      expect(stats.goalsReached, 1);
    });

    test('personal records stay all-time and timed durations stay separate', () {
      final stats = ProgressStatistics(
        records: [
          record(id: 'free-old', at: DateTime(2026, 7, 1), reps: 67),
          record(
            id: '60',
            at: DateTime(2026, 7, 2),
            reps: 31,
            duration: 60,
            mode: WorkoutMode.timed,
            challenge: 60,
          ),
          record(
            id: '60-incomplete',
            at: DateTime(2026, 7, 3),
            reps: 99,
            duration: 40,
            mode: WorkoutMode.timed,
            challenge: 60,
          ),
          record(
            id: '90',
            at: DateTime(2026, 7, 4),
            reps: 42,
            duration: 90,
            mode: WorkoutMode.timed,
            challenge: 90,
          ),
        ],
        now: now,
        range: ProgressRange.days7,
        exerciseId: 'push_up',
      );
      expect(stats.records, isEmpty);
      expect(stats.personalBestFree, 67);
      expect(stats.personalBestTimed(60), 31);
      expect(stats.personalBestTimed(90), 42);
    });
  });

  group('History Progress UI', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<void> pumpPage(
      WidgetTester tester, {
      double scale = 1,
      double width = 393,
    }) async {
      tester.view.physicalSize = Size(width, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final locale = LocaleController(AppLanguage.vi);
      addTearDown(locale.dispose);
      await tester.pumpWidget(
        LocaleScope(
          controller: locale,
          child: MaterialApp(
            theme: RepCoachTheme.dark(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
              ),
              child: child!,
            ),
            home: const HistoryPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('empty state matches progress contract at 2x text', (tester) async {
      await pumpPage(tester, scale: 2, width: 320);
      expect(tester.takeException(), isNull);
      expect(
        find.text('Tiến bộ của bạn bắt đầu từ buổi tập đầu tiên.'),
        findsOneWidget,
      );
      expect(find.text('Tập ngay'), findsOneWidget);
      expect(find.text('7D'), findsOneWidget);
      expect(find.text('30D'), findsOneWidget);
      expect(find.text('90D'), findsOneWidget);
      expect(find.text('ALL'), findsOneWidget);
    });

    testWidgets('saved records render truthful metrics and PR card', (tester) async {
      final now = DateTime.now();
      final saved = [
        record(
          id: 'recent-a',
          at: now.subtract(const Duration(days: 1)),
          reps: 20,
          target: 20,
          mode: WorkoutMode.targetReps,
          workoutQuality: quality(82),
        ),
        record(
          id: 'recent-b',
          at: now.subtract(const Duration(days: 2)),
          reps: 23,
          workoutQuality: quality(80),
        ),
        record(
          id: 'free-pr',
          at: now.subtract(const Duration(days: 40)),
          reps: 67,
        ),
        record(
          id: 'timed-pr',
          at: now.subtract(const Duration(days: 35)),
          reps: 31,
          duration: 60,
          mode: WorkoutMode.timed,
          challenge: 60,
        ),
      ];
      SharedPreferences.setMockInitialValues({
        'workout_history_v1': [
          for (final item in saved) jsonEncode(item.toJson()),
        ],
      });

      await pumpPage(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('TỔNG REP'), findsOneWidget);
      expect(find.text('KỶ LỤC CÁ NHÂN'), findsOneWidget);
      expect(find.text('67 rep'), findsOneWidget);
      expect(find.text('31 rep'), findsOneWidget);

      final node = tester.getSemantics(
        find.byKey(const Key('progress-range-7D')),
      );
      expect(node.hasFlag(SemanticsFlag.isSelected), isTrue);
    });
  });
}
