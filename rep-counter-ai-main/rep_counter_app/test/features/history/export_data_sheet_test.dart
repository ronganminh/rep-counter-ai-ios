import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/features/history/export/export_data_sheet.dart';
import 'package:rep_counter_app/features/workout/data/workout_record.dart';
import 'package:rep_counter_app/theme/app_theme.dart';

WorkoutRecord record() => WorkoutRecord(
      id: 'one',
      exerciseId: 'push_up',
      exerciseName: 'Hít đất',
      startedAt: DateTime(2026, 10, 2),
      durationSeconds: 60,
      reps: 12,
      sets: 1,
      targetReps: null,
      poseFrames: 10,
      readyFrames: 9,
      lostFrames: 1,
    );

Future<void> pumpSheet(
  WidgetTester tester, {
  required Future<List<WorkoutRecord>> Function() loader,
  Future<void> Function(dynamic, Rect?)? share,
  double scale = 1,
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final locale = LocaleController();
  addTearDown(locale.dispose);
  await tester.pumpWidget(LocaleScope(
    controller: locale,
    child: MaterialApp(
      theme: RepCoachTheme.dark(),
      home: Scaffold(
        body: ExportDataSheet(
          loadRecords: loader,
          shareFile: share == null
              ? null
              : (file, origin) => share(file, origin),
        ),
      ),
      builder: (_, child) => MediaQuery(
        data: MediaQueryData(
          size: const Size(393, 852),
          textScaler: TextScaler.linear(scale),
        ),
        child: child!,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('export sheet defaults to CSV and saved AI feedback off',
      (tester) async {
    await pumpSheet(tester, loader: () async => [record()]);

    final checkbox =
        tester.widget<CheckboxListTile>(find.byKey(const Key('export-include-ai')));
    expect(checkbox.value, isFalse);
    expect(find.text('CSV'), findsOneWidget);
    expect(find.text('JSON'), findsOneWidget);
    expect(find.text('Tạo file xuất'), findsOneWidget);
    expect(
      find.textContaining('Không bao gồm hình ảnh camera'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty history shows Figma empty-state contract',
      (tester) async {
    await pumpSheet(tester, loader: () async => const []);
    await tester.tap(find.byKey(const Key('create-export')));
    await tester.pumpAndSettle();

    expect(find.text('Chưa có gì để xuất'), findsOneWidget);
    expect(find.text('Hãy hoàn thành một buổi tập trước.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('share failure shows retry and keeps UI usable at 2x text',
      (tester) async {
    await pumpSheet(
      tester,
      scale: 2,
      loader: () async => [record()],
      share: (_, __) async => throw StateError('failed'),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('create-export')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('create-export')));
    await tester.pumpAndSettle();

    expect(find.text('Không thể tạo file xuất'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('retry-export')),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('retry-export')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
