import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/config/app_config.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/core/legal/legal_config.dart';
import 'package:rep_counter_app/features/legal/legal_page.dart';
import 'package:rep_counter_app/theme/app_theme.dart';

import '../support/l10n.dart';

/// D-14 (owner, 2026-10-27): support and legal values from the v1 store
/// listings. No placeholder may reach the app.

const decided = {
  'SUPPORT_EMAIL': 'ronganminh221@gmail.com',
  'SUPPORT_URL': 'https://repcoach-ai.duckdns.org/support.html',
  'PRIVACY_URL': 'https://repcoach-ai.duckdns.org/privacy-policy.html',
  'TERMS_URL': 'https://repcoach-ai.duckdns.org/terms.html',
  'WEBSITE': 'https://repcoach-ai.duckdns.org/',
};

final _placeholder =
    RegExp(r'\[(SUPPORT_EMAIL|SUPPORT_URL|TERMS_URL|PRIVACY_URL)\]');

void main() {
  test('config defaults are the D-14 values', () {
    expect(AppConfig.supportEmail, decided['SUPPORT_EMAIL']);
    expect(AppConfig.supportUrl, decided['SUPPORT_URL']);
    expect(AppConfig.privacyPolicyUrl, decided['PRIVACY_URL']);
    expect(AppConfig.termsUrl, decided['TERMS_URL']);
    expect(AppConfig.websiteUrl, decided['WEBSITE']);
    expect(LegalConfig.contactEmail, decided['SUPPORT_EMAIL']);
    expect(LegalConfig.supportUrl, decided['SUPPORT_URL']);
    for (final url in [
      AppConfig.supportUrl,
      AppConfig.privacyPolicyUrl,
      AppConfig.termsUrl,
      AppConfig.websiteUrl,
    ]) {
      expect(Uri.parse(url).scheme, 'https');
    }
  });

  test('billing stays off: no product IDs, prices or trials invented', () {
    expect(AppConfig.productIdProMonthly, isEmpty);
    expect(AppConfig.productIdProAnnual, isEmpty);
    expect(AppConfig.billingConfigured, isFalse);
  });

  test('no support/legal placeholder in app code or ARB strings', () {
    final offenders = <String>[];
    for (final dir in ['lib']) {
      for (final f in Directory(dir).listSync(recursive: true)) {
        if (f is! File) continue;
        if (!(f.path.endsWith('.dart') || f.path.endsWith('.arb'))) continue;
        final text = f.readAsStringSync();
        for (final m in _placeholder.allMatches(text)) {
          offenders.add('${f.path}: ${m.group(0)}');
        }
      }
    }
    expect(offenders, isEmpty);
  });

  for (final kind in LegalKind.values) {
    testWidgets('legal page ${kind.name} links its online version',
        (tester) async {
      final locale = LocaleController(AppLanguage.en);
      addTearDown(locale.dispose);
      await tester.pumpWidget(LocaleScope(
        controller: locale,
        child: MaterialApp(
          theme: RepCoachTheme.dark(),
          supportedLocales: testSupportedLocales,
          localizationsDelegates: testLocalizationsDelegates,
          home: LegalPage(kind: kind),
        ),
      ));
      await tester.pumpAndSettle();
      final url = kind == LegalKind.privacy
          ? decided['PRIVACY_URL']!
          : decided['TERMS_URL']!;
      await tester.scrollUntilVisible(find.text(url), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.text(url), findsOneWidget);
      expect(find.textContaining(decided['SUPPORT_EMAIL']!), findsOneWidget);
    });
  }
}
