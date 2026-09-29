/// Nút "?" và màn hướng dẫn: đủ nội dung ở hai ngôn ngữ, mở được, không tràn.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/exercise.dart';
import 'package:rep_counter_app/features/workout/presentation/exercise_help_sheet.dart';
import 'package:rep_counter_app/guide_template.dart';
import 'package:rep_counter_app/rep_counter.dart';

Future<void> _openHelp(
    WidgetTester tester, ExerciseProfile p, AppLanguage lang) async {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(LocaleScope(
    controller: LocaleController(lang),
    child: MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(body: Center(child: ExerciseHelpButton(profile: p))),
    ),
  ));
  await tester.tap(find.byType(ExerciseHelpButton));
  await tester.pumpAndSettle();
}

void main() {
  for (final lang in AppLanguage.values) {
    final s = S.of(lang);
    for (final p in [pushUp, pullUp]) {
      testWidgets('${p.id} mở được hướng dẫn, không tràn (${lang.code})',
          (tester) async {
        await _openHelp(tester, p, lang);
        final h = s.exerciseHelp[p.id]!;
        // ListView chỉ dựng phần đang thấy: phải cuộn tới mới kiểm được.
        for (final text in [h.oneRep, h.notCounted.last]) {
          await tester.dragUntilVisible(
              find.text(text), find.byType(ListView), const Offset(0, -200));
          expect(find.text(text), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      });
    }

    test('kéo xà không còn câu "set 1–2 rep bị trừ" (${lang.code})', () {
      // Set ngắn của kéo xà được giữ (minRepsPerSet = 1); hướng dẫn mà còn
      // nhắc quy tắc của hít đất là nói sai với người tập.
      final all = s.exerciseHelp['pull_up']!.notCounted.join(' ');
      expect(all.contains('1–2'), isFalse);
    });
  }

  test('bài chưa có hướng dẫn thì không hiện nút', () {
    expect(S.vi.exerciseHelp.containsKey(dumbbellCurl.id), isFalse);
  });

  test('mỗi bài có hướng dẫn đều có khung xương mẫu', () {
    for (final id in S.vi.exerciseHelp.keys) {
      expect(skeletonTemplateFor(id), isNotNull, reason: id);
    }
  });

  test('mẫu kéo xà có xà nằm trên cổ tay, người ở giữa khung', () {
    const t = pullUpTemplate;
    final b = t.bounds;
    expect(t.extra, TemplateExtra.bar);
    expect(t.points['lWrist']!.dy, lessThan(t.points['lShoulder']!.dy));
    expect(b.center.dx, closeTo(0.5, 0.05));
  });

  group('số rep tối thiểu mỗi set', () {
    SessionTracker run(int minReps) {
      final t = SessionTracker(minReps: minReps);
      // Hai set, mỗi set 2 rep, nghỉ 10 s giữa hai set.
      for (final at in [0, 3000, 13000, 16000]) {
        // Giữa hai rep app còn chạy nhiều khung, khung nào cũng tick; tick ngay
        // trước onRep đóng vai khung cuối cùng trước rep đó.
        t.tick(Duration(milliseconds: at));
        t.onRep(Duration(milliseconds: at));
      }
      t.tick(const Duration(seconds: 30));
      return t;
    }

    test('hít đất giữ mọi rep đã xác nhận qua quãng nghỉ', () {
      expect(pushUp.minRepsPerSet, 1);
      final t = run(pushUp.minRepsPerSet);
      expect(t.totalReps, 4);
      expect(t.sets.length, 2);
    });

    test('kéo xà giữ mọi rep đã xác nhận qua quãng nghỉ', () {
      expect(pullUp.minRepsPerSet, 1);
      final t = run(pullUp.minRepsPerSet);
      expect(t.totalReps, 4);
      expect(t.sets.length, 2);
    });
  });
}
