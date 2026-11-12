// QA v2 integration-test harness.
//
// Pumps the real app root (`RepCounterApp` from lib/main.dart) with the
// native boundaries replaced by fakes, so the same journeys run on the host
// (`flutter test integration_test`) and on a device
// (`flutter test integration_test -d <id>`). Nothing here changes app code.
//
// Faked native boundaries:
// - permission_handler: camera status / request result / openAppSettings
//   are scripted and counted (App Store 5.1.1(iv) journeys);
// - camera: no camera available (the engine is never started);
// - flutter_tts, google_mlkit_pose_detector, repcoach/diag: inert;
// - flutter_local_notifications: initialised, notifications never granted
//   (the reminder journeys), nothing scheduled.

import 'dart:io';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rep_counter_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The binding for these journeys.
///
/// On a device (`flutter test integration_test -d <id>`) this is the
/// integration_test binding. On the host, `flutter test` refuses files under
/// `integration_test/` without a device, so the same files are re-exported
/// by `test/qa_journeys/*_test.dart` and run on the ordinary automated
/// binding (which also loads `test/flutter_test_config.dart`: in-memory
/// workout database).
TestWidgetsFlutterBinding ensureQaBinding() {
  final onHost = Platform.environment.containsKey('FLUTTER_TEST') &&
      !(Platform.isAndroid || Platform.isIOS);
  return onHost
      ? TestWidgetsFlutterBinding.ensureInitialized()
      : IntegrationTestWidgetsFlutterBinding.ensureInitialized();
}

/// permission_handler status codes.
const permissionDenied = 0; // iOS: not asked yet · Android: denied once
const permissionGranted = 1;
const permissionRestricted = 2;
const permissionPermanentlyDenied = 4; // iOS: Don't Allow earlier

/// A camera platform with no cameras: the gate reaches the real
/// "camera unavailable" state without touching the engine.
class NoCameraPlatform extends CameraPlatform {
  int requests = 0;

  @override
  Future<List<CameraDescription>> availableCameras() async {
    requests++;
    return const [];
  }
}

class PluginFakes {
  PluginFakes(this.messenger);

  final TestDefaultBinaryMessenger messenger;

  /// What `Permission.camera.status` answers before any request.
  int cameraStatus = permissionDenied;

  /// What the system camera prompt answers.
  int cameraRequestResult = permissionGranted;

  /// Notifications: what the OS answers to the request.
  bool notificationsGranted = false;

  final permissionCalls = <String>[];
  final notificationCalls = <String>[];
  bool _cameraGranted = false;
  NoCameraPlatform? _camera;
  CameraPlatform? _previousCamera;

  int get settingsOpened =>
      permissionCalls.where((c) => c == 'openAppSettings').length;
  int get cameraPrompts =>
      permissionCalls.where((c) => c == 'requestPermissions').length;
  int get cameraRequests => _camera?.requests ?? 0;

  static const _channels = [
    'flutter.baseflow.com/permissions/methods',
    'flutter_tts',
    'repcoach/diag',
    'google_mlkit_pose_detector',
    'dexterous.com/flutter/local_notifications',
    'dev.fluttercommunity.plus/package_info',
  ];

  void install() {
    _previousCamera = CameraPlatform.instance;
    _camera = NoCameraPlatform();
    CameraPlatform.instance = _camera!;
    _cameraGranted = false;
    permissionCalls.clear();
    notificationCalls.clear();
    messenger.setMockMethodCallHandler(
        const MethodChannel('flutter.baseflow.com/permissions/methods'),
        (call) async {
      permissionCalls.add(call.method);
      switch (call.method) {
        case 'checkPermissionStatus':
          return _cameraGranted ? permissionGranted : cameraStatus;
        case 'requestPermissions':
          if (cameraRequestResult == permissionGranted) _cameraGranted = true;
          return {1: cameraRequestResult}; // 1 = Permission.camera
        case 'openAppSettings':
          return true;
      }
      return null;
    });
    messenger.setMockMethodCallHandler(const MethodChannel('flutter_tts'),
        (call) async => call.method == 'isLanguageAvailable' ? true : 1);
    messenger.setMockMethodCallHandler(
        const MethodChannel('repcoach/diag'), (_) async => false);
    messenger.setMockMethodCallHandler(
        const MethodChannel('google_mlkit_pose_detector'),
        (_) async => <Object?>[]);
    messenger.setMockMethodCallHandler(
        const MethodChannel('dexterous.com/flutter/local_notifications'),
        (call) async {
      notificationCalls.add(call.method);
      switch (call.method) {
        case 'initialize':
          return true;
        case 'areNotificationsEnabled':
        case 'requestNotificationsPermission':
          return notificationsGranted;
        case 'pendingNotificationRequests':
        case 'getActiveNotifications':
          return <Map<Object?, Object?>>[];
        case 'getNotificationAppLaunchDetails':
          return null;
      }
      return null;
    });
    messenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/package_info'),
        (_) async => <String, Object?>{
              'appName': 'RepCoach AI',
              'packageName': 'com.ronganminh.repcoach',
              'version': '2.0.0',
              'buildNumber': '8',
              'buildSignature': '',
            });
  }

  void uninstall() {
    for (final name in _channels) {
      messenger.setMockMethodCallHandler(MethodChannel(name), null);
    }
    if (_previousCamera != null) CameraPlatform.instance = _previousCamera!;
  }
}

