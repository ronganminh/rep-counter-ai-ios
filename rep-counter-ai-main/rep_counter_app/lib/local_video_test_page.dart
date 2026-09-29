import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:image/image.dart' as img;
import 'package:video_player/video_player.dart';

import 'exercise.dart';
import 'features/pose/domain/pose_mapper.dart';
import 'overlay_painter.dart';
import 'core/i18n/app_strings.dart';
import 'core/i18n/locale_controller.dart';
import 'placement.dart';
import 'rep_counter.dart';

class _VideoPoseFrame {
  const _VideoPoseFrame(this.at, this.points);
  final Duration at;
  final Map<PoseLandmarkType,
      ({double x, double y, double z, double likelihood})> points;
}

class LocalVideoTestPage extends StatefulWidget {
  const LocalVideoTestPage({super.key, this.autoVideoPath});

  final String? autoVideoPath;

  @override
  State<LocalVideoTestPage> createState() => _LocalVideoTestPageState();
}

class _LocalVideoTestPageState extends State<LocalVideoTestPage> {
  static const _videoFrames = MethodChannel('rep_counter/video_frames');
  VideoPlayerController? _video;
  final _detector = PoseDetector(
    options: PoseDetectorOptions(
        mode: PoseDetectionMode.single, model: PoseDetectionModel.base),
  );
  // Khung hướng dẫn cần chuỗi theo ngôn ngữ, mà InheritedWidget chưa dùng được
  // trong khởi tạo trường. Dựng lại ở didChangeDependencies để đổi ngôn ngữ
  // giữa chừng cũng cập nhật theo.
  late GuideZone _guide;
  late S _strings;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _strings = context.s;
    _guide = guideFor(pushUp, _strings);
  }
  final _smooth = RollingMean(5);
  late RepCounter _counter;
  List<_VideoPoseFrame> _frames = const [];
  int _frameIndex = -1;
  int _consumedIndex = -1;
  Landmarks? _landmarks;
  PlacementStatus _status = PlacementStatus.noPose;
  bool _positionLocked = false;
  bool _analyzing = false;
  double _progress = 0;
  String _message = 'Chọn video push-up từ điện thoại';
  final List<double> _trace = [];
  double _flash = 0;
  bool _reportedResult = false;

  String get _ciResultPath =>
      '${Directory.systemTemp.path}/ci-video-result.txt';

  Future<void> _writeCiStatus(String line) async {
    final path = widget.autoVideoPath;
    if (path == null || path.isEmpty) return;
    try {
      await File(_ciResultPath).writeAsString('$line\n', flush: true);
    } catch (error) {
      debugPrint('[CI_VIDEO_ERROR] status_write_failed error=$error');
    }
  }

  @override
  void initState() {
    super.initState();
    _resetCounter();
    final path = widget.autoVideoPath;
    if (path != null && path.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_analyzePath(path));
      });
    }
  }

  void _resetCounter() {
    _counter = RepCounter(
      hi: pushUp.repHi,
      lo: pushUp.repLo,
      minAmplitude: pushUp.minAmplitude,
      minPeriod: pushUp.minPeriod,
    );
    _smooth.reset();
    _positionLocked = false;
    _frameIndex = -1;
    _consumedIndex = -1;
    _trace.clear();
    _reportedResult = false;
  }

  Future<void> _pickAndAnalyze() async {
    final result = await FilePicker.pickFiles(type: FileType.video);
    final path = result.isEmpty ? null : result.first.path;
    if (path == null || !mounted) return;
    await _analyzePath(path);
  }

  Future<void> _analyzePath(String path) async {
    final input = File(path);
    if (!await input.exists()) {
      final line = '[CI_VIDEO_ERROR] missing_file path=$path';
      debugPrint(line);
      await _writeCiStatus(line);
      if (mounted) setState(() => _message = 'Không tìm thấy video: $path');
      return;
    }
    await _writeCiStatus('[CI_VIDEO_STATUS] analyzing path=$path');
    await _video?.dispose();
    final controller = VideoPlayerController.file(File(path));
    await controller.initialize();
    controller.addListener(_onTick);
    setState(() {
      _video = controller;
      _analyzing = true;
      _progress = 0;
      _message = 'Đang phân tích MediaPipe…';
      _frames = const [];
      _resetCounter();
    });

    const stepMs = 200; // 5 FPS is enough for 0.7 s minimum rep period.
    // Debug replay phải xem toàn bộ clip; giới hạn cũ 60 giây làm video
    // 100pushup trả 0 vì phần động tác nằm sau phút đầu.
    final analyzeMs =
        controller.value.duration.inMilliseconds.clamp(0, 600000);
    final output = <_VideoPoseFrame>[];
    try {
      for (var atMs = 0; atMs <= analyzeMs; atMs += stepMs) {
        if (!mounted || _video != controller) return;
        final thumbnail = await _videoFrames.invokeMethod<String>('frame', {
          'path': path,
          'timeMs': atMs,
          'maxWidth': 480,
        });
        if (thumbnail != null) {
          final bytes = await File(thumbnail).readAsBytes();
          final decoded = img.decodeImage(bytes);
          final poses =
              await _detector.processImage(InputImage.fromFilePath(thumbnail));
          if (decoded != null && poses.isNotEmpty) {
            final points = <PoseLandmarkType,
                ({double x, double y, double z, double likelihood})>{};
            for (final entry in poses.first.landmarks.entries) {
              final point = entry.value;
              points[entry.key] = (
                x: point.x / decoded.width,
                y: point.y / decoded.height,
                z: point.z / decoded.width,
                likelihood: point.likelihood,
              );
            }
            output.add(_VideoPoseFrame(Duration(milliseconds: atMs), points));
          } else {
            output.add(_VideoPoseFrame(Duration(milliseconds: atMs), const {}));
          }
        }
        if (atMs % 1000 == 0 && mounted) {
          setState(() => _progress = analyzeMs == 0 ? 1 : atMs / analyzeMs);
        }
      }
      if (!mounted || _video != controller) return;
      setState(() {
        _frames = output;
        _analyzing = false;
        _progress = 1;
        _message = 'Đã phân tích ${output.length} frame • toàn bộ video';
      });
      await _replay();
    } catch (error) {
      final line = '[CI_VIDEO_ERROR] analyze_failed error=$error';
      debugPrint(line);
      await _writeCiStatus(line);
      if (mounted) {
        setState(() {
          _analyzing = false;
          _message = 'Không phân tích được video: $error';
        });
      }
    }
  }

  Future<void> _replay() async {
    final video = _video;
    if (video == null || _frames.isEmpty) return;
    _resetCounter();
    await video.seekTo(Duration.zero);
    await video.setPlaybackSpeed(4);
    await video.play();
    if (mounted) setState(() {});
  }

  void _onTick() {
    final video = _video;
    if (!mounted || video == null || _frames.isEmpty) return;
    final now = video.value.position;
    var next = _frameIndex + 1;
    while (next + 1 < _frames.length && _frames[next + 1].at <= now) {
      next++;
    }
    if (next >= 0 && next < _frames.length && next != _frameIndex) {
      setState(() {
        _frameIndex = next;
        _flash = (_flash - 0.1).clamp(0, 1);
      });
    }
    if (_frameIndex == _frames.length - 1 && video.value.isPlaying) {
      unawaited(video.pause());
      if (!_reportedResult) {
        _reportedResult = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final durationMs = video.value.duration.inMilliseconds;
          final line =
              '[CI_VIDEO_RESULT] frames=${_frames.length} reps=${_counter.count} duration_ms=$durationMs';
          debugPrint(line);
          unawaited(_writeCiStatus(line));
        });
      }
    }
  }

  Landmarks _mapFrame(Size viewSize) {
    final video = _video!;
    final mapper = PoseMapper(
      rawImageSize: video.value.size,
      viewSize: viewSize,
      mirror: false,
    );
    final mapped = <PoseLandmarkType, PoseLandmark>{};
    _frames[_frameIndex].points.forEach((type, point) {
      final offset = mapper.map(
        point.x * video.value.size.width,
        point.y * video.value.size.height,
      );
      mapped[type] = PoseLandmark(
        type: type,
        x: offset.dx,
        y: offset.dy,
        z: point.z,
        likelihood: point.likelihood,
      );
    });
    return Landmarks(mapped);
  }

  void _consume(Size size) {
    if (_frameIndex < 0 || _frameIndex == _consumedIndex) return;
    _consumedIndex = _frameIndex;
    final landmarks = _mapFrame(size);
    final placement = evaluatePlacement(
      profile: pushUp,
      lm: landmarks,
      viewSize: size,
      guide: _guide,
      strings: _strings,
    );
    if (placement.status.canCount) _positionLocked = true;
    final raw = pushUp.signal(landmarks, pushUp.minLikelihood);
    final arms = [raw.left, raw.right].whereType<double>().toList();
    final signal = arms.isEmpty
        ? double.nan
        : _smooth.add(arms.reduce((a, b) => a + b) / arms.length);
    if (_positionLocked && !signal.isNaN) {
      if (_counter.update(signal, _frames[_frameIndex].at) != null) _flash = 1;
    } else {
      _counter.onSignalLost();
    }
    _trace.add(signal);
    if (_trace.length > 150) _trace.removeAt(0);
    _landmarks = landmarks;
    _status = placement.status;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        body: LayoutBuilder(builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          if (_video?.value.isInitialized == true && _frameIndex >= 0) {
            _consume(size);
          }
          return Stack(fit: StackFit.expand, children: [
            if (_video?.value.isInitialized == true)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox.fromSize(
                    size: _video!.value.size, child: VideoPlayer(_video!)),
              )
            else
              const ColoredBox(color: Colors.black),
            if (_frames.isNotEmpty)
              CustomPaint(
                painter: PoseOverlayPainter(
                  profile: pushUp,
                  strings: context.s,
                  guide: _guide,
                  showGuide: true,
                  status: _status,
                  landmarks: _landmarks,
                  trace: List<double>.from(_trace),
                  traceRange: (min: 0, max: 180),
                  repFlash: _flash,
                  repHi: pushUp.repHi,
                  repLo: pushUp.repLo,
                ),
              ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  Row(children: [
                    const BackButton(color: Colors.white),
                    const Expanded(
                      child: Text('Test video local',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                    ),
                    Text('REP ${_counter.count}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800)),
                    IconButton(
                        onPressed: _analyzing ? null : _replay,
                        icon: const Icon(Icons.replay)),
                  ]),
                  const Spacer(),
                  Card(
                    color: Colors.black.withValues(alpha: 0.72),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(_message,
                            style: const TextStyle(color: Colors.white70)),
                        if (_analyzing) ...[
                          const SizedBox(height: 10),
                          LinearProgressIndicator(value: _progress),
                        ],
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: _analyzing ? null : _pickAndAnalyze,
                          icon: const Icon(Icons.video_library_outlined),
                          label: const Text('Chọn video từ máy'),
                        ),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
          ]);
        }),
      );

  @override
  void dispose() {
    _video?.removeListener(_onTick);
    _video?.dispose();
    _detector.close();
    super.dispose();
  }
}
