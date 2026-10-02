import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/core/services/training_preferences.dart';
import 'package:rep_counter_app/features/achievements/achievement.dart';
import 'package:rep_counter_app/features/achievements/presentation/achievement_earned_card.dart';
import 'package:rep_counter_app/features/legal/voice_cadence_page.dart';
import 'package:rep_counter_app/features/workout/data/workout_history_store.dart';
import 'package:rep_counter_app/features/workout/data/workout_record.dart';
import 'package:rep_counter_app/features/workout/presentation/result_page.dart';
import 'package:rep_counter_app/theme/app_theme.dart';

WorkoutRecord resultRecord() => WorkoutRecord(
      id: 'a7-result',
      exerciseId: 'push_up',
      exerciseName: 'Hít đất',
      startedAt: DateTime(2026, 10, 2, 9),
      durationSeconds: 60,
      reps: 23,
      sets: 1,
      targetReps: null,
      poseFrames: 100,
      readyFrames: 90,
      lostFrames: 10,
    );

Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  double scale = 1,
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final locale = LocaleController();
  addTearDown(locale.dispose);
  await tester.pumpWidget(
    LocaleScope(
      controller: locale,
      child: MaterialApp(
        theme: RepCoachTheme.dark(),
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(393, 852),
            textScaler: TextScaler.linear(scale),
          ),
          child: child,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('achievement card matches post-result hierarchy at 2x text',
      (tester) async {
    await pumpApp(
      tester,
      const Scaffold(
        body: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: AchievementEarnedCard(
            achievement: AchievementId.streak7,
          ),
        ),
      ),
      scale: 2,
    );

    expect(find.byKey(const Key('achievement-streak7')), findsOneWidget);
    expect(find.text('HUY HIỆU MỚI'), findsOneWidget);
    expect(find.text('Streak 7 ngày'), findsOneWidget);
    expect(find.text('Bạn đã tập 7 ngày liên tiếp.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saved workout result claims and displays local badges',
      (tester) async {
    final history = WorkoutHistoryStore();
    final record = resultRecord();
    await history.save(record);

    await pumpApp(
      tester,
      ResultPage(
        record: record,
        historyStore: history,
        aiConfigured: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('achievement-firstWorkout')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('achievement-newPersonalRecord')),
      findsOneWidget,
    );
  });

  testWidgets('voice cadence page persists selection and survives 2x text',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      TrainingPreferences.voiceKey: true,
      TrainingPreferences.hapticsKey: true,
      TrainingPreferences.soundKey: false,
      TrainingPreferences.cuesKey: true,
      TrainingPreferences.repSpeechCadenceKey:
          RepSpeechCadence.everyRep.name,
    });

    await pumpApp(tester, const VoiceCadencePage(), scale: 2);

    expect(find.byKey(const Key('cadence-every-rep')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('cadence-every-5')),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('cadence-every-5')));
    await tester.pumpAndSettle();

    final loaded = await TrainingPreferences.load();
    expect(loaded.repSpeechCadence, RepSpeechCadence.every5Reps);

    await tester.scrollUntilVisible(
      find.text('CÀI ĐẶT LIÊN QUAN'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Voice Coach'), findsOneWidget);
    expect(find.text('Nhắc tư thế'), findsOneWidget);
    expect(find.text('Âm thanh set'), findsOneWidget);
    expect(find.text('Rung'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
