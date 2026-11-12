// QA v2 screenshot generator (docs/qa/QA_REPORT_v2.md).
//
// Renders the journeys' screens on the host with the app's real fonts
// (Inter, Barlow Condensed, Lucide, Material icons) and writes PNGs to
// docs/qa/screenshots/. It is NOT part of the normal test run: fonts and
// rasterisation differ per machine, so it only runs when asked for and only
// ever (re)writes the images:
//
//   QA_SCREENSHOTS=1 flutter test test/qa_journeys/qa_screenshots_test.dart --update-goldens
//
// The native boundaries are the same fakes as the journeys (no camera, no
// network, scripted permission answers), so these are host renders of the
// real widgets, not device captures.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/app/app_shell.dart';
import 'package:rep_counter_app/app/app_tab_bar.dart';
import 'package:rep_counter_app/app/route_observer.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/features/auth/application/auth_controller.dart';
import 'package:rep_counter_app/features/auth/application/auth_scope.dart';
import 'package:rep_counter_app/features/auth/domain/auth_repository.dart';
import 'package:rep_counter_app/features/plan/application/plan_repository.dart';
import 'package:rep_counter_app/features/plan/domain/local_date.dart';
import 'package:rep_counter_app/features/plan/domain/plan_templates.dart';
import 'package:rep_counter_app/features/workout/data/workout_draft_store.dart';
import 'package:rep_counter_app/features/workout/data/workout_history_store.dart';
import 'package:rep_counter_app/features/workout/domain/workout_mode.dart';
import 'package:rep_counter_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/support/app_harness.dart';
import '../support/fake_auth_repository.dart';
import '../support/l10n.dart';

const _out = '../../../../docs/qa/screenshots';
final _enabled = Platform.environment['QA_SCREENSHOTS'] == '1';

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> assets) async {
    final loader = FontLoader(family);
    for (final a in assets) {
      loader.addFont(rootBundle.load(a));
    }
    await loader.load();
  }

  await load('Inter', ['assets/fonts/Inter.ttf']);
  await load('Barlow Condensed', [
    'assets/fonts/BarlowCondensed-SemiBold.ttf',
    'assets/fonts/BarlowCondensed-Bold.ttf',
    'assets/fonts/BarlowCondensed-ExtraBold.ttf',
  ]);
  await load('packages/lucide_icons_flutter/Lucide',
      ['packages/lucide_icons_flutter/assets/lucide.ttf']);
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.path;
  final material = File(
      '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (material.existsSync()) {
    final bytes = await material.readAsBytes();
    final loader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
  }
}

Future<void> _shot(WidgetTester tester, String name) async {
  await settle(tester);
  await expectLater(find.byType(MaterialApp).first,
      matchesGoldenFile('$_out/$name.png'));
}

