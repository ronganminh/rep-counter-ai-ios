import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rep_counter_app/app/app_shell.dart';
import 'package:rep_counter_app/app/route_observer.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/features/workout/data/workout_history_store.dart';
import 'package:rep_counter_app/features/workout/data/workout_record.dart';
import 'package:rep_counter_app/features/workout/domain/rep_metric.dart';
import 'package:rep_counter_app/features/workout/domain/rep_quality_analyzer.dart';
import 'package:rep_counter_app/features/workout/domain/workout_aggregator.dart';
import 'package:rep_counter_app/features/workout/domain/workout_summary.dart';
import 'package:rep_counter_app/features/workout/presentation/result_page.dart';
import 'package:rep_counter_app/features/workout/presentation/widgets/rep_pace_chart.dart';
import 'package:rep_counter_app/theme/app_theme.dart';
import 'features/workout/workout_controller_test.dart' show calibration;
import 'new_ui_test.dart' show fixture;

WorkoutRecord detail({bool legacyFlags = false, String id = 'phase8'}) {
  final json = fixture().toJson();
  json['id'] = id;
  json['reps'] = 6;
  json['sets'] = 2;
  json['rep_details'] = [
    for (var i = 0; i < 6; i++)
      {
        'seconds': [.55, 1.2, 1.6, 2.2, 1.1, 1.4][i],
        'set': i < 3 ? 1 : 2,
        'flagged': i == 0 || i == 3,
        if (!legacyFlags)
          'flags': i == 0
              ? ['tooFast']
              : i == 3
                  ? ['shallow']
                  : <String>[],
      }
  ];
  return WorkoutRecord.fromJson(json);
}

class FailingDeleteStore extends WorkoutHistoryStore {
  @override
  Future<DeletedWorkout?> delete(String id) async =>
      throw StateError('disk failed');
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

  test(
      'summary persists actual timing, grouped sets and engine flags only locally',
      () {
    final observations = [
      for (var i = 0; i < 4; i++)
        RepObservation(
            startedAt: Duration(
                milliseconds:
                    [1000, 3000, 10000, 12000][i] - [500, 1200, 1100, 1400][i]),
            bottomAt: Duration(milliseconds: [750, 2400, 9450, 11300][i]),
            completedAt: Duration(milliseconds: [1000, 3000, 10000, 12000][i]),
            bottomAngle: 90,
            topAngle: 160),
    ];
    final summary = const WorkoutAggregator().build(
        id: 'measured',
        exerciseId: 'push_up',
        startedAt: DateTime(2026, 9, 27),
        endedAt: DateTime(2026, 9, 27, 0, 1),
        reps: [
          for (var i = 0; i < observations.length; i++)
            RepMetric(
                index: i + 1,
                setIndex: 1,
                observation: observations[i],
                flags: const RepQualityAnalyzer().analyze(observations[i]))
        ],
        poseStats: const PoseQualityStats(
            totalProcessedFrames: 100, countableFrames: 90),
        calibration: calibration);
    final r = WorkoutRecord.fromSummary(
        summary: summary,
        exerciseName: 'Hít đất',
        durationSeconds: 60,
        poseFrames: 100,
        readyFrames: 90,
        lostFrames: 0);
    final copy = WorkoutRecord.fromJson(jsonDecode(jsonEncode(r.toJson())));
    expect(copy.repDetails!.map((r) => r.seconds), [.5, 1.2, 1.1, 1.4]);
    expect(copy.repDetails!.map((r) => r.setIndex), [1, 1, 2, 2]);
    expect(copy.repDetails!.first.qualityFlags, ['tooFast']);
    expect(copy.repDetails![1].qualityFlags, isEmpty);
    expect(copy.toJson()['rep_details_version'], 2);
    final old = {...r.toJson()}
      ..remove('rep_details')
      ..remove('rep_details_version');
    expect(copy.toAiPayload(), WorkoutRecord.fromJson(old).toAiPayload());
    expect(copy.toAiPayload().containsKey('rep_details'), isFalse);
  });

