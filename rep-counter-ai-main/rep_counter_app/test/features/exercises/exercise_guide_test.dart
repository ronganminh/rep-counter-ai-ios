import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/exercise.dart';
import 'package:rep_counter_app/features/exercises/data/exercise_guide_clips.dart';
import 'package:rep_counter_app/features/exercises/presentation/exercise_detail_page.dart';
import 'package:rep_counter_app/features/exercises/presentation/exercise_guide_card.dart';
import 'package:rep_counter_app/features/plan/presentation/plan_today_sheet.dart';
import 'package:rep_counter_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../../support/l10n.dart';

/// In-memory player: records calls, never decodes anything.
class _FakePlayer extends VideoPlayerPlatform {
  final created = <String>[];
  final calls = <String>[];
  final _events = <int, StreamController<VideoEvent>>{};
  var _next = 0;

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final id = _next++;
    created.add(options.dataSource.asset ?? '');
    _events[id] = StreamController<VideoEvent>();
    scheduleMicrotask(() => _events[id]!.add(VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(seconds: 6),
        size: const Size(1280, 720))));
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _events[playerId]!.stream;

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async =>
      calls.add('mix:$mixWithOthers');
  @override
  Future<void> setLooping(int playerId, bool looping) async =>
      calls.add('loop:$looping');
  @override
  Future<void> setVolume(int playerId, double volume) async =>
      calls.add('volume:$volume');
  @override
  Future<void> play(int playerId) async => calls.add('play');
  @override
  Future<void> pause(int playerId) async => calls.add('pause');
  @override
  Future<void> seekTo(int playerId, Duration position) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;
  @override
  Future<void> dispose(int playerId) async => calls.add('dispose');
  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const ColoredBox(key: Key('fake-video-view'), color: Colors.black);
}

Future<void> _pump(WidgetTester tester, Widget page,
    {AppLanguage language = AppLanguage.en,
    bool reducedMotion = false,
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
      theme: RepCoachTheme.dark(),
      locale: language.locale,
      supportedLocales: testSupportedLocales,
      localizationsDelegates: testLocalizationsDelegates,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
              disableAnimations: reducedMotion,
              textScaler: TextScaler.linear(scale)),
          child: child!),
      home: page,
    ),
  ));
  await tester.pumpAndSettle();
}

