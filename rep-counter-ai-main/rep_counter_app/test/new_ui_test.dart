import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/features/legal/onboarding_page.dart';
import 'package:rep_counter_app/features/legal/legal_page.dart';
import 'package:rep_counter_app/features/exercises/presentation/exercise_picker_screen.dart';
import 'package:rep_counter_app/features/workout/presentation/goal_setup_page.dart';
import 'package:rep_counter_app/features/workout/presentation/result_page.dart';
import 'package:rep_counter_app/features/workout/presentation/widgets/workout_hud.dart';
import 'package:rep_counter_app/features/workout/presentation/widgets/camera_permission_view.dart';
import 'package:rep_counter_app/features/workout/data/workout_record.dart';
import 'package:rep_counter_app/features/workout/application/workout_ui_state.dart';
import 'package:rep_counter_app/placement.dart';
import 'package:rep_counter_app/rep_counter.dart';
import 'package:rep_counter_app/exercise.dart';
import 'package:rep_counter_app/theme/app_theme.dart';

// All sample records below exist only in tests and rendered widget previews.
WorkoutRecord fixture({bool legacy = false}) => WorkoutRecord(
    id: 'ui-fixture',
    exerciseId: 'push_up',
    exerciseName: 'Hít đất',
    startedAt: DateTime(2026, 9, 27, 18, 40),
    durationSeconds: 252,
    reps: 23,
    sets: 3,
    targetReps: 20,
    poseFrames: 100,
    readyFrames: 90,
    lostFrames: 10,
    quality: legacy
        ? null
        : const WorkoutQuality(
            flaggedReps: 2,
            avgRepSeconds: 1.8,
            avgAmplitude: 55,
            amplitudeDropPercent: 10,
            leftRightDiffPercent: 5,
            qualityScore: 82,
            rangeOfMotion: 88,
            cadenceConsistency: 74,
            leftRightBalance: 90,
            poseAlignment: 76,
            hasEnoughData: true),
    repDetails: legacy
        ? null
        : List.generate(
            23,
            (i) => StoredRep(
                seconds: 1.2 + (i % 5) * .25,
                setIndex: i ~/ 8 + 1,
                flagged: i == 19 || i == 20)));
