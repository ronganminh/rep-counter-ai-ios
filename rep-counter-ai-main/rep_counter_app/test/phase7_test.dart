import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/features/ai/ai_feedback_service.dart';
import 'package:rep_counter_app/features/workout/application/result_controller.dart';
import 'package:rep_counter_app/features/workout/data/workout_history_store.dart';
import 'package:rep_counter_app/features/workout/data/workout_record.dart';
import 'package:rep_counter_app/features/workout/presentation/result_page.dart';
import 'package:rep_counter_app/features/workout/presentation/widgets/result_feedback_card.dart';
import 'package:rep_counter_app/theme/app_colors.dart';
import 'package:rep_counter_app/theme/app_theme.dart';
import 'new_ui_test.dart' show fixture;

// These records and AI responses exist only in tests, never production seeds.
WorkoutRecord record(
        {int reps = 14,
        int? goal = 20,
        bool legacy = false,
        String? feedback,
        String id = 'phase7'}) =>
    WorkoutRecord(
        id: id,
        exerciseId: 'push_up',
        exerciseName: 'Hít đất',
        startedAt: DateTime(2026, 9, 27, 18, 40),
        durationSeconds: 168,
        reps: reps,
        sets: 2,
        targetReps: goal,
        poseFrames: 100,
        readyFrames: 92,
        lostFrames: 8,
        aiFeedback: feedback,
        quality: legacy
            ? null
            : const WorkoutQuality(
                flaggedReps: 2,
                avgRepSeconds: 1.9,
                avgAmplitude: 51,
                amplitudeDropPercent: 14,
                leftRightDiffPercent: 8,
                qualityScore: 71,
                rangeOfMotion: 67,
                cadenceConsistency: 73,
                leftRightBalance: 79,
                poseAlignment: 61,
                hasEnoughData: true));

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

  test('AI is explicit, duplicate requests coalesce and locale is forwarded',
      () async {
    final response = Completer<String>();
    var requests = 0, saves = 0;
    AppLanguage? sentLanguage;
    final r = record();
    final c = ResultController(r, configured: true, analyze: (sent, lang) {
      requests++;
      expect(sent.toJson(), r.toJson());
      sentLanguage = lang;
      return response.future;
    }, saveFeedback: (id, text) async {
      expect(id, r.id);
      expect(text, 'Actual response');
      saves++;
    });
    addTearDown(c.dispose);
    expect(c.phase, ResultFeedbackPhase.idle);
    expect(requests, 0);
    final pending = c.request(AppLanguage.en);
    await c.request(AppLanguage.en);
    expect(requests, 1);
    expect(c.phase, ResultFeedbackPhase.loading);
    response.complete('Actual response');
    await pending;
    expect(sentLanguage, AppLanguage.en);
    expect(saves, 1);
    expect(c.phase, ResultFeedbackPhase.ready);
    expect(c.record.toAiPayload(), r.toAiPayload());
  });

  for (final failure in AiFeedbackFailure.values) {
    test('AI $failure retains workout and allows appropriate retry', () async {
      var requests = 0;
      final c =
          ResultController(record(), configured: true, analyze: (_, __) async {
        if (++requests == 1) throw AiFeedbackException(failure);
        return 'Recovered';
      }, saveFeedback: (_, __) async {});
      addTearDown(c.dispose);
      await c.request(AppLanguage.vi);
      expect(c.failure, failure);
      expect(
          c.phase,
          switch (failure) {
            AiFeedbackFailure.offline => ResultFeedbackPhase.offline,
            AiFeedbackFailure.notConfigured => ResultFeedbackPhase.unavailable,
            _ => ResultFeedbackPhase.error,
          });
      expect(c.record.reps, 14);
      if (failure != AiFeedbackFailure.notConfigured) {
        await c.request(AppLanguage.vi);
        expect(c.record.aiFeedback, 'Recovered');
        expect(c.phase, ResultFeedbackPhase.ready);
      }
    });
  }

  test('cached AI survives a failed refresh; unconfigured never requests',
      () async {
    var requests = 0;
    final c = ResultController(record(feedback: 'Saved text'), configured: true,
        analyze: (_, __) async {
      requests++;
      throw const AiFeedbackException(AiFeedbackFailure.offline);
    });
    addTearDown(c.dispose);
    expect(c.phase, ResultFeedbackPhase.ready);
    expect(requests, 0);
    await c.request(AppLanguage.vi);
    expect(c.record.aiFeedback, 'Saved text');
    final disabled =
        ResultController(record(), configured: false, analyze: (_, __) async {
      requests++;
      return 'unexpected';
    });
    addTearDown(disabled.dispose);
    await disabled.request(AppLanguage.vi);
    expect(disabled.phase, ResultFeedbackPhase.unavailable);
    expect(requests, 1);
  });

  test(
      'write failure keeps response and retry saves without another AI request',
      () async {
    var requests = 0, writes = 0;
    final c =
        ResultController(record(), configured: true, analyze: (_, __) async {
      requests++;
      return 'Received';
    }, saveFeedback: (_, __) async {
      if (++writes == 1) throw StateError('disk error');
    });
    addTearDown(c.dispose);
    await c.request(AppLanguage.vi);
    expect(c.phase, ResultFeedbackPhase.ready);
    expect(c.saveFailed, isTrue);
    expect(c.record.aiFeedback, 'Received');
    await c.request(AppLanguage.vi); // Must offer disk retry first.
    await c.retrySave();
    expect(c.saveFailed, isFalse);
    expect(writes, 2);
    expect(requests, 1);
  });

  test('late AI response after disposal never writes or notifies', () async {
    final response = Completer<String>();
    var writes = 0, notifications = 0;
    final c = ResultController(record(),
        configured: true,
        analyze: (_, __) => response.future,
        saveFeedback: (_, __) async {
          writes++;
        });
    c.addListener(() => notifications++);
    final pending = c.request(AppLanguage.vi);
    c.dispose();
    response.complete('Late');
    await pending;
    expect(writes, 0);
    expect(notifications, 1);
  });

  test(
      'feedback storage updates only text and never resurrects a deleted workout',
      () async {
    final store = WorkoutHistoryStore();
    final r = fixture();
    await store.save(r);
    await store.saveFeedback(r.id, 'Saved feedback');
    final saved = (await store.load()).single;
    expect(saved.toJson(), r.copyWith(aiFeedback: 'Saved feedback').toJson());
    await store.delete(r.id);
    await expectLater(
        store.saveFeedback(r.id, 'Late feedback'), throwsStateError);
    expect(await store.load(), isEmpty);
  });

  final capture = GlobalKey();
  Future<void> pump(WidgetTester tester, Widget child,
      {AppLanguage language = AppLanguage.vi,
      double scale = 1,
      double width = 393,
      bool reducedMotion = false}) async {
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
                data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    disableAnimations: reducedMotion),
                child: RepaintBoundary(key: capture, child: child!)),
            home: child)));
    await tester.pump();
  }

  Future<void> screenshot(WidgetTester tester, String name) async {
    const dir = String.fromEnvironment('PHASE7_SCREENSHOTS');
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
      for (final entry in {
        'partial': record(),
        'met': record(reps: 20),
        'over': fixture(),
        'free': record(goal: null),
        'empty': record(reps: 0, legacy: true)
      }.entries) {
        testWidgets('${entry.key} result ${lang.code} ${scale}x uses real data',
            (tester) async {
          final r = entry.value;
          await pump(tester, ResultPage(record: r),
              language: lang, scale: scale, width: scale == 2 ? 320 : 393);
          await tester.pumpAndSettle();
          final ring = tester.widget<CircularProgressIndicator>(
              find.byKey(const Key('result-goal-ring')));
          expect(ring.value,
              r.targetReps == null ? 1 : (r.reps / r.targetReps!).clamp(0, 1));
          expect(find.text('${r.reps}'), findsOneWidget);
          if (entry.key == 'over') {
            final extra = tester.widget<CircularProgressIndicator>(
                find.byKey(const Key('result-extra-ring')));
            expect(extra.value, .15);
          } else {
            expect(find.byKey(const Key('result-extra-ring')), findsNothing);
          }
          if (entry.key == 'partial') {
            expect(find.text('14/20 · 70%'), findsOneWidget);
            expect(ring.color, AppColors.accent);
          }
          final footer = tester.getRect(find.byKey(const Key('result-done')));
          expect(footer.bottom, lessThanOrEqualTo(852));
          if (scale == 1 && lang == AppLanguage.vi) {
            await screenshot(tester, 'result-${entry.key}');
          }
          await tester.drag(find.byType(ListView), const Offset(0, -1500));
          await tester.pumpAndSettle();
          expect(tester.getRect(find.byKey(const Key('result-done'))), footer);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('form breakdown uses stored scores instead of design examples',
      (tester) async {
    await pump(tester, ResultPage(record: record()));
    await tester.scrollUntilVisible(find.text('67'), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    for (final value in ['67', '73', '79', '61']) {
      expect(find.text(value), findsOneWidget);
    }
    expect(find.text('88'), findsNothing);
    await screenshot(tester, 'result-form');
  });

  for (final phase in ResultFeedbackPhase.values) {
    testWidgets(
        'feedback card $phase renders truthful source and fallback at 2x',
        (tester) async {
      final response = Completer<String>();
      final c = ResultController(
          record(
              feedback: phase == ResultFeedbackPhase.ready
                  ? 'Saved AI response'
                  : null),
          configured: phase != ResultFeedbackPhase.unavailable,
          analyze: (_, __) => response.future,
          saveFeedback: (_, __) async {});
      addTearDown(c.dispose);
      if (phase == ResultFeedbackPhase.loading) {
        unawaited(c.request(AppLanguage.vi));
      } else if (phase == ResultFeedbackPhase.offline ||
          phase == ResultFeedbackPhase.error) {
        final pending = c.request(AppLanguage.vi);
        response.completeError(AiFeedbackException(
            phase == ResultFeedbackPhase.offline
                ? AiFeedbackFailure.offline
                : AiFeedbackFailure.server));
        await pending;
      }
      await pump(
          tester,
          Scaffold(
              body: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ResultFeedbackCard(controller: c))),
          reducedMotion: true);
      await screenshot(tester, 'feedback-${phase.name}');
      await pump(
          tester,
          Scaffold(
              body: SingleChildScrollView(
                  child: ResultFeedbackCard(controller: c))),
          scale: 2,
          width: 320,
          reducedMotion: true);
      expect(find.byKey(const Key('feedback-source')), findsOneWidget);
      expect(
          find.text(phase == ResultFeedbackPhase.ready
              ? 'Nhận xét AI'
              : 'Nhận xét nhanh · trên máy'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
      if (phase == ResultFeedbackPhase.loading) {
        expect(
            tester
                .widget<LinearProgressIndicator>(
                    find.byKey(const Key('ai-loading')))
                .value,
            0);
      }
    });
  }

  testWidgets(
      'page retry saves received text, no automatic request or duplicate call',
      (tester) async {
    var requests = 0, writes = 0;
    final response = Completer<String>();
    await pump(
        tester,
        ResultPage(
            record: record(),
            aiConfigured: true,
            analyze: (_, __) {
              requests++;
              return response.future;
            },
            saveFeedback: (_, __) async {
              if (++writes == 1) throw StateError('disk');
            }));
    expect(requests, 0);
    await tester.ensureVisible(find.byKey(const Key('ask-result-ai')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ask-result-ai')));
    await tester.pump();
    expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('ask-result-ai')))
            .onPressed,
        isNull);
    response.complete('Received AI feedback');
    await tester.pumpAndSettle();
    expect(find.text('Received AI feedback'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('retry-feedback-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('retry-feedback-save')));
    await tester.pumpAndSettle();
    expect(requests, 1);
    expect(writes, 2);
    expect(find.byKey(const Key('retry-feedback-save')), findsNothing);
  });

  testWidgets('replacing record ignores old pending request', (tester) async {
    final response = Completer<String>();
    var writes = 0;
    final selected = ValueNotifier(record());
    addTearDown(selected.dispose);
    await pump(
        tester,
        ValueListenableBuilder<WorkoutRecord>(
            valueListenable: selected,
            builder: (_, value, __) => ResultPage(
                record: value,
                aiConfigured: true,
                analyze: (_, __) => response.future,
                saveFeedback: (_, __) async {
                  writes++;
                })));
    await tester.ensureVisible(find.byKey(const Key('ask-result-ai')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ask-result-ai')));
    await tester.pump();
    expect(find.byKey(const Key('ai-loading')), findsOneWidget);
    selected.value = record(id: 'new', reps: 18);
    await tester.pump();
    response.complete('Wrong record feedback');
    await tester.pumpAndSettle();
    expect(find.text('Wrong record feedback'), findsNothing);
    expect(writes, 0);
    expect(tester.takeException(), isNull);
  });

  for (final readOnly in [false, true]) {
    testWidgets('fixed Done returns ${readOnly ? 'to previous route' : 'home'}',
        (tester) async {
      final nav = GlobalKey<NavigatorState>();
      final locale = LocaleController();
      addTearDown(locale.dispose);
      await tester.pumpWidget(LocaleScope(
          controller: locale,
          child: MaterialApp(
              navigatorKey: nav,
              theme: RepCoachTheme.dark(),
              home: const Scaffold(body: Text('Home route')))));
      unawaited(nav.currentState!.push(MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Previous route')))));
      await tester.pumpAndSettle();
      unawaited(nav.currentState!.push(MaterialPageRoute<void>(
          builder: (_) => ResultPage(record: record(), readOnly: readOnly))));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('result-done')));
      await tester.pumpAndSettle();
      expect(find.text(readOnly ? 'Previous route' : 'Home route'),
          findsOneWidget);
    });
  }
}
