import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/exercise.dart';
import 'package:rep_counter_app/features/exercises/presentation/exercise_detail_page.dart';
import 'package:rep_counter_app/features/exercises/presentation/exercise_picker_screen.dart';
import 'package:rep_counter_app/features/home/presentation/home_screen.dart';
import 'package:rep_counter_app/features/legal/onboarding_page.dart';
import 'package:rep_counter_app/features/legal/settings_page.dart';
import 'package:rep_counter_app/features/profile/presentation/profile_page.dart';
import 'package:rep_counter_app/features/workout/data/workout_history_store.dart';
import 'package:rep_counter_app/features/workout/data/workout_record.dart';
import 'package:rep_counter_app/features/workout/presentation/goal_setup_page.dart';
import 'package:rep_counter_app/features/workout/presentation/history_page.dart';
import 'package:rep_counter_app/features/workout/presentation/result_page.dart';
import 'package:rep_counter_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/contrast.dart';
import '../support/l10n.dart';

/// WCAG AA text contrast (4.5:1 body, 3:1 large) for the screens v2 touches,
/// computed per paragraph by `auditTextContrast` (see test/support/contrast.dart
/// for why Flutter's pixel-sampling guideline is not enough).
/// Tracks PRODUCT_DECISIONS D-25 / FINAL_QA A11Y-02.

WorkoutRecord _record(String id, {int reps = 23, int daysAgo = 0}) =>
    WorkoutRecord(
      id: id,
      exerciseId: 'push_up',
      exerciseName: 'Hít đất',
      startedAt: DateTime.now().subtract(Duration(days: daysAgo)),
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
    {AppLanguage language = AppLanguage.vi}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final locale = LocaleController(language);
  addTearDown(locale.dispose);
  await tester.pumpWidget(LocaleScope(
    controller: locale,
    child: MaterialApp(
      theme: RepCoachTheme.dark(),
      locale: language.locale,
      supportedLocales: testSupportedLocales,
      localizationsDelegates: testLocalizationsDelegates,
      home: page,
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _checkWholeScroll(WidgetTester tester) async {
  final issues = <String>{};
  void collect() => issues.addAll(auditTextContrast(tester).map((i) => '$i'));
  collect();
  final scrollables = find.byType(Scrollable);
  if (scrollables.evaluate().isNotEmpty) {
    for (var i = 0; i < 6; i++) {
      await tester.drag(scrollables.first, const Offset(0, -500),
          warnIfMissed: false);
      await tester.pumpAndSettle();
      collect();
    }
  }
  expect(issues, isEmpty);
}

void main() {
  setUpAll(_loadFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final screens = <String, Widget Function()>{
    'home': () => const HomeScreen(),
    'exercises': () => const ExercisePickerScreen(),
    'exercise detail': () => const ExerciseDetailPage(profile: pushUp),
    'progress': () => const ProgressPage(),
    'history list': () => const HistoryListPage(),
    'profile': () => const ProfilePage(),
    'settings': () => const SettingsPage(),
    'goal setup': () => const GoalSetupPage(profile: pushUp),
    'result': () => ResultPage(record: _record('r'), readOnly: true),
  };

  for (final language in AppLanguage.values) {
    for (final withHistory in [true, false]) {
      for (final entry in screens.entries) {
        if (!withHistory && entry.key == 'result') continue;
        testWidgets(
            'text contrast meets WCAG AA · ${entry.key} · ${language.code}'
            '${withHistory ? '' : ' · empty'}', (tester) async {
          final handle = tester.ensureSemantics();
          if (withHistory) {
            final store = WorkoutHistoryStore();
            await store.save(_record('a'));
            await store.save(_record('b', reps: 31, daysAgo: 1));
          }
          await _pump(tester, entry.value(), language: language);
          await _checkWholeScroll(tester);
          handle.dispose();
        });
      }
    }
    testWidgets('text contrast meets WCAG AA · onboarding · ${language.code}',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, OnboardingPage(onDone: () {}), language: language);
      for (var page = 0; page < 4; page++) {
        expect(auditTextContrast(tester).map((i) => '$i'), isEmpty);
        final next = find.byType(FilledButton);
        if (next.evaluate().isEmpty) break;
        await tester.tap(next.first);
        await tester.pumpAndSettle();
      }
      handle.dispose();
    });
  }
}
