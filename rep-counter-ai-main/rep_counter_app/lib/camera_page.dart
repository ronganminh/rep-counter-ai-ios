/// Camera + ML Kit Pose + đếm rep thời gian thực.
library;

import 'dart:async';
import 'dart:io' show Directory, File, Platform;
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';

import 'core/i18n/app_strings.dart';
import 'core/services/training_preferences.dart';
import 'core/services/workout_feedback.dart';
import 'features/diag/diag_recorder.dart';
import 'core/i18n/locale_controller.dart';
import 'exercise.dart';
import 'features/pose/domain/pose_mapper.dart';
import 'features/workout/data/calibration_store.dart';
import 'features/workout/application/workout_controller.dart';
import 'features/workout/application/workout_ui_state.dart';
import 'features/workout/domain/quality_thresholds.dart';
import 'features/workout/domain/rep_tracker.dart';
import 'features/workout/domain/rep_quality_analyzer.dart';
import 'features/workout/domain/rep_metric.dart';
import 'features/workout/domain/workout_mode.dart';
import 'widgets/product_ui.dart';
import 'theme/app_colors.dart';
import 'features/workout/presentation/widgets/workout_hud.dart';
import 'features/workout/presentation/widgets/camera_permission_view.dart';
import 'features/workout/presentation/result_page.dart';
import 'overlay_painter.dart';
import 'placement.dart';
import 'rep_counter.dart';
import 'features/workout/presentation/exercise_help_sheet.dart';

/// Chuyển `Pose` của ML Kit sang hệ toạ độ widget.
///
/// Phần hình học nằm ở `features/pose/domain/pose_mapper.dart` để test được mà
/// không cần camera hay ML Kit; ở đây chỉ còn phần bám vào kiểu dữ liệu ML Kit.
Landmarks remapPose(Pose pose, PoseMapper mapper) {
  final out = <PoseLandmarkType, PoseLandmark>{};
  pose.landmarks.forEach((t, l) {
    final p = mapper.map(l.x, l.y);
    out[t] = PoseLandmark(
        type: t, x: p.dx, y: p.dy, z: l.z, likelihood: l.likelihood);
  });
  return Landmarks(out);
}

class _CiWorkoutClock implements WorkoutClock {
  Duration _elapsed = Duration.zero;
  bool _running = false;

  set elapsed(Duration value) {
    if (_running) _elapsed = value;
  }

  @override
  Duration get elapsed => _elapsed;
  @override
  bool get isRunning => _running;
  @override
  void start() => _running = true;
  @override
  void stop() => _running = false;
}

class CameraPage extends StatefulWidget {
  const CameraPage({
    super.key,
    required this.profile,
    this.targetReps,
    this.timedChallenge,
    this.challengeBestReps,
    this.ciVideoPath,
  });

  final ExerciseProfile profile;
  final int? targetReps;
  final TimedChallengeConfig? timedChallenge;
  final int? challengeBestReps;

  /// CI-only camera substitute. When set, the production workout screen and
  /// production rep pipeline stay intact; only the camera image source is
  /// replaced by a prerecorded video from the app sandbox.
  final String? ciVideoPath;

  @override
  State<CameraPage> createState() => _CameraPageState();
}

enum _CameraState {
  awaitingConsent,
  initializing,
  ready,
  denied,
  unavailable,

  /// App đang ở nền, camera đã thu lại.
  ///
  /// Phải là trạng thái RIÊNG, không dùng lại `initializing`: `_start()`
  /// mở đầu bằng `if (_cameraState == initializing) return;` để chặn mở
  /// camera hai lần, nên nếu lúc thu camera cũng đặt `initializing` thì
  /// lúc quay lại `_start()` thoát ngay và người dùng kẹt ở màn hình
  /// "Đang mở camera…" mãi mãi.
  suspended,
}

