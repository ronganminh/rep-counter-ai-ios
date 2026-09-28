import 'package:flutter/foundation.dart';
import '../../../core/i18n/app_strings.dart';
import '../../ai/ai_feedback_service.dart';
import '../data/workout_history_store.dart';
import '../data/workout_record.dart';

enum ResultFeedbackPhase { idle, loading, ready, offline, error, unavailable }

typedef AnalyzeWorkout = Future<String> Function(
    WorkoutRecord record, AppLanguage language);
typedef SaveFeedback = Future<void> Function(String id, String feedback);

/// Presentation state only. The existing service owns the aggregate API payload.
/// The caller initiates requests after a manual action or saved automatic consent.
class ResultController extends ChangeNotifier {
  ResultController(WorkoutRecord record,
      {AnalyzeWorkout? analyze, SaveFeedback? saveFeedback, bool? configured})
      : _record = record,
        _analyze = analyze ??
            ((record, language) =>
                AiFeedbackService().analyze(record, language: language)),
        _saveFeedback = saveFeedback ?? WorkoutHistoryStore().saveFeedback,
        configured = configured ??
            (AiFeedbackService().isConfigured && AiFeedbackService().isSecure) {
    phase = hasFeedback
        ? ResultFeedbackPhase.ready
        : this.configured
            ? ResultFeedbackPhase.idle
            : ResultFeedbackPhase.unavailable;
  }

  WorkoutRecord _record;
  WorkoutRecord get record => _record;
  final AnalyzeWorkout _analyze;
  final SaveFeedback _saveFeedback;
  final bool configured;
  late ResultFeedbackPhase phase;
  AiFeedbackFailure? failure;
  bool saving = false, saveFailed = false, _disposed = false;
  bool get hasFeedback => _record.aiFeedback?.trim().isNotEmpty == true;
  bool get busy => phase == ResultFeedbackPhase.loading || saving;

  Future<void> request(AppLanguage language) async {
    if (_disposed || busy || saveFailed || !configured) return;
    phase = ResultFeedbackPhase.loading;
    failure = null;
    notifyListeners();
    try {
      final text = await _analyze(_record, language);
      if (_disposed) return;
      if (text.trim().isEmpty) {
        throw const AiFeedbackException(AiFeedbackFailure.server);
      }
      _record = _record.copyWith(aiFeedback: text);
      phase = ResultFeedbackPhase.ready;
      await retrySave();
    } catch (error) {
      if (_disposed) return;
      failure = error is AiFeedbackException ? error.failure : null;
      phase = switch (failure) {
        AiFeedbackFailure.offline => ResultFeedbackPhase.offline,
        AiFeedbackFailure.notConfigured => ResultFeedbackPhase.unavailable,
        _ => ResultFeedbackPhase.error,
      };
      notifyListeners();
    }
  }

  /// Retain received text after a write failure; retry disk, not the AI request.
  Future<void> retrySave() async {
    if (_disposed || saving || !hasFeedback) return;
    saving = true;
    saveFailed = false;
    notifyListeners();
    try {
      await _saveFeedback(_record.id, _record.aiFeedback!);
    } catch (_) {
      if (!_disposed) saveFailed = true;
    } finally {
      if (!_disposed) {
        saving = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
