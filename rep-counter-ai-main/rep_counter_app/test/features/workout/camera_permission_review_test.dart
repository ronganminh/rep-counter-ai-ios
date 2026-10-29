import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/features/workout/presentation/widgets/camera_permission_view.dart';
import 'package:rep_counter_app/theme/app_theme.dart';

import '../../support/l10n.dart';

/// App Store Guideline 5.1.1(iv) (rejection of 1.0.0 (6)): the screen shown
/// before the camera permission prompt must not say "Allow" and must not let
/// the user close it or delay the prompt.
void main() {
  Future<void> pump(WidgetTester tester, AppLanguage language,
      {required bool denied, VoidCallback? onExit}) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final locale = LocaleController(language);
    addTearDown(locale.dispose);
    final s = language == AppLanguage.vi ? S.vi : S.en;
    await tester.pumpWidget(LocaleScope(
        controller: locale,
        child: MaterialApp(
            theme: RepCoachTheme.dark(),
            localizationsDelegates: testLocalizationsDelegates,
            supportedLocales: testSupportedLocales,
            locale: Locale(language.name),
            home: CameraPermissionView(
                title: denied ? s.cameraDenied : s.cameraPermissionTitle,
                body: denied ? s.cameraDeniedBody : s.cameraPermissionBody,
                denied: denied,
                loading: false,
                actionLabel: denied ? s.openSettings : s.cameraContinue,
                onAction: () {},
                onRetry: denied ? () {} : null,
                onManual: denied ? () {} : null,
                onExit: onExit))));
    await tester.pumpAndSettle();
  }

  Iterable<String> visibleText(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '');

  for (final language in AppLanguage.values) {
    testWidgets(
        'pre-permission screen: Continue only, no Allow, no exit '
        '(${language.name})', (tester) async {
      await pump(tester, language, denied: false);
      final s = language == AppLanguage.vi ? S.vi : S.en;
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
  }

  testWidgets('after the prompt was denied: Settings, retry, manual and close',
      (tester) async {
    var closed = 0;
    await pump(tester, AppLanguage.en, denied: true, onExit: () => closed++);
    expect(find.text(S.en.openSettings), findsOneWidget);
    expect(find.text(S.en.cameraGrantedRetry), findsOneWidget);
    expect(find.byKey(const Key('camera-track-manually')), findsOneWidget);
    await tester.ensureVisible(find.widgetWithText(TextButton, 'Close'));
    await tester.tap(find.widgetWithText(TextButton, 'Close'));
    expect(closed, 1);
    expect(find.text('Not now'), findsNothing);
  });
}
