import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/core/services/app_links.dart';
import 'package:rep_counter_app/core/services/training_preferences.dart';
import 'package:rep_counter_app/core/services/workout_feedback.dart';
import 'package:rep_counter_app/exercise.dart';
import 'package:rep_counter_app/features/ai/ai_preferences.dart';
import 'package:rep_counter_app/features/ai/ai_feedback_service.dart';
import 'package:rep_counter_app/features/ai/presentation/ai_consent.dart';
import 'package:rep_counter_app/features/exercises/presentation/exercise_picker_screen.dart';
import 'package:rep_counter_app/features/legal/settings_page.dart';
import 'package:rep_counter_app/features/share/story_page.dart';
import 'package:rep_counter_app/features/workout/presentation/goal_setup_page.dart';
import 'package:rep_counter_app/features/workout/presentation/result_page.dart';
import 'package:rep_counter_app/theme/app_theme.dart';
import 'phase6_test.dart' show FakeSpeech;
import 'phase7_test.dart' show record;

class FakeExporter extends StoryExporter {
  Uint8List? bytes;
  Rect? origin;
  int saves = 0, shares = 0;
  bool fail = false;
  ShareResultStatus status = ShareResultStatus.dismissed;
  @override
  Future<void> save(Uint8List value) async {
    saves++;
    bytes = value;
    if (fail) throw StateError('disk full');
  }

