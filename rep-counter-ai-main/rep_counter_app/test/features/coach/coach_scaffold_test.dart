import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/features/coach/coach_v2.dart';
import 'package:rep_counter_app/features/coach/presentation/coach_consent_page.dart';
import 'package:rep_counter_app/features/coach/presentation/coach_privacy_rows.dart';
import 'package:rep_counter_app/features/coach/presentation/coach_widgets.dart';
import 'package:rep_counter_app/features/credits/ai_coach_v2.dart';
import 'package:rep_counter_app/l10n/app_localizations.dart';
import 'package:rep_counter_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/l10n.dart';

/// AI Coach · PT ảo scaffold: strings from the handoff, the D-29 costs, the
/// flag, the consent screen (AC-03a) and the AI privacy rows (AC-05a).

Widget _app(Widget home, {Locale locale = const Locale('en')}) => MaterialApp(
      theme: RepCoachTheme.dark(),
      locale: locale,
      supportedLocales: testSupportedLocales,
      localizationsDelegates: testLocalizationsDelegates,
      home: home,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('all 158 handoff keys are in the app ARB files, EN and VI', () {
    for (final lang in ['en', 'vi']) {
      final handoff = jsonDecode(File(
              '../../docs/design/v2-final-c/aicoach/l10n/app_$lang.aicoach.arb')
          .readAsStringSync()) as Map<String, dynamic>;
      final app = jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync())
          as Map<String, dynamic>;
      final keys = handoff.keys.where((k) => !k.startsWith('@')).toList();
      expect(keys, hasLength(158));
      for (final k in keys) {
        expect(app[k], handoff[k], reason: '$lang $k');
      }
    }
    final vi = lookupAppLocalizations(const Locale('vi'));
    expect(vi.ptTurnOn, 'Bật AI Coach');
    expect(lookupAppLocalizations(const Locale('en')).ptCreditsLeft(6, 10),
        '6 of 10 left');
  });

  test('D-29 credit costs and D-32 minimums', () {
    expect(CoachCost.dailyPick, 0);
    expect(CoachCost.newSuggestion, 1);
    expect(CoachCost.review, 1);
    expect(CoachCost.chatMessage, 1);
    expect(CoachCost.safetyReply, 0);
    expect(CoachCost.weekPlan, 2);
    expect(CoachMinimum.pickWorkouts, 3);
    expect(CoachMinimum.weekHistoryDays, 14);
  });

  test('flag is off by default (tests run without dart-defines)', () {
    expect(AiCoachV2.enabled, isFalse);
  });

  testWidgets('gate: nothing without the flag or without credits',
      (tester) async {
    late bool off, noCredits;
    await tester.pumpWidget(_app(Builder(builder: (context) {
      off = CoachGate.available(context, enabled: false);
      noCredits = CoachGate.available(context, enabled: true);
      return const SizedBox();
    })));
    expect(off, isFalse);
    expect(noCredits, isFalse, reason: 'no CreditsScope above');
  });

  for (final agree in [true, false]) {
    testWidgets('consent: ${agree ? 'turn on' : 'not now'}', (tester) async {
      bool? result;
      await tester.pumpWidget(_app(Builder(
          builder: (context) => TextButton(
              onPressed: () async => result = await CoachConsentPage.ensure(
                  context,
                  requireAccount: (_) async => true),
              child: const Text('open')))));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Turn on AI Coach?'), findsOneWidget);
      expect(find.text('Video or photos'), findsOneWidget);
      expect(find.text('Name or contacts'), findsOneWidget);
      await tester.tap(find
          .byKey(Key(agree ? 'coach-consent-on' : 'coach-consent-not-now')));
      await tester.pumpAndSettle();
      expect(result, agree);
      expect(await const CoachConsentStore().given(), agree);
    });
  }

  testWidgets('consent: guest who stays a guest never sees the consent',
      (tester) async {
    bool? result;
    await tester.pumpWidget(_app(Builder(
        builder: (context) => TextButton(
            onPressed: () async => result = await CoachConsentPage.ensure(
                context,
                requireAccount: (_) async => false),
            child: const Text('open')))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    expect(find.byKey(const Key('coach-consent')), findsNothing);
  });

  testWidgets('consent buttons are ≥ 48 dp and readable at 375 px (VI)',
      (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester
        .pumpWidget(_app(const CoachConsentPage(), locale: const Locale('vi')));
    await tester.pumpAndSettle();
    for (final k in ['coach-consent-on', 'coach-consent-not-now']) {
      final size = tester.getSize(find.byKey(Key(k)));
      expect(size.height, greaterThanOrEqualTo(48), reason: k);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('AI privacy: coach switch withdraws, body check-in is off',
      (tester) async {
    SharedPreferences.setMockInitialValues({AiCoachV2.consentKey: true});
    await tester.pumpWidget(_app(
        Scaffold(body: CoachPrivacyRows(requireAccount: (_) async => true))));
    await tester.pumpAndSettle();
    expect(find.text('Body check-in'), findsOneWidget);
    expect(find.text('LATER'), findsOneWidget);
    expect(tester.getSemantics(find.byKey(const Key('settings-body-check-in'))),
        isSemantics(hasEnabledState: true, isEnabled: false));
    final sw = find.byKey(const Key('settings-ai-coach-switch'));
    expect(tester.widget<Switch>(sw).value, isTrue);
    await tester.tap(sw);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(sw).value, isFalse);
    expect(await const CoachConsentStore().given(), isFalse);
    // Turning it on goes through the consent screen.
    await tester.tap(sw);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('coach-consent')), findsOneWidget);
    await tester.tap(find.byKey(const Key('coach-consent-on')));
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(sw).value, isTrue);
  });

  testWidgets('busy ring holds still under Reduce Motion', (tester) async {
    for (final still in [false, true]) {
      await tester.pumpWidget(MediaQuery(
          data: MediaQueryData(disableAnimations: still),
          child: _app(const Scaffold(body: CoachBusy(title: 'Coach…')))));
      final ring = tester.widget<CircularProgressIndicator>(
          find.byKey(const Key('coach-busy-ring')));
      expect(ring.value == null, !still);
    }
  });

  testWidgets('credits chip and coach chip', (tester) async {
    await tester.pumpWidget(_app(const Scaffold(
        body: Column(children: [
      CoachCreditsChip(remaining: 0, allowance: 10),
      CoachChip(),
    ]))));
    expect(find.text('0 of 10 left'), findsOneWidget);
    expect(find.text('COACH'), findsOneWidget);
  });
}
