import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/app/app_shell.dart';
import 'package:rep_counter_app/app/route_observer.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/features/home/presentation/home_screen.dart';
import 'package:rep_counter_app/features/workout/data/workout_draft_store.dart';
import 'package:rep_counter_app/features/workout/data/workout_history_store.dart';
import 'package:rep_counter_app/features/workout/domain/workout_mode.dart';
import 'package:rep_counter_app/features/workout/presentation/recovery_page.dart';
import 'package:rep_counter_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/l10n.dart';

/// W-5: an unfinished workout found at launch must be saved or discarded,
/// never dropped silently.

WorkoutDraft _draft({DateTime? updated}) => WorkoutDraft(
      startedAt: DateTime.now().subtract(const Duration(minutes: 30)),
      updatedAt:
          updated ?? DateTime.now().subtract(const Duration(minutes: 25)),
      exerciseId: 'push_up',
      exerciseName: 'Hít đất',
      reps: 14,
      sets: 2,
      durationSeconds: 168,
      mode: WorkoutMode.targetReps,
      targetReps: 20,
    );

Future<void> _pump(WidgetTester tester,
    {WorkoutDraft? draft, AppLanguage language = AppLanguage.vi}) async {
  SharedPreferences.setMockInitialValues({
    if (draft != null) WorkoutDraftStore.key: jsonEncode(draft.toJson()),
  });
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final locale = LocaleController(language);
  addTearDown(locale.dispose);
  await tester.pumpWidget(LocaleScope(
    controller: locale,
    child: MaterialApp(
      theme: RepCoachTheme.dark(),
      locale: language.locale,
      supportedLocales: testSupportedLocales,
      localizationsDelegates: testLocalizationsDelegates,
      navigatorObservers: [appRouteObserver],
      home: const AppShell(),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('no draft: the app opens straight to Home', (tester) async {
    await _pump(tester);
    expect(find.byType(RecoveryPage), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('a draft opens recovery with its rep count', (tester) async {
    await _pump(tester, draft: _draft());
    expect(find.byType(RecoveryPage), findsOneWidget);
    expect(find.text('Tiếp tục buổi tập?'), findsOneWidget);
    expect(
        find.text('RepCoach đóng khi bạn đang tập ở 14 rep. '
            'Mọi thứ đến lúc đó đã được giữ trên máy.'),
        findsOneWidget);
    // Resume is not offered (needs an engine change, L-D17).
    expect(find.text(S.vi.finishContinue), findsNothing);
  });

  testWidgets('save as partial writes one record and returns to the app',
      (tester) async {
    await _pump(tester, draft: _draft());
    await tester.tap(find.byKey(const Key('recovery-save-partial')));
    await tester.pumpAndSettle();
    expect(find.byType(RecoveryPage), findsNothing);
    expect(find.text('Đã lưu buổi tập dở dang'), findsOneWidget);
    final history = await WorkoutHistoryStore().load();
    expect(history, hasLength(1));
    expect(history.single.partial, isTrue);
    expect(history.single.reps, 14);
    expect(await WorkoutDraftStore().load(), isNull);
  });

  testWidgets('discard asks first; cancelling keeps the draft', (tester) async {
    await _pump(tester, draft: _draft());
    await tester.tap(find.byKey(const Key('recovery-discard')));
    await tester.pumpAndSettle();
    expect(find.text('Bỏ buổi tập này?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('discard-cancel')));
    await tester.pumpAndSettle();
    expect(find.byType(RecoveryPage), findsOneWidget);
    expect(await WorkoutDraftStore().load(), isNotNull);

    await tester.tap(find.byKey(const Key('recovery-discard')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('discard-confirm')));
    await tester.pumpAndSettle();
    expect(find.byType(RecoveryPage), findsNothing);
    expect(await WorkoutDraftStore().load(), isNull);
    expect(await WorkoutHistoryStore().load(), isEmpty);
  });

  testWidgets('system Back cannot dismiss recovery silently', (tester) async {
    await _pump(tester, draft: _draft());
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(RecoveryPage), findsOneWidget);
    expect(await WorkoutDraftStore().load(), isNotNull);
  });

  testWidgets('after 12 h the expired copy is shown, still with both choices',
      (tester) async {
    await _pump(tester,
        draft:
            _draft(updated: DateTime.now().subtract(const Duration(hours: 13))),
        language: AppLanguage.en);
    expect(
        find.text('This workout (14 reps) is older than the 12-hour resume '
            'window. Nothing was deleted: save it as a partial workout or '
            'discard it.'),
        findsOneWidget);
    expect(find.byKey(const Key('recovery-save-partial')), findsOneWidget);
    expect(find.byKey(const Key('recovery-discard')), findsOneWidget);
  });

  testWidgets('the saved partial workout is labelled in history',
      (tester) async {
    await _pump(tester, draft: _draft());
    await tester.tap(find.byKey(const Key('recovery-save-partial')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tiến bộ').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-history-list')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byKey(const Key('history-partial')), 250,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Chưa trọn'), findsOneWidget);
  });
}