/// Lets plugin streams and `StreamSubscription.cancel` (which complete
/// outside Flutter's frame scheduling) run, then pumps until no frame is
/// scheduled — bounded, so a screen with a repeating animation (spinner,
/// pulsing badge) cannot hang the journey the way `pumpAndSettle` would.
Future<void> settle(WidgetTester tester) async {
  await tester
      .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
  await tester.pump();
  for (var i = 0; i < 40 && tester.binding.hasScheduledFrame; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump();
}

/// Pumps the real app root with the given SharedPreferences contents.
///
/// `{'onboarding_v1': true, 'app_language': 'en'}` opens the shell in
/// English; an empty map is a fresh install (onboarding, English).
Future<void> pumpApp(WidgetTester tester,
    {Map<String, Object> prefs = const {},
    Size size = const Size(393, 852),
    double textScale = 1}) async {
  SharedPreferences.setMockInitialValues(Map.of(prefs));
  await pumpAppKeepingPrefs(tester, size: size, textScale: textScale);
}

/// Like [pumpApp] but on the preferences already in the mock store (a
/// "relaunch" after data was written, e.g. a recovery draft).
Future<void> pumpAppKeepingPrefs(WidgetTester tester,
    {Size size = const Size(393, 852), double textScale = 1}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(const RepCounterApp());
  // The root shows a spinner until the saved language and onboarding flag
  // load (two microtasks with the mock store); do not pumpAndSettle on it.
  await tester.pump();
  await tester.pump();
  await settle(tester);
}

/// Unmounts the app so camera/stream subscriptions are cancelled before the
/// next test installs new fakes.
Future<void> closeApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester
      .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
  await tester.pumpAndSettle();
}

/// Every visible `Text` on screen, for copy assertions.
Iterable<String> visibleTexts(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '');

/// Scrolls lazily built lists until [finder] exists, then makes it visible.
Future<void> reveal(WidgetTester tester, Finder finder) async {
  // Stores (SQLite via FFI, preferences) complete on real time: give an
  // async-loaded widget a few rounds before scrolling for it.
  for (var i = 0; i < 3 && finder.evaluate().isEmpty; i++) {
    await settle(tester);
  }
  if (finder.evaluate().isEmpty) {
    final scrollables = find.byType(Scrollable);
    final n = scrollables.evaluate().length;
    for (var i = 0; i < n && finder.evaluate().isEmpty; i++) {
      // Down first, then up (the list may already be scrolled past it).
      for (final delta in const [160.0, -160.0]) {
        if (finder.evaluate().isNotEmpty) break;
        try {
          await tester.scrollUntilVisible(finder, delta,
              scrollable: scrollables.at(i), maxScrolls: 30);
        } catch (_) {
          // This scrollable did not reach it; try the other way / next one.
        }
      }
    }
  }
  if (finder.evaluate().isNotEmpty) {
    await tester.ensureVisible(finder.first);
    await tester.pump();
    // ensureVisible scrolls minimally and can leave the widget under the
    // app bar, where a tap would miss: nudge the list down a little.
    if (tester.getTopLeft(finder.first).dy < 100) {
      final list =
          find.ancestor(of: finder.first, matching: find.byType(Scrollable));
      if (list.evaluate().isNotEmpty) {
        await tester.drag(list.first, const Offset(0, 120));
        await tester.pump();
      }
    }
  }
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await reveal(tester, finder);
  expect(finder, findsOneWidget, reason: 'key $key');
  await tester.tap(finder);
  await settle(tester);
}

Future<void> tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await reveal(tester, finder);
  expect(finder, findsWidgets, reason: 'text "$text"');
  await tester.tap(finder.first);
  await settle(tester);
}

/// True once any of [finders] exists, giving async-loaded sections a few
/// rounds to appear.
Future<bool> anyAppears(WidgetTester tester, List<Finder> finders) async {
  for (var i = 0; i < 4; i++) {
    if (finders.any((f) => f.evaluate().isNotEmpty)) return true;
    await settle(tester);
  }
  return false;
}

/// Android system back.
Future<void> systemBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await settle(tester);
}
