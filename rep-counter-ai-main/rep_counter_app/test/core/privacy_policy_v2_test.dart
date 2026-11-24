import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/config/app_config.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/legal/legal_config.dart';

/// Store compliance S-1 / S-2 (docs/qa/STORE_COMPLIANCE_v2.md): the in-app
/// privacy policy and the web pages describe v2 (optional account, sync,
/// friends, AI Coach, account deletion) and no longer the v1 "no accounts,
/// 100 records" wording.

String _privacyText(S s) => [
      s.privacyIntroBody,
      s.privCameraBody,
      s.privWorkoutBody,
      s.privAccountBody,
      s.privSyncBody,
      s.privSocialBody,
      s.privAiBody,
      s.privCoachBody,
      s.privNotifBody,
      s.privRetentionBody,
      s.privDeletionBody,
      s.privSecurityBody,
      s.privNoAdsBody,
      s.privChildrenBody,
      s.privChoicesBody,
      s.privChangesBody,
    ].join('\n');

const _web = '../backend/static';

void main() {
  test('account-deletion URL is on the D-14 site, over https', () {
    expect(AppConfig.accountDeletionUrl,
        'https://repcoach-ai.duckdns.org/delete-account.html');
    expect(LegalConfig.accountDeletionUrl, AppConfig.accountDeletionUrl);
  });

  for (final (name, s) in [('en', S.en), ('vi', S.vi)]) {
    test('in-app privacy policy ($name) describes v2 data', () {
      final text = _privacyText(s);
      for (final fact in [
        'Supabase',
        'GroqCloud',
        'Keychain',
        'Keystore',
        'ai-request',
        '90',
        '7',
        LegalConfig.accountDeletionUrl,
      ]) {
        expect(text, contains(fact), reason: 'missing "$fact"');
      }
      // Sign-in providers and the deletion path in the app.
      expect(text, contains('Apple'));
      expect(text, contains('Google'));
      expect(text, contains(name == 'en' ? 'Delete account' : 'Xóa tài khoản'));
      // v1 wording that is now wrong.
      for (final stale in [
        '100',
        'no user-account',
        'không có hệ thống tài khoản',
        'Gemini',
      ]) {
        expect(text, isNot(contains(stale)), reason: 'stale "$stale"');
      }
    });
  }

  test('effective date is the v2 revision in both languages', () {
    expect(LegalConfig.effectiveDate, '24/11/2026');
    expect(LegalConfig.effectiveDateEn, 'November 24, 2026');
  });

  test('web privacy policy matches the app (v2, bilingual)', () {
    final html = File('$_web/privacy-policy.html').readAsStringSync();
    expect(html, contains(LegalConfig.effectiveDateEn));
    expect(html, contains(LegalConfig.aiConsentVersion));
    for (final fact in [
      'Supabase',
      'GroqCloud',
      'Sign in with Apple',
      'Google Sign-In',
      'ai-request',
      'delete-account.html',
      'id="en"',
      'id="vi"',
    ]) {
      expect(html, contains(fact), reason: 'missing "$fact"');
    }
    expect(html, isNot(contains('has no user-account system')));
    expect(html, isNot(contains('up to the latest 100')));
    expect(html, isNot(contains('Gemini')));
    expect(html.toLowerCase(), isNot(contains('<script')));
  });

  test('web delete-account page lets people request deletion without the app',
      () {
    final html = File('$_web/delete-account.html').readAsStringSync();
    expect(html, contains(LegalConfig.appName));
    expect(html, contains(LegalConfig.developerName));
    expect(html, contains('mailto:${LegalConfig.contactEmail}'));
    expect(html, contains('id="en"'));
    expect(html, contains('id="vi"'));
    expect(html, contains('Delete account'));
    expect(html, contains('Xóa tài khoản'));
    expect(html.toLowerCase(), isNot(contains('<script')));
  });

  test('support page links account deletion and drops the v1 wording', () {
    final html = File('$_web/support.html').readAsStringSync();
    expect(html, contains('/delete-account.html'));
    expect(html, isNot(contains('does not provide user accounts')));
  });
}
