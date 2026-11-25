import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// S-3 (L-D42): `ios/Runner/PrivacyInfo.xcprivacy` matches the App Privacy
/// table A.2 of `store_listing/PRIVACY_DECLARATIONS_V2.md`, and the readiness
/// gate rejects a manifest that drifts from it.

/// Runs [mutation] (Python, on `m`, the parsed manifest) and then the gate's
/// manifest check; returns the process result.
ProcessResult _check(String mutation) => Process.runSync('python3', [
      '-c',
      '''
import copy, plistlib, sys
sys.path.insert(0, "tool")
import check_app_store_readiness as c
m = plistlib.loads((c.ROOT / c.PRIVACY_MANIFEST).read_bytes())
$mutation
c.check_privacy_manifest(m)
''',
    ]);

void main() {
  final hasPython = () {
    try {
      return Process.runSync('python3', ['--version']).exitCode == 0;
    } on ProcessException {
      return false;
    }
  }();

  test('manifest is a valid plist that declares the v2 data types', () {
    final xml = File('ios/Runner/PrivacyInfo.xcprivacy').readAsStringSync();
    for (final type in [
      'EmailAddress',
      'Name',
      'UserID',
      'Fitness',
      'OtherUserContent',
      'ProductInteraction',
    ]) {
      expect(xml, contains('<string>NSPrivacyCollectedDataType$type</string>'));
    }
    expect(xml, isNot(contains('NSPrivacyCollectedDataTypeCrashData')));
    expect(xml, contains('<key>NSPrivacyTracking</key>\n\t<false/>'));
  });

  test('the committed manifest passes the gate', () {
    final r = _check('');
    expect(r.exitCode, 0, reason: '${r.stderr}');
  }, skip: !hasPython);

  test('the gate reads every ticked A.2 row of the declarations', () {
    final r = Process.runSync('python3', [
      '-c',
      'import sys; sys.path.insert(0, "tool"); '
          'import check_app_store_readiness as c; '
          'print(sorted(c.declared_app_privacy_types()))',
    ]);
    expect(r.exitCode, 0, reason: '${r.stderr}');
    expect(
        (r.stdout as String).trim(),
        "['Email Address', 'Fitness', 'Name', 'Other User Content', "
        "'Product Interaction', 'User ID']");
  }, skip: !hasPython);

  group('the gate fails when the manifest', () {
    final cases = {
      'turns on tracking': 'm["NSPrivacyTracking"] = True',
      'adds a tracking domain': 'm["NSPrivacyTrackingDomains"] = ["x.example"]',
      'drops a declared data type':
          'm["NSPrivacyCollectedDataTypes"] = m["NSPrivacyCollectedDataTypes"][1:]',
      'adds an undeclared data type':
          'm["NSPrivacyCollectedDataTypes"].append(dict(m["NSPrivacyCollectedDataTypes"][0], NSPrivacyCollectedDataType="NSPrivacyCollectedDataTypeCrashData"))',
      'marks a type not linked':
          'm["NSPrivacyCollectedDataTypes"][0]["NSPrivacyCollectedDataTypeLinked"] = False',
      'uses a type for tracking':
          'm["NSPrivacyCollectedDataTypes"][0]["NSPrivacyCollectedDataTypeTracking"] = True',
      'adds an advertising purpose':
          'm["NSPrivacyCollectedDataTypes"][0]["NSPrivacyCollectedDataTypePurposes"].append("NSPrivacyCollectedDataTypePurposeThirdPartyAdvertising")',
      'loses the UserDefaults reason': 'm["NSPrivacyAccessedAPITypes"] = []',
    };
    cases.forEach((name, mutation) {
      test(name, () {
        final r = _check(mutation);
        expect(r.exitCode, isNot(0), reason: 'mutation: $mutation');
        expect(r.stderr as String, contains('AssertionError'));
      }, skip: !hasPython);
    });
  });
}
