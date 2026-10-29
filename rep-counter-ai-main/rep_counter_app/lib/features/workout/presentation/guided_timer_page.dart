import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/l10n.dart';
import '../../../core/i18n/locale_controller.dart';
import '../../../exercise.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_feedback.dart';
import '../../../widgets/product_ui.dart';
import '../data/workout_history_store.dart';
import '../data/workout_record.dart';
import '../domain/workout_mode.dart';

enum GuidedTimerPhase { work, rest, done }

/// W-4b guided timer (design 1.9a, "Guided timer · camera off"): timed
/// sets with rest for holds and intervals. Nothing is camera-verified, so
/// it is a timer the user controls: +10 s, pause, done early. The record
/// is manual with the time actually held (never the target), no reps and
/// no form data, so it never counts toward timed bests or challenges.
class GuidedTimerPage extends StatefulWidget {
  const GuidedTimerPage({
    super.key,
    required this.profile,
    this.sets = 2,
    this.seconds = 40,
    this.restSeconds = 30,
    this.history,
    this.now = DateTime.now,
  });

  final ExerciseProfile profile;
  final int sets, seconds, restSeconds;
  final WorkoutHistoryStore? history;
  final DateTime Function() now;

  @override
  State<GuidedTimerPage> createState() => _GuidedTimerPageState();
}

class _GuidedTimerPageState extends State<GuidedTimerPage> {
  late final DateTime _openedAt = widget.now();
  late final List<int> _targets = List.filled(widget.sets, widget.seconds);
  late final List<int> _held = List.filled(widget.sets, 0);
  Timer? _ticker;
  GuidedTimerPhase _phase = GuidedTimerPhase.work;
  int _set = 0;
  int _rest = 0;
  bool _paused = false, _saving = false, _saved = false;
  String? _error;

  int get _totalHeld => _held.fold(0, (a, b) => a + b);

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _tick() {
    if (_paused || _phase == GuidedTimerPhase.done || !mounted) return;
    setState(() {
      if (_phase == GuidedTimerPhase.rest) {
        _rest--;
        if (_rest <= 0) _phase = GuidedTimerPhase.work;
        return;
      }
      _held[_set]++;
      final target = _targets[_set];
      if (_held[_set] * 2 == target) HapticFeedback.lightImpact();
      if (_held[_set] >= target) {
        HapticFeedback.mediumImpact();
        _endSet();
      }
    });
  }

  /// Moves on after a set: rest before the next one, or done.
  void _endSet() {
    if (_set + 1 >= widget.sets) {
      _finish();
    } else {
      _set++;
      _rest = widget.restSeconds;
      _phase = widget.restSeconds > 0
          ? GuidedTimerPhase.rest
          : GuidedTimerPhase.work;
    }
  }

  void _finish() {
    _phase = GuidedTimerPhase.done;
    _ticker?.cancel();
    if (_totalHeld > 0) _save();
  }

