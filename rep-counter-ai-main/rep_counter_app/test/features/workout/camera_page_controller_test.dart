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
    poseGate = null;
    poseCalls = 0;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter.baseflow.com/permissions/methods'),
        (_) async => granted ? 1 : 0);
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
    await tester.tap(find.text(S.vi.cameraAllowAndOpen));
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

  testWidgets('denied camera preserves settings and retry actions',
      (tester) async {
    camera.deny = true;
    await open(tester);
    await tester.tap(find.text(S.vi.cameraAllowAndOpen));
    await tester.pumpAndSettle();
    expect(find.text(S.vi.cameraDenied), findsOneWidget);
    expect(find.text(S.vi.openSettings), findsOneWidget);
    expect(find.text(S.vi.cameraGrantedRetry), findsOneWidget);
    await close(tester);
  });

  testWidgets('missing camera can retry and discard without saving',
      (tester) async {
    camera.noCamera = true;
    await open(tester);
    await tester.tap(find.text(S.vi.cameraAllowAndOpen));
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
    await tester.tap(find.text(S.vi.cameraAllowAndOpen));
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
