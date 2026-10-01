import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/features/routine/domain/routine_preset.dart';
import 'package:rep_counter_app/features/routine/presentation/rest_overlay.dart';
import 'package:rep_counter_app/features/routine/presentation/routine_editor_page.dart';
import 'package:rep_counter_app/features/workout/application/workout_ui_state.dart';
import 'package:rep_counter_app/features/workout/domain/workout_mode.dart';
import 'package:rep_counter_app/placement.dart';
import 'package:rep_counter_app/rep_counter.dart';
import 'package:rep_counter_app/theme/app_theme.dart';

const routine = RoutineSnapshot(
  id: 'morning',
  name: 'Hít đất buổi sáng',
  exerciseId: 'push_up',
  targetReps: 15,
  targetSets: 3,
  restSeconds: 60,
  voiceCoachEnabled: true,
);

WorkoutUiState restState() => const WorkoutUiState(
      phase: WorkoutUiPhase.resting,
      exerciseId: 'push_up',
      exerciseName: 'Hít đất',
      reps: 30,
      repsInCurrentSet: 0,
      completedSets: 2,
      sessionState: SessionState.resting,
      goal: null,
      elapsed: Duration(seconds: 120),
      placementReady: true,
      placementStatus: PlacementStatus.ready,
      placementMessage: '',
      calibrated: false,
      calibrationSamples: 0,
      goalReachedOnce: false,
      saveError: null,
      mode: WorkoutMode.free,
      routine: routine,
      routineRestRemaining: Duration(seconds: 43),
      routineCompletedSetReps: 15,
    );

Future<void> pumpPage(
  WidgetTester tester,
  Widget page, {
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
        home: page,
        builder: (_, child) => MediaQuery(
          data: MediaQueryData(
            size: const Size(393, 852),
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('routine editor exposes only v1 fields and supports 2x text',
      (tester) async {
    await pumpPage(tester, const RoutineEditorPage(), scale: 2);

    expect(find.byKey(const Key('routine-name')), findsOneWidget);
    expect(find.byKey(const Key('routine-exercise')), findsOneWidget);
    expect(find.byKey(const Key('routine-reps')), findsOneWidget);
    expect(find.byKey(const Key('routine-sets')), findsOneWidget);
    expect(find.byKey(const Key('routine-rest')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('routine-voice')),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('routine-voice')), findsOneWidget);
    expect(find.text('Voice Coach'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rest state matches routine contract and remains usable at 2x',
      (tester) async {
    var skipped = false;
    var ended = false;
    await pumpPage(
      tester,
      Scaffold(
        body: RoutineRestOverlay(
          state: restState(),
          onSkip: () => skipped = true,
          onEnd: () => ended = true,
        ),
      ),
      scale: 2,
    );

    expect(find.text('HOÀN THÀNH SET 2'), findsOneWidget);
    expect(find.text('15'), findsOneWidget);
    expect(find.text('00:43'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('routine-skip-rest')),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('routine-skip-rest')));
    expect(skipped, isTrue);

    await tester.scrollUntilVisible(
      find.byKey(const Key('routine-end-workout')),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('routine-end-workout')));
    expect(ended, isTrue);
    expect(tester.takeException(), isNull);
  });
}