  Future<void> _save() async {
    if (_saving || _saved) return;
    _saving = true;
    final record = WorkoutRecord(
      id: 'timer-${_openedAt.toUtc().microsecondsSinceEpoch}',
      exerciseId: widget.profile.id,
      exerciseName: widget.profile.name,
      startedAt: _openedAt,
      durationSeconds: _totalHeld,
      reps: 0,
      sets: _held.where((s) => s > 0).length,
      targetReps: null,
      poseFrames: 0,
      readyFrames: 0,
      lostFrames: 0,
      mode: WorkoutMode.free,
      manual: true,
    );
    try {
      await (widget.history ?? WorkoutHistoryStore()).save(record);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saved = true;
        _error = null;
      });
      AppToast.show(context, context.l10n.commonFaSaved);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = context.l10n.legacyCameraPageCouldNotSaveWorkout;
        });
      }
    }
  }

  void _doneEarly() => setState(_finish);

  Future<bool> _confirmDiscard() async {
    if (_totalHeld == 0 || _saved) return true;
    final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(context.tr(
                  'Bỏ thời gian đã tập?', 'Discard the time you held?')),
              content: Text(context.tr(
                  'Bạn đã giữ ${_clock(_totalHeld)}. Chọn "Kết thúc sớm" để lưu.',
                  'You held ${_clock(_totalHeld)}. Use "Done early" to save it.')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(context.tr('Tiếp tục', 'Keep going'))),
                TextButton(
                    key: const Key('timer-discard'),
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(context.tr('Bỏ', 'Discard'))),
              ],
            ));
    return discard ?? false;
  }

  static String _clock(int s) =>
      '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final name = exerciseNameFor(widget.profile.id, context.s);
    final held = _held[_set];
    final target = _targets[_set];
    final left = (target - held).clamp(0, target);
    final done = _phase == GuidedTimerPhase.done;
    return PopScope(
      canPop: _totalHeld == 0 || done,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmDiscard() && mounted) {
          _ticker?.cancel();
          navigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(context.l10n.homeGuidedTimerCameraOff)),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Text(
                  done
                      ? name
                      : context.tr('Set ${_set + 1}/${widget.sets} · $name',
                          'Set ${_set + 1} of ${widget.sets} · $name'),
                  key: const Key('timer-title'),
                  style: AppTypography.title22),
              const SizedBox(height: 24),
              Semantics(
                liveRegion: true,
                child: Text(
                    key: const Key('timer-clock'),
                    switch (_phase) {
                      GuidedTimerPhase.work => _clock(left),
                      GuidedTimerPhase.rest => _clock(_rest),
                      GuidedTimerPhase.done => _clock(_totalHeld),
                    },
                    textAlign: TextAlign.center,
                    style: AppTypography.metric40.copyWith(fontSize: 72)),
              ),
              const SizedBox(height: 8),
              Text(
                  key: const Key('timer-detail'),
                  switch (_phase) {
                    GuidedTimerPhase.work => context.tr(
                        '${_clock(held)} / ${_clock(target)} · còn $left giây',
                        '${_clock(held)} of ${_clock(target)} · $left s left'),
                    GuidedTimerPhase.rest => context.tr(
                        'Nghỉ trước set ${_set + 1}',
                        'Rest before set ${_set + 1}'),
                    GuidedTimerPhase.done => context.tr(
                        'Đã giữ ${_clock(_totalHeld)} trong ${_held.where((s) => s > 0).length} set',
                        'Held ${_clock(_totalHeld)} over ${_held.where((s) => s > 0).length} sets'),
                  },
                  textAlign: TextAlign.center,
                  style: AppTypography.body16.copyWith(color: AppColors.text2)),
              const SizedBox(height: 24),
              Text(
                  context.tr(
                      'Thời gian không được camera kiểm tra: bản ghi là "thủ công", không có điểm form và không tính vào thử thách.',
                      'Time is not camera-verified: the record is manual, with no form score, and does not count toward challenges.'),
                  style:
                      AppTypography.caption12.copyWith(color: AppColors.text2)),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: AppTypography.body14
                        .copyWith(color: AppColors.warningText)),
                AppButton(
                    key: const Key('timer-retry-save'),
                    label: context.l10n.commonSave,
                    onPressed: _save),
              ],
              const SizedBox(height: 24),
              if (!done) ...[
                if (_phase == GuidedTimerPhase.work)
                  AppButton(
                      key: const Key('timer-add'),
                      label: context.tr('+10 giây', '+10 s'),
                      icon: LucideIcons.plus,
                      variant: AppButtonVariant.secondary,
                      onPressed: () => setState(() => _targets[_set] += 10))
                else
                  AppButton(
                      key: const Key('timer-skip-rest'),
                      label: context.tr('Bỏ qua nghỉ', 'Skip rest'),
                      variant: AppButtonVariant.secondary,
                      onPressed: () => setState(() {
                            _rest = 0;
                            _phase = GuidedTimerPhase.work;
                          })),
                const SizedBox(height: 12),
                AppButton(
                    key: const Key('timer-pause'),
                    label: _paused
                        ? context.tr('Tiếp tục', 'Resume')
                        : context.tr('Tạm dừng', 'Pause'),
                    icon: _paused ? LucideIcons.play : LucideIcons.pause,
                    onPressed: () => setState(() => _paused = !_paused)),
                const SizedBox(height: 12),
                AppButton(
                    key: const Key('timer-done-early'),
                    label: context.tr('Kết thúc sớm', 'Done early'),
                    variant: AppButtonVariant.ghost,
                    onPressed: _doneEarly),
              ] else
                AppButton(
                    key: const Key('timer-close'),
                    label: context.tr('Xong', 'Done'),
                    loading: _saving,
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(_saved)),
            ],
          ),
        ),
      ),
    );
  }
}
