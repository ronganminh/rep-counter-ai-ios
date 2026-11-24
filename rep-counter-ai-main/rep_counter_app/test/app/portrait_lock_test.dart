import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// QA-08 (L-D42): Android is locked to portrait like iOS. The HUD, the
/// placement guide and the Train sheet are designed for portrait only.
void main() {
  test('Android main activity is portrait only', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final activity = RegExp(r'<activity\b[^>]*android:name="\.MainActivity"[^>]*>')
        .firstMatch(manifest);
    expect(activity, isNotNull);
    expect(activity!.group(0), contains('android:screenOrientation="portrait"'));
  });

  test('iOS supports portrait only (unchanged)', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final start = plist.indexOf('<key>UISupportedInterfaceOrientations</key>');
    final block = plist.substring(start, plist.indexOf('</array>', start));
    expect(block, contains('UIInterfaceOrientationPortrait'));
    expect(block, isNot(contains('Landscape')));
    expect(block, isNot(contains('PortraitUpsideDown')));
  });
}
