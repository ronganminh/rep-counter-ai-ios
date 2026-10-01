import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/features/workout/application/result_controller.dart';
import 'package:rep_counter_app/features/workout/data/workout_record.dart';
import 'package:rep_counter_app/features/workout/presentation/result_page.dart';
import 'package:rep_counter_app/features/workout/presentation/widgets/form_score_details.dart';
import 'package:rep_counter_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../new_ui_test.dart' show fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  setUpAll(() async {
    for (final font in {
      'Inter': 'assets/fonts/Inter.ttf',
      'Barlow Condensed': 'assets/fonts/BarlowCondensed-ExtraBold.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });

  Future<void> pump(
    WidgetTester tester,
    Widget page, {
    AppLanguage language = AppLanguage.vi,
    double width = 393,
    double scale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final locale = LocaleController(language);
    addTearDown(locale.dispose);
    await tester.pumpWidget(
      LocaleScope(
        controller: locale,
        child: MaterialApp(
          theme: RepCoachTheme.dark(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
            ),
            child: child!,
          ),
          home: page,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('valid deterministic score opens truthful Figma detail sheet',
      (tester) async {
    await pump(
      tester,
      ResultPage(
        record: fixture(),
        aiConfigured: false,
      ),
    );

    final explain = find.byKey(const Key('form-score-explain'));
    await tester.scrollUntilVisible(
      explain,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    tester.widget<TextButton>(explain).onPressed!();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('form-score-details')), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('form-score-details-overall')))
          .data,
      '82 / 100',
    );
    expect(find.text('Biên độ chuyển động'), findsOneWidget);
    expect(find.text('Độ ổn định nhịp'), findsOneWidget);
    expect(find.text('Cân bằng trái/phải'), findsOneWidget);
    expect(find.text('Căn chỉnh tư thế'), findsOneWidget);
    expect(find.text('ĐIỀU ẢNH HƯỞNG ĐẾN BUỔI TẬP'), findsOneWidget);
    expect(
      find.text(
        'Nhận xét tư thế chỉ nhằm hỗ trợ tập luyện, không phải tư vấn y tế.',
      ),
      findsOneWidget,
    );
    expect(find.byType(LinearProgressIndicator), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('insufficient score saves reps and never renders zero as score',
      (tester) async {
    final raw = fixture().toJson();
    final quality = Map<String, dynamic>.from(raw['quality'] as Map);
    quality['has_enough_data'] = false;
    raw['quality'] = quality;
    final record = WorkoutRecord.fromJson(raw);

    await pump(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: FormScoreSection(record: record),
        ),
      ),
    );

    expect(find.byKey(const Key('form-score-insufficient')), findsOneWidget);
    expect(find.text('23 rep đã lưu'), findsOneWidget);
    expect(find.text('Điểm form chưa khả dụng'), findsOneWidget);
    expect(
      find.text('Chưa đủ dữ liệu chuyển động đáng tin cậy'),
      findsOneWidget,
    );
    expect(find.text('0 / 100'), findsNothing);
    expect(find.byKey(const Key('form-score-explain')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('legacy and partial records stay readable without fabricated data',
      (tester) async {
    final partialJson = fixture().toJson();
    final partialQuality =
        Map<String, dynamic>.from(partialJson['quality'] as Map);
    partialQuality
      ..remove('range_of_motion')
      ..['has_enough_data'] = true;
    partialJson['quality'] = partialQuality;
    final partial = WorkoutRecord.fromJson(partialJson);

    expect(partial.reps, 23);
    expect(partial.quality, isNotNull);
    expect(partial.quality!.hasEnoughData, isFalse);

    await pump(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: FormScoreSection(record: partial),
        ),
      ),
    );
    expect(find.text('23 rep đã lưu'), findsOneWidget);
    expect(find.text('0 / 100'), findsNothing);

    await pump(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: FormScoreSection(record: fixture(legacy: true)),
        ),
      ),
    );
    expect(find.text('23 rep đã lưu'), findsOneWidget);
    expect(find.text('0 / 100'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final language in AppLanguage.values) {
    testWidgets('Form Score details support ${language.code} and 2x text',
        (tester) async {
      await pump(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: FormScoreSection(record: fixture()),
          ),
        ),
        language: language,
        width: 320,
        scale: 2,
      );

      await tester.tap(find.byKey(const Key('form-score-explain')));
      await tester.pumpAndSettle();

      if (language == AppLanguage.vi) {
        expect(find.text('Biên độ chuyển động'), findsOneWidget);
        expect(
          find.text(
            'Nhận xét tư thế chỉ nhằm hỗ trợ tập luyện, không phải tư vấn y tế.',
          ),
          findsOneWidget,
        );
      } else {
        expect(find.text('Range of motion'), findsOneWidget);
        expect(
          find.text(
            'Form feedback is exercise guidance, not medical advice.',
          ),
          findsOneWidget,
        );
      }
      expect(find.byKey(const Key('form-score-details')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  test('AI feedback cannot alter deterministic Form Score', () async {
    final controller = ResultController(
      fixture(),
      configured: true,
      analyze: (_, __) async => 'AI says the score should be 0/100.',
      saveFeedback: (_, __) async {},
    );
    addTearDown(controller.dispose);

    await controller.request(AppLanguage.en);

    expect(controller.record.aiFeedback, contains('0/100'));
    expect(controller.record.quality!.qualityScore, 82);
    expect(controller.record.quality!.rangeOfMotion, 88);
    expect(controller.record.quality!.cadenceConsistency, 74);
    expect(controller.record.quality!.leftRightBalance, 90);
    expect(controller.record.quality!.poseAlignment, 76);
  });
}
