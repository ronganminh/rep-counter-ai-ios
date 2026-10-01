import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/features/ai/ai_feedback_service.dart';
import 'package:rep_counter_app/features/workout/application/result_controller.dart';
import 'package:rep_counter_app/features/workout/data/workout_record.dart';
import 'package:rep_counter_app/features/workout/presentation/widgets/result_feedback_card.dart';

WorkoutRecord record() => WorkoutRecord(
      id: 'synthetic-workout',
      exerciseId: 'push_up',
      exerciseName: 'Push-up',
      startedAt: DateTime.utc(2026, 10, 1),
      durationSeconds: 120,
      reps: 20,
      sets: 2,
      targetReps: 20,
      poseFrames: 1000,
      readyFrames: 950,
      lostFrames: 20,
    );

Future<void> pumpCard(WidgetTester tester, ResultController controller) async {
  final locale = LocaleController(AppLanguage.en);
  addTearDown(locale.dispose);
  await tester.pumpWidget(
    LocaleScope(
      controller: locale,
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(body: ResultFeedbackCard(controller: controller)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('manual consent Cancel sends no request', (tester) async {
    var requests = 0;
    final controller = ResultController(
      record(),
      configured: true,
      analyze: (_, __) async {
        requests++;
        return 'should not happen';
      },
      saveFeedback: (_, __) async {},
    );
    addTearDown(controller.dispose);
    await pumpCard(tester, controller);

    await tester.tap(find.byKey(const Key('ask-result-ai')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cancel-manual-ai')), findsOneWidget);

    await tester.tap(find.byKey(const Key('cancel-manual-ai')));
    await tester.pumpAndSettle();

    expect(requests, 0);
    expect(controller.phase, ResultFeedbackPhase.idle);
    expect(controller.record.aiFeedback, isNull);
  });

  testWidgets('manual consent Agree sends one request and saves feedback',
      (tester) async {
    var requests = 0;
    final saves = <(String, String)>[];
    final controller = ResultController(
      record(),
      configured: true,
      analyze: (_, __) async {
        requests++;
        return 'Synthetic saved feedback';
      },
      saveFeedback: (id, feedback) async => saves.add((id, feedback)),
    );
    addTearDown(controller.dispose);
    await pumpCard(tester, controller);

    await tester.tap(find.byKey(const Key('ask-result-ai')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('accept-manual-ai')));
    await tester.pumpAndSettle();

    expect(requests, 1);
    expect(saves, [('synthetic-workout', 'Synthetic saved feedback')]);
    expect(controller.phase, ResultFeedbackPhase.ready);
    expect(controller.record.aiFeedback, 'Synthetic saved feedback');
    expect(find.text('Synthetic saved feedback'), findsOneWidget);
  });

  test('backend offline keeps the local workout intact', () async {
    var saves = 0;
    final original = record();
    final controller = ResultController(
      original,
      configured: true,
      analyze: (_, __) async =>
          throw const AiFeedbackException(AiFeedbackFailure.offline),
      saveFeedback: (_, __) async => saves++,
    );
    addTearDown(controller.dispose);

    await controller.request(AppLanguage.en);

    expect(controller.phase, ResultFeedbackPhase.offline);
    expect(controller.failure, AiFeedbackFailure.offline);
    expect(controller.record.id, original.id);
    expect(controller.record.reps, 20);
    expect(controller.record.sets, 2);
    expect(controller.record.aiFeedback, isNull);
    expect(saves, 0);
  });

  testWidgets('timeout leaves workout intact and exposes retry UI',
      (tester) async {
    final original = record();
    final controller = ResultController(
      original,
      configured: true,
      analyze: (_, __) async =>
          throw const AiFeedbackException(AiFeedbackFailure.timeout),
      saveFeedback: (_, __) async => fail('timeout must not save feedback'),
    );
    addTearDown(controller.dispose);
    await pumpCard(tester, controller);

    await controller.request(AppLanguage.en);
    await tester.pumpAndSettle();

    expect(controller.phase, ResultFeedbackPhase.error);
    expect(controller.failure, AiFeedbackFailure.timeout);
    expect(controller.record.id, original.id);
    expect(controller.record.aiFeedback, isNull);
    expect(find.byKey(const Key('ask-result-ai')), findsOneWidget);
    expect(find.text(S.of(AppLanguage.en).aiTimeout), findsOneWidget);
  });

  test('successful AI request saves feedback without changing workout data',
      () async {
    final original = record();
    final saves = <(String, String)>[];
    final controller = ResultController(
      original,
      configured: true,
      analyze: (_, __) async => 'Saved locally',
      saveFeedback: (id, feedback) async => saves.add((id, feedback)),
    );
    addTearDown(controller.dispose);

    await controller.request(AppLanguage.en);

    expect(controller.phase, ResultFeedbackPhase.ready);
    expect(controller.record.reps, original.reps);
    expect(controller.record.sets, original.sets);
    expect(controller.record.durationSeconds, original.durationSeconds);
    expect(controller.record.aiFeedback, 'Saved locally');
    expect(saves, [('synthetic-workout', 'Saved locally')]);
  });
}
