import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/features/workout/presentation/widgets/camera_permission_view.dart';
import 'package:rep_counter_app/theme/app_theme.dart';

/// App Store Guideline 5.1.1(iv).
/// - Rejection of 1.0.0 (6): the screen before the prompt must not say "Allow"
///   and must not let the user close it or delay the prompt.
/// - Rejection of 1.0.0 (7): when access is off, only state it and offer a
///   plain link to Settings. No "denied" title or icon, no steps, no retry,
///   no prominent Settings call to action.
void main() {
  Future<void> pumpScreen(
      WidgetTester tester, AppLanguage language, Widget screen) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final locale = LocaleController(language);
    addTearDown(locale.dispose);
    await tester.pumpWidget(LocaleScope(
        controller: locale,
        child: MaterialApp(theme: RepCoachTheme.dark(), home: screen)));
    await tester.pumpAndSettle();
  }

  Iterable<String> visibleText(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '');

  for (final language in AppLanguage.values) {
    final s = language == AppLanguage.vi ? S.vi : S.en;

    testWidgets(
        'pre-permission screen: Continue only, no Allow, no exit '
        '(${language.name})', (tester) async {
      await pumpScreen(
          tester,
          language,
          CameraPermissionView(
              title: s.cameraPermissionTitle,
              body: s.cameraPermissionBody,
              loading: false,
              actionLabel: s.cameraContinue,
              onAction: () {},
              onExit: null));
      expect(s.cameraContinue,
          language == AppLanguage.vi ? 'Tiếp tục' : 'Continue');
      expect(
          find.widgetWithText(FilledButton, s.cameraContinue), findsOneWidget);
      for (final text in visibleText(tester)) {
        expect(text.toLowerCase(), isNot(contains('allow')));
        expect(text.toLowerCase(), isNot(contains('cho phép')));
      }
      expect(find.text('Not now'), findsNothing);
      expect(find.text('Để sau'), findsNothing);
      // The only control on the screen leads to the system prompt.
      expect(find.byType(TextButton), findsNothing);
      expect(find.byType(IconButton), findsNothing);
      expect(find.byType(BackButton), findsNothing);
      expect(find.byType(CloseButton), findsNothing);
    });

    testWidgets(
        'camera-off notice is neutral: Back and Settings link only '
        '(${language.name})', (tester) async {
      var back = 0, settings = 0;
      await pumpScreen(
          tester,
          language,
          CameraOffNotice(
              onBack: () => back++, onOpenSettings: () => settings++));
      expect(
          s.cameraOffMessage,
          language == AppLanguage.vi
              ? 'Quyền truy cập camera của RepCoach đang tắt. Tính năng đếm rep cần camera.'
              : 'Camera access is off for RepCoach. Rep counting needs the camera.');
      // One short message and the two actions; nothing else to read.
      expect(visibleText(tester).toList(),
          [s.cameraOffMessage, s.cameraBack, s.openSettings]);
      for (final text in visibleText(tester)) {
        final t = text.toLowerCase();
        for (final banned in [
          'denied',
          'từ chối',
          'retry',
          'thử lại',
          'granted',
          'đã cấp',
          'grant ',
          'please',
          'vui lòng',
          'reconsider',
          'enable camera',
          'bật camera',
          '1.',
          '2.',
          '3.',
        ]) {
          expect(t, isNot(contains(banned)), reason: '"$text" has "$banned"');
        }
      }
      // No icon: no crossed-out camera, no close button, no prominent CTA.
      expect(find.byType(Icon), findsNothing);
      expect(find.byType(IconButton), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(TextButton), findsNothing);
      // Back and Settings are the same kind of button, the same size.
      final backBtn = find.widgetWithText(OutlinedButton, s.cameraBack);
      final settingsBtn = find.widgetWithText(OutlinedButton, s.openSettings);
      expect(backBtn, findsOneWidget);
      expect(settingsBtn, findsOneWidget);
      expect(tester.getSize(backBtn), tester.getSize(settingsBtn));
      expect(tester.widget<OutlinedButton>(backBtn).style,
          tester.widget<OutlinedButton>(settingsBtn).style);
      await tester.tap(backBtn);
      await tester.tap(settingsBtn);
      expect(back, 1);
      expect(settings, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
