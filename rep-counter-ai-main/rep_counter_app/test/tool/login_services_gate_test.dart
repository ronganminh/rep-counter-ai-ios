import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// App Store 4.8 (S-5, L-D42): `tool/check_app_store_readiness.py` fails any
/// dart-define file that turns on Google Sign-In for iOS without Sign in with
/// Apple, and the committed staging example passes it.

Future<ProcessResult> _gate(List<String> args) =>
    Process.run('python3', ['tool/check_app_store_readiness.py', ...args]);

void main() {
  final hasPython = () {
    try {
      return Process.runSync('python3', ['--version']).exitCode == 0;
    } on ProcessException {
      return false;
    }
  }();

  test('staging example pairs Google on iOS with Sign in with Apple', () {
    final d = jsonDecode(
            File('dart_defines.staging.example.json').readAsStringSync())
        as Map<String, dynamic>;
    expect(d['ENABLE_ACCOUNTS'], 'true');
    expect((d['GOOGLE_IOS_CLIENT_ID'] as String).isNotEmpty, isTrue);
    expect(d['APPLE_SIGN_IN_ENABLED'], 'true');
  });

  group('readiness gate 4.8', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('gate48'));
    tearDown(() => dir.deleteSync(recursive: true));

    File defines(Map<String, String> values) =>
        File('${dir.path}/dart_defines.build.json')
          ..writeAsStringSync(jsonEncode(values));

    test('Google on iOS without Apple fails', () async {
      final f = defines({
        'ENABLE_ACCOUNTS': 'true',
        'GOOGLE_IOS_CLIENT_ID': 'ios.apps.googleusercontent.com',
        'APPLE_SIGN_IN_ENABLED': 'false',
      });
      final r = await _gate(['--dart-define-from-file=${f.path}']);
      expect(r.exitCode, 1);
      expect(r.stderr as String, contains('4.8'));
    }, skip: !hasPython);

    test('Google with Apple, or accounts off, passes', () async {
      for (final values in [
        {
          'ENABLE_ACCOUNTS': 'true',
          'GOOGLE_IOS_CLIENT_ID': 'ios.apps.googleusercontent.com',
          'APPLE_SIGN_IN_ENABLED': 'true',
        },
        {
          'ENABLE_ACCOUNTS': 'false',
          'GOOGLE_IOS_CLIENT_ID': 'ios.apps.googleusercontent.com',
        },
        {'ENABLE_ACCOUNTS': 'true'},
      ]) {
        final r = await _gate(['--dart-define-from-file=${defines(values).path}']);
        expect(r.exitCode, 0, reason: '${r.stderr}');
      }
    }, skip: !hasPython);
  });
}
