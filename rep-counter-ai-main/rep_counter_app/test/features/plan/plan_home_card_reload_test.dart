import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/features/plan/application/plan_repository.dart';
import 'package:rep_counter_app/features/plan/presentation/plan_home_card.dart';
import 'package:rep_counter_app/features/plan/presentation/plan_setup_page.dart';
import 'package:rep_counter_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/l10n.dart';

/// QA-07: coming back from the plan pages reloads the card without calling
/// `setState` with a callback that returns a Future (a FlutterError in debug).
class _CountingRepository extends PlanRepository {
  _CountingRepository() : super(loadWorkouts: () async => const []);
  int loads = 0;

  @override
  Future<PlanView?> load() {
    loads++;
    return super.load();
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('returning from a plan page reloads the card without an error',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final locale = LocaleController(AppLanguage.en);
    addTearDown(locale.dispose);
    final repo = _CountingRepository();
    await tester.pumpWidget(LocaleScope(
      controller: locale,
      child: MaterialApp(
        theme: RepCoachTheme.dark(),
        locale: AppLanguage.en.locale,
        supportedLocales: testSupportedLocales,
        localizationsDelegates: testLocalizationsDelegates,
        home: Scaffold(body: PlanHomeCard(repository: repo)),
      ),
    ));
    await tester.pumpAndSettle();
    expect(repo.loads, 1);

    await tester.tap(find.byKey(const Key('plan-home-card')));
    await tester.pumpAndSettle();
    expect(find.byType(PlanSetupPage), findsOneWidget);

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(PlanSetupPage), findsNothing);
    expect(find.byKey(const Key('plan-home-card')), findsOneWidget);
    expect(repo.loads, 2);
  });
}
