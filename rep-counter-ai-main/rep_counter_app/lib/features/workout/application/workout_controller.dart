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
import '../domain/rep_tracker.dart';
import '../domain/workout_aggregator.dart';
import '../domain/workout_summary.dart';
import '../domain/workout_mode.dart';
import '../../routine/domain/routine_preset.dart';
import 'rep_feedback.dart';
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
    WorkoutMode? mode,
    this.timedChallenge,
    this.routine,
    this.requireCountdown = true,
    this.feedbackDuration = const Duration(milliseconds: 1600),
    WorkoutClock? trackingClock,
    WorkoutClock? clock,
    DateTime Function()? now,
    Future<void> Function(WorkoutRecord)? saveRecord,
  })  : assert(timedChallenge == null ||
            mode == null ||
            mode == WorkoutMode.timed),
        assert(timedChallenge == null || targetReps == null),
        mode = mode ??
            (timedChallenge != null
                ? WorkoutMode.timed
                : targetReps != null
                    ? WorkoutMode.targetReps
                    : WorkoutMode.free),
        _trackingClock = trackingClock ?? StopwatchWorkoutClock(),
        _clock = clock ?? StopwatchWorkoutClock(),
        _now = now ?? DateTime.now,
        _saveRecord = saveRecord ?? WorkoutHistoryStore().save,
        _session = SessionTracker(
            restTimeout: routine == null
                ? const Duration(seconds: 6)
                : const Duration(days: 365),
            minReps: 1),
        _aggregator = const WorkoutAggregator(
            setGap: Duration(seconds: 6), minRepsPerSet: 1) {
    _startedAt = _now();
  }

  final ExerciseProfile profile;
  final int? targetReps;
  final WorkoutMode mode;
  final TimedChallengeConfig? timedChallenge;
  final RoutineSnapshot? routine;
  final bool requireCountdown;
  final Duration feedbackDuration;
  final WorkoutClock _trackingClock;
  bool _armed = false, _startRequested = false;
  Duration? _readySince, _lastReadyFrame;
  Timer? _countdownTimer;
  Timer? _feedbackTimer;
  Timer? _routineRestTimer;
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
  bool _challengeExpired = false;
  Duration? _routineRestUntil;
  int _routineCompletedSetReps = 0;
  bool _routineComplete = false;
  bool _calibrating = false, _calibrated = false, _goalReachedOnce = false;
  int _calibrationSamples = 0;
  int _poseFrames = 0, _readyFrames = 0, _lostFrames = 0;
  bool _placementReady = false;
  PlacementStatus _placementStatus = PlacementStatus.noPose;
  String _placementMessage = '';
  String? _saveError;
  RepFeedback? _repFeedback;
  WorkoutUiPhase? _terminalPhase;
  Future<WorkoutRecord>? _finishFuture;

  bool get hasStarted => _started;
  bool get isTimedChallenge => mode == WorkoutMode.timed;
  bool get challengeExpired => _challengeExpired;
  bool get isRoutineResting => _routineRestUntil != null;
  Duration? get routineRestRemaining {
    final until = _routineRestUntil;
    if (until == null) return null;
    final left = until - frameTime;
    return left.isNegative ? Duration.zero : left;
  }

  /// Pose/placement time must advance while the workout timer is still stopped.
  Duration get frameTime => _trackingClock.elapsed;
  Duration get elapsed => _clock.elapsed;
  Duration? get challengeRemaining {
    final config = timedChallenge;
    if (!isTimedChallenge || config == null) return null;
    final left = Duration(seconds: config.durationSeconds) - elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  bool get _pastChallengeDeadline {
    final config = timedChallenge;
    return isTimedChallenge &&
        config != null &&
        _armed &&
        elapsed > Duration(seconds: config.durationSeconds);
  }

  bool get acceptsReps =>
      acceptsFrames &&
      _armed &&
      !_calibrating &&
      !_pastChallengeDeadline &&
      !isRoutineResting &&
      !_routineComplete;
  bool get acceptsFrames =>
      !_disposed &&
      _started &&
      !_paused &&
      !_challengeExpired &&
      _terminalPhase == null;

  WorkoutUiState get state => WorkoutUiState(
        phase: _terminalPhase ??
            (_paused
                ? WorkoutUiPhase.paused
                : _countdown != null
                    ? WorkoutUiPhase.countdown
                    : _calibrating
                        ? WorkoutUiPhase.calibrating
                        : isRoutineResting
                            ? WorkoutUiPhase.resting
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
        repFeedback: _repFeedback,
        countdown: _countdown,
        sessionStarted: _armed,
        startRequested: _startRequested,
        mode: mode,
        challengeSeconds: timedChallenge?.durationSeconds,
        challengeRemaining: challengeRemaining,
        challengeExpired: _challengeExpired,
        routine: routine,
        routineRestRemaining: routineRestRemaining,
        routineCompletedSetReps: _routineCompletedSetReps,
        routineComplete: _routineComplete,
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
    if (_armed &&
        !_calibrating &&
        !_challengeExpired &&
        !_clock.isRunning) {
      _clock.start();
    }
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
    _clearRepFeedback();
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
    } else if (_calibrating &&
        _armed &&
        !_paused &&
        !_challengeExpired) {
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
    final challenge = timedChallenge;
    if (isTimedChallenge &&
        challenge != null &&
        elapsed > Duration(seconds: challenge.durationSeconds)) {
      return false;
    }
    final flags = _analyzer.analyze(observation);
    final assignedSetIndex =
        routine == null ? 1 : _session.sets.length + 1;
    _reps.add(RepMetric(
      index: _reps.length + 1,
      setIndex: assignedSetIndex,
      observation: observation,
      flags: flags,
    ));
    _session.onRep(at);
    _replaceRepFeedback(
        feedbackForCompletedRep(_session.totalReps, flags));
    final reached = targetReps != null &&
        _session.totalReps >= targetReps! &&
        !_goalReachedOnce;
    if (reached) _goalReachedOnce = true;

    final routineConfig = routine;
    if (routineConfig != null &&
        _session.repsInCurrentSet >= routineConfig.targetReps) {
      _routineCompletedSetReps = _session.repsInCurrentSet;
      _session.finish();
      if (_session.sets.length >= routineConfig.targetSets) {
        _routineComplete = true;
        _cancelRoutineRest();
      } else {
        _beginRoutineRest();
      }
    }

    _emit();
    return reached;
  }

  void _beginRoutineRest() {
    final config = routine;
    if (config == null || _routineComplete) return;
    _cancelRoutineRest();
    if (config.restSeconds <= 0) {
      _emit();
      return;
    }
    _routineRestUntil =
        frameTime + Duration(seconds: config.restSeconds);
    _routineRestTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (_disposed || _terminalPhase != null) {
          _cancelRoutineRest();
          return;
        }
        if ((routineRestRemaining ?? Duration.zero) <= Duration.zero) {
          skipRoutineRest();
        } else {
          _emit();
        }
      },
    );
  }

  void skipRoutineRest() {
    if (!isRoutineResting) return;
    _cancelRoutineRest();
    _placementReady = false;
    _clearRepFeedback();
    _emit();
  }

  void _cancelRoutineRest() {
    _routineRestTimer?.cancel();
    _routineRestTimer = null;
    _routineRestUntil = null;
  }

  /// Presentation-only event from the existing tracker. It never changes the
  /// accepted session total.
  void reportRepAborted(RepAbortReason reason) {
    if (!acceptsReps) return;
    final feedback = feedbackForAbortedRep(reason);
    if (feedback == null) return;
    _replaceRepFeedback(feedback);
    _emit();
  }

  /// Clears a persistent placement/pose interruption once a countable signal is
  /// available again. Counted feedback expires independently on its timer.
  void repSignalRestored() {
    if (_repFeedback?.persistsUntilResolved != true) return;
    _clearRepFeedback();
    _emit();
  }

  void _replaceRepFeedback(RepFeedback feedback) {
    _feedbackTimer?.cancel();
    _feedbackTimer = null;
    _repFeedback = feedback;
    if (feedback.persistsUntilResolved) return;
    _feedbackTimer = Timer(feedbackDuration, () {
      if (_disposed || !identical(_repFeedback, feedback)) return;
      _repFeedback = null;
      _feedbackTimer = null;
      _emit();
    });
  }

  void _clearRepFeedback() {
    _feedbackTimer?.cancel();
    _feedbackTimer = null;
    _repFeedback = null;
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
    if (acceptsReps &&
        !poseFound &&
        _repFeedback?.kind != RepFeedbackKind.poseLost) {
      _replaceRepFeedback(const RepFeedback.poseLost());
    }
    if (acceptsReps) _session.tick(at);

    final challenge = timedChallenge;
    if (_armed &&
        isTimedChallenge &&
        challenge != null &&
        !_challengeExpired &&
        elapsed >= Duration(seconds: challenge.durationSeconds)) {
      // RepCompleted is handled before frameProcessed. Equality therefore
      // counts, while any later rep is blocked by _pastChallengeDeadline.
      _challengeExpired = true;
      _clearRepFeedback();
      _trackingClock.stop();
      _clock.stop();
    }

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
    _cancelRoutineRest();
    _clearRepFeedback();
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
        preserveAssignedSetIndex: routine != null,
      );
      final durationSeconds = isTimedChallenge
          ? (_challengeExpired
              ? timedChallenge!.durationSeconds
              : elapsed.inSeconds.clamp(0, 86400))
          : elapsed.inSeconds.clamp(1, 86400);
      final record = WorkoutRecord.fromSummary(
        summary: summary,
        exerciseName: profile.name,
        durationSeconds: durationSeconds,
        targetReps: targetReps,
        mode: mode,
        challengeSeconds: timedChallenge?.durationSeconds,
        routine: routine,
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
    _cancelRoutineRest();
    _clearRepFeedback();
    _trackingClock.stop();
    _clock.stop();
    _terminalPhase = WorkoutUiPhase.aborted;
    _emit();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelCountdown();
    _cancelRoutineRest();
    _clearRepFeedback();
    _trackingClock.stop();
    _clock.stop();
    super.dispose();
  }
}
