import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../../exercise.dart';
import '../../../placement.dart';
import '../../../rep_counter.dart';
import '../data/workout_history_store.dart';
import '../data/workout_record.dart';
import '../domain/quality_thresholds.dart';
import '../domain/rep_metric.dart';
import '../domain/rep_quality_analyzer.dart';
import '../domain/workout_aggregator.dart';
import '../domain/workout_summary.dart';
import 'workout_ui_state.dart';

/// Injectable monotonic time for lifecycle tests without a camera or timers.
abstract interface class WorkoutClock {
  Duration get elapsed;
  bool get isRunning;
  void start();
  void stop();
}

class StopwatchWorkoutClock implements WorkoutClock {
  final _watch = Stopwatch();
  @override
  Duration get elapsed => _watch.elapsed;
  @override
  bool get isRunning => _watch.isRunning;
  @override
  void start() => _watch.start();
  @override
  void stop() => _watch.stop();
}

/// Owns session orchestration; consumes reps already accepted by the old engine.
/// Camera lifecycle, conversion, placement gating, smoothing and calibration
/// formulas remain in CameraPage/the original domain classes during Phase 4.
class WorkoutController extends ChangeNotifier {
  WorkoutController({
    required this.profile,
    this.targetReps,
    this.requireCountdown = true,
    WorkoutClock? trackingClock,
    WorkoutClock? clock,
    DateTime Function()? now,
    Future<void> Function(WorkoutRecord)? saveRecord,
  })  : _trackingClock = trackingClock ?? StopwatchWorkoutClock(),
        _clock = clock ?? StopwatchWorkoutClock(),
        _now = now ?? DateTime.now,
        _saveRecord = saveRecord ?? WorkoutHistoryStore().save,
        _session = SessionTracker(
            restTimeout: const Duration(seconds: 6), minReps: 1),
        _aggregator = const WorkoutAggregator(
            setGap: Duration(seconds: 6), minRepsPerSet: 1) {
    _startedAt = _now();
  }

  final ExerciseProfile profile;
  final int? targetReps;
  final bool requireCountdown;
  final WorkoutClock _trackingClock;
  bool _armed = false, _startRequested = false;
  Duration? _readySince, _lastReadyFrame;
  Timer? _countdownTimer;
  int? _countdown;
  final WorkoutClock _clock;
  final DateTime Function() _now;
  final Future<void> Function(WorkoutRecord) _saveRecord;
  final SessionTracker _session;
  final WorkoutAggregator _aggregator;
  final _analyzer = const RepQualityAnalyzer();
  final List<RepMetric> _reps = [];
  late DateTime _startedAt;
  bool _started = false, _paused = false, _disposed = false;
  bool _calibrating = false, _calibrated = false, _goalReachedOnce = false;
  int _calibrationSamples = 0;
  int _poseFrames = 0, _readyFrames = 0, _lostFrames = 0;
  bool _placementReady = false;
  PlacementStatus _placementStatus = PlacementStatus.noPose;
  String _placementMessage = '';
  String? _saveError;
  WorkoutUiPhase? _terminalPhase;
  Future<WorkoutRecord>? _finishFuture;

  bool get hasStarted => _started;

  /// Pose/placement time must advance while the workout timer is still stopped.
  Duration get frameTime => _trackingClock.elapsed;
  bool get acceptsReps => acceptsFrames && _armed && !_calibrating;
  Duration get elapsed => _clock.elapsed;
  bool get acceptsFrames =>
      !_disposed && _started && !_paused && _terminalPhase == null;

  WorkoutUiState get state => WorkoutUiState(
        phase: _terminalPhase ??
            (_paused
                ? WorkoutUiPhase.paused
                : _countdown != null
                    ? WorkoutUiPhase.countdown
                    : _calibrating
                        ? WorkoutUiPhase.calibrating
                        : !_placementReady
                            ? WorkoutUiPhase.positioning
                            : _armed && requireCountdown
                                ? WorkoutUiPhase.active
                                : _session.totalReps == 0
                                    ? WorkoutUiPhase.ready
                                    : WorkoutUiPhase.active),
        exerciseId: profile.id,
        exerciseName: profile.name,
        reps: _session.totalReps,
        repsInCurrentSet: _session.repsInCurrentSet,
        completedSets: _session.sets.length,
        sessionState: _session.state,
        goal: targetReps,
        elapsed: elapsed,
        placementReady: _placementReady,
        placementStatus: _placementStatus,
        placementMessage: _placementMessage,
        calibrated: _calibrated,
        calibrationSamples: _calibrationSamples,
        goalReachedOnce: _goalReachedOnce,
        saveError: _saveError,
        countdown: _countdown,
        sessionStarted: _armed,
        startRequested: _startRequested,
      );

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  /// Called only after the native image stream has started successfully.
  void cameraStarted() {
    if (_disposed || _terminalPhase != null) return;
    if (!_started) {
      _startedAt = _now();
      _started = true;
      _armed = !requireCountdown;
    }
    _paused = false;
    _trackingClock.start();
    if (_armed && !_calibrating && !_clock.isRunning) _clock.start();
    _emit();
  }

  /// CameraPage also interrupts both trackers and clears its placement grace.
  void pause() {
    if (_disposed || !_started) return;
    _cancelCountdown();
    _trackingClock.stop();
    _clock.stop();
    _paused = true;
    _placementReady = false;
    _emit();
  }

