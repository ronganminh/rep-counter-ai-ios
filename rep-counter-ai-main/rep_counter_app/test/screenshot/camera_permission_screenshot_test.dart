// Renders the real CameraPermissionView (build 1.0.0 (7) code) to PNG goldens so
// the App Store 5.1.1(iv) fix can be verified visually: the pre-permission
// screen has a single "Continue"/"Tiếp tục" button, no "Allow", no "Not now",
// no close/back. Generate with: flutter test --update-goldens <this file>.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/features/workout/presentation/widgets/camera_permission_view.dart';
import 'package:rep_counter_app/theme/app_theme.dart';

Future<void> _loadFonts() async {
  const fonts = {
    'Inter': 'assets/fonts/Inter.ttf',
    'Barlow Condensed': 'assets/fonts/BarlowCondensed-ExtraBold.ttf',
  };
  for (final entry in fonts.entries) {
    final file = File(entry.value);
    if (!file.existsSync()) continue;
    final bytes = file.readAsBytesSync();
    final loader = FontLoader(entry.key)
      ..addFont(Future.value(ByteData.view(
          Uint8List.fromList(bytes).buffer)));
    await loader.load();
  }
}

void main() {
  Future<void> shot(
    WidgetTester tester,
    String name,
    AppLanguage language, {
    required bool denied,
    VoidCallback? onExit,
    VoidCallback? onRetry,
  }) async {
    await _loadFonts();
    tester.view.physicalSize = const Size(786, 1704);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final locale = LocaleController(language);
    addTearDown(locale.dispose);
    final s = language == AppLanguage.vi ? S.vi : S.en;
    await tester.pumpWidget(LocaleScope(
      controller: locale,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: RepCoachTheme.dark(),
        home: CameraPermissionView(
          title: denied ? s.cameraDenied : s.cameraPermissionTitle,
          body: denied ? s.cameraDeniedBody : s.cameraPermissionBody,
          denied: denied,
          loading: false,
          actionLabel: denied ? s.openSettings : s.cameraContinue,
          onAction: () {},
          onRetry: onRetry,
          onExit: onExit,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(CameraPermissionView),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  testWidgets('before prompt — EN', (t) async {
    await shot(t, 'permission_before_en', AppLanguage.en, denied: false);
  });
  testWidgets('before prompt — VI', (t) async {
    await shot(t, 'permission_before_vi', AppLanguage.vi, denied: false);
  });
  testWidgets('after denied — EN', (t) async {
    await shot(t, 'permission_denied_en', AppLanguage.en,
        denied: true, onExit: () {}, onRetry: () {});
  });
}
