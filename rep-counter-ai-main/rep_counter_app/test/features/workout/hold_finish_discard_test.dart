import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/features/workout/presentation/widgets/discard_confirm.dart';
import 'package:rep_counter_app/features/workout/presentation/widgets/workout_hud.dart';
import 'package:rep_counter_app/theme/app_theme.dart';

Future<void> _pump(WidgetTester tester, Widget child,
    {AppLanguage language = AppLanguage.vi}) async {
  final locale = LocaleController(language);
  addTearDown(locale.dispose);
  await tester.pumpWidget(LocaleScope(
    controller: locale,
    child: MaterialApp(theme: RepCoachTheme.dark(), home: child),
  ));
  await tester.pumpAndSettle();
}

Finder get _holdTarget => find
    .descendant(of: find.byType(HoldToFinish), matching: find.byType(Listener))
    .first;

void main() {
  testWidgets('hold disc uses the 76 px token', (tester) async {
    await _pump(
        tester, Scaffold(body: Center(child: HoldToFinish(onFinish: () {}))));
    final disc = find.descendant(
        of: find.byType(HoldToFinish),
        matching: find.byWidgetPredicate((w) =>
            w is SizedBox &&
            w.width == HoldToFinish.size &&
            w.height == HoldToFinish.size));
    expect(disc, findsOneWidget);
    expect(HoldToFinish.size, 76);
  });

  testWidgets('a quick tap explains the hold, then the hint clears',
      (tester) async {
    var finished = 0;
    await _pump(
        tester,
        Scaffold(
            body: Center(child: HoldToFinish(onFinish: () => finished++))));
    final touch = await tester.startGesture(tester.getCenter(_holdTarget));
    await tester.pump(const Duration(milliseconds: 200));
    await touch.up();
    await tester.pump();
    expect(finished, 0);
    expect(find.text('Giữ 1 giây để kết thúc'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Giữ 1 giây để kết thúc'), findsNothing);
    expect(find.text('Giữ để kết thúc'), findsOneWidget);
  });

  testWidgets('reduced motion keeps the full one-second hold', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    var finished = 0;
    await _pump(
        tester,
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
              body: Center(child: HoldToFinish(onFinish: () => finished++))),
        ));
    final touch = await tester.startGesture(tester.getCenter(_holdTarget));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // A `normal` AnimationController would already have completed here.
    expect(finished, 0);
    final ring = tester.widget<CircularProgressIndicator>(
        find.byKey(const Key('hold-to-finish-ring')));
    expect(ring.value, 1, reason: 'static fill instead of an animated ring');
    await tester.pump(const Duration(milliseconds: 800));
    expect(finished, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(finished, 1);
    await touch.up();
    await tester.pumpAndSettle();
  });

  test('only workouts with counted reps need a discard confirmation', () {
    expect(discardNeedsConfirmation(0), isFalse);
    expect(discardNeedsConfirmation(1), isTrue);
  });

  for (final (choice, expected) in [
    (const Key('discard-confirm'), true),
    (const Key('discard-cancel'), false),
  ]) {
    testWidgets('discard confirmation returns $expected', (tester) async {
      bool? result;
      await _pump(
          tester,
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async =>
                    result = await confirmDiscardWorkout(context),
                child: const Text('leave'),
              ),
            ),
          ));
      await tester.tap(find.text('leave'));
      await tester.pumpAndSettle();
      expect(find.text('Bỏ buổi tập này?'), findsOneWidget);
      expect(
          find.text('Số rep của buổi này sẽ không được lưu.'), findsOneWidget);
      await tester.tap(find.byKey(choice));
      await tester.pumpAndSettle();
      expect(result, expected);
    });
  }

  testWidgets('dismissing the confirmation keeps the workout', (tester) async {
    bool? result;
    await _pump(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  result = await confirmDiscardWorkout(context),
              child: const Text('leave'),
            ),
          ),
        ),
        language: AppLanguage.en);
    await tester.tap(find.text('leave'));
    await tester.pumpAndSettle();
    expect(find.text('Discard this workout?'), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });
}
