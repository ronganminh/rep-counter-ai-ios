// QA v2 · J-03 "kill the app mid-workout": the recovery draft is offered on
// the next launch (W-5 / F-4, L-D17). Save partial lands in History as a
// partial record; Discard leaves nothing; nothing is ever saved twice.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/app/app_shell.dart';
import 'package:rep_counter_app/app/app_tab_bar.dart';
import 'package:rep_counter_app/features/workout/data/workout_draft_store.dart';
import 'package:rep_counter_app/features/workout/data/workout_history_store.dart';
import 'package:rep_counter_app/features/workout/domain/workout_mode.dart';
import 'package:rep_counter_app/features/workout/presentation/recovery_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_harness.dart';

void main() {
  final binding = ensureQaBinding();
  late PluginFakes fakes;

  setUp(() {
    fakes = PluginFakes(binding.defaultBinaryMessenger)..install();
  });
  tearDown(() => fakes.uninstall());

  WorkoutDraft draft({Duration age = const Duration(minutes: 30)}) {
    final start = DateTime.now().subtract(age);
    return WorkoutDraft(
      startedAt: start,
      updatedAt: start.add(const Duration(minutes: 2)),
      exerciseId: 'push_up',
      exerciseName: 'Hít đất',
      reps: 7,
      sets: 1,
      durationSeconds: 120,
      mode: WorkoutMode.free,
    );
  }

  /// A workout was in progress when the app was killed: the draft is in
  /// the preferences store when the app launches again.
  Future<void> launchWithDraft(WidgetTester tester, WorkoutDraft d) async {
    SharedPreferences.setMockInitialValues(
        {'onboarding_v1': true, 'app_language': 'en'});
    await WorkoutDraftStore().save(d);
    await pumpAppKeepingPrefs(tester);
  }

  testWidgets('pending draft: recovery offered once; Save partial → History',
      (tester) async {
    await launchWithDraft(tester, draft());
    expect(find.byType(RecoveryPage), findsOneWidget);
    expect(find.byKey(const Key('recovery-resume')), findsOneWidget,
        reason: 'free workout inside 12 h can be resumed (L-D17 B)');
    expect(find.byType(AppTabBar), findsNothing,
        reason: 'D-02: no tab bar over the recovery flow');

    await tapKey(tester, 'recovery-save-partial');
    expect(find.byType(RecoveryPage), findsNothing);
    expect(find.byType(AppShell), findsOneWidget);
    final saved = await WorkoutHistoryStore().load();
    expect(saved, hasLength(1));
    expect(saved.single.reps, 7);
    expect(saved.single.partial, isTrue);
    expect(await WorkoutDraftStore().load(), isNull, reason: 'draft cleared');

    await tester.tap(find.descendant(
        of: find.byType(AppTabBar), matching: find.text('Progress')));
    await settle(tester);
    await tapKey(tester, 'open-history-list');
    expect(find.byKey(const Key('history-partial')), findsOneWidget);
    await closeApp(tester);

    // Relaunch: the draft is gone, nothing is offered or saved twice.
    await pumpAppKeepingPrefs(tester);
    expect(find.byType(RecoveryPage), findsNothing);
    expect(await WorkoutHistoryStore().load(), hasLength(1));
    await closeApp(tester);
  });

  testWidgets('Discard keeps History empty and clears the draft',
      (tester) async {
    await launchWithDraft(tester, draft());
    expect(find.byType(RecoveryPage), findsOneWidget);
    await tapKey(tester, 'recovery-discard');
    // Destructive: a confirmation dialog follows (shared with the HUD).
    await tapKey(tester, 'discard-confirm');
    expect(find.byType(RecoveryPage), findsNothing);
    expect(await WorkoutHistoryStore().load(), isEmpty);
    expect(await WorkoutDraftStore().load(), isNull);
    await closeApp(tester);
  });

  testWidgets('expired draft (> 12 h) is still offered, without Resume',
      (tester) async {
    await launchWithDraft(tester, draft(age: const Duration(hours: 13)));
    expect(find.byType(RecoveryPage), findsOneWidget);
    expect(find.byKey(const Key('recovery-resume')), findsNothing);
    expect(find.byKey(const Key('recovery-save-partial')), findsOneWidget);
    expect(find.byKey(const Key('recovery-discard')), findsOneWidget);
    await closeApp(tester);
  });
}