  @override
  Future<ShareResultStatus> share(Uint8List value, Rect rect) async {
    shares++;
    bytes = value;
    origin = rect;
    return status;
  }
}

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
  Future<void> pump(WidgetTester tester, Widget child,
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
                child: child!),
            home: child)));
    await tester.pumpAndSettle();
  }

  test('automatic AI defaults off and can be revoked', () async {
    expect(await AiPreferences.enabled(), false);
    await AiPreferences.setEnabled(true);
    expect(await AiPreferences.enabled(), true);
    await AiPreferences.setEnabled(false);
    expect(await AiPreferences.enabled(), false);
  });
  test('store URL uses Android production id; iOS has no invented listing', () {
    expect(AppLinks.email.scheme, 'mailto');
    expect(AppLinks.email.path, 'ronganminh221@gmail.com');
    expect(AppLinks.email.queryParameters['subject'], 'RepCoach AI feedback');
    expect(AppLinks.reviewUrl(ios: false)!.queryParameters['id'],
        'com.ronganminh.repcoach');
    expect(AppLinks.reviewUrl(ios: true), isNull);
  });
  test(
      'sound and posture preferences persist independently of voice and haptics',
      () async {
    final defaults = await TrainingPreferences.load();
    expect(defaults.sound, false);
    expect(defaults.cues, true);
    await defaults.update(sound: true, cues: false);
    final saved = await TrainingPreferences.load();
    expect(saved.sound, true);
    expect(saved.cues, false);
    expect(saved.voice, true);
    expect(saved.haptics, true);
  });
  test('set sound obeys preference and disposal even with voice muted',
      () async {
    final events = <bool>[];
    final feedback = WorkoutFeedback(
        speech: FakeSpeech(), sound: (start) async => events.add(start));
    feedback.setBoundary(true);
    expect(events, isEmpty);
    feedback.configure(
        const TrainingPreferences(voice: false, sound: true), AppLanguage.vi);
    feedback.setBoundary(true);
    feedback.setBoundary(false);
    expect(events, [true, false]);
    feedback.dispose();
    feedback.setBoundary(true);
    await feedback.settled;
    expect(events, [true, false]);
  });
  test('spoken posture cues are throttled, optional and never replace goal',
      () async {
    final speech = FakeSpeech();
    final feedback = WorkoutFeedback(speech: speech, haptic: (_) async {});
    feedback.cue('Keep in view', Duration.zero);
    await feedback.settled;
    feedback.cue('Repeated', const Duration(seconds: 7));
    await feedback.settled;
    expect(speech.spoken, ['Keep in view']);
    feedback.rep(1,
        goalReached: false, cue: 'Slow down', at: const Duration(seconds: 8));
    await feedback.settled;
    expect(speech.spoken.last, '1. Slow down');
    feedback.rep(2,
        goalReached: true, cue: 'Ignored', at: const Duration(seconds: 16));
    await feedback.settled;
    expect(speech.spoken.last, '2. Đạt mục tiêu!');
    feedback.configure(const TrainingPreferences(cues: false), AppLanguage.vi);
    feedback.cue('Disabled', const Duration(seconds: 30));
    await feedback.settled;
    expect(speech.spoken, hasLength(3));
    feedback.configure(const TrainingPreferences(voice: false), AppLanguage.vi);
    feedback.cue('Muted', const Duration(seconds: 40));
    await feedback.settled;
    expect(speech.spoken, hasLength(3));
    feedback.dispose();
    await feedback.settled;
  });
  for (final accept in [false, true]) {
    testWidgets('consent ${accept ? 'accepts' : 'rejects'} automatic AI',
        (tester) async {
      bool? result;
      await pump(
          tester,
          Scaffold(
              body: Builder(
                  builder: (context) => TextButton(
                      onPressed: () async {
                        result = await requestAutomaticAiConsent(context);
                      },
                      child: const Text('open')))));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(await AiPreferences.enabled(), false);
      await tester.tap(accept
          ? find.byKey(const Key('accept-automatic-ai'))
          : find.text('Để sau'));
      await tester.pumpAndSettle();
      expect(result, accept);
      expect(await AiPreferences.enabled(), accept);
    });
  }
  for (final option in [
    (false, false, true),
    (true, false, true),
    (true, true, true),
    (true, false, false)
  ]) {
    testWidgets('automatic request consent/readOnly/new: $option',
        (tester) async {
      await AiPreferences.setEnabled(option.$1);
      var calls = 0, saves = 0;
      await pump(
          tester,
          ResultPage(
              record: record(),
              offerAutomaticAi: option.$3,
              readOnly: option.$2,
              aiConfigured: true,
              analyze: (sent, lang) async {
                calls++;
                return 'Saved automatic feedback';
              },
              saveFeedback: (_, __) async {
                saves++;
              }));
      final expected = option.$1 && !option.$2 && option.$3 ? 1 : 0;
      expect(calls, expected);
      expect(saves, expected);
      await tester.pump(const Duration(seconds: 2));
      expect(calls, expected);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('automatic AI network failure keeps workout and manual retry',
      (tester) async {
    await AiPreferences.setEnabled(true);
    var calls = 0;
    await pump(
        tester,
        ResultPage(
            record: record(),
            offerAutomaticAi: true,
            aiConfigured: true,
            analyze: (_, __) async {
              calls++;
              throw const AiFeedbackException(AiFeedbackFailure.offline);
            },
            saveFeedback: (_, __) async =>
                fail('Failed AI must not save feedback')));
    expect(calls, 1);
    expect(find.byKey(const Key('result-done')), findsOneWidget);
    expect(find.byKey(const Key('ask-result-ai')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('settings enable requires consent and switch can revoke it',
      (tester) async {
    await pump(tester, const SettingsPage());
    final toggle = find.byKey(const Key('auto-ai-setting'));
    await tester.scrollUntilVisible(toggle, 350);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(await AiPreferences.enabled(), false);
    await tester.tap(find.byKey(const Key('accept-automatic-ai')));
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(toggle).value, true);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(await AiPreferences.enabled(), false);
  });
  for (final profile in allExercises) {
    testWidgets('exercise picker opens existing ${profile.id} profile',
        (tester) async {
      await pump(tester, const ExercisePickerScreen());
      final tile = find.byKey(Key('exercise-${profile.id}'));
      await tester.scrollUntilVisible(tile, 300);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(find.byType(GoalSetupContent), findsOneWidget);
      expect(
          tester
              .widget<GoalSetupContent>(find.byType(GoalSetupContent))
              .profile
              .id,
          profile.id);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('unsupported exercise stays marked coming soon', (tester) async {
    await pump(tester, const ExercisePickerScreen());
    final tile = find.byKey(const Key('exercise-squat'));
    await tester.scrollUntilVisible(tile, 300);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.byType(GoalSetupContent), findsNothing);
    expect(find.text('Bài tập này sắp ra mắt.'), findsOneWidget);
  });
  for (final variant in [
    (false, ShareResultStatus.dismissed),
    (false, ShareResultStatus.unavailable),
    (true, ShareResultStatus.success),
  ]) {
    final save = variant.$1;
    testWidgets(
        'story ${save ? 'saves' : 'shares'} ${variant.$2} actual 1080x1920 PNG only after action',
        (tester) async {
      final exporter = FakeExporter()..status = variant.$2;
      await pump(
          tester,
          StoryPage(
              record: record(feedback: 'Test-only feedback. ' * 80),
              exporter: exporter),
          width: 320,
          scale: 2);
      expect(tester.takeException(), isNull);
      expect(exporter.saves + exporter.shares, 0);
      await tester.runAsync(() async {
        await tester.tap(find.byKey(Key(save ? 'save-story' : 'share-story')));
        await tester.pump();
        for (var i = 0; i < 50 && exporter.bytes == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      await tester.pumpAndSettle();
      expect(exporter.bytes, isNotNull);
      expect(exporter.saves, save ? 1 : 0);
      expect(exporter.shares, save ? 0 : 1);
      if (!save) {
        expect(exporter.origin!.isEmpty, false);
        expect(find.byType(SnackBar), findsNothing);
      }
      await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(exporter.bytes!);
        final frame = await codec.getNextFrame();
        expect(frame.image.width, 1080);
        expect(frame.image.height, 1920);
        frame.image.dispose();
        codec.dispose();
        const dir = String.fromEnvironment('FEATURE_SCREENSHOTS');
        if (dir.isNotEmpty && save) {
          await Directory(dir).create(recursive: true);
          await File('$dir/story-fixture.png').writeAsBytes(exporter.bytes!);
        }
      });
      expect(find.text('Đã lưu ảnh vào thư viện.'),
          save ? findsOneWidget : findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('story save failure never reports success', (tester) async {
    final exporter = FakeExporter()..fail = true;
    await pump(tester, StoryPage(record: record(), exporter: exporter));
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('save-story')));
      await tester.pump();
      for (var i = 0; i < 50 && exporter.bytes == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pumpAndSettle();
    expect(exporter.saves, 1);
    expect(find.text('Đã lưu ảnh vào thư viện.'), findsNothing);
    expect(find.text('Chưa xuất được ảnh. Hãy thử lại.'), findsOneWidget);
  });
  testWidgets('result opens story with the current saved feedback',
      (tester) async {
    await pump(
        tester,
        ResultPage(
            record: record(feedback: 'Actual saved text'), readOnly: true));
    await tester.tap(find.byKey(const Key('open-story')));
    await tester.pumpAndSettle();
    expect(find.byType(StoryPage), findsOneWidget);
    expect(find.text('Actual saved text'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