  test('legacy aggregate and legacy timing retain unknown flag categories', () {
    final aggregate = WorkoutRecord.fromJson(fixture(legacy: true).toJson());
    expect(aggregate.repDetails, isNull);
    expect(aggregate.reps, 23);
    final legacy = detail(legacyFlags: true);
    expect(legacy.repDetails!.first.flagged, isTrue);
    expect(legacy.repDetails!.first.qualityFlags, isNull);
    expect(legacy.repDetails!.first.tooFast, isFalse);
  });

  for (final invalid in [
    'bad',
    [
      {'seconds': -1, 'set': 1}
    ],
    [
      {'seconds': double.nan, 'set': 1}
    ],
    [
      {'seconds': 1, 'set': 1.5}
    ],
    [
      {'seconds': 1, 'set': 0}
    ],
    [
      {'seconds': 1, 'set': 2},
      {'seconds': 2, 'set': 1}
    ],
  ]) {
    test('malformed optional detail preserves aggregate: $invalid', () {
      final raw = fixture().toJson()..['rep_details'] = invalid;
      final r = WorkoutRecord.fromJson(raw);
      expect(r.repDetails, isNull);
      expect(r.reps, 23);
      expect(r.quality!.qualityScore, 82);
    });
  }

  test('unknown detail version and damaged quality do not discard record', () {
    final raw = detail().toJson()
      ..['rep_details_version'] = 99
      ..['quality'] = 'bad';
    final r = WorkoutRecord.fromJson(raw);
    expect(r.repDetails, isNull);
    expect(r.quality, isNull);
    expect(r.reps, 6);
  });

  test('unknown flag names survive round trip; malformed flags stay unknown',
      () {
    final rep = StoredRep.fromJson({
      'seconds': 1.2,
      'set': 1,
      'flags': ['futureFlag']
    });
    expect(rep.flagged, isTrue);
    expect(rep.tooFast, isFalse);
    expect(rep.toJson()['flags'], ['futureFlag']);
    expect(
        StoredRep.fromJson({
          'seconds': 1.2,
          'set': 1,
          'flags': [42]
        }).qualityFlags,
        isNull);
  });

  test('concurrent store instances preserve all writes and requested order',
      () async {
    await Future.wait([
      for (var i = 0; i < 12; i++) WorkoutHistoryStore().save(detail(id: 'r$i'))
    ]);
    expect((await WorkoutHistoryStore().load()).length, 12);
    final store = WorkoutHistoryStore();
    await Future.wait(
        [store.saveFeedback('r1', 'Received'), store.delete('r1')]);
    expect((await store.load()).any((r) => r.id == 'r1'), isFalse);
    await store.clear();
    await expectLater(store.saveFeedback('r2', 'Late'), throwsStateError);
    expect(await store.load(), isEmpty);
    await store.save(detail(id: 'after-failure'));
    expect((await store.load()).single.id, 'after-failure');
  });

  test(
      'unreadable raw entries and future fields survive feedback, delete and undo',
      () async {
    final raw = detail().toJson()..['future_field'] = {'keep': true};
    SharedPreferences.setMockInitialValues({
      'workout_history_v1': ['broken-json', jsonEncode(raw)]
    });
    final store = WorkoutHistoryStore();
    expect((await store.load()).single.id, 'phase8');
    await store.save(detail(id: 'another'));
    await store.saveFeedback('phase8', 'Saved');
    final deleted = (await store.delete('phase8'))!;
    expect(deleted.record.aiFeedback, 'Saved');
    await store.restore(deleted);
    await store.saveFeedback('phase8', 'Newer');
    await store.restore(deleted); // Does not overwrite a newer record.
    final prefs = await SharedPreferences.getInstance();
    final values = prefs.getStringList('workout_history_v1')!;
    expect(values, contains('broken-json'));
    final restored = values
        .where((s) => s != 'broken-json')
        .map((s) => jsonDecode(s) as Map)
        .singleWhere((r) => r['id'] == 'phase8');
    expect(restored['future_field'], {'keep': true});
    expect(restored['ai_feedback'], 'Newer');
    expect(restored['rep_details'], raw['rep_details']);
  });

