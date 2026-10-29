import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/core/services/training_preferences.dart';
import 'package:rep_counter_app/core/services/workout_feedback.dart';
import 'package:rep_counter_app/exercise.dart';
import 'package:rep_counter_app/features/workout/application/guided_timer_cues.dart';
import 'package:rep_counter_app/features/workout/presentation/guided_timer_page.dart';
import 'package:rep_counter_app/features/workout/presentation/guided_timer_settings.dart';
import 'package:rep_counter_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/l10n.dart';

/// X-2: guided timer voice cues (system voice, app language, existing
/// voice setting) and keep-screen-on while counting; both switchable in
/// Settings and on by default.

class FakeSpeech implements SpeechDriver {
  final said = <String>[];
  final locales = <String>[];
  @override
  Future<void> configure(String locale) async => locales.add(locale);
  @override
  Future<void> speak(String text) async => said.add(text);
  @override
  Future<void> stop() async {}
}

class FakeAwake implements ScreenAwake {
  final states = <bool>[];
  @override
  Future<void> set(bool on) async => states.add(on);
}

Future<void> _pump(WidgetTester tester, Widget home,
    {AppLanguage language = AppLanguage.en}) async {
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
      home: home,
    ),
  ));
  await tester.pump();
}

Future<void> _seconds(WidgetTester tester, int n) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  late FakeSpeech speech;
  late FakeAwake awake;
  GuidedTimerPage page(
          {TrainingPreferences prefs = const TrainingPreferences(),
          int sets = 2,
          int seconds = 10,
          int rest = 3}) =>
      GuidedTimerPage(
        profile: pushUp,
        sets: sets,
        seconds: seconds,
        restSeconds: rest,
        cues: GuidedTimerCues(speech: speech, awake: awake),
        loadPreferences: () async => prefs,
      );

  setUp(() {
    speech = FakeSpeech();
    awake = FakeAwake();
  });

  testWidgets('EN: set, halfway, countdown, rest, next set, done',
      (tester) async {
    await _pump(tester, page());
    await _seconds(tester, 10); // set 1
    await _seconds(tester, 3); // rest
    await _seconds(tester, 10); // set 2
    await tester.pump();
    expect(speech.said, [
      'Set 1 of 2. Go!',
      'Halfway.',
      '3',
      '2',
      '1',
      'Rest for 3 seconds.',
      '2',
      '1',
      'Set 2 of 2. Go!',
      'Halfway.',
      '3',
      '2',
      '1',
      'Done!',
    ]);
    expect(speech.locales.toSet(), {'en-US'});
  });

  testWidgets('VI: the app language picks the voice and the words',
      (tester) async {
    await _pump(tester, page(sets: 1, seconds: 4), language: AppLanguage.vi);
    await _seconds(tester, 4);
    await tester.pump();
    expect(speech.said,
        ['Set 1 trên 1. Bắt đầu!', 'Ba', 'Hai', 'Một', 'Hoàn thành!']);
    expect(speech.locales.toSet(), {'vi-VN'});
  });

  testWidgets('silent when the timer voice or the app voice is off',
      (tester) async {
    for (final prefs in const [
      TrainingPreferences(timerVoice: false),
      TrainingPreferences(voice: false),
    ]) {
      speech = FakeSpeech();
      await _pump(tester, page(prefs: prefs, sets: 1, seconds: 4));
      await _seconds(tester, 4);
      expect(speech.said, isEmpty, reason: '$prefs');
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('screen stays on only while counting; released on leave',
      (tester) async {
    await _pump(tester, page(sets: 1, seconds: 20));
    expect(awake.states, [true]);
    await tester.tap(find.byKey(const Key('timer-pause')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('timer-pause'))); // resume
    await tester.pump();
    expect(awake.states, [true, false, true]);
    await tester.pumpWidget(const SizedBox()); // leaves the page
    expect(awake.states, [true, false, true, false]);
  });

  testWidgets('screen released when the timer finishes; never on when off',
      (tester) async {
    await _pump(tester, page(sets: 1, seconds: 2));
    await _seconds(tester, 2);
    expect(awake.states, [true, false]);
    await tester.pumpWidget(const SizedBox());

    awake = FakeAwake();
    await _pump(
        tester, page(prefs: const TrainingPreferences(timerKeepAwake: false)));
    await _seconds(tester, 3);
    expect(awake.states, isEmpty);
  });

  test('preferences: on by default, saved separately', () async {
    final p = await TrainingPreferences.load();
    expect(p.timerVoice, isTrue);
    expect(p.timerKeepAwake, isTrue);
    final q = await p.update(timerVoice: false);
    expect(q.timerVoice, isFalse);
    expect(q.voice, isTrue);
    final r = await TrainingPreferences.load();
    expect((r.timerVoice, r.timerKeepAwake), (false, true));
  });

  testWidgets('Settings › Guided timer: two switches, on by default',
      (tester) async {
    await _pump(
        tester,
        const Scaffold(
            body: SingleChildScrollView(child: GuidedTimerSettingsGroup())));
    await tester.pump();
    expect(
        find.text('Guided timer'.toUpperCase()).evaluate().length +
            find.text('Guided timer').evaluate().length,
        1);
    expect(find.text('Voice cues'), findsOneWidget);
    expect(find.text('Keep screen on'), findsOneWidget);
    Switch sw(String key) => tester.widget<Switch>(find.byKey(Key(key)));
    expect(sw('timer-voice-setting').value, isTrue);
    expect(sw('timer-awake-setting').value, isTrue);
    await tester.tap(find.byKey(const Key('timer-awake-setting')));
    await tester.pump();
    await tester.pump();
    expect(sw('timer-awake-setting').value, isFalse);
    final saved = await tester.runAsync(TrainingPreferences.load);
    expect(saved!.timerKeepAwake, isFalse);
    expect(saved.timerVoice, isTrue);
  });
}
