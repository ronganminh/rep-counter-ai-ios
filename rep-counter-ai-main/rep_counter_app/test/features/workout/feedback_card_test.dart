/// Thẻ nhận xét dựng được ở cả hai ngôn ngữ và không tràn bố cục.
///
/// Màn hình hẹp 320dp là ca đáng lo nhất: câu khuyên chỉnh camera khá dài.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/features/workout/data/workout_record.dart';
import 'package:rep_counter_app/features/workout/presentation/feedback_card.dart';

WorkoutRecord _record({
  int reps = 20,
  int? targetReps = 20,
  int lostFrames = 20,
  WorkoutQuality? quality,
}) =>
    WorkoutRecord(
      id: 'w1',
      exerciseId: 'push_up',
      exerciseName: 'Hít đất',
      startedAt: DateTime(2026, 9, 20),
      durationSeconds: 120,
      reps: reps,
      sets: 1,
      targetReps: targetReps,
      poseFrames: 1000,
      readyFrames: 950,
      lostFrames: lostFrames,
      quality: quality,
    );

const _goodQuality = WorkoutQuality(
  flaggedReps: 0,
  avgRepSeconds: 1.8,
  avgAmplitude: 55,
  amplitudeDropPercent: 25,
  leftRightDiffPercent: 22,
  qualityScore: 70,
  rangeOfMotion: 85,
  cadenceConsistency: 90,
  leftRightBalance: 50,
  poseAlignment: 70,
  hasEnoughData: true,
);

Future<void> _pump(WidgetTester tester, WorkoutRecord r, AppLanguage lang,
    {Size size = const Size(320, 900)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(LocaleScope(
    controller: LocaleController(lang),
    child: MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        body: SingleChildScrollView(child: FeedbackCard(record: r)),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  for (final lang in AppLanguage.values) {
    final s = S.of(lang);

    testWidgets('buổi tập đủ dữ liệu hiện điểm mạnh và điểm yếu (${lang.code})',
        (tester) async {
      await _pump(tester, _record(quality: _goodQuality), lang);

      expect(find.text(s.fbTitle), findsOneWidget);
      expect(find.text(s.fbGoalReached), findsOneWidget);
      expect(find.text(s.fbSteadyCadence), findsOneWidget);
      expect(find.text(s.fbGoodRange), findsOneWidget);
      // Hai bên lệch 22% -> phải nói, và KHÔNG được khen cân đối.
      expect(find.text(s.fbLeftRightUneven), findsOneWidget);
      expect(find.text(s.fbBalancedSides), findsNothing);
      expect(find.text(s.fbNotEnoughData), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('mất dấu nhiều: chỉ khuyên camera, không chấm kỹ thuật '
        '(${lang.code})', (tester) async {
      await _pump(
        tester,
        _record(lostFrames: 500, quality: _goodQuality),
        lang,
      );

      expect(find.text(s.fbPoseLostOften), findsOneWidget);
      expect(find.text(s.fbNotEnoughData), findsOneWidget);
      expect(find.text(s.fbAmplitudeDropped), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('bản ghi cũ không có số liệu chất lượng vẫn dựng được '
        '(${lang.code})', (tester) async {
      await _pump(tester, _record(quality: null), lang);

      expect(find.text(s.fbNotEnoughData), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
