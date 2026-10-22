import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/features/workout/application/workout_ui_state.dart';
import 'package:rep_counter_app/features/workout/domain/workout_mode.dart';
import 'package:rep_counter_app/features/workout/presentation/widgets/workout_hud.dart';
import 'package:rep_counter_app/placement.dart';
import 'package:rep_counter_app/rep_counter.dart';
import 'package:rep_counter_app/theme/app_colors.dart';
import 'package:rep_counter_app/theme/app_theme.dart';

import '../../support/l10n.dart';

/// W-1: HUD skin from design-source/project/RepCoach-AI-HUD.dc.html (A0–E1).
/// The HUD only renders [WorkoutUiState]; these tests drive it with fixed
/// states, never with the engine.

WorkoutUiState _state({
  WorkoutUiPhase phase = WorkoutUiPhase.active,
  int reps = 14,
  int? goal = 20,
  bool ready = true,
  bool goalReachedOnce = false,
  WorkoutMode mode = WorkoutMode.targetReps,
}) =>
    WorkoutUiState(
      phase: phase,
      exerciseId: 'push_up',
      exerciseName: 'Hít đất',
      reps: reps,
      repsInCurrentSet: reps,
      completedSets: 1,
      sessionState: SessionState.working,
      goal: goal,
      elapsed: const Duration(seconds: 92),
      placementReady: ready,
      placementStatus:
          ready ? PlacementStatus.ready : PlacementStatus.partiallyOut,
      placementMessage: '',
      calibrated: true,
      calibrationSamples: 0,
      goalReachedOnce: goalReachedOnce,
      saveError: null,
      mode: mode,
    );

final _states = <String, (WorkoutUiState, bool)>{
  'active': (_state(), false),
  'tracking-lost': (_state(ready: false), false),
  'paused': (_state(phase: WorkoutUiPhase.paused), false),
  'goal-reached': (_state(reps: 20, goalReachedOnce: true), true),
  'over-goal': (_state(reps: 23, goalReachedOnce: true), false),
  'free': (_state(reps: 37, goal: null, mode: WorkoutMode.free), false),
};

Future<void> _loadFonts() async {
  for (final font in {
    'Inter': ['assets/fonts/Inter.ttf'],
    'Barlow Condensed': [
      'assets/fonts/BarlowCondensed-SemiBold.ttf',
      'assets/fonts/BarlowCondensed-Bold.ttf',
      'assets/fonts/BarlowCondensed-ExtraBold.ttf',
    ],
    'MaterialIcons': ['fonts/MaterialIcons-Regular.otf'],
    'packages/lucide_icons_flutter/Lucide': [
      'packages/lucide_icons_flutter/assets/lucide.ttf'
    ],
  }.entries) {
    final loader = FontLoader(font.key);
    for (final asset in font.value) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }
}

class _Callbacks {
  int finish = 0, keepGoing = 0, pause = 0;
}

Future<_Callbacks> _pump(WidgetTester tester, WorkoutUiState state,
    {AppLanguage language = AppLanguage.vi,
    Size size = const Size(393, 852),
    double scale = 1,
    bool goalBanner = false,
    bool reducedMotion = false}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final locale = LocaleController(language);
  addTearDown(locale.dispose);
  final calls = _Callbacks();
  await tester.pumpWidget(LocaleScope(
    controller: locale,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: RepCoachTheme.dark(),
      locale: language.locale,
      supportedLocales: testSupportedLocales,
      localizationsDelegates: testLocalizationsDelegates,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: reducedMotion),
          child: child!),
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(fit: StackFit.expand, children: [
          // Stand-in for the camera preview: the v1 HUD frames' room tones.
          const DecoratedBox(
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF3A342D), Color(0xFF1D1914)]))),
          if (state.phase == WorkoutUiPhase.paused)
            const ColoredBox(color: AppColors.dialogScrim),
          SafeArea(
            child: WorkoutHud(
              state: state,
              exerciseName: 'Hít đất',
              hint: '',
              onExit: () {},
              onPause: () => calls.pause++,
              onResume: () {},
              onFinish: () => calls.finish++,
              onCalibrate: () {},
              onHelp: () {},
              goalBanner: goalBanner,
              onDismissGoal: () => calls.keepGoing++,
            ),
          ),
        ]),
      ),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(seconds: 4));
  return calls;
}

Color? _colorOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style?.color;

