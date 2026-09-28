import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rep_counter_app/app/app_shell.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/theme/app_theme.dart';

// Optional rendered widget captures, not simulator screenshots.
// flutter test test/phase3_visual_test.dart \
//   --dart-define=PHASE3_SCREENSHOTS=/tmp/repcoach-phase3
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
  for (final scale in [1.0, 2.0]) {
    testWidgets('three product tabs render with bundled fonts at ${scale}x',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final locale = LocaleController();
      addTearDown(locale.dispose);
      final capture = GlobalKey();
      await tester.pumpWidget(LocaleScope(
        controller: locale,
        child: MaterialApp(
          theme: RepCoachTheme.dark(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: RepaintBoundary(key: capture, child: child!),
          ),
          home: const AppShell(),
        ),
      ));
      for (final tab in ['Tập', 'Lịch sử', 'Cài đặt']) {
        await tester.pumpAndSettle();
        await tester.tap(find.text(tab).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        const directory = String.fromEnvironment('PHASE3_SCREENSHOTS');
        if (directory.isNotEmpty && scale == 1) {
          final boundary = capture.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            final name = {
              'Tập': 'home',
              'Lịch sử': 'history',
              'Cài đặt': 'settings'
            }[tab];
            await Directory(directory).create(recursive: true);
            await File('$directory/$name.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      }
    });
  }
}
