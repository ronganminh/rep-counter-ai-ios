import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/app/os_links.dart';

/// X-1: `repcoach://` is registered with the OS, only those links reach the
/// N-2a router, and the Supabase auth callback scheme is untouched.
void main() {
  test('only repcoach:// links are ours', () {
    expect(isRepcoachLink('repcoach://plan/session/s1'), isTrue);
    expect(isRepcoachLink('repcoach://inbox'), isTrue);
    expect(isRepcoachLink('com.ronganminh.repcoach://login-callback'), isFalse);
    expect(
        isRepcoachLink(
            'com.googleusercontent.apps.354784213486-x:/oauth2redirect'),
        isFalse);
    expect(isRepcoachLink('https://repcoach-ai.duckdns.org/'), isFalse);
    expect(isRepcoachLink('not a url %%%'), isFalse);
  });

  test('the OS stream keeps repcoach:// links and survives errors', () async {
    final source = StreamController<String>();
    final got = osRepcoachLinks(source: source.stream).toList();
    source
      ..add('com.ronganminh.repcoach://login-callback?code=x')
      ..addError(StateError('plugin'))
      ..add('repcoach://inbox');
    unawaited(source.close());
    expect(await got, ['repcoach://inbox']);
  });

  test('no plugin in tests: the default OS stream is empty', () async {
    expect(await osRepcoachLinks().toList(), isEmpty);
  });

  test('merged sources; a replayed link within 2 s opens once', () async {
    var t = DateTime.utc(2026, 10, 29, 12);
    final a = StreamController<String>(), b = StreamController<String>();
    final got = <String>[];
    final sub =
        mergeLinkStreams([a.stream, b.stream], now: () => t).listen(got.add);
    a.add('plan-session:s1');
    await pumpEventQueue();
    b.add('plan-session:s1'); // same link replayed by the OS
    await pumpEventQueue();
    b.add('repcoach://inbox');
    await pumpEventQueue();
    t = t.add(const Duration(seconds: 3));
    a.add('repcoach://inbox'); // later tap: opens again
    await pumpEventQueue();
    expect(got, ['plan-session:s1', 'repcoach://inbox', 'repcoach://inbox']);
    await sub.cancel();
  });

  group('platform registration', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    test('iOS: repcoach URL type next to the unchanged auth callback', () {
      expect(plist, contains('<string>com.ronganminh.repcoach.links</string>'));
      expect(plist, contains('<string>repcoach</string>'));
      expect(plist, contains('<string>com.ronganminh.repcoach</string>'),
          reason: 'Supabase login-callback scheme kept');
      expect(plist, isNot(contains('FlutterDeepLinkingEnabled')),
          reason: 'links go to app_links / N-2a, not the Flutter router');
    });

    test('Android: repcoach intent filter next to the auth callback', () {
      expect(manifest, contains('<data android:scheme="repcoach"/>'));
      expect(
          RegExp(r'android:scheme="com\.ronganminh\.repcoach"\s+'
                  r'android:host="login-callback"')
              .hasMatch(manifest),
          isTrue);
      expect(manifest, contains('android:launchMode="singleTop"'),
          reason: 'links reach the running app instead of a second copy');
    });
  });
}