void main() {
  setUpAll(_loadFonts);

  for (final language in AppLanguage.values) {
    for (final size in const [Size(393, 852), Size(375, 667)]) {
      for (final entry in _states.entries) {
        final (state, banner) = entry.value;
        final name = '${entry.key}_${language.code}_'
            '${size.width.toInt()}x${size.height.toInt()}';
        testWidgets('HUD golden · $name', (tester) async {
          await _pump(tester, state,
              language: language, size: size, goalBanner: banner);
          await expectLater(find.byType(Scaffold),
              matchesGoldenFile('goldens/hud_$name.png'));
        }, skip: !Platform.isLinux);
      }
    }
    for (final entry in _states.entries) {
      testWidgets(
          'HUD has no overflow at 2x text · ${entry.key} · '
          '${language.code}', (tester) async {
        final (state, banner) = entry.value;
        await _pump(tester, state,
            language: language,
            size: const Size(320, 640),
            scale: 2,
            goalBanner: banner);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
      'counter is accent while tracking and grey while counting is held',
      (tester) async {
    await _pump(tester, _state());
    expect(_colorOf(tester, '14'), AppColors.accent);
    expect(find.text('Còn 6'), findsOneWidget);
    expect(find.text(S.vi.placeReady), findsOneWidget);

    await _pump(tester, _state(ready: false));
    expect(_colorOf(tester, '14'), AppColors.text3);
    // The count never changes because tracking was lost (A2).
    expect(find.text('14'), findsOneWidget);
    expect(find.text(S.vi.placePartiallyOut), findsOneWidget);
  });

  testWidgets('goal reached turns the counter green, over goal shows a chip',
      (tester) async {
    await _pump(tester, _state(reps: 20, goalReachedOnce: true));
    expect(_colorOf(tester, '20'), AppColors.success);

    await _pump(tester, _state(reps: 23, goalReachedOnce: true),
        language: AppLanguage.en);
    expect(_colorOf(tester, '23'), AppColors.accent);
    expect(find.text('+3 over goal'), findsOneWidget);
    expect(find.textContaining('remaining'), findsNothing);
  });

  testWidgets('free mode shows no goal and marks the info line',
      (tester) async {
    await _pump(tester, _state(reps: 37, goal: null, mode: WorkoutMode.free));
    expect(find.text(' / 20'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('01:32 · Set 2 · Hít đất'), findsOneWidget);
    expect(find.text(' · Tự do'), findsOneWidget);
  });

  testWidgets('goal card: Keep going and See results reach their callbacks',
      (tester) async {
    final calls = await _pump(tester, _state(reps: 20, goalReachedOnce: true),
        goalBanner: true);
    expect(find.byKey(const Key('goal-reached-card')), findsOneWidget);
    await tester.tap(find.text(S.vi.goalKeepGoing));
    await tester.tap(find.text(S.vi.finishSeeResult));
    expect(calls.keepGoing, 1);
    expect(calls.finish, 1);
  });

  testWidgets('glass controls keep 48 dp targets and screen-reader labels',
      (tester) async {
    final handle = tester.ensureSemantics();
    final calls = await _pump(tester, _state());
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await tester.tap(find.byKey(const Key('pause-workout')));
    expect(calls.pause, 1);
    expect(find.bySemanticsLabel('14 ${S.vi.repsShort}'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a new rep pulses the counter, but not under reduced motion',
      (tester) async {
    double scale() => tester
        .widget<ScaleTransition>(find.ancestor(
            of: find.text('15'), matching: find.byType(ScaleTransition)))
        .scale
        .value;

    for (final reduced in [false, true]) {
      final locale = LocaleController(AppLanguage.vi);
      addTearDown(locale.dispose);
      Widget hud(int reps) => LocaleScope(
            controller: locale,
            child: MaterialApp(
              localizationsDelegates: testLocalizationsDelegates,
              supportedLocales: testSupportedLocales,
              locale: const Locale('vi'),
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(disableAnimations: reduced),
                  child: child!),
              home: Scaffold(
                body: WorkoutHud(
                  state: _state(reps: reps),
                  exerciseName: 'Hít đất',
                  hint: '',
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
          );
      await tester.pumpWidget(hud(14));
      await tester.pumpWidget(hud(15));
      await tester.pump(const Duration(milliseconds: 96));
      expect(scale(), reduced ? 1 : greaterThan(1), reason: 'reduced=$reduced');
      await tester.pumpAndSettle();
      expect(scale(), 1);
      await tester.pumpWidget(const SizedBox());
    }
  });
}