class _CameraPageState extends State<CameraPage>
    with WidgetsBindingObserver {
  static const _videoFrames = MethodChannel('rep_counter/video_frames');

  CameraController? _cam;
  VideoPlayerController? _ciVideo;
  final _ciTrackingClock = _CiWorkoutClock();
  final _ciSessionClock = _CiWorkoutClock();
  int? _ciSavedReps;
  late final PoseDetector _detector;
  late GuideZone _guide;
  late S _strings;

  final _statusDebouncer = StatusDebouncer();
  late final WorkoutController _workout;
  late final WorkoutFeedback _feedback;
  TrainingPreferences _preferences = const TrainingPreferences();
  bool _preferencesLoaded = false, _settingsBusy = false;
  bool _wasAcceptingReps = false;
  int? _lastCountdown;
  bool _sessionArmed = false;
  SessionState _lastSetState = SessionState.idle;
  final _merger = TwoArmMerger();
  // Phải dao động ít nhất bằng MỘT rep hợp lệ của bài. Mặc định 0.15 của
  // Calibrator là theo thang tín hiệu 0..1 (cuốn tạ); với góc khuỷu tính bằng
  // độ thì đứng yên rung tay cũng vượt, và ngưỡng rơi vào vùng nhiễu -> rep ma
  // được lưu luôn cho các buổi sau.
  late final _calibrator = Calibrator(minSpan: p.minAmplitude);
  /// `RepTracker` bọc quanh `RepCounter` — cùng phép đếm, nhưng gom thêm số liệu
  /// từng rep (biên độ, nhịp, lệch hai tay, độ tin cậy pose) để dựng
  /// `WorkoutSummary`. Không có nó, AI chỉ biết được số rep chứ không biết tập
  /// tốt hay xấu.
  late RepTracker _trackL, _trackR;
  late RollingMean _smoothL, _smoothR;

  /// Giữ lại để vẽ vạch ngưỡng trên đồ thị; sau hiệu chỉnh thì đổi theo.
  late double _repHi, _repLo, _repAmp;

  Landmarks? _landmarks;
  double _repFlash = 0;
  bool _busy = false;
  bool _calibrating = false;
  bool _calibrationSaving = false;
  /// Đã hiệu chỉnh ngưỡng theo người dùng chưa — ghi vào CalibrationSnapshot
  /// để sau này biết số liệu chất lượng dựa trên mốc của ai.
  bool _calibrated = false;

  static const _calibrationStore = CalibrationStore();

  /// Người dùng đã tự hiệu chỉnh trong phiên này chưa.
  ///
  /// Ngưỡng lưu sẵn nạp bất đồng bộ. Nếu người dùng bấm hiệu chỉnh trước
  /// khi nạp xong, kết quả nạp về sẽ đè lên ngưỡng vừa đo — cờ này chặn
  /// đúng tình huống đó.
  bool _calibratedThisSession = false;
  bool _calibrationLoadStarted = false;
  /// Thời điểm gần nhất tư thế còn ĐẠT. Bộ đếm vẫn chạy trong [_placementGrace]
  /// sau mốc này.
  ///
  /// Khung hướng dẫn là khung TĨNH nên không dùng làm cổng cho từng frame được:
  /// lúc xuống đáy, vai và cổ tay tự nhiên ra ngoài khung. Nhưng cũng không thể
  /// bỏ cổng hẳn — bản trước dùng một cờ bật-một-lần-không-bao-giờ-tắt, nên sau
  /// khi vào đúng tư thế một lần là app đếm mãi, kể cả khi người dùng đứng dậy
  /// đi chỗ khác. Trên 7 video thật, đúng kiểu chuyển động đó sinh 113 rep giả.
  Duration? _lastPlacementOk;
  static const _placementGrace = Duration(seconds: 2);

  // Async native operations must not attach an old camera after backgrounding.
  int _cameraEpoch = 0;
  bool _inBackground = false;
  Future<void>? _cameraShutdown;

  // Ghi man hinh chi co o ban `diag`. Ban store: kenh tra available = false
  // nen `_diagAvailable` mai la false va nut khong bao gio hien.
  bool _diagAvailable = false;
  bool _diagRecording = false;
  bool _repThisFrame = false;
  bool _allowPop = false;
  bool _manualPaused = false, _goalBanner = false;
  bool _challengeAutoFinishRequested = false;
  int? _lastChallengeCountdownSecond;
  Timer? _pauseTimer, _goalTimer;
  _CameraState _cameraState = _CameraState.awaitingConsent;

  ExerciseProfile get p => widget.profile;
  WorkoutUiState get _ui => _workout.state;
  bool get _finishing => _ui.isFinishing;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _feedback = WorkoutFeedback(onVoiceUnavailable: () {
      if (mounted) { _notify(context.tr('Không có giọng đọc phù hợp trên máy. Bạn vẫn có thể tập với số trên màn hình.',
        'A matching voice is unavailable on this device. On-screen counting still works.')); }
    });
    _loadTrainingPreferences();
    _workout = WorkoutController(
      profile: p,
      targetReps: widget.targetReps,
      timedChallenge: widget.timedChallenge,
      trackingClock: widget.ciVideoPath == null ? null : _ciTrackingClock,
      clock: widget.ciVideoPath == null ? null : _ciSessionClock,
    )..addListener(_workoutChanged);
    // Ban store tra ve false ngay, nen nut ghi khong bao gio hien o ban do.
    DiagRecorder.instance.available.then((ok) {
      if (mounted && ok) setState(() => _diagAvailable = true);
    });
    _detector = PoseDetector(
      options: PoseDetectorOptions(
        mode: widget.ciVideoPath == null
            ? PoseDetectionMode.stream
            : PoseDetectionMode.single,
        model: PoseDetectionModel.base,
      ),
    );
    _buildCounters(p.repHi, p.repLo, p.minAmplitude);
    if (widget.ciVideoPath != null) {
      _cameraState = _CameraState.initializing;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_startCiVideo());
      });
    } else {
      _skipConsentIfAlreadyGranted();
    }
  }

  Future<void> _loadTrainingPreferences() async {
    try { _preferences = await TrainingPreferences.load(); } catch (_) { /* Defaults still work for this session. */ }
    if (!mounted) return;
    _preferencesLoaded = true;
    _feedback.configure(_preferences, context.language);
    setState(() {});
  }

  Future<void> _toggleVoice() async {
    if (!_preferencesLoaded || _settingsBusy) return;
    setState(() => _settingsBusy = true);
    try {
      _preferences = await _preferences.update(voice: !_preferences.voice);
      if (!mounted) return;
      _feedback.configure(_preferences, context.language);
    } catch (_) {
      if (mounted) _notify(context.tr('Chưa lưu được tùy chọn giọng đọc.', 'Could not save the voice preference.'));
    } finally { if (mounted) setState(() => _settingsBusy = false); }
  }

  void _resetTransient() {
    _trackL.onInterrupted(_workout.frameTime, RepAbortReason.placementLost);
    _trackR.onInterrupted(_workout.frameTime, RepAbortReason.placementLost);
    _smoothL.reset();
    _smoothR.reset();
    _merger.reset();
    _lastPlacementOk = null;
  }

  void _workoutChanged() {
    if (!mounted) return;
    final accepting = _workout.acceptsReps;
    if (accepting != _wasAcceptingReps) {
      _wasAcceptingReps = accepting;
      _cameraEpoch++;
      _resetTransient();
    }
    if (_ui.sessionState != _lastSetState) {
      _lastSetState = _ui.sessionState;
      if (accepting && _lastSetState != SessionState.idle) {
        _feedback.setBoundary(_lastSetState == SessionState.working);
      }
    }
    final countdown = _ui.countdown;
    if (countdown != _lastCountdown) {
      _lastCountdown = countdown;
      if (countdown != null) { _feedback.countdown(countdown); }
      else { _feedback.stop(); }
    }
    if (_ui.sessionStarted && !_sessionArmed) {
      _sessionArmed = true;
      _feedback.started();
    }

    final challengeSecond =
        _ui.isFinalTenSeconds ? _ui.challengeRemainingSeconds : null;
    if (challengeSecond != _lastChallengeCountdownSecond) {
      _lastChallengeCountdownSecond = challengeSecond;
      if (challengeSecond != null && challengeSecond > 0) {
        _feedback.challengeCountdown(challengeSecond);
      }
    }

    if (_ui.challengeExpired && !_challengeAutoFinishRequested) {
      _challengeAutoFinishRequested = true;
      unawaited(Future<void>.microtask(_finishWorkout));
    }
    setState(() {});
  }

  void _syncCalibration() => _workout.calibrationChanged(
    collecting: _calibrating,
    calibrated: _calibrated,
    samples: _calibrator.sampleCount,
  );

  /// Thông báo một lần cho các sự kiện hiệu chỉnh.
  ///
  /// KHÔNG dùng placementMessage cho việc này: controller cập nhật nó
  /// ở MỖI khung hình, nên mọi câu đặt vào đó biến mất sau chưa tới một phần
  /// mười giây. Vì vậy các thông báo hiệu chỉnh trước giờ gần như không ai
  /// nhìn thấy — bấm "Hiệu chỉnh" xong không có phản hồi gì.
  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 4),
      ));
  }

  /// Nạp ngưỡng đã hiệu chỉnh lần trước, nếu có.
  Future<void> _loadSavedCalibration() async {
    final saved = await _calibrationStore.load(p.id);
    if (saved == null || !mounted || _calibratedThisSession) return;
    if (!isPlausibleCalibration(saved, profileMinAmplitude: p.minAmplitude)) {
      return;
    }
    setState(() {
      _buildCounters(saved.repHi, saved.repLo, saved.minAmplitude);
      _calibrated = saved.source == CalibrationSource.userCalibration;
    });
    _syncCalibration();
    if (!_calibrated) return;
    // Đợi hết khung hình hiện tại rồi mới báo: didChangeDependencies chạy
    // trước khi Scaffold có mặt, ScaffoldMessenger lúc đó chưa tìm thấy.
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => _notify(_strings.calibrateRestored));
  }

  /// Thu camera khi app xuống nền, mở lại khi quay về.
  ///
  /// Trước đây không xử lý gì: bấm Home giữa buổi tập thì camera và MediaPipe
  /// vẫn chạy nền — đo trên LG V60 là hơn 2 lõi CPU chạy không công, máy nóng
  /// và tụt pin. Tệ hơn, Android có quyền thu hồi camera của app đang ở nền,
  /// lúc quay lại sẽ là màn hình đen chứ không phải preview.
  ///
  /// Chỉ xử lý `paused`/`hidden`/`detached`, KHÔNG xử lý `inactive`: `inactive`
  /// bắn ra cả khi chỉ kéo thanh thông báo xuống, dựng lại camera cho một cú
  /// kéo nhầm thì giật hơn là để yên.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _inBackground = true;
        _suspendCamera();
      case AppLifecycleState.resumed:
        _inBackground = false;
        _resumeCamera();
      case AppLifecycleState.inactive:
        break;
    }
  }

  Future<void> _suspendCamera() async {
    _cameraEpoch++;
    _feedback.stop();
    _workout.pause();
    final cam = _cam;
    if (cam == null) {
      if (mounted && _cameraState == _CameraState.initializing) {
        setState(() => _cameraState = _CameraState.suspended);
      }
      return;
    }

    // Đồng hồ dừng theo, nên thời lượng buổi tập không cộng khoảng thời gian
    // người dùng đi làm việc khác. SessionTracker trong controller cũng dùng đồng hồ này nên
    // không bị hiểu nhầm thành một quãng nghỉ dài rồi tự chốt set.

    // Bỏ dở chu kỳ đang đếm. Không làm thì cái đáy trước khi rời app sẽ ghép
    // với cái đỉnh sau khi quay lại thành một rep ma.
    final now = _workout.frameTime;
    _trackL.onInterrupted(now, RepAbortReason.placementLost);
    _trackR.onInterrupted(now, RepAbortReason.placementLost);
    _smoothL.reset();
    _smoothR.reset();
    _lastPlacementOk = null;

    setState(() {
      _cam = null;
      _landmarks = null;
      _cameraState = _CameraState.suspended;
    });
    final shutdown = _releaseCamera(cam);
    _cameraShutdown = shutdown;
    await shutdown;
    if (identical(_cameraShutdown, shutdown)) _cameraShutdown = null;
    // An in-flight detector owns _busy until its finally block completes.
  }

  Future<void> _releaseCamera(CameraController cam) async {
    try {
      if (cam.value.isStreamingImages) await cam.stopImageStream();
    } catch (_) { /* Stream may have already stopped during teardown. */ }
    try {
      await cam.dispose();
    } catch (error) {
      debugPrint('camera dispose: $error');
    }
  }

  Future<void> _resumeCamera() async {
    await _cameraShutdown;
    if (!mounted || _inBackground || _manualPaused || _cam != null || _finishing) return;
    // Chưa từng mở camera (còn ở màn giải thích) thì đừng tự mở.
    if (!_workout.hasStarted && _cameraState != _CameraState.suspended) return;
    await _start();
  }

  /// Đã cấp quyền camera rồi thì vào thẳng, đừng hỏi lại.
  ///
  /// `_cameraState` trước đây luôn bắt đầu ở `awaitingConsent`, nên mỗi lần vào
  /// buổi tập là phải bấm "Cho phép và mở camera" một lần nữa, dù đã cấp quyền
  /// từ lâu. Người dùng đọc câu "Cần quyền camera" thì tưởng quyền bị mất.
  ///
  /// Việc này KHÔNG phá yêu cầu của Google Play là phải giải thích trước khi
  /// xin quyền: màn hình giải thích chỉ bị bỏ qua khi quyền ĐÃ được cấp.
  Future<void> _skipConsentIfAlreadyGranted() async {
    try {
      if (!await Permission.camera.isGranted) return;
    } catch (_) {
      // Không đọc được trạng thái quyền thì cứ hiện màn giải thích.
      return;
    }
    if (mounted) await _start();
  }

  String get _ciResultPath =>
      '${Directory.systemTemp.path}/ci-video-result.txt';

  Future<void> _writeCiStatus(String line) async {
    if (widget.ciVideoPath == null) return;
    try {
      await File(_ciResultPath).writeAsString('$line\n', flush: true);
    } catch (error) {
      debugPrint('[CI_VIDEO_ERROR] status_write_failed error=$error');
    }
  }

  Future<void> _startCiVideo() async {
    final path = widget.ciVideoPath;
    if (path == null || path.isEmpty) return;
    final input = File(path);
    if (!await input.exists()) {
      final line = '[CI_VIDEO_ERROR] missing_file path=$path';
      debugPrint(line);
      await _writeCiStatus(line);
      if (mounted) setState(() => _cameraState = _CameraState.unavailable);
      return;
    }

    VideoPlayerController? controller;
    try {
      controller = VideoPlayerController.file(input);
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      _ciVideo = controller;
      _workout.cameraStarted();
      _workout.requestStart();
      setState(() => _cameraState = _CameraState.ready);
      await _writeCiStatus(
        '[CI_VIDEO_STATUS] production_workout_started duration_ms=${controller.value.duration.inMilliseconds}',
      );
      await _runCiVideo(controller, path);
    } catch (error) {
      final line = '[CI_VIDEO_ERROR] production_workout_failed error=$error';
      debugPrint(line);
      await _writeCiStatus(line);
      if (mounted) setState(() => _cameraState = _CameraState.unavailable);
    }
  }

  Future<void> _runCiVideo(
      VideoPlayerController controller, String path) async {
    const stepMs = 200;
    final durationMs = controller.value.duration.inMilliseconds;
    final rawSize = controller.value.size;
    var processed = 0;

    for (var atMs = 0; atMs <= durationMs; atMs += stepMs) {
      if (!mounted || !identical(_ciVideo, controller)) return;
      final at = Duration(milliseconds: atMs);
      _ciTrackingClock.elapsed = at;
      _ciSessionClock.elapsed = at;

      // Keep the production workout UI visually attached to the same source.
      // Updating preview once per second avoids doubling the cost of pose
      // extraction while the overlay still updates at 5 FPS.
      if (atMs % 1000 == 0) {
        await controller.seekTo(at);
      }

      final thumbnail = await _videoFrames.invokeMethod<String>('frame', {
        'path': path,
        'timeMs': atMs,
        'maxWidth': 480,
      });

      Pose? pose;
      var poseImageSize = rawSize;
      if (thumbnail != null) {
        final bytes = await File(thumbnail).readAsBytes();
        final decoded = img.decodeImage(bytes);
        if (decoded != null) {
          poseImageSize =
              Size(decoded.width.toDouble(), decoded.height.toDouble());
        }
        final poses =
            await _detector.processImage(InputImage.fromFilePath(thumbnail));
        if (poses.isNotEmpty) pose = poses.first;
      }

      if (!mounted || !identical(_ciVideo, controller)) return;
      _consumePose(
        pose,
        rawImageSize: poseImageSize,
        rotationDegrees: 0,
        mirror: false,
      );
      processed++;

      if (atMs % 5000 == 0) {
        await _writeCiStatus(
          '[CI_VIDEO_STATUS] production_workout at_ms=$atMs total_ms=$durationMs frames=$processed reps=${_ui.reps} phase=${_ui.phase.name}',
        );
      }
    }

    await controller.seekTo(controller.value.duration);
    final reps = _ui.reps;
    await _writeCiStatus(
      '[CI_VIDEO_STATUS] production_workout_finishing frames=$processed reps=$reps',
    );

    // Exercise the same save/result transition as a real workout too.
    await _finishWorkout();
    await Future<void>.delayed(const Duration(seconds: 2));
    final savedReps = _ciSavedReps;
    if (savedReps == null) {
      await _writeCiStatus(
        '[CI_VIDEO_ERROR] missing_saved_rep_count hud_reps=$reps',
      );
      return;
    }
    if (savedReps != reps) {
      await _writeCiStatus(
        '[CI_VIDEO_ERROR] rep_count_mismatch hud_reps=$reps saved_reps=$savedReps',
      );
      return;
    }
    await _writeCiStatus(
      '[CI_VIDEO_RESULT] mode=production_workout frames=$processed hud_reps=$reps saved_reps=$savedReps result_reps=$savedReps duration_ms=$durationMs',
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // guideFor cần chuỗi theo ngôn ngữ, mà InheritedWidget chưa dùng được trong
    // initState. Ở đây còn tự dựng lại khi người dùng đổi ngôn ngữ giữa chừng.
    _strings = context.s;
    if (_preferencesLoaded) _feedback.configure(_preferences, context.language);
    _guide = guideFor(p, _strings);
    // Nạp ở đây chứ không ở initState: hàm nạp báo thông báo theo `_strings`, mà
    // `_strings` là `late` và chỉ có giá trị từ didChangeDependencies trở đi.
    if (!_calibrationLoadStarted) {
      _calibrationLoadStarted = true;
      _loadSavedCalibration();
    }
  }

  void _buildCounters(double hi, double lo, double amp) {
    RepTracker make() => RepTracker(
          counter: RepCounter(
              hi: hi,
              lo: lo,
              minAmplitude: amp,
              minPeriod: p.minPeriod,
              startFromTop: p.startFromTop),
          torsoDeviationDeg: p.torsoAngleTolerance,
        );
    _trackL = make();
    _trackR = make();
    _repHi = hi;
    _repLo = lo;
    _repAmp = amp;
    _smoothL = RollingMean(p.smoothWindow);
    _smoothR = RollingMean(p.smoothWindow);
  }

  /// Độ lệch trục thân so với hướng bài tập yêu cầu (độ).
  double? _torsoDeviation(Landmarks lm) {
    final sh = lm.mid(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder,
        minLikelihood: p.minLikelihood);
    final hp = lm.mid(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip,
        minLikelihood: p.minLikelihood);
    if (sh == null || hp == null) return null;
    final d = sh - hp;
    if (d.distance < 1e-3) return null;
    final ang = math.atan2(d.dy.abs(), d.dx.abs()) * 180 / math.pi;
    final want = p.orientation == BodyOrientation.horizontal ? 0.0 : 90.0;
    return (ang - want).abs();
  }

  /// Độ tin cậy trung bình của các landmark bài tập cần.
  double _poseConfidence(Landmarks lm) {
    var sum = 0.0;
    var n = 0;
    for (final t in p.requiredLandmarks) {
      final l = lm.get(t);
      if (l != null) {
        sum += l.likelihood;
        n++;
      }
    }
    return n == 0 ? 0 : sum / n;
  }

  /// Gom event của tracker. RepCompleted chỉ bổ sung presentation feedback
  /// sau khi production counter đã chấp nhận rep; RepAborted không đổi tổng rep.
  void _handle(List<RepEvent> events, Duration now,
      {required bool merge, required String arm}) {
    for (final e in events) {
      if (e is RepAborted) {
        if (!_repThisFrame) _workout.reportRepAborted(e.reason);
        continue;
      }
      if (e is! RepCompleted) continue;
      if (merge && !_merger.accept(arm, now)) continue;
      if (!_workout.acceptsReps) continue;
      final reachedGoal = _workout.acceptRep(e.observation, now);
      final flags = const RepQualityAnalyzer().analyze(e.observation);
      final cue = flags.contains(RepQualityFlag.poseUnreliable)
          ? context.tr('Giữ người trong khung hình', 'Keep your body in view')
          : flags.contains(RepQualityFlag.bodyAlignmentLost)
              ? context.tr('Giữ thân người ổn định', 'Keep your torso steady')
              : flags.contains(RepQualityFlag.tooFast)
                  ? context.tr('Chậm lại một chút', 'Slow down a little')
                  : null;
      _feedback.rep(_ui.reps, goalReached: reachedGoal, cue: cue, at: now);
      _repThisFrame = true;
      _repFlash = 1;
      if (reachedGoal) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _showGoalReached());
      }
    }
  }

  Future<void> _start() async {
    await _cameraShutdown;
    if (!mounted || _inBackground || _finishing || _ui.phase == WorkoutUiPhase.aborted ||
        _cameraState == _CameraState.initializing) {
      return;
    }
    final epoch = ++_cameraEpoch;
    setState(() {
      _cameraState = _CameraState.initializing;
    });
    CameraController? ctrl;
    try {
      final cams = await availableCameras();
      if (!_cameraRequestCurrent(epoch)) return;
      if (cams.isEmpty) {
        throw CameraException('noCamera', 'Không tìm thấy camera');
      }
      final cam = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cams.first,
      );
      ctrl = CameraController(
        cam,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await ctrl.initialize();
      if (!_cameraRequestCurrent(epoch)) {
        await ctrl.dispose();
        return;
      }
      await ctrl.startImageStream(_onFrame);
      if (!_cameraRequestCurrent(epoch)) {
        await ctrl.dispose();
        return;
      }
      // Chỉ đặt mốc thời gian ở lần mở ĐẦU TIÊN. `_start()` còn được gọi lại
      // khi app quay về từ nền; tạo Stopwatch mới ở đó sẽ xoá sạch thời lượng
      // và làm buổi tập bắt đầu lại từ 0.
      _workout.cameraStarted();
      setState(() {
        _cam = ctrl;
        _cameraState = _CameraState.ready;
      });
    } on CameraException catch (error) {
      await ctrl?.dispose();
      if (!_cameraRequestCurrent(epoch)) return;
      final code = error.code.toLowerCase();
      setState(() {
        _cameraState = code.contains('denied') || code.contains('access')
            ? _CameraState.denied
            : _CameraState.unavailable;
        debugPrint('camera: ${error.code} ${error.description}');
      });
    } catch (error) {
      await ctrl?.dispose();
      if (_cameraRequestCurrent(epoch)) {
        setState(() {
          _cameraState = _CameraState.unavailable;
          debugPrint('camera: $error');
        });
      }
    }
  }

  bool _cameraRequestCurrent(int epoch) => mounted && !_inBackground &&
      epoch == _cameraEpoch && !_finishing && _ui.phase != WorkoutUiPhase.aborted;

  Future<void> _onFrame(CameraImage image) async {
    if (_busy || !mounted || !_workout.acceptsFrames) return;
    final camera = _cam;
    if (camera == null) return;
    final epoch = _cameraEpoch;
    _busy = true;
    try {
      final input = _toInputImage(image);
      if (input == null) return;
      final poses = await _detector.processImage(input);
      if (!mounted || epoch != _cameraEpoch || !identical(camera, _cam) || !_workout.acceptsFrames) return;
      _consume(poses.isEmpty ? null : poses.first, image);
    } catch (e) {
      debugPrint('pose error: $e');
    } finally {
      _busy = false;
    }
  }

  void _consume(Pose? pose, CameraImage image) {
    final camera = _cam;
    if (camera == null) return;
    _consumePose(
      pose,
      rawImageSize: Size(image.width.toDouble(), image.height.toDouble()),
      rotationDegrees: camera.description.sensorOrientation,
      mirror: camera.description.lensDirection == CameraLensDirection.front,
    );
  }

  void _consumePose(
    Pose? pose, {
    required Size rawImageSize,
    required int rotationDegrees,
    required bool mirror,
  }) {
    final view = context.size ?? MediaQuery.sizeOf(context);
    // PoseMapper tự hoán đổi rộng/cao theo góc xoay — đừng xoay sẵn ở đây nữa.
    final mapper = PoseMapper(
      rawImageSize: rawImageSize,
      viewSize: view,
      rotationDegrees: rotationDegrees,
      mirror: mirror,
    );
    final lm = pose == null ? null : remapPose(pose, mapper);

    final placement = evaluatePlacement(
      profile: p,
      lm: lm,
      viewSize: view,
      guide: _guide,
      strings: _strings,
    );
    final status = _statusDebouncer.update(placement.status);
    final now = _workout.frameTime;
    if (status.canCount) _lastPlacementOk = now;
    final canCount = _lastPlacementOk != null &&
        now - _lastPlacementOk! <= _placementGrace;


    double sig = double.nan;
    var signalRestored = false;
    bool? gateOk;
    if (lm != null) {
      final raw = p.signal(lm, p.minLikelihood);
      gateOk = p.countGate?.call(lm, p.minLikelihood);

      if (canCount && gateOk != false) {
        final torso = _torsoDeviation(lm);
        final conf = _poseConfidence(lm);
        PoseSample sample(double? v) => PoseSample(
              at: now,
              signal: v,
              leftAngle: raw.left,
              rightAngle: raw.right,
              torsoDeviationDeg: torso,
              poseConfidence: conf,
            );

        if (p.combineArms == CombineArms.mean) {
          // Hai tay ràng buộc cứng cùng pha -> lấy trung bình rồi đếm MỘT lần.
          // Đếm riêng ở đây sẽ nhân đôi rep mỗi khi pose gán nhầm trái/phải.
          final vals = [raw.left, raw.right].whereType<double>().toList();
          final v = vals.isEmpty
              ? null
              : _smoothL.add(vals.reduce((a, b) => a + b) / vals.length);
          if (v != null) {
            sig = v;
            signalRestored = true;
          }
          if (_workout.acceptsReps) _handle(_trackL.update(sample(v)), now, merge: false, arm: 'M');
        } else {
          final vl = raw.left == null ? null : _smoothL.add(raw.left!);
          if (vl != null) {
            sig = vl;
            signalRestored = true;
          }
          if (_workout.acceptsReps) _handle(_trackL.update(sample(vl)), now, merge: true, arm: 'L');

          final vr = raw.right == null ? null : _smoothR.add(raw.right!);
          if (sig.isNaN && vr != null) sig = vr;
          if (vr != null) signalRestored = true;
          if (_workout.acceptsReps) _handle(_trackR.update(sample(vr)), now, merge: true, arm: 'R');
        }
        if (_calibrating && !sig.isNaN) _calibrator.add(sig);
      } else {
        // Rời tư thế hợp lệ -> huỷ chu kỳ đang dở, đừng ghép đáy cũ với đỉnh mới.
        final leftAbort =
            _trackL.onInterrupted(now, RepAbortReason.placementLost);
        final rightAbort =
            _trackR.onInterrupted(now, RepAbortReason.placementLost);
        if (leftAbort != null) {
          _handle([leftAbort], now, merge: false, arm: 'L');
        }
        if (rightAbort != null) {
          _handle([rightAbort], now, merge: false, arm: 'R');
        }
        _smoothL.reset();
        _smoothR.reset();
      }
    }

    if (signalRestored) _workout.repSignalRestored();

    _workout.frameProcessed(
      at: now,
      poseFound: pose != null,
      countable: canCount,
      status: status,
      message: placement.detail,
      calibrationSamples: _calibrator.sampleCount,
    );
    // Keep the legacy placement grace: a normal rep can briefly leave the guide.
    if (_workout.acceptsReps && !canCount && !_repThisFrame) {
      _feedback.cue(status.message(_strings), now);
    }
    if (_repFlash > 0) _repFlash = (_repFlash - 0.08).clamp(0.0, 1.0);

    if (_diagRecording) {
      DiagRecorder.instance.row(
        at: now,
        raw: lm == null ? null : p.signal(lm, p.minLikelihood).left,
        smooth: sig.isNaN ? null : sig,
        hi: _repHi,
        lo: _repLo,
        poseFound: pose != null,
        status: status.name,
        reps: _ui.reps,
        repEvent: _repThisFrame,
        rawRight: lm == null ? null : p.signal(lm, p.minLikelihood).right,
        gate: gateOk,
        exercise: p.id,
        view: view,
        landmarks: lm,
      );
    }
    _repThisFrame = false;

    setState(() {
      _landmarks = lm;
    });
  }

  Future<void> _toggleDiagRecording() async {
    final d = DiagRecorder.instance;
    if (_diagRecording) {
      final video = await d.stop();
      final csv = d.csvPath;
      final rows = d.csvRows;
      if (!mounted) return;
      setState(() => _diagRecording = false);
      await _offerDiagShare(video, csv, rows);
      return;
    }
    final ok = await d.start(exercise: p.id);
    if (!mounted) return;
    setState(() => _diagRecording = ok);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa được phép quay màn hình')),
      );
    }
  }

  Future<void> _offerDiagShare(String? video, String? csv, int rows) async {
    if (video == null && csv == null) return;
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đã ghi xong'),
        content: Text([
          if (video != null) 'Video: ${video.split('/').last}',
          if (csv != null) 'Số liệu: ${csv.split('/').last} ($rows dòng)',
          '',
          'Lưu ra máy để gửi cho người phát triển tìm nguyên nhân đếm sai.',
        ].join('\n')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Để sau'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.save_alt),
            label: const Text('Lưu vào máy'),
          ),
        ],
      ),
    );
    if (save != true) return;

    // Lưu cả hai file: video để nhìn khung xương có bám người không, CSV để
    // chạy lại bộ đếm ngoại tuyến. Thiếu một trong hai là chẩn đoán bị mù một
    // nửa.
    final d = DiagRecorder.instance;
    final saved = <String>[];
    for (final path in [video, csv]) {
      if (path == null) continue;
      final at = await d.save(path);
      if (at != null) saved.add(at);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: const Duration(seconds: 6),
      content: Text(saved.isEmpty
          ? 'Không lưu được file ra bộ nhớ máy'
          : 'Đã lưu:\n${saved.join('\n')}'),
    ));
  }

  Future<void> _showGoalReached() async {
    if (!mounted || _finishing || _ui.phase == WorkoutUiPhase.aborted) return;
    setState(() => _goalBanner = true);
    _goalTimer?.cancel();
    _goalTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _goalBanner = false);
    });
  }

  void _pauseWorkout() {
    if (_finishing || _manualPaused || _ui.challengeExpired) return;
    _manualPaused = true;
    _cameraEpoch++;
    _feedback.stop();
    _workout.pause();
    final now = _workout.frameTime;
    _trackL.onInterrupted(now, RepAbortReason.placementLost);
    _trackR.onInterrupted(now, RepAbortReason.placementLost);
    _smoothL.reset();
    _smoothR.reset();
    _lastPlacementOk = null;
    _pauseTimer?.cancel();
    _pauseTimer = Timer(const Duration(minutes: 5), _finishWorkout);
    setState(() {});
  }

  Future<void> _resumeWorkout() async {
    _pauseTimer?.cancel();
    _manualPaused = false;
    if (_ciVideo != null) {
      _workout.cameraStarted();
    } else if (_cam == null) {
      await _resumeCamera();
    } else {
      _workout.cameraStarted();
    }
  }

  Future<void> _finishWorkout() async {
    if (_finishing) return;
    _pauseTimer?.cancel();
    _goalTimer?.cancel();
    _feedback.stop();
    _cameraEpoch++;
    // Interrupt a partial cycle before a possibly slow write. On failure the
    // user can continue/retry without joining a pre-save bottom to a new top.
    _trackL.onInterrupted(_workout.elapsed, RepAbortReason.placementLost);
    _trackR.onInterrupted(_workout.elapsed, RepAbortReason.placementLost);
    _smoothL.reset();
    _smoothR.reset();
    try {
      final saving = _workout.finish(calibration: CalibrationSnapshot(
          repHi: _repHi, repLo: _repLo, minAmplitude: _repAmp,
          source: _calibrated ? CalibrationSource.userCalibration : CalibrationSource.defaults));
      // Release the camera as soon as saving begins. A storage failure still
      // leaves the controller snapshot available for retry/resume.
      final camera = _cam;
      _cam = null;
      if (camera != null) _cameraShutdown = _releaseCamera(camera);
      final record = await saving;
      _ciSavedReps = record.reps;
      await _cameraShutdown;
      if (!mounted) return;
      _allowPop = true;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ResultPage(record: record, offerAutomaticAi: true)));
    } catch (_) {
      if (!mounted) return;
      _notify(context.tr('Chưa lưu được buổi tập. Bạn có thể thử lại.',
          'Could not save your workout. You can retry.'));
      if (widget.ciVideoPath == null && !_inBackground && _cam == null) {
        await _resumeCamera();
      }
    }
  }

  Future<void> _confirmExit() async {
    if (_finishing || !mounted) return;
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.s.finishTitle),
        content: Text(_ui.reps == 0
            ? context.s.finishNoReps
            : '${context.s.goalDonePrefix} ${_ui.reps} '
                '${context.s.repsShort}. ${context.s.finishSaveHint}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'continue'),
            child: Text(context.s.finishContinue),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: Text(context.s.finishDiscard),
          ),
          if (_ui.reps > 0)
            FilledButton(
              onPressed: () => Navigator.pop(context, 'save'),
              child: Text(context.s.finishSave),
            ),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == 'save') return _finishWorkout();
    if (choice == 'discard') {
      _feedback.stop();
      _workout.abort();
      _allowPop = true;
      Navigator.of(context).pop();
    }
  }

  Future<void> _toggleCalibration() async {
    if (!_workout.acceptsFrames || _ui.countdown != null || _calibrationSaving) return;
    _feedback.stop();
    _resetTransient();
    var shouldSave = false;
    if (_calibrating) {
      final s = _calibrator.suggest();
      setState(() {
        _calibrating = false;
        if (s == null) {
          _notify(context.s.calibrateNotEnough);
        } else {
          _buildCounters(s.hi, s.lo, s.minAmp);
          _calibrated = true;
          _calibratedThisSession = true;
          shouldSave = true;
          // Notify only after the actual calibration snapshot is persisted.
        }
      });
    } else {
      _calibrator.reset();
      setState(() {
        _calibrating = true;
      });
      _notify(context.s.calibrateStart);
    }
    _syncCalibration();
    if (shouldSave) {
      _calibrationSaving = true;
      try {
        final saved = await _calibrationStore.save(p.id, CalibrationSnapshot(repHi: _repHi, repLo: _repLo,
          minAmplitude: _repAmp, source: CalibrationSource.userCalibration));
        if (!saved) throw StateError('Calibration write failed');
        if (mounted) _notify(context.s.calibrateDone);
      } catch (_) {
        if (mounted) { _notify(context.tr('Đã áp dụng hiệu chỉnh cho buổi này nhưng chưa lưu được. Hãy hiệu chỉnh lại ở buổi sau.',
          'Calibration is active for this workout but could not be saved. Calibrate again next time.')); }
      } finally { _calibrationSaving = false; }
    }
  }

  InputImage? _toInputImage(CameraImage image) {
    final rotation = InputImageRotationValue.fromRawValue(
        _cam!.description.sensorOrientation);
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    // Đã yêu cầu nv21 (Android) / bgra8888 (iOS) nên mỗi ảnh chỉ có một plane.
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  @override
  void dispose() {
    _pauseTimer?.cancel();
    _goalTimer?.cancel();
    _feedback.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _cameraEpoch++;
    _workout.removeListener(_workoutChanged);
    _workout.dispose();
    // Roi man hinh ma con dang quay thi MediaProjection se treo lai cung thong
    // bao "dang ghi" -> dung han truoc khi di.
    if (_diagRecording) DiagRecorder.instance.stop();
    final cam = _cam;
    if (cam != null) unawaited(_releaseCamera(cam));
    final ciVideo = _ciVideo;
    if (ciVideo != null) unawaited(ciVideo.dispose());
    unawaited(_detector.close().catchError((Object error) {
      debugPrint('pose detector close: $error');
    }));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_finishing) {
      return Scaffold(body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const CircularProgressIndicator(), const SizedBox(height: 24),
        Text(context.tr('Đang lưu buổi tập…', 'Saving your workout…')),
      ])));
    }
    final cam = _cam;
    final ciVideo = _ciVideo;
    final ciVideoReady = ciVideo?.value.isInitialized == true;
    if (_manualPaused && cam == null && !ciVideoReady) {
      return Scaffold(body: SafeArea(child: _hud()));
    }
    if (!ciVideoReady && (cam == null || !cam.value.isInitialized)) {
      return _cameraGate();
    }
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
          if (ciVideoReady)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox.fromSize(
                size: ciVideo!.value.size,
                child: VideoPlayer(ciVideo),
              ),
            )
          else
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: cam!.value.previewSize!.height,
                height: cam.value.previewSize!.width,
                child: CameraPreview(cam),
              ),
            ),
          CustomPaint(
            painter: PoseOverlayPainter(
              profile: p,
              guide: _guide,
              status: _ui.placementStatus,
              landmarks: _landmarks,
              repFlash: MediaQuery.disableAnimationsOf(context) ? 0 : _repFlash,
              repHi: _repHi,
              repLo: _repLo,
              strings: context.s,
              showGuide: !_ui.placementReady,
            ),
          ),
            const IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xF20B0B0C), Color(0x990B0B0C), Color(0x000B0B0C), Color(0xD90B0B0C)],
              stops: [0, .4, .7, 1])))),
            SafeArea(child: _hud()),
          ],
        ),
      ),
    );
  }

  Widget _cameraGate() => PopScope(
    canPop: _allowPop,
    onPopInvokedWithResult: (didPop, _) { if (!didPop) _confirmExit(); },
    child: CameraPermissionView(
      title: _cameraTitle, body: _cameraBody,
      denied: _cameraState == _CameraState.denied,
      loading: _cameraState == _CameraState.initializing,
      actionLabel: _cameraState == _CameraState.denied ? context.s.openSettings
        : _cameraState == _CameraState.awaitingConsent ? context.s.cameraAllowAndOpen : context.s.retry,
      onAction: _cameraState == _CameraState.denied ? openAppSettings : _start,
      onRetry: _cameraState == _CameraState.denied ? _start : null,
      onExit: _confirmExit,
    ),
  );

  String get _cameraTitle => switch (_cameraState) {
        _CameraState.awaitingConsent => context.s.cameraPermissionTitle,
        _CameraState.initializing => context.s.cameraOpening,
        _CameraState.denied => context.s.cameraDenied,
        _CameraState.unavailable => context.s.cameraUnavailable,
        _CameraState.ready => context.s.cameraReady,
        _CameraState.suspended => context.s.cameraPaused,
      };

  String get _cameraBody => switch (_cameraState) {
        _CameraState.awaitingConsent => context.s.cameraPermissionBody,
        _CameraState.initializing => context.s.cameraOpeningBody,
        _CameraState.denied => context.s.cameraDeniedBody,
        _CameraState.unavailable => context.s.cameraUnavailableBody,
        _CameraState.suspended => context.s.cameraPausedBody,
        _CameraState.ready => '',
      };

  Widget _hud() => WorkoutHud(
    state: _ui, onStart: _workout.requestStart,
    challengeBestReps: widget.challengeBestReps,
    voiceEnabled: _preferences.voice, onToggleVoice: _preferencesLoaded && !_settingsBusy ? _toggleVoice : null,
    exerciseName: p.localizedName(context.s), hint: p.localizedHint(context.s),
    onExit: _confirmExit, onPause: _pauseWorkout, onResume: _resumeWorkout,
    onFinish: _finishWorkout, onCalibrate: _toggleCalibration,
    onHelp: () => showExerciseHelp(context, p),
    goalBanner: _goalBanner, onDismissGoal: () => setState(() => _goalBanner = false),
    diagnosticAction: !_diagAvailable ? null : IconButton(
      onPressed: _toggleDiagRecording,
      tooltip: _diagRecording ? context.s.hudStopRecord : context.s.hudRecord,
      icon: Icon(_diagRecording ? Icons.stop_circle : Icons.videocam_outlined,
        color: _diagRecording ? AppColors.danger : AppColors.text)),
  );
}
