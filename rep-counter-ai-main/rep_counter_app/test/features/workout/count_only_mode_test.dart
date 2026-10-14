import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/features/workout/application/rep_feedback.dart';
import 'package:rep_counter_app/features/workout/application/workout_ui_state.dart';
import 'package:rep_counter_app/features/workout/domain/rep_metric.dart';
import 'package:rep_counter_app/features/workout/domain/workout_mode.dart';
import 'package:rep_counter_app/features/workout/presentation/widgets/workout_hud.dart';
import 'package:rep_counter_app/placement.dart';
import 'package:rep_counter_app/rep_counter.dart';
import 'package:rep_counter_app/theme/app_theme.dart';

const _state = WorkoutUiState(
  phase: WorkoutUiPhase.active,
  exerciseId: 'push_up',
  exerciseName: 'Push-up',
  reps: 4,
  repsInCurrentSet: 4,
  completedSets: 0,
  sessionState: SessionState.working,
  goal: 10,
  elapsed: Duration(seconds: 12),
  placementReady: true,
  placementStatus: PlacementStatus.ready,
  placementMessage: '',
  calibrated: false,
  calibrationSamples: 0,
  goalReachedOnce: false,
  saveError: null,
  repFeedback: RepFeedback.countedWarning(4, RepQualityFlag.tooFast),
  sessionStarted: true,
);

const _timedState = WorkoutUiState(
  phase: WorkoutUiPhase.active,
  exerciseId: 'push_up',
  exerciseName: 'Push-up',
  reps: 4,
  repsInCurrentSet: 4,
  completedSets: 0,
  sessionState: SessionState.working,
  goal: null,
  elapsed: Duration(seconds: 12),
  placementReady: true,
  placementStatus: PlacementStatus.ready,
  placementMessage: '',
  calibrated: false,
  calibrationSamples: 0,
  goalReachedOnce: false,
  saveError: null,
  repFeedback: RepFeedback.countedWarning(4, RepQualityFlag.tooFast),
  sessionStarted: true,
  mode: WorkoutMode.timed,
  challengeSeconds: 60,
  challengeRemaining: Duration(seconds: 48),
);

void main() {
  Future<void> pumpHud(
    WidgetTester tester, {
    required bool showFeedback,
    WorkoutUiState state = _state,
  }) async {
    final locale = LocaleController();
    addTearDown(locale.dispose);
    await tester.pumpWidget(
      LocaleScope(
        controller: locale,
        child: MaterialApp(
          theme: RepCoachTheme.dark(),
          home: Scaffold(
            body: SafeArea(
              child: WorkoutHud(
                state: state,
                exerciseName: 'Hít đất',
                hint: '',
                voiceEnabled: false,
                showRepFeedback: showFeedback,
                onExit: () {},
                onPause: () {},
                onResume: () {},
                onFinish: () {},
                onCalibrate: () {},
                onHelp: () {},
                goalBanner: false,
                onDismissGoal: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('count-only mode hides per-rep coaching but keeps the count',
      (tester) async {
    await pumpHud(tester, showFeedback: false);

    expect(find.text('4'), findsOneWidget);
    expect(find.text('Chậm lại một chút'), findsNothing);
  });

  testWidgets('opting into coaching shows per-rep feedback', (tester) async {
    await pumpHud(tester, showFeedback: true);

    expect(find.text('4'), findsOneWidget);
    expect(find.text('Chậm lại một chút'), findsOneWidget);
  });

  testWidgets('count-only also hides feedback in timed challenges',
      (tester) async {
    await pumpHud(tester, showFeedback: false, state: _timedState);

    expect(find.byKey(const Key('timed-reps')), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('Chậm lại một chút'), findsNothing);
  });
}