  test('100 newest sessions retained when an older record is saved', () async {
    final raws = [
      for (var i = 0; i < 100; i++)
        jsonEncode({
          ...detail(id: '$i').toJson(),
          'started_at':
              DateTime(2026, 1, 1).add(Duration(days: i)).toIso8601String()
        })
    ];
    SharedPreferences.setMockInitialValues({'workout_history_v1': raws});
    final older = WorkoutRecord.fromJson(
        {...detail(id: 'old').toJson(), 'started_at': '2020-01-01T00:00:00Z'});
    await WorkoutHistoryStore().save(older);
    final loaded = await WorkoutHistoryStore().load();
    expect(loaded.length, 100);
    expect(loaded.first.id, '99');
    expect(loaded.any((r) => r.id == 'old'), isFalse);
  });

  final capture = GlobalKey();
  Future<void> pump(WidgetTester tester, Widget page,
      {double scale = 1, AppLanguage language = AppLanguage.vi}) async {
    tester.view.physicalSize = Size(scale == 1 ? 393 : 320, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final locale = LocaleController(language);
    addTearDown(locale.dispose);
    await tester.pumpWidget(LocaleScope(
        controller: locale,
        child: MaterialApp(
            navigatorObservers: [appRouteObserver],
            theme: RepCoachTheme.dark(),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: RepaintBoundary(key: capture, child: child!)),
            home: page)));
    await tester.pumpAndSettle();
  }