void main() {
  final binding = ensureQaBinding();
  late PluginFakes fakes;
  Finder tab(String label) =>
      find.descendant(of: find.byType(AppTabBar), matching: find.text(label));

  setUpAll(() async {
    if (_enabled) await _loadFonts();
  });
  setUp(() {
    fakes = PluginFakes(binding.defaultBinaryMessenger)..install();
  });
  tearDown(() => fakes.uninstall());

  const prefsEn = {'onboarding_v1': true, 'app_language': 'en'};

  testWidgets('01-03 onboarding', (tester) async {
    await pumpApp(tester);
    await _shot(tester, '01-onboarding-1-en');
    await tapText(tester, 'Continue');
    await _shot(tester, '02-onboarding-2-placement-en');
    await tapText(tester, 'Continue');
    await _shot(tester, '03-onboarding-3-privacy-en');
    await closeApp(tester);
  }, skip: !_enabled);

  testWidgets('04-06 shell tabs and train sheet', (tester) async {
    await pumpApp(tester, prefs: prefsEn);
    await _shot(tester, '04-home-en');
    await tester.tap(tab('Exercises'));
    await _shot(tester, '05-exercises-en');
    await tapKey(tester, 'tab-train');
    await _shot(tester, '06-train-sheet-en');
    await closeApp(tester);
  }, skip: !_enabled);

  testWidgets('07-10 camera gate states', (tester) async {
    await pumpApp(tester, prefs: prefsEn);
    await tapKey(tester, 'tab-train');
    await tapKey(tester, 'mode-free');
    await tapKey(tester, 'start-free-workout');
    await _shot(tester, '07-camera-explanation-en');
    await closeApp(tester);

    await pumpApp(tester, prefs: {'onboarding_v1': true, 'app_language': 'vi'});
    await tapKey(tester, 'tab-train');
    await tapKey(tester, 'mode-free');
    await tapKey(tester, 'start-free-workout');
    await _shot(tester, '08-camera-explanation-vi');
    await closeApp(tester);

    fakes.cameraStatus = permissionPermanentlyDenied;
    await pumpApp(tester, prefs: prefsEn);
    await tapKey(tester, 'tab-train');
    await tapKey(tester, 'mode-free');
    await tapKey(tester, 'start-free-workout');
    await _shot(tester, '09-camera-off-notice-en');
    await closeApp(tester);

    fakes.cameraStatus = permissionGranted;
    await pumpApp(tester, prefs: prefsEn);
    await tapKey(tester, 'tab-train');
    await tapKey(tester, 'mode-free');
    await tapKey(tester, 'start-free-workout');
    await _shot(tester, '10-camera-unavailable-track-manually-en');
    await tapKey(tester, 'camera-track-manually');
    await tapKey(tester, 'manual-plus');
    await tapKey(tester, 'manual-plus');
    await _shot(tester, '11-manual-log-en');
    await tapKey(tester, 'manual-save');
    await closeApp(tester);
  }, skip: !_enabled);

  testWidgets('12-14 recovery and history', (tester) async {
    SharedPreferences.setMockInitialValues(Map.of(prefsEn));
    final start = DateTime.now().subtract(const Duration(minutes: 40));
    await WorkoutDraftStore().save(WorkoutDraft(
        startedAt: start,
        updatedAt: start.add(const Duration(minutes: 3)),
        exerciseId: 'push_up',
        exerciseName: 'Hít đất',
        reps: 9,
        sets: 1,
        durationSeconds: 180,
        mode: WorkoutMode.free));
    await pumpAppKeepingPrefs(tester);
    await _shot(tester, '12-recovery-en');
    await tapKey(tester, 'recovery-save-partial');
    await tester.tap(tab('Progress'));
    await _shot(tester, '13-progress-en');
    await tapKey(tester, 'open-history-list');
    await _shot(tester, '14-history-list-partial-en');
    await closeApp(tester);
  }, skip: !_enabled);

  testWidgets('15-19 profile, settings, legal, dialogs', (tester) async {
    SharedPreferences.setMockInitialValues(Map.of(prefsEn));
    final start = DateTime.now().subtract(const Duration(hours: 2));
    await WorkoutHistoryStore().save(WorkoutDraft(
            startedAt: start,
            updatedAt: start,
            exerciseId: 'push_up',
            exerciseName: 'Hít đất',
            reps: 12,
            sets: 1,
            durationSeconds: 90,
            mode: WorkoutMode.free)
        .toPartialRecord());
    await pumpAppKeepingPrefs(tester);
    await tester.tap(tab('Profile'));
    await _shot(tester, '15-profile-guest-en');
    await tapKey(tester, 'profile-settings');
    await _shot(tester, '16-settings-top-en');
    await tapText(tester, S.en.privacyPolicy);
    await _shot(tester, '17-privacy-page-en');
    await systemBack(tester);
    await tapText(tester, S.en.clearHistory);
    await _shot(tester, '18-delete-local-history-dialog-en');
    await systemBack(tester); // closes the dialog
    final toggle = find.byKey(const Key('auto-ai-setting'));
    await reveal(tester, toggle);
    await tester.tap(toggle);
    await _shot(tester, '19-automatic-ai-consent-en');
    await tapText(tester, 'Not now');
    await closeApp(tester);
  }, skip: !_enabled);

  testWidgets('20 plan setup', (tester) async {
    await pumpApp(tester, prefs: prefsEn);
    await tapKey(tester, 'plan-home-card');
    await _shot(tester, '20-plan-setup-goal-en');
    await closeApp(tester);
  }, skip: !_enabled);

  // Separate test: seeding the plan store right after closing a first app
  // instance in the same test deadlocks the in-memory SQLite (FFI) store.
  testWidgets('21-23 plan overview and reminders', (tester) async {
    SharedPreferences.setMockInitialValues(Map.of(prefsEn));
    final now = DateTime.now();
    await tester.runAsync(() => PlanRepository(now: () => now).activate(
        PlanTemplates.beginnerPlan(
            id: 'qa-plan',
            startDate: LocalDate.of(now).startOfWeek,
            timezone: now.timeZoneName,
            now: now)));
    await pumpAppKeepingPrefs(tester);
    await tapKey(tester, 'plan-home-card');
    await _shot(tester, '21-plan-overview-en');
    await tapKey(tester, 'plan-menu');
    await tapText(tester, 'Workout reminders');
    await _shot(tester, '22-reminder-explanation-en');
    await tapKey(tester, 'reminder-enable');
    await tapKey(tester, 'plan-menu');
    await tapText(tester, 'Workout reminders');
    await _shot(tester, '23-reminder-off-notice-en');
    await closeApp(tester);
  }, skip: !_enabled);

  testWidgets('24-26 accounts UI with the in-memory backend', (tester) async {
    Future<void> pumpShell(AuthSession? saved, AppLanguage language) async {
      SharedPreferences.setMockInitialValues({'onboarding_v1': true});
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final auth = AuthController(FakeAuthRepository(saved: saved));
      addTearDown(auth.dispose);
      await tester.runAsync(auth.restore);
      final locale = LocaleController(language);
      addTearDown(locale.dispose);
      await tester.pumpWidget(LocaleScope(
        controller: locale,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: RepCoachTheme.dark(),
          locale: language.locale,
          supportedLocales: testSupportedLocales,
          localizationsDelegates: testLocalizationsDelegates,
          navigatorObservers: [appRouteObserver],
          home: AuthScope(controller: auth, child: const AppShell()),
        ),
      ));
      await settle(tester);
    }

    await pumpShell(null, AppLanguage.en);
    await tester.tap(tab('Profile'));
    await tapKey(tester, 'profile-sign-in');
    await tapKey(tester, 'auth-sign-in');
    await _shot(tester, '24-sign-in-en');
    await closeApp(tester);

    const user = AuthUser(
        id: 'u-1',
        email: 'qa@example.com',
        emailVerified: true,
        provider: AuthProvider.email);
    await pumpShell(const AuthSession(user), AppLanguage.en);
    await tester.tap(tab('Profile'));
    await _shot(tester, '25-profile-signed-in-en');
    await tapKey(tester, 'profile-delete-account');
    await _shot(tester, '26-delete-account-en');
    await closeApp(tester);
  }, skip: !_enabled);

  testWidgets('27-28 large text 2.0 (VI)', (tester) async {
    await pumpApp(tester,
        prefs: {'onboarding_v1': true, 'app_language': 'vi'}, textScale: 2);
    await tester.tap(tab('Hồ sơ'));
    await _shot(tester, '27-profile-vi-text-2x');
    await tapKey(tester, 'profile-settings');
    await _shot(tester, '28-settings-vi-text-2x');
    await closeApp(tester);
  }, skip: !_enabled);
}
