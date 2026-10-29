import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';

/// `repcoach://` links handed to the app by the OS (iOS URL type in
/// Info.plist, Android intent filter in AndroidManifest), for the N-2a
/// router. Other schemes the app registers are left to their owners: the
/// Supabase auth callback (`com.ronganminh.repcoach://login-callback`) is
/// read by supabase_flutter, the Google sign-in scheme by google_sign_in.
bool isRepcoachLink(String raw) => Uri.tryParse(raw)?.scheme == 'repcoach';

/// The OS link stream. It also delivers the link that launched the app, so
/// there is no separate initial-link call. Empty in tests and on platforms
/// without the plugin.
Stream<String> osRepcoachLinks({Stream<String>? source}) {
  if (source == null &&
      (Platform.environment.containsKey('FLUTTER_TEST') ||
          !(Platform.isIOS || Platform.isAndroid))) {
    return const Stream.empty();
  }
  return (source ?? AppLinks().stringLinkStream)
      .handleError((Object _) {})
      .where(isRepcoachLink);
}

/// One stream of link strings from several sources; the same link arriving
/// twice within [window] (an OS replaying the launch link) is opened once.
Stream<String> mergeLinkStreams(List<Stream<String>> sources,
    {Duration window = const Duration(seconds: 2),
    DateTime Function() now = DateTime.now}) {
  late final StreamController<String> controller;
  final subs = <StreamSubscription<String>>[];
  String? last;
  DateTime? lastAt;
  controller = StreamController<String>.broadcast(
    onListen: () {
      for (final s in sources) {
        subs.add(s.listen((raw) {
          final t = now();
          if (raw == last && lastAt != null && t.difference(lastAt!) < window) {
            return;
          }
          last = raw;
          lastAt = t;
          controller.add(raw);
        }, onError: (Object _) {}));
      }
    },
    onCancel: () async {
      for (final s in subs) {
        await s.cancel();
      }
      subs.clear();
    },
  );
  return controller.stream;
}