  Future<void> screenshot(WidgetTester tester, String name) async {
    const directory = String.fromEnvironment('PHASE8_SCREENSHOTS');
    if (directory.isEmpty) return;
    final boundary =
        capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(directory).create(recursive: true);
      await File('$directory/$name.png')
          .writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final language in AppLanguage.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
          'grouped pace, selection and stored flags ${language.code} ${scale}x',
          (tester) async {
        await pump(
            tester,
            Scaffold(
                body: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: RepPaceChart(record: detail()))),
            scale: scale,
            language: language);
        expect(find.text('Set 1 · 3 rep'), findsOneWidget);
        expect(find.text('Set 2 · 3 rep'), findsOneWidget);
        expect(find.byKey(const Key('pace-fast-summary')), findsOneWidget);
        expect(find.textContaining('1.34'),
            findsOneWidget); // actual measured average
        await tester.tap(find.byKey(const ValueKey('pace-rep-1')));
        await tester.pumpAndSettle();
        expect(find.text('Rep 1 · Set 1 · 0.55 s'), findsOneWidget);
        expect(
            find.text(
                language == AppLanguage.vi ? 'Nhịp quá nhanh' : 'Too fast'),
            findsOneWidget);
        expect(tester.takeException(), isNull);
        if (scale == 1 && language == AppLanguage.vi) {
          await screenshot(tester, 'pace-selected');
        }
        await tester.drag(
            find.byKey(const Key('pace-scroll')), const Offset(-350, 0));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('pace-rep-4')));
        await tester.pumpAndSettle();
        expect(find.text('Rep 4 · Set 2 · 2.20 s'), findsOneWidget);
        expect(
            find.text(language == AppLanguage.vi
                ? 'Biên độ ngắn'
                : 'Short range of motion'),
            findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('legacy pace does not label a generic flag as too fast',
      (tester) async {
    await pump(
        tester,
        Scaffold(
            body: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: RepPaceChart(record: detail(legacyFlags: true)))));
    expect(find.byKey(const Key('pace-flags-unavailable')), findsOneWidget);
    expect(find.byKey(const Key('pace-fast-summary')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('pace-rep-1')));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('bản ghi cũ chưa lưu loại lưu ý'), findsOneWidget);
    await screenshot(tester, 'pace-legacy');
  });

  testWidgets('partial detail is labeled and never changes aggregate totals',
      (tester) async {
    final r = WorkoutRecord.fromJson(detail().toJson()..['reps'] = 9);
    await pump(tester,
        Scaffold(body: SingleChildScrollView(child: RepPaceChart(record: r))));
    expect(find.textContaining('6/9 rep'), findsOneWidget);
    expect(r.reps, 9);
    expect(find.text('1 rep quá nhanh trong dữ liệu nhịp đã lưu.'),
        findsOneWidget);
  });

  testWidgets('changing record resets selected rep and handles long sessions',
      (tester) async {
    final selectedRecord = ValueNotifier(detail());
    addTearDown(selectedRecord.dispose);
    await pump(
        tester,
        Scaffold(
            body: SingleChildScrollView(
                child: ValueListenableBuilder<WorkoutRecord>(
                    valueListenable: selectedRecord,
                    builder: (_, r, __) => RepPaceChart(record: r)))));
    await tester.tap(find.byKey(const ValueKey('pace-rep-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pace-selection')), findsOneWidget);
    selectedRecord.value = WorkoutRecord.fromJson({
      ...detail().toJson(),
      'reps': 200,
      'sets': 10,
      'rep_details': [
        for (var i = 0; i < 200; i++)
          {
            'seconds': 1.0 + i % 4,
            'set': i ~/ 20 + 1,
            'flags': <String>[],
            'flagged': false
          }
      ]
    });
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pace-selection')), findsNothing);
    expect(find.text('Set 10 · 20 rep'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('legacy detail retains aggregate and shows unavailable pace',
      (tester) async {
    await pump(
        tester, ResultPage(record: fixture(legacy: true), readOnly: true),
        scale: 2);
    expect(find.text('23'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.byKey(const Key('pace-unavailable')), 250,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Buổi tập này chưa có dữ liệu nhịp từng rep.'),
        findsOneWidget);
    expect(find.byKey(const Key('delete-workout-detail')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'saved AI detail never calls AI or offers unnecessary regeneration',
      (tester) async {
    var requests = 0;
    await pump(
        tester,
        ResultPage(
            record: detail().copyWith(aiFeedback: 'Nhận xét đã lưu'),
            readOnly: true,
            analyze: (_, __) async {
              requests++;
              return 'unexpected';
            }));
    expect(find.text('Nhận xét đã lưu'), findsOneWidget);
    expect(find.byKey(const Key('ask-result-ai')), findsNothing);
    expect(requests, 0);
    await screenshot(tester, 'history-detail');
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets(
        'history detail cancel, delete and undo preserve exact record through AppShell ${scale}x',
        (tester) async {
      // Keep this history-navigation fixture within the default 7-day filter.
      // A fixed 2026-09-27 record would disappear as the calendar advances.
      final recent = detail().toJson()
        ..['started_at'] = DateTime.now().toIso8601String();
      final r =
          WorkoutRecord.fromJson(recent).copyWith(aiFeedback: 'Saved feedback');
      final store = WorkoutHistoryStore();
      await store.save(r);
      await pump(tester, const AppShell(), scale: scale);
      expect(tester.takeException(), isNull, reason: 'Home at $scale text');
      await tester.tap(find.text('Lịch sử').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byType(ListTile), 250,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();
      expect(find.byType(ResultPage), findsOneWidget);
      expect(tester.takeException(), isNull,
          reason: 'History and detail at $scale text');
      await tester.tap(find.byKey(const Key('delete-workout-detail')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(S.vi.cancel));
      await tester.pumpAndSettle();
      expect((await store.load()).single.id, r.id);
      await tester.tap(find.byKey(const Key('delete-workout-detail')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-delete-workout')));
      await tester.pumpAndSettle();
      expect(find.byType(ResultPage), findsNothing);
      expect(await store.load(), isEmpty);
      expect(find.text('Hoàn tác'), findsOneWidget);
      if (scale == 1) {
        await screenshot(tester, 'history-deleted');
      }
      await tester.tap(find.text('Hoàn tác'));
      await tester.pumpAndSettle();
      expect((await store.load()).single.toJson(), r.toJson());
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('failed detail deletion keeps screen and metrics for retry',
      (tester) async {
    await pump(
        tester,
        ResultPage(
            record: detail(),
            readOnly: true,
            historyStore: FailingDeleteStore()));
    await tester.tap(find.byKey(const Key('delete-workout-detail')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete-workout')));
    await tester.pumpAndSettle();
    expect(find.byType(ResultPage), findsOneWidget);
    expect(find.text('Không thể xóa. Hãy thử lại.'), findsOneWidget);
    expect(
        tester
            .widget<IconButton>(find.byKey(const Key('delete-workout-detail')))
            .onPressed,
        isNotNull);
    expect(find.text('6'), findsOneWidget);
  });
}