  void calibrationChanged(
      {required bool collecting,
      required bool calibrated,
      required int samples}) {
    if (_disposed || _terminalPhase != null) return;
    if (collecting) {
      _cancelCountdown();
      _clock.stop();
    } else if (_calibrating && _armed && !_paused) {
      _clock.start();
    }
    _calibrating = collecting;
    _calibrated = calibrated;
    _calibrationSamples = samples;
    _emit();
  }

  /// The caller has already applied placement/count gates and two-arm merging.
  /// Returns true once when the existing session count reaches the goal.
  bool acceptRep(RepObservation observation, Duration at) {
    if (!acceptsReps) return false;
    _reps.add(RepMetric(
      index: _reps.length + 1,
      setIndex: 1,
      observation: observation,
      flags: _analyzer.analyze(observation),
    ));
    _session.onRep(at);
    final reached = targetReps != null &&
        _session.totalReps >= targetReps! &&
        !_goalReachedOnce;
    if (reached) _goalReachedOnce = true;
    _emit();
    return reached;
  }

  /// Called once per successfully processed camera frame, including no-pose.
  void frameProcessed(
      {required Duration at,
      required bool poseFound,
      required bool countable,
      required PlacementStatus status,
      required String message,
      required int calibrationSamples}) {
    if (!acceptsFrames) return;
    if (acceptsReps) {
      _poseFrames++;
      if (!poseFound) _lostFrames++;
      if (countable) _readyFrames++;
    }
    _placementReady = countable;
    _placementStatus = status;
    _placementMessage = message;
    _calibrationSamples = calibrationSamples;
    if (acceptsReps) _session.tick(at);
    if (!_armed && !_calibrating && _startRequested) {
      // Setup uses the actual stable status, not the workout's two-second grace.
      if (poseFound && status.canCount) {
        if (_lastReadyFrame != null &&
            frameTime - _lastReadyFrame! > const Duration(milliseconds: 750)) {
          _cancelCountdown();
        }
        _lastReadyFrame = frameTime;
        _readySince ??= frameTime;
        if (_countdown == null &&
            frameTime - _readySince! >= const Duration(milliseconds: 1500)) {
          _beginCountdown();
        }
      } else {
        _cancelCountdown();
      }
    }
    _emit();
  }

  void requestStart() {
    if (!acceptsFrames || _armed || _calibrating || _startRequested) return;
    _startRequested = true;
    _readySince = null;
    _emit();
  }

  void _beginCountdown() {
    _countdown = 3;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      // A stalled detector cannot arm a session using an old ready frame.
      if (!acceptsFrames ||
          _calibrating ||
          _lastReadyFrame == null ||
          frameTime - _lastReadyFrame! > const Duration(milliseconds: 750)) {
        _cancelCountdown();
      } else if (_countdown! > 1) {
        _countdown = _countdown! - 1;
      } else {
        _cancelCountdown();
        _armed = true;
        _startedAt = _now();
        _clock.start();
      }
      _emit();
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _countdown = null;
    _readySince = null;
    _lastReadyFrame = null;
  }

  /// One snapshot and one write for concurrent finish requests. No navigation,
  /// dialogs or network requests live here. Save errors unlock a retry.
  Future<WorkoutRecord> finish({required CalibrationSnapshot calibration}) {
    if (_finishFuture != null) return _finishFuture!;
    if (_disposed || _terminalPhase == WorkoutUiPhase.aborted) {
      return Future.error(StateError('Workout is no longer available'));
    }
    final completer = Completer<WorkoutRecord>();
    _finishFuture = completer.future;
    final resumeOnFailure = _clock.isRunning;
    _cancelCountdown();
    _clock.stop();
    _terminalPhase = WorkoutUiPhase.ending;
    _saveError = null;
    _emit();
    unawaited(_save(calibration, completer, resumeOnFailure));
    return completer.future;
  }

  Future<void> _save(CalibrationSnapshot calibration,
      Completer<WorkoutRecord> completer, bool resumeOnFailure) async {
    try {
      final summary = _aggregator.build(
        id: _startedAt.microsecondsSinceEpoch.toString(),
        exerciseId: profile.id,
        startedAt: _startedAt,
        endedAt: _now(),
        reps: List.unmodifiable(_reps),
        poseStats: PoseQualityStats(
            totalProcessedFrames: _poseFrames,
            countableFrames: _readyFrames,
            poseLostFrames: _lostFrames),
        calibration: calibration,
      );
      final record = WorkoutRecord.fromSummary(
        summary: summary,
        exerciseName: profile.name,
        durationSeconds: elapsed.inSeconds.clamp(1, 86400),
        targetReps: targetReps,
        poseFrames: _poseFrames,
        readyFrames: _readyFrames,
        lostFrames: _lostFrames,
      );
      _terminalPhase = WorkoutUiPhase.saving;
      _emit();
      await _saveRecord(record);
      _terminalPhase = WorkoutUiPhase.done;
      _emit();
      completer.complete(record);
    } catch (error, stack) {
      _terminalPhase = null;
      _finishFuture = null;
      _saveError = error.toString();
      if (!_disposed && !_paused && resumeOnFailure) _clock.start();
      _emit();
      completer.completeError(error, stack);
    }
  }

  void abort() {
    if (_disposed || _terminalPhase != null) return;
    _cancelCountdown();
    _trackingClock.stop();
    _clock.stop();
    _terminalPhase = WorkoutUiPhase.aborted;
    _emit();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelCountdown();
    _trackingClock.stop();
    _clock.stop();
    super.dispose();
  }
}