WorkoutUiState hudState(WorkoutUiPhase phase) => WorkoutUiState(
    phase: phase,
    exerciseId: 'push_up',
    exerciseName: 'Hít đất',
    reps: phase == WorkoutUiPhase.positioning ||
            phase == WorkoutUiPhase.calibrating ||
            phase == WorkoutUiPhase.countdown
        ? 0
        : 14,
    repsInCurrentSet: phase == WorkoutUiPhase.positioning ||
            phase == WorkoutUiPhase.countdown ||
            phase == WorkoutUiPhase.calibrating
        ? 0
        : 6,
    completedSets: phase == WorkoutUiPhase.positioning ||
            phase == WorkoutUiPhase.countdown ||
            phase == WorkoutUiPhase.calibrating
        ? 0
        : 1,
    sessionState: SessionState.working,
    goal: 20,
    elapsed:
        phase == WorkoutUiPhase.countdown || phase == WorkoutUiPhase.positioning
            ? Duration.zero
            : const Duration(seconds: 92),
    placementReady: phase != WorkoutUiPhase.positioning,
    placementStatus: PlacementStatus.values.firstWhere((s) => s.canCount),
    placementMessage: '',
    calibrated: false,
    calibrationSamples: 67,
    goalReachedOnce: false,
    saveError: null,
    countdown: phase == WorkoutUiPhase.countdown ? 3 : null,
    sessionStarted: phase != WorkoutUiPhase.positioning &&
        phase != WorkoutUiPhase.countdown,
    startRequested: phase == WorkoutUiPhase.countdown);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    for (final font in {
      'Inter': 'assets/fonts/Inter.ttf',
      'Barlow Condensed': 'assets/fonts/BarlowCondensed-ExtraBold.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
      'packages/lucide_icons_flutter/Lucide':
          'packages/lucide_icons_flutter/assets/lucide.ttf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });
  final capture = GlobalKey();
  Future<void> pump(WidgetTester tester, Widget page,
      {double width = 393,
      double scale = 1,
      AppLanguage language = AppLanguage.vi}) async {
    tester.view.physicalSize = Size(width, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final locale = LocaleController(language);
    addTearDown(locale.dispose);
    await tester.pumpWidget(LocaleScope(
        controller: locale,
        child: MaterialApp(
            theme: RepCoachTheme.dark(),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: RepaintBoundary(key: capture, child: child!)),
            home: page)));
    await tester.pumpAndSettle();
  }

  Future<void> screenshot(WidgetTester tester, String name) async {
    const dir = String.fromEnvironment('NEW_UI_SCREENSHOTS');
    if (dir.isEmpty) return;
    final boundary =
        capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final im = await boundary.toImage(pixelRatio: 2);
      final bytes = await im.toByteData(format: ui.ImageByteFormat.png);
      await Directory(dir).create(recursive: true);
      await File('$dir/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      im.dispose();
    });
  }

  for (final lang in AppLanguage.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('onboarding all pages ${lang.code} ${scale}x',
          (tester) async {
        var done = 0;
        await pump(tester, OnboardingPage(onDone: () => done++),
            width: scale == 2 ? 320 : 393, scale: scale, language: lang);
        for (var i = 0; i < 3; i++) {
          expect(tester.takeException(), isNull);
          if (scale == 1 && lang == AppLanguage.vi) {
            await screenshot(tester, 'onboarding-${i + 1}');
          }
          await tester.tap(find.byType(FilledButton));
          await tester.pumpAndSettle();
        }
        expect(done, 1);
        expect((await SharedPreferences.getInstance()).getBool('onboarding_v1'),
            isTrue);
      });
    }
  }
  testWidgets('skip persists onboarding without requesting camera',
      (tester) async {
    var done = 0;
    await pump(tester, OnboardingPage(onDone: () => done++));
    await tester.tap(find.text('Bỏ qua'));
    await tester.pumpAndSettle();
    expect(done, 1);
    expect((await SharedPreferences.getInstance()).getBool('onboarding_v1'),
        isTrue);
  });
  testWidgets('onboarding swipe and local privacy route', (tester) async {
    await pump(tester, OnboardingPage(onDone: () {}));
    await tester.drag(find.byType(PageView), const Offset(-380, 0));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(-380, 0));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Quyền riêng tư'));
    await tester.tap(find.text('Quyền riêng tư'));
    await tester.pumpAndSettle();
    expect(find.byType(LegalPage), findsOneWidget);
  });
  testWidgets('plan maps preset custom and free goals', (tester) async {
    final goals = <int?>[];
    await pump(
        tester,
        Scaffold(
            body: SingleChildScrollView(
                child: GoalSetupContent(profile: pushUp, onStart: goals.add))));
    await tester.tap(find.text('BẮT ĐẦU'));
    expect(goals.last, 20);
    await tester.enterText(find.byType(TextField), '37');
    await tester.pumpAndSettle();
    await tester.tap(find.text('BẮT ĐẦU'));
    expect(goals.last, 37);
    await tester.tap(find.byType(FilterChip));
    await tester.pumpAndSettle();
    await tester.tap(find.text('BẮT ĐẦU'));
    expect(goals.last, isNull);
    await tester.tap(find.byType(FilterChip));
    await tester.enterText(find.byType(TextField), '0');
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets('plan and picker support ${scale}x text', (tester) async {
      await pump(tester, const GoalSetupPage(profile: pushUp),
          width: 320, scale: scale);
      expect(tester.takeException(), isNull);
      if (scale == 1) await screenshot(tester, 'goal-setup');
      await pump(tester, const ExercisePickerScreen(),
          width: 320, scale: scale);
      expect(tester.takeException(), isNull);
    });
    testWidgets('result uses actual scores and legacy is readable ${scale}x',
        (tester) async {
      await pump(tester, ResultPage(record: fixture()),
          width: scale == 2 ? 320 : 393, scale: scale);
      expect(find.text('23'), findsOneWidget);
      if (scale == 1) await screenshot(tester, 'result');
      await tester.drag(find.byType(ListView), const Offset(0, -650));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView), const Offset(0, -650));
      await tester.pumpAndSettle();
      expect(find.text('88'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (scale == 1) await screenshot(tester, 'result-detail');
      await pump(
          tester, ResultPage(record: fixture(legacy: true), readOnly: true),
          width: 320, scale: scale);
      await tester.drag(find.byType(ListView), const Offset(0, -1300));
      await tester.pumpAndSettle();
      expect(find.text('Buổi tập này chưa có dữ liệu nhịp từng rep.'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    for (final phase in [
      WorkoutUiPhase.positioning,
      WorkoutUiPhase.countdown,
      WorkoutUiPhase.active,
      WorkoutUiPhase.calibrating,
      WorkoutUiPhase.paused
    ]) {
      testWidgets('HUD ${phase.name} ${scale}x renders controller state',
          (tester) async {
        await pump(
            tester,
            Scaffold(
                body: SafeArea(
                    child: WorkoutHud(
                        state: hudState(phase),
                        exerciseName: 'Hít đất',
                        hint: 'Đặt máy thấp, thấy rõ vai, hai tay và hông.',
                        onExit: () {},
                        onPause: () {},
                        onResume: () {},
                        onFinish: () {},
                        onCalibrate: () {},
                        onHelp: () {},
                        goalBanner: false,
                        onDismissGoal: () {}))),
            width: scale == 2 ? 320 : 393,
            scale: scale);
        expect(tester.takeException(), isNull);
        if (phase == WorkoutUiPhase.calibrating) {
          expect(find.text('67 mẫu đã thu'), findsOneWidget);
        }
        if (scale == 1) await screenshot(tester, 'hud-${phase.name}');
      });
    }
  }
  testWidgets('hold finish cancels early and fires once at one second',
      (tester) async {
    var count = 0;
    await pump(tester,
        Scaffold(body: Center(child: HoldToFinish(onFinish: () => count++))));
    final target = find
        .descendant(
            of: find.byType(HoldToFinish), matching: find.byType(Listener))
        .first;
    var touch = await tester.startGesture(tester.getCenter(target));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await touch.up();
    await tester.pumpAndSettle();
    expect(count, 0);
    touch = await tester.startGesture(tester.getCenter(target));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1100));
    expect(count, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(count, 1);
    await touch.up();
    await tester.pumpAndSettle();
  });
  testWidgets('permission and denied views are responsive', (tester) async {
    for (final denied in [false, true]) {
      await pump(
          tester,
          CameraPermissionView(
              title: denied ? S.vi.cameraDenied : S.vi.cameraPermissionTitle,
              body: denied ? S.vi.cameraDeniedBody : S.vi.cameraPermissionBody,
              denied: denied,
              loading: false,
              actionLabel: S.vi.cameraAllowAndOpen,
              onAction: () {},
              onExit: () {}));
      expect(tester.takeException(), isNull);
      await screenshot(tester, denied ? 'camera-denied' : 'camera-permission');
    }
  });
  test('timing detail round trips and is excluded from AI payload', () {
    final record = fixture();
    final decoded = WorkoutRecord.fromJson(record.toJson());
    expect(decoded.repDetails!.length, 23);
    expect(decoded.repDetails![19].flagged, isTrue);
    expect(decoded.copyWith(aiFeedback: 'ok').repDetails!.length, 23);
    expect(decoded.toAiPayload().containsKey('rep_details'), isFalse);
    expect(WorkoutRecord.fromJson(fixture(legacy: true).toJson()).repDetails,
        isNull);
  });
}
