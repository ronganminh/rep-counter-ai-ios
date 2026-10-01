import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/features/workout/application/rep_feedback.dart';
import 'package:rep_counter_app/features/workout/domain/rep_metric.dart';
import 'package:rep_counter_app/features/workout/presentation/widgets/rep_feedback_pill.dart';
import 'package:rep_counter_app/theme/app_theme.dart';

Widget _host(
  RepFeedback feedback, {
  AppLanguage language = AppLanguage.vi,
  double textScale = 1,
  bool reducedMotion = false,
}) {
  final locale = LocaleController(language);
  return LocaleScope(
    controller: locale,
    child: MaterialApp(
      theme: RepCoachTheme.dark(),
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(393, 852),
          textScaler: TextScaler.linear(textScale),
          disableAnimations: reducedMotion,
        ),
        child: Scaffold(
          body: Center(
            child: RepFeedbackTransition(feedback: feedback),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders clean counted state in Vietnamese', (tester) async {
    await tester.pumpWidget(_host(const RepFeedback.countedClean(3)));
    await tester.pumpAndSettle();

    expect(find.text('ĐÃ TÍNH'), findsOneWidget);
    expect(find.text('Rep tốt'), findsOneWidget);
    expect(find.bySemanticsLabel('ĐÃ TÍNH. Rep tốt'), findsOneWidget);
  });

  testWidgets('warning remains explicitly counted in English', (tester) async {
    await tester.pumpWidget(_host(
      const RepFeedback.countedWarning(4, RepQualityFlag.shallow),
      language: AppLanguage.en,
    ));
    await tester.pumpAndSettle();

    expect(find.text('COUNTED'), findsOneWidget);
    expect(find.text('Try a deeper range'), findsOneWidget);
    expect(
      find.bySemanticsLabel('COUNTED. Try a deeper range'),
      findsOneWidget,
    );
  });

  testWidgets('renders interrupted and pose-lost variants', (tester) async {
    await tester.pumpWidget(
        _host(const RepFeedback.placementInterrupted()));
    await tester.pumpAndSettle();
    expect(find.text('CHUYỂN ĐỘNG BỊ GIÁN ĐOẠN'), findsOneWidget);
    expect(find.text('Quay lại vùng camera'), findsOneWidget);

    await tester.pumpWidget(_host(const RepFeedback.poseLost()));
    await tester.pumpAndSettle();
    expect(find.text('MẤT NHẬN DIỆN TƯ THẾ'), findsOneWidget);
    expect(
      find.text('Giữ phần thân trên trong khung hình'),
      findsOneWidget,
    );
  });

  testWidgets('supports 2x text without fixed-height overflow', (tester) async {
    await tester.pumpWidget(_host(
      const RepFeedback.placementInterrupted(),
      textScale: 2,
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(RepFeedbackPill)).height,
      greaterThanOrEqualTo(82),
    );
  });

  testWidgets('reduced motion uses fade without scale transition',
      (tester) async {
    await tester.pumpWidget(_host(
      const RepFeedback.countedClean(1),
      reducedMotion: true,
    ));
    await tester.pump();

    expect(find.byType(FadeTransition), findsWidgets);
    expect(find.byType(ScaleTransition), findsNothing);
  });
}
