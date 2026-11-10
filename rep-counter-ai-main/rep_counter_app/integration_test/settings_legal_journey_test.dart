// QA v2 · J-05 Profile › Settings › legal pages, support values, delete
// local history (typed confirmation), About rows. Store relevance: App
// Store 5.1.1(i) (privacy policy reachable in-app), 1.5 (contact), Play
// User Data (privacy policy link in app).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/app/app_tab_bar.dart';
import 'package:rep_counter_app/core/config/app_config.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/features/legal/legal_page.dart';
import 'package:rep_counter_app/features/legal/settings_page.dart';
import 'package:rep_counter_app/features/workout/data/workout_draft_store.dart';
import 'package:rep_counter_app/features/workout/data/workout_history_store.dart';
import 'package:rep_counter_app/features/workout/domain/workout_mode.dart';

import 'support/app_harness.dart';

void main() {
  final binding = ensureQaBinding();
  late PluginFakes fakes;
  const s = S.en;

  setUp(() {
    fakes = PluginFakes(binding.defaultBinaryMessenger)..install();
  });
  tearDown(() => fakes.uninstall());

  Finder tab(String label) =>
      find.descendant(of: find.byType(AppTabBar), matching: find.text(label));

  Future<void> openSettings(WidgetTester tester) async {
    await pumpApp(tester, prefs: {'onboarding_v1': true, 'app_language': 'en'});
    await tester.tap(tab('Profile'));
    await settle(tester);
    await tapKey(tester, 'profile-settings');
    expect(find.byType(SettingsPage), findsOneWidget);
  }

  testWidgets('privacy and terms pages open from Settings and link the web copy',
      (tester) async {
    await openSettings(tester);
    await tapText(tester, s.privacyPolicy);
    expect(find.byType(LegalPage), findsOneWidget);
    await reveal(tester, find.byKey(const Key('legal-privacy-url')));
    expect(find.byKey(const Key('legal-privacy-url')), findsOneWidget);
    expect(find.text(AppConfig.privacyPolicyUrl), findsOneWidget);
    await reveal(tester, find.textContaining('GroqCloud'));
    expect(find.textContaining('GroqCloud'), findsWidgets,
        reason: 'AI provider is disclosed (5.1.2(i))');
    await systemBack(tester);

    await tapText(tester, s.termsOfUse);
    expect(find.byType(LegalPage), findsOneWidget);
    await reveal(tester, find.byKey(const Key('legal-terms-url')));
    expect(find.byKey(const Key('legal-terms-url')), findsOneWidget);
    expect(find.text(AppConfig.termsUrl), findsOneWidget);
    await reveal(tester, find.textContaining('medical'));
    expect(find.textContaining('medical'), findsWidgets,
        reason: 'not-a-medical-device wording (Play Health apps)');
    await systemBack(tester);
    await closeApp(tester);
  });

  testWidgets('About rows: help & support, feedback email, website, version',
      (tester) async {
    await openSettings(tester);
    await reveal(tester, find.byKey(const Key('settings-help-support')));
    expect(find.byKey(const Key('settings-help-support')), findsOneWidget);
    expect(find.text(AppConfig.supportUrl), findsOneWidget);
    expect(find.text(AppConfig.supportEmail), findsOneWidget);
    await reveal(tester, find.byKey(const Key('settings-website')));
    expect(find.byKey(const Key('settings-website')), findsOneWidget);
    expect(find.text(AppConfig.websiteUrl), findsOneWidget);
    for (final placeholder in [
      '[SUPPORT_EMAIL]',
      '[SUPPORT_URL]',
      '[TERMS_URL]',
      '[PRIVACY_URL]',
      '[APP_VERSION]'
    ]) {
      expect(visibleTexts(tester).any((t) => t.contains(placeholder)), isFalse,
          reason: placeholder);
    }
    expect(find.text('2.0.0 (8)'), findsOneWidget,
        reason: 'version from build metadata (package_info fake)');
    await closeApp(tester);
  });

  testWidgets('delete local history needs the typed word and clears records',
      (tester) async {
    await pumpApp(tester, prefs: {'onboarding_v1': true, 'app_language': 'en'});
    final start = DateTime.now().subtract(const Duration(hours: 1));
    await WorkoutHistoryStore().save(WorkoutDraft(
      startedAt: start,
      updatedAt: start,
      exerciseId: 'push_up',
      exerciseName: 'Hít đất',
      reps: 5,
      sets: 1,
      durationSeconds: 60,
      mode: WorkoutMode.free,
    ).toPartialRecord());
    expect(await WorkoutHistoryStore().load(), hasLength(1));

    await tester.tap(tab('Profile'));
    await settle(tester);
    await tapKey(tester, 'profile-settings');
    await tapText(tester, s.clearHistory);
    final confirm = find.byKey(const Key('delete-data'));
    expect(confirm, findsOneWidget);
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull,
        reason: 'disabled until the word is typed');
    await tester.enterText(find.byKey(const Key('delete-confirmation')), 'nope');
    await tester.pump();
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    await tester.enterText(
        find.byKey(const Key('delete-confirmation')), 'delete');
    await tester.pump();
    expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull,
        reason: 'case-insensitive (L-D09)');
    await tester.tap(confirm);
    await settle(tester);
    expect(await WorkoutHistoryStore().load(), isEmpty);
    await closeApp(tester);
  });

  testWidgets('automatic AI stays off until consent; Not now keeps it off',
      (tester) async {
    await openSettings(tester);
    final toggle = find.byKey(const Key('auto-ai-setting'));
    await reveal(tester, toggle);
    expect(tester.widget<Switch>(toggle).value, isFalse);
    expect(tester.widget<Switch>(toggle).onChanged, isNotNull);
    await tester.tap(toggle);
    await settle(tester);
    expect(find.byKey(const Key('accept-automatic-ai')), findsOneWidget,
        reason: 'consent dialog names the provider before enabling');
    expect(visibleTexts(tester).any((t) => t.contains('GroqCloud')), isTrue);
    await tapText(tester, 'Not now');
    expect(tester.widget<Switch>(toggle).value, isFalse);
    await closeApp(tester);
  });
}
