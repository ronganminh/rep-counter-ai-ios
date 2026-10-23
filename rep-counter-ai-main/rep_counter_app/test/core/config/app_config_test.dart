import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:rep_counter_app/core/config/app_config.dart';
import 'package:rep_counter_app/core/config/build_info.dart';
import 'package:rep_counter_app/core/legal/legal_config.dart';

void main() {
  test('store configuration is empty unless provided (never invented)', () {
    expect(AppConfig.productIdProMonthly, isEmpty);
    expect(AppConfig.productIdProAnnual, isEmpty);
    expect(AppConfig.billingConfigured, isFalse);
  });

  test('legal defaults are the values already shipping, over HTTPS', () {
    expect(LegalConfig.contactEmail, AppConfig.supportEmail);
    expect(LegalConfig.privacyPolicyUrl, AppConfig.privacyPolicyUrl);
    for (final url in [
      AppConfig.privacyPolicyUrl,
      AppConfig.termsUrl,
      AppConfig.supportUrl,
    ]) {
      expect(Uri.parse(url).scheme, 'https', reason: url);
    }
    // Same host and pages that backend/server.py serves.
    final server = File('../backend/server.py').readAsStringSync();
    for (final path in [
      '/privacy-policy.html',
      '/terms.html',
      '/support.html'
    ]) {
      expect(server, contains('"$path"'));
    }
  });

  test('no hard-coded version literal remains in Settings', () {
    final settings =
        File('lib/features/legal/settings_page.dart').readAsStringSync();
    expect(RegExp(r"'\d+\.\d+\.\d+ \(\d+\)'").hasMatch(settings), isFalse);
    expect(settings, contains('AppVersionText('));
  });

  test('BuildInfo reads platform metadata', () async {
    PackageInfo.setMockInitialValues(
      appName: 'RepCoach AI',
      packageName: 'com.ronganminh.repcoach',
      version: '2.0.0',
      buildNumber: '8',
      buildSignature: '',
    );
    final info = await BuildInfo.load();
    expect(info!.label, '2.0.0 (8)');
  });

  testWidgets('AppVersionText shows metadata, or a dash when unavailable',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Column(children: [
        AppVersionText(
            loader: () async =>
                const BuildInfo(version: '2.0.0', buildNumber: '8')),
        AppVersionText(loader: () async => null),
      ]),
    ));
    await tester.pump();
    expect(find.text('2.0.0 (8)'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
  });
}
