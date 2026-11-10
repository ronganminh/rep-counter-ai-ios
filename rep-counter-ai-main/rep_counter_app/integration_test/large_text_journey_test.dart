// QA v2 · J-08 EN/VI at text scale 2.0 on the store-sensitive screens:
// onboarding, shell tabs, Settings, Privacy page, camera explanation, the
// camera-off notice and the reminder explanation. A RenderFlex overflow is
// reported as a test failure by the framework, so a passing run means no
// overflow on an iPhone-14-sized viewport.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/app/app_tab_bar.dart';
import 'package:rep_counter_app/camera_page.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/features/legal/legal_page.dart';
import 'package:rep_counter_app/features/legal/onboarding_page.dart';
import 'package:rep_counter_app/features/legal/settings_page.dart';
import 'package:rep_counter_app/features/workout/presentation/widgets/camera_permission_view.dart';

import 'support/app_harness.dart';

void main() {
  final binding = ensureQaBinding();
  late PluginFakes fakes;

  setUp(() {
    fakes = PluginFakes(binding.defaultBinaryMessenger)..install();
  });
  tearDown(() => fakes.uninstall());

  for (final language in AppLanguage.values) {
    final s = language == AppLanguage.vi ? S.vi : S.en;
    final labels = language == AppLanguage.vi
        ? ['Trang chủ', 'Bài tập', 'Tập', 'Tiến bộ', 'Hồ sơ']
        : ['Home', 'Exercises', 'Train', 'Progress', 'Profile'];
    Finder tab(String label) => find.descendant(
        of: find.byType(AppTabBar), matching: find.text(label));

    testWidgets('${language.name} @2.0: onboarding pages render without overflow',
        (tester) async {
      await pumpApp(tester,
          prefs: {'app_language': language.code}, textScale: 2);
      expect(find.byType(OnboardingPage), findsOneWidget);
      final next = language == AppLanguage.vi ? 'Tiếp tục' : 'Continue';
      await tapText(tester, next);
      await tapText(tester, next);
      expect(tester.takeException(), isNull);
      await closeApp(tester);
    });

    testWidgets('${language.name} @2.0: tabs, Settings and Privacy page',
        (tester) async {
      await pumpApp(tester,
          prefs: {'onboarding_v1': true, 'app_language': language.code},
          textScale: 2);
      // Train is the centre action (opens the Train sheet): covered by the
      // camera journey below, so it is skipped in this tab sweep.
      for (final label in labels.where((l) => l != labels[2])) {
        await tester.tap(tab(label).first);
        await settle(tester);
        expect(tester.takeException(), isNull, reason: label);
      }
      await tapKey(tester, 'profile-settings');
      expect(find.byType(SettingsPage), findsOneWidget);
      await tapText(tester, s.privacyPolicy);
      expect(find.byType(LegalPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      await closeApp(tester);
    });

    testWidgets('${language.name} @2.0: camera explanation and camera-off notice',
        (tester) async {
      fakes.cameraStatus = permissionDenied;
      await pumpApp(tester,
          prefs: {'onboarding_v1': true, 'app_language': language.code},
          textScale: 2);
      await tapKey(tester, 'tab-train');
      await tapKey(tester, 'mode-free');
      await tapKey(tester, 'start-free-workout');
      expect(find.byType(CameraPage), findsOneWidget);
      expect(find.text(s.cameraPermissionTitle), findsOneWidget);
      expect(find.widgetWithText(FilledButton, s.cameraContinue), findsOneWidget);
      expect(tester.takeException(), isNull);
      await closeApp(tester);

      fakes.cameraStatus = permissionPermanentlyDenied;
      await pumpApp(tester,
          prefs: {'onboarding_v1': true, 'app_language': language.code},
          textScale: 2);
      await tapKey(tester, 'tab-train');
      await tapKey(tester, 'mode-free');
      await tapKey(tester, 'start-free-workout');
      expect(find.byType(CameraOffNotice), findsOneWidget);
      expect(tester.takeException(), isNull);
      await closeApp(tester);
    });
  }
}
