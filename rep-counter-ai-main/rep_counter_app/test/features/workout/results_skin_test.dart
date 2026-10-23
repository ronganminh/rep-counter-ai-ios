import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/features/share/story_page.dart';
import 'package:rep_counter_app/features/workout/application/result_controller.dart';
import 'package:rep_counter_app/features/workout/data/workout_record.dart';
import 'package:rep_counter_app/features/workout/presentation/result_page.dart';
import 'package:rep_counter_app/features/workout/presentation/widgets/result_feedback_card.dart';
import 'package:rep_counter_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/l10n.dart';

/// W-3 (visual part): Results R1/R2, AI card AI1/AI2 and story S1 from
/// design-source/project/RepCoach-AI-Results.dc.html. Data comes from the
/// saved record only.

WorkoutRecord _record(String id, {int reps = 23, int daysAgo = 0}) =>
    WorkoutRecord(
      id: id,
      exerciseId: 'push_up',
      exerciseName: 'Hít đất',
      // Fixed time: the date line is part of the goldens.
      startedAt:
          DateTime(2026, 10, 22, 18, 40).subtract(Duration(days: daysAgo)),
      durationSeconds: 252,
      reps: reps,
      sets: 3,
      targetReps: 20,
      poseFrames: 100,
      readyFrames: 90,
      lostFrames: 10,
      quality: const WorkoutQuality(
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
      repDetails: List.generate(
          reps,
          (i) => StoredRep(
              seconds: 1.2 + (i % 5) * .25,
              setIndex: i ~/ 8 + 1,
              flagged: i == 19 || i == 20)),
    );

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
      debugShowCheckedModeBanner: false,
      theme: RepCoachTheme.dark(),
      locale: language.locale,
      supportedLocales: testSupportedLocales,
      localizationsDelegates: testLocalizationsDelegates,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale), disableAnimations: true),
          child: child!),
      home: page,
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(_loadFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final language in AppLanguage.values) {
    for (final (name, reps) in [('reached', 23), ('stopped-early', 14)]) {
      testWidgets('Results golden · $name · ${language.code}', (tester) async {
        await _pump(
            tester,
            ResultPage(
                record: _record('r', reps: reps),
                readOnly: false,
                aiConfigured: false),
            language: language);
        await expectLater(find.byType(ResultPage),
            matchesGoldenFile('goldens/results_${name}_${language.code}.png'));
      }, skip: !Platform.isLinux);
    }
    testWidgets('Story golden · ${language.code}', (tester) async {
      await _pump(
          tester,
          Scaffold(
              body: Center(
                  child: SizedBox(
                      width: 360,
                      height: 640,
                      child: StoryCard(
                          record: _record('s').copyWith(
                              aiFeedback: language == AppLanguage.vi
                                  ? 'Vượt mục tiêu 3 rep với biên độ tốt.'
                                  : 'Beat your goal by 3 reps with good range.'))))),
          language: language);
      await expectLater(find.byType(StoryCard),
          matchesGoldenFile('goldens/story_${language.code}.png'));
    }, skip: !Platform.isLinux);
  }

  testWidgets('hero keeps the goal on the count baseline', (tester) async {
    await _pump(tester,
        ResultPage(record: _record('r', reps: 23), aiConfigured: false));
    final count = tester.getBottomLeft(find.text('23'));
    final goal = tester.getBottomLeft(find.text('/20'));
    expect(goal.dx, greaterThan(count.dx));
    expect((goal.dy - count.dy).abs(), lessThan(24));
  });

  testWidgets('Share is a labelled button next to Done', (tester) async {
    await _pump(tester, ResultPage(record: _record('r'), aiConfigured: false),
        language: AppLanguage.en);
    final share = find.byKey(const Key('open-story'));
    expect(find.descendant(of: share, matching: find.text('Share')),
        findsOneWidget);
    expect(tester.getSize(share).height, greaterThanOrEqualTo(48));
    await tester.tap(share);
    await tester.pumpAndSettle();
    expect(find.byType(StoryPage), findsOneWidget);
  });

  testWidgets('loading shows a skeleton instead of jumping content',
      (tester) async {
    final response = Completer<String>();
    final c = ResultController(_record('r'),
        configured: true,
        analyze: (_, __) => response.future,
        saveFeedback: (_, __) async {});
    addTearDown(c.dispose);
    unawaited(c.request(AppLanguage.vi));
    await _pump(
        tester,
        Scaffold(
            body: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ListenableBuilder(
                    listenable: c,
                    builder: (_, __) => ResultFeedbackCard(controller: c)))));
    expect(find.byKey(const Key('ai-skeleton')), findsOneWidget);
    expect(find.byKey(const Key('ai-loading')), findsOneWidget);
    expect(find.byKey(const Key('feedback-next-goal')), findsNothing);
    response.complete('Ready text');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ai-skeleton')), findsNothing);
    expect(find.text('Ready text'), findsOneWidget);
  });

  testWidgets('quick feedback shows the next-session box and estimate tag',
      (tester) async {
    await _pump(tester,
        ResultPage(record: _record('r', reps: 23), aiConfigured: false));
    final next = find.byKey(const Key('feedback-next-goal'));
    await tester.scrollUntilVisible(next, 200,
        scrollable: find.byType(Scrollable).first);
    expect(
        find.descendant(
            of: next, matching: find.text(S.vi.fbNextGoal.toUpperCase())),
        findsOneWidget);
    await tester.scrollUntilVisible(
        find.byKey(const Key('form-score-estimated')), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('ước tính'), findsOneWidget);
  });

  for (final language in AppLanguage.values) {
    testWidgets('Results and story fit at 2x text · ${language.code}',
        (tester) async {
      await _pump(tester, ResultPage(record: _record('r'), aiConfigured: false),
          language: language, size: const Size(320, 640), scale: 2);
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView), const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