Map<String, dynamic> _arb(String lang) =>
    jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  late _FakePlayer player;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    player = _FakePlayer();
    VideoPlayerPlatform.instance = player;
  });

  test('only pull-up and curl have a clip; curl is a similar movement', () {
    expect(ExerciseGuideClip.forExercise(pushUp.id), isNull);
    expect(ExerciseGuideClip.forExercise(overheadExtension.id), isNull);
    final pull = ExerciseGuideClip.forExercise(pullUp.id)!;
    final curl = ExerciseGuideClip.forExercise(dumbbellCurl.id)!;
    expect((pull.sourceId, pull.slug, pull.fit),
        ('l02', 'wide-grip-pull-up', GuideClipFit.exact));
    expect((curl.sourceId, curl.slug, curl.fit),
        ('b01', 'standing-barbell-curl', GuideClipFit.similar));
    for (final clip in ExerciseGuideClip.all) {
      expect(clip.cuesEn, hasLength(3));
      // VI cues are our own translation, still waiting for review.
      expect(clip.cuesViReviewed, isFalse);
    }
  });

  test('bundled clips match the recorded size and SHA-256', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final clip in ExerciseGuideClip.all) {
      final video = File(clip.videoAsset);
      expect(video.existsSync(), isTrue, reason: clip.videoAsset);
      final bytes = video.readAsBytesSync();
      expect(bytes.length, clip.bytes, reason: clip.slug);
      expect(sha256.convert(bytes).toString(), clip.sha256, reason: clip.slug);
      expect(File(clip.posterAsset).existsSync(), isTrue);
      expect(pubspec, contains('- ${clip.videoAsset}'));
      expect(pubspec, contains('- ${clip.posterAsset}'));
      // The asset README records the same checksum and the licence.
      final readme = File('assets/guide/README.md').readAsStringSync();
      expect(readme, contains(clip.sha256));
      expect(readme, contains('CC0 1.0'));
    }
  });

  test('EN ARB cues are the library cues, and VI cues exist', () {
    final en = _arb('en');
    final vi = _arb('vi');
    final keys = {
      'pull_up': ['guideCuePullUp1', 'guideCuePullUp2', 'guideCuePullUp3'],
      'curl': ['guideCueCurl1', 'guideCueCurl2', 'guideCueCurl3'],
    };
    for (final clip in ExerciseGuideClip.all) {
      final k = keys[clip.appId]!;
      expect([for (final key in k) en[key]], clip.cuesEn);
      for (final key in k) {
        expect(vi[key], isA<String>());
        expect(vi[key], isNot(en[key]));
        expect((en['@$key'] as Map)['description'], contains('needs review'));
      }
    }
  });

  for (final language in AppLanguage.values) {
    testWidgets('pull-up detail shows the clip and 3 cues ($language)',
        (tester) async {
      await _pump(tester, const ExerciseDetailPage(profile: pullUp),
          language: language);
      expect(find.byKey(const Key('guide-clip-pull_up')), findsOneWidget);
      for (var i = 0; i < 3; i++) {
        expect(find.byKey(Key('guide-cue-$i')), findsOneWidget);
      }
      expect(
          find.text(language == AppLanguage.vi
              ? 'Kéo ngực về phía xà'
              : 'Pull the chest toward the bar'),
          findsOneWidget);
      // Exact movement: no "shown with a barbell" note.
      expect(find.byKey(const Key('guide-similar-note')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('curl detail notes the barbell ($language)', (tester) async {
      await _pump(tester, const ExerciseDetailPage(profile: dumbbellCurl),
          language: language);
      expect(find.byKey(const Key('guide-clip-curl')), findsOneWidget);
      expect(find.byKey(const Key('guide-cue-2')), findsOneWidget);
      expect(
          find.text(language == AppLanguage.vi
              ? 'Minh hoạ với tạ đòn'
              : 'Shown with a barbell'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final language in AppLanguage.values) {
    testWidgets('curl detail fits 375x667 at 2.0x text ($language)',
        (tester) async {
      await _pump(tester, const ExerciseDetailPage(profile: dumbbellCurl),
          language: language, size: const Size(375, 667), scale: 2);
      await tester.scrollUntilVisible(find.byKey(const Key('guide-cue-2')), 200,
          scrollable: find.byType(Scrollable).first);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('push-up and overhead extension show no clip and no error',
      (tester) async {
    for (final profile in [pushUp, overheadExtension]) {
      await _pump(tester, ExerciseDetailPage(profile: profile));
      expect(find.byKey(Key('guide-card-${profile.id}')), findsNothing);
      expect(find.byKey(const Key('guide-cue-0')), findsNothing);
      expect(find.byKey(const Key('exercise-start')), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    expect(player.created, isEmpty);
  });

  testWidgets('the clip autoplays muted, looping and mixed with other audio',
      (tester) async {
    await _pump(tester, const ExerciseDetailPage(profile: pullUp));
    expect(player.created, ['assets/guide/wide-grip-pull-up.mp4']);
    expect(player.calls,
        containsAll(['mix:true', 'loop:true', 'volume:0.0', 'play']));
    expect(find.byKey(const Key('fake-video-view')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('wide-grip pull-up')), findsOneWidget);

    await tester.tap(find.byKey(const Key('guide-play-toggle')));
    await tester.pump();
    expect(player.calls.last, 'pause');
  });

  testWidgets('reduced motion shows the poster and a play button',
      (tester) async {
    await _pump(tester, const ExerciseDetailPage(profile: dumbbellCurl),
        reducedMotion: true);
    expect(player.created, isEmpty);
    expect(find.byKey(const Key('guide-poster')), findsOneWidget);
    expect(find.byKey(const Key('fake-video-view')), findsNothing);
    expect(find.byTooltip('Play demo video'), findsOneWidget);

    await tester.tap(find.byKey(const Key('guide-play-toggle')));
    await tester.pumpAndSettle();
    expect(player.created, ['assets/guide/standing-barbell-curl.mp4']);
    expect(player.calls, contains('play'));
    expect(find.byTooltip('Pause demo video'), findsOneWidget);
  });

  testWidgets('the clip pauses while another page covers it', (tester) async {
    await _pump(tester, const ExerciseDetailPage(profile: pullUp));
    expect(player.calls.last, 'play');
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('covering page'))));
    await tester.pumpAndSettle();
    expect(player.calls.last, 'pause');
    navigator.pop();
    await tester.pumpAndSettle();
    expect(player.calls.last, 'play');
  });

  testWidgets('a player error keeps the poster and the cues', (tester) async {
    VideoPlayerPlatform.instance = _BrokenPlayer();
    await _pump(tester, const ExerciseGuideCard(exerciseId: 'pull_up'));
    expect(find.byKey(const Key('guide-poster')), findsOneWidget);
    expect(find.byKey(const Key('guide-play-toggle')), findsNothing);
    expect(find.byKey(const Key('guide-cue-2')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the Train sheet shows the guide before Start', (tester) async {
    await _pump(
        tester,
        Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () =>
                        showPlanTodaySheet(context, pullUp, showPlan: false),
                    child: const Text('open')))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('guide-card-pull_up')), findsOneWidget);
    expect(find.byKey(const Key('guide-cue-0')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _BrokenPlayer extends _FakePlayer {
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async =>
      throw UnimplementedError('no player');
}
