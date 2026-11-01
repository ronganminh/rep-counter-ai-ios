import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/exercise.dart';
import 'package:rep_counter_app/features/workout/data/workout_history_store.dart';
import 'package:rep_counter_app/features/workout/data/workout_record.dart';
import 'package:rep_counter_app/features/workout/domain/workout_mode.dart';
import 'package:rep_counter_app/features/workout/domain/workout_personal_records.dart';
import 'package:rep_counter_app/features/workout/presentation/history_page.dart';
import 'package:rep_counter_app/features/workout/presentation/manual_log_page.dart';
import 'package:rep_counter_app/features/workout/presentation/widgets/camera_permission_view.dart';
import 'package:rep_counter_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/l10n.dart';

/// W-4: manual entry saves a record marked manual that never counts toward
/// camera challenges.

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final locale = LocaleController(AppLanguage.vi);
  addTearDown(locale.dispose);
  await tester.pumpWidget(LocaleScope(
    controller: locale,
    child: MaterialApp(
      theme: RepCoachTheme.dark(),
      locale: AppLanguage.vi.locale,
      supportedLocales: testSupportedLocales,
      localizationsDelegates: testLocalizationsDelegates,
      home: child,
    ),
  ));
  await tester.pumpAndSettle();
}

WorkoutRecord _timed(
        {required String id, required int reps, bool manual = false}) =>
    WorkoutRecord(
        id: id,
        exerciseId: 'push_up',
        exerciseName: 'Hít đất',
        startedAt: DateTime(2026, 10, 23, 8),
        durationSeconds: 60,
        reps: reps,
        sets: 1,
        targetReps: null,
        poseFrames: 0,
        readyFrames: 0,
        lostFrames: 0,
        mode: WorkoutMode.timed,
        challengeSeconds: 60,
        manual: manual);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('source survives JSON; camera records stay unchanged', () {
    final manual = _timed(id: 'm', reps: 3, manual: true);
    final json = manual.toJson();
    expect(json['source'], 'manual');
    expect(WorkoutRecord.fromJson(json).manual, isTrue);
    expect(manual.copyWith(aiFeedback: 'x').manual, isTrue);
    final camera = _timed(id: 'c', reps: 3);
    expect(camera.toJson().containsKey('source'), isFalse);
    expect(WorkoutRecord.fromJson(camera.toJson()).manual, isFalse);
  });

  test('manual records never set a timed personal best', () {
    final best = WorkoutPersonalRecordStore.bestTimedRepsFrom([
      _timed(id: 'camera', reps: 20),
      _timed(id: 'manual', reps: 99, manual: true),
    ], exerciseId: 'push_up', challengeSeconds: 60);
    expect(best, 20);
  });

  testWidgets('Save is disabled until a rep is entered', (tester) async {
    await _pump(tester, const ManualLogPage(profile: pushUp));
    expect(find.text('Nhập thủ công'), findsOneWidget);
    expect(find.text('Số rep nhập thủ công không tính vào thử thách camera'),
        findsOneWidget);
    await tester.tap(find.byKey(const Key('manual-save')));
    await tester.pumpAndSettle();
    expect(await WorkoutHistoryStore().load(), isEmpty);
  });

  testWidgets('steppers and sets build one manual record', (tester) async {
    var t = DateTime(2026, 10, 23, 9);
    await _pump(tester, ManualLogPage(profile: pushUp, now: () => t));
    Future<void> tap(Finder f) async {
      await tester.tap(f);
      await tester.pump();
    }

    final plus = find.byKey(const Key('manual-plus'));
    for (var i = 0; i < 5; i++) {
      await tap(plus.first);
    }
    await tap(find.byKey(const Key('manual-minus')).first);
    await tap(find.byKey(const Key('manual-add-set')));
    for (var i = 0; i < 3; i++) {
      await tap(plus.at(1));
    }
    // An empty third set is ignored in the set count.
    await tap(find.byKey(const Key('manual-add-set')));
    expect(find.text('Lưu · 7 rep'), findsOneWidget);

    t = t.add(const Duration(minutes: 4));
    await tester.tap(find.byKey(const Key('manual-save')));
    await tester.pumpAndSettle();
    final saved = (await WorkoutHistoryStore().load()).single;
    expect(saved.manual, isTrue);
    expect(saved.reps, 7);
    expect(saved.sets, 2);
    expect(saved.mode, WorkoutMode.free);
    expect(saved.quality, isNull);
    expect(saved.durationSeconds, 240);
    expect(saved.id, startsWith('manual-'));
  });

  testWidgets('removing a set drops its reps', (tester) async {
    await _pump(tester, const ManualLogPage(profile: pushUp));
    // A single set cannot be removed.
    expect(
        tester
            .widget<IconButton>(find.byKey(const Key('manual-remove-set')))
            .onPressed,
        isNull);
    await tester.tap(find.byKey(const Key('manual-add-set')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('manual-plus')).at(1));
    await tester.pump();
    expect(find.text('Lưu · 1 rep'), findsOneWidget);
    await tester.tap(find.byKey(const Key('manual-remove-set')).at(1));
    await tester.pump();
    expect(find.text('Lưu · 0 rep'), findsOneWidget);
  });

  testWidgets('the camera gate offers manual tracking', (tester) async {
    var opened = 0;
    await _pump(
        tester,
        CameraPermissionView(
            title: 't',
            body: 'b',
            denied: true,
            loading: false,
            actionLabel: 'a',
            onAction: () {},
            onExit: () {},
            onManual: () => opened++));
    await tester.tap(find.text('Đếm thủ công'));
    expect(opened, 1);
  });

  testWidgets('history labels manual records', (tester) async {
    final r = _timed(id: 'manual-1', reps: 12, manual: true);
    // History opens on the last 7 days, so the record must be recent.
    await WorkoutHistoryStore().save(WorkoutRecord.fromJson({
      ...r.toJson(),
      'mode': 'free',
      'challenge_seconds': null,
      'started_at': DateTime.now()
          .subtract(const Duration(hours: 1))
          .toUtc()
          .toIso8601String(),
    }));
    await _pump(tester, const Scaffold(body: HistoryPage()));
    await tester.scrollUntilVisible(
        find.byKey(const Key('history-manual')), 250,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Thủ công'), findsOneWidget);
  });
}
