import 'dart:async';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/features/workout/presentation/widgets/workout_hud.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rep_counter_app/camera_page.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/core/i18n/locale_controller.dart';
import 'package:rep_counter_app/exercise.dart';
import 'package:rep_counter_app/features/workout/data/workout_history_store.dart';
import 'package:rep_counter_app/features/workout/presentation/result_page.dart';
import 'package:rep_counter_app/features/workout/presentation/widgets/camera_permission_view.dart';
import 'package:rep_counter_app/theme/app_theme.dart';

// Test-only native boundary: production still uses the real camera/ML Kit.
class FakeCamera extends CameraPlatform {
  final frames = StreamController<CameraImageData>.broadcast();
  final disposed = <int>[];
  int created = 0, requests = 0;
  bool noCamera = false, deny = false;
  Completer<void>? initializeGate;
  @override
  Future<List<CameraDescription>> availableCameras() async {
    requests++;
    if (deny) throw CameraException('CameraAccessDenied', 'Test denied');
    return noCamera
        ? []
        : [
            const CameraDescription(
                name: 'test-front',
                lensDirection: CameraLensDirection.front,
                sensorOrientation: 90)
          ];
  }

  @override
  Future<int> createCameraWithSettings(CameraDescription cameraDescription,
          MediaSettings mediaSettings) async =>
      ++created;
  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      const Stream.empty();
  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      Stream.value(CameraInitializedEvent(
          cameraId, 640, 480, ExposureMode.auto, true, FocusMode.auto, true));
  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) => Stream.multi((_) {});
  @override
  Future<void> initializeCamera(int cameraId,
      {ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown}) async {
    await initializeGate?.future;
  }

  @override
  bool supportsImageStreaming() => true;
  @override
  Stream<CameraImageData> onStreamedFrameAvailable(int cameraId,
          {CameraImageStreamOptions? options}) =>
      frames.stream;
  @override
  Future<void> dispose(int cameraId) async {
    disposed.add(cameraId);
  }

  @override
  Widget buildPreview(int cameraId) =>
      const ColoredBox(color: Colors.black, key: Key('native-preview'));
  void sendFrame() => frames.add(CameraImageData(
        format:
            const CameraImageFormat(ImageFormatGroup.bgra8888, raw: 1111970369),
        width: 2,
        height: 2,
        planes: [CameraImagePlane(bytes: Uint8List(16), bytesPerRow: 8)],
      ));
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late FakeCamera camera;
  late CameraPlatform previous;
  var granted = false;
  // permission_handler codes: 0 denied (iOS: not asked yet), 1 granted,
  // 2 restricted, 4 permanentlyDenied (iOS: denied earlier).
  var permissionStatus = 0, requestResult = 1;
  var permissionCalls = <String>[];
  Completer<List<Object?>>? poseGate;
  var poseCalls = 0;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    previous = CameraPlatform.instance;
    camera = FakeCamera();
    CameraPlatform.instance = camera;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter_tts'),
        (call) async => call.method == 'isLanguageAvailable' ? true : 1);
    granted = false;
    permissionStatus = 0;
    requestResult = 1;
    permissionCalls = <String>[];
    poseGate = null;
    poseCalls = 0;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter.baseflow.com/permissions/methods'),
        (call) async {
      permissionCalls.add(call.method);
      switch (call.method) {
        case 'checkPermissionStatus':
          return granted ? 1 : permissionStatus;
        case 'requestPermissions':
          if (requestResult == 1) granted = true;
          return {1: requestResult}; // 1 = Permission.camera
        case 'openAppSettings':
          return true;
      }
      return null;
    });
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('repcoach/diag'), (_) async => false);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('google_mlkit_pose_detector'), (call) async {
      if (call.method == 'vision#startPoseDetector') {
        poseCalls++;
        return poseGate == null ? <Object?>[] : await poseGate!.future;
      }
      return null;
    });
  });
  tearDown(() async {
    CameraPlatform.instance = previous;
    await camera.frames.close();
    for (final name in [
      'flutter.baseflow.com/permissions/methods',
      'repcoach/diag',
      'google_mlkit_pose_detector',
      'flutter_tts'
    ]) {
      binding.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), null);
    }
  });
  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final locale = LocaleController();
    addTearDown(locale.dispose);
    await tester.pumpWidget(LocaleScope(
        controller: locale,
        child: MaterialApp(
          theme: RepCoachTheme.dark(),
          home: Builder(
              builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const CameraPage(profile: pushUp))),
                      child: const Text('Open camera')))),
        )));
    await tester.tap(find.text('Open camera'));
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();
  }

  Future<void> settleNative(WidgetTester tester) async {
    await tester.pumpAndSettle();
    // StreamSubscription.cancel completes outside Flutter's frame scheduling.
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();
  }

  testWidgets('consent gate opens new camera HUD and saves through controller',
      (tester) async {
    await open(tester);
    expect(find.text(S.vi.cameraPermissionTitle), findsOneWidget);
    expect(camera.requests, 0);
    await tester.tap(find.text(S.vi.cameraContinue));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('native-preview')), findsOneWidget);
    expect(find.byKey(const Key('start-countdown')), findsOneWidget);
    expect(find.text('00:00 · Set 1 · Hít đất'), findsOneWidget);
    camera.sendFrame();
    await tester.pumpAndSettle();
    expect(poseCalls, 1);
    final hold = find
        .descendant(
            of: find.byType(HoldToFinish), matching: find.byType(Listener))
        .first;
    final gesture = await tester.startGesture(tester.getCenter(hold));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1100));
    await gesture.up();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();
    expect(find.byType(ResultPage), findsOneWidget);
    final record = (await WorkoutHistoryStore().load()).single;
    expect(
        record.poseFrames, 0); // Preparation does not affect workout quality.
    expect(record.lostFrames, 0);
    expect(record.reps, 0);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets(
      'already granted permission skips consent and lifecycle reopens preview',
      (tester) async {
    granted = true;
    await open(tester);
    expect(find.byKey(const Key('native-preview')), findsOneWidget);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await settleNative(tester);
    expect(camera.disposed, [1]);
    // Các trạng thái nền kế tiếp không được đóng cùng camera lần thứ hai.
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await settleNative(tester);
    expect(camera.disposed, [1]);
    // Flutter suppresses new frames while paused; verify native teardown here.
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settleNative(tester);
    expect(camera.created, 2);
    expect(find.byKey(const Key('native-preview')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('5.1.1(iv): no way out before the prompt; Continue always asks',
      (tester) async {
    await open(tester);
    expect(find.text(S.vi.cameraPermissionTitle), findsOneWidget);
    expect(find.text('Để sau'), findsNothing);
    expect(find.byTooltip('Đóng'), findsNothing);
    // System back does not leave or open the exit dialog either.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text(S.vi.cameraPermissionTitle), findsOneWidget);
    expect(find.text(S.vi.finishTitle), findsNothing);
    expect(camera.requests, 0);
    await tester.tap(find.text(S.vi.cameraContinue));
    await tester.pumpAndSettle();
    expect(
        permissionCalls.where((m) => m == 'requestPermissions'), hasLength(1),
        reason: 'Continue goes to the system prompt');
    expect(camera.requests, 1);
    await close(tester);
  });

  // App Store 5.1.1(iv), rejection of 1.0.0 (7).
  for (final answer in [4, 0]) {
    testWidgets(
        "Don't Allow in the system prompt returns to the previous screen "
        '(status $answer)', (tester) async {
      requestResult = answer;
      await open(tester);
      await tester.tap(find.text(S.vi.cameraContinue));
      await tester.pumpAndSettle();
      expect(find.text('Open camera'), findsOneWidget);
      expect(find.byType(CameraPage), findsNothing);
      expect(find.byType(CameraOffNotice), findsNothing);
      expect(find.text(S.vi.cameraOffMessage), findsNothing);
      expect(
          permissionCalls.where((m) => m == 'requestPermissions'), hasLength(1),
          reason: 'asked once, not again');
      expect(permissionCalls, isNot(contains('openAppSettings')));
      expect(camera.requests, 0);
      expect(await WorkoutHistoryStore().load(), isEmpty);
      await close(tester);
    });
  }

  for (final status in [4, 2]) {
    testWidgets(
        'camera off when the user starts: neutral notice, Back leaves '
        '(status $status)', (tester) async {
      permissionStatus = status;
      await open(tester);
      expect(find.byType(CameraOffNotice), findsOneWidget);
      expect(find.text(S.vi.cameraOffMessage), findsOneWidget);
      expect(find.text(S.vi.cameraPermissionTitle), findsNothing);
      expect(find.text(S.vi.cameraContinue), findsNothing);
      expect(find.text(S.vi.retry), findsNothing);
      expect(permissionCalls, isNot(contains('requestPermissions')));
      expect(permissionCalls, isNot(contains('openAppSettings')),
          reason: 'Settings opens only when the user taps the link');
      expect(camera.requests, 0);
      await tester.tap(find.text(S.vi.cameraBack));
      await tester.pumpAndSettle();
      expect(find.text('Open camera'), findsOneWidget);
      expect(find.text(S.vi.finishTitle), findsNothing);
      expect(await WorkoutHistoryStore().load(), isEmpty);
      await close(tester);
    });
  }

  testWidgets('system back on the camera-off notice leaves the workout',
      (tester) async {
    permissionStatus = 4;
    await open(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Open camera'), findsOneWidget);
    await close(tester);
  });

  testWidgets(
      'Open Settings is a plain link; back with access on opens the camera',
      (tester) async {
    permissionStatus = 4;
    await open(tester);
    await tester.tap(find.text(S.vi.openSettings));
    await tester.pumpAndSettle();
    expect(permissionCalls.where((m) => m == 'openAppSettings'), hasLength(1));
    expect(find.byType(CameraOffNotice), findsOneWidget);
    // Returning without changing anything keeps the notice, asks nothing.
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settleNative(tester);
    expect(find.byType(CameraOffNotice), findsOneWidget);
    expect(permissionCalls, isNot(contains('requestPermissions')));
    // Access turned on in Settings: the camera opens on return.
    granted = true;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settleNative(tester);
    expect(find.byKey(const Key('native-preview')), findsOneWidget);
    expect(permissionCalls, isNot(contains('requestPermissions')));
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('camera refused by the OS after access shows the neutral notice',
      (tester) async {
    camera.deny = true;
    await open(tester);
    await tester.tap(find.text(S.vi.cameraContinue));
    await tester.pumpAndSettle();
    expect(find.byType(CameraOffNotice), findsOneWidget);
    expect(find.text(S.vi.cameraOffMessage), findsOneWidget);
    expect(permissionCalls, isNot(contains('openAppSettings')));
    await close(tester);
  });

  testWidgets('missing camera can retry and discard without saving',
      (tester) async {
    camera.noCamera = true;
    await open(tester);
    await tester.tap(find.text(S.vi.cameraContinue));
    await tester.pumpAndSettle();
    expect(find.text(S.vi.cameraUnavailable), findsOneWidget);
    await tester.tap(find.text(S.vi.retry));
    await tester.pumpAndSettle();
    expect(camera.requests, 2);
    await tester.tap(find.byTooltip('Đóng'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.vi.finishDiscard));
    await tester.pumpAndSettle();
    expect(find.text('Open camera'), findsOneWidget);
    expect(await WorkoutHistoryStore().load(), isEmpty);
    await close(tester);
  });

  testWidgets(
      'camera initialized after background is disposed instead of attached',
      (tester) async {
    camera.initializeGate = Completer<void>();
    await open(tester);
    await tester.tap(find.text(S.vi.cameraContinue));
    await tester.pump();
    await tester.pump();
    expect(camera.created, 1);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    camera.initializeGate!.complete();
    await settleNative(tester);
    expect(camera.disposed, [1]);
    expect(find.byKey(const Key('native-preview')), findsNothing);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settleNative(tester);
    expect(camera.created, 2);
    expect(find.byKey(const Key('native-preview')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets(
      'late pose is ignored after background and new camera can process frames',
      (tester) async {
    granted = true;
    await open(tester);
    poseGate = Completer<List<Object?>>();
    camera.sendFrame();
    await tester.pump();
    expect(poseCalls, 1);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await settleNative(tester);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settleNative(tester);
    camera.sendFrame();
    await tester.pump();
    expect(poseCalls, 1); // Detector stays serialized while old call finishes.
    poseGate!.complete([]);
    await tester.pumpAndSettle();
    poseGate = null;
    camera.sendFrame();
    await tester.pumpAndSettle();
    final hold = find
        .descendant(
            of: find.byType(HoldToFinish), matching: find.byType(Listener))
        .first;
    final gesture = await tester.startGesture(tester.getCenter(hold));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1100));
    await gesture.up();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await settleNative(tester);
    expect((await WorkoutHistoryStore().load()).single.poseFrames, 0);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets(
      'finish freezes results while an old detector call is still pending',
      (tester) async {
    granted = true;
    await open(tester);
    poseGate = Completer<List<Object?>>();
    camera.sendFrame();
    await tester.pump();
    expect(poseCalls, 1);
    final hold = find
        .descendant(
            of: find.byType(HoldToFinish), matching: find.byType(Listener))
        .first;
    final gesture = await tester.startGesture(tester.getCenter(hold));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1100));
    await gesture.up();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await settleNative(tester);
    expect(find.byType(ResultPage), findsOneWidget);
    poseGate!.complete([]);
    await tester.pumpAndSettle();
    expect((await WorkoutHistoryStore().load()).single.poseFrames, 0);
    expect(tester.takeException(), isNull);
    await close(tester);
  });
  testWidgets('manual pause blocks frames, survives background, resumes once',
      (tester) async {
    granted = true;
    await open(tester);
    camera.sendFrame();
    await tester.pumpAndSettle();
    expect(poseCalls, 1);
    await tester.tap(find.byKey(const Key('pause-workout')));
    await tester.pumpAndSettle();
    camera.sendFrame();
    await tester.pumpAndSettle();
    expect(poseCalls, 1);
    expect(find.text('Đã tạm dừng'), findsOneWidget);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await settleNative(tester);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settleNative(tester);
    expect(camera.created, 1);
    await tester.tap(find.byKey(const Key('resume-workout')));
    await settleNative(tester);
    expect(camera.created, 2);
    camera.sendFrame();
    await tester.pumpAndSettle();
    expect(poseCalls, 2);
    await close(tester);
  });
}
