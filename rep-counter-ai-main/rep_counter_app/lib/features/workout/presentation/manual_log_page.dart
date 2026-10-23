import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/locale_controller.dart';
import '../../../core/i18n/l10n.dart';
import '../../../exercise.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_feedback.dart';
import '../data/workout_history_store.dart';
import '../data/workout_record.dart';
import '../domain/workout_mode.dart';

/// W-4: log reps by hand when the camera is unavailable or unwanted. The
/// record is marked manual, carries no form data and never counts toward
/// timed challenges or personal bests (FA "manual reps").
class ManualLogPage extends StatefulWidget {
  const ManualLogPage(
      {super.key,
      required this.profile,
      this.history,
      this.now = DateTime.now});

  final ExerciseProfile profile;
  final WorkoutHistoryStore? history;
  final DateTime Function() now;

  @override
  State<ManualLogPage> createState() => _ManualLogPageState();
}

class _ManualLogPageState extends State<ManualLogPage> {
  late final DateTime _openedAt;
  final _sets = <int>[0];
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _openedAt = widget.now();
  }

  int get _total => _sets.fold(0, (a, b) => a + b);

  void _change(int set, int delta) => setState(() {
        _sets[set] = (_sets[set] + delta).clamp(0, 999);
        _error = null;
      });

  Future<void> _save() async {
    if (_saving || _total == 0) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final now = widget.now();
    final record = WorkoutRecord(
      id: 'manual-${_openedAt.toUtc().microsecondsSinceEpoch}',
      exerciseId: widget.profile.id,
      exerciseName: widget.profile.name,
      startedAt: _openedAt,
      durationSeconds: now.difference(_openedAt).inSeconds.clamp(1, 86400),
      reps: _total,
      sets: _sets.where((r) => r > 0).length,
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
      AppToast.show(context, context.l10n.commonFaSaved);
      Navigator.of(context).pop(record);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = context.l10n.legacyCameraPageCouldNotSaveWorkout;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.workoutManualEntry)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(exerciseNameFor(widget.profile.id, context.s),
                style: AppTypography.title22),
            const SizedBox(height: 12),
            AppBanner(
                title: l.workoutManualNotInChallenges,
                body: l.fbTapAfterEachRep),
            const SizedBox(height: 16),
            for (var i = 0; i < _sets.length; i++)
              _SetRow(
                key: Key('manual-set-$i'),
                index: i,
                reps: _sets[i],
                onMinus: _sets[i] > 0 ? () => _change(i, -1) : null,
                onPlus: () => _change(i, 1),
                onRemove: _sets.length > 1
                    ? () => setState(() => _sets.removeAt(i))
                    : null,
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('manual-add-set'),
                onPressed: _sets.length < 20
                    ? () => setState(() => _sets.add(0))
                    : null,
                icon: const Icon(LucideIcons.plus),
                label: Text(l.commonHomeAddSet),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(_error!,
                    style: AppTypography.body14
                        .copyWith(color: AppColors.warningText)),
              ),
            ],
            const SizedBox(height: 20),
            AppButton(
              key: const Key('manual-save'),
              label: '${l.commonSave} · $_total rep',
              icon: LucideIcons.save,
              loading: _saving,
              onPressed: _total == 0 || _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow(
      {super.key,
      required this.index,
      required this.reps,
      required this.onMinus,
      required this.onPlus,
      required this.onRemove});

  final int index, reps;
  final VoidCallback? onMinus, onPlus, onRemove;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
              child: Text('${l.legacyWorkoutHudSet} ${index + 1}',
                  style: AppTypography.body16)),
          IconButton(
              key: const Key('manual-minus'),
              tooltip: l.commonHomeDecrease,
              onPressed: onMinus,
              icon: const Icon(LucideIcons.minus)),
          SizedBox(
            width: 56,
            child: Text('$reps',
                textAlign: TextAlign.center,
                style: AppTypography.metric40.copyWith(fontSize: 28)),
          ),
          IconButton(
              key: const Key('manual-plus'),
              tooltip: l.commonHomeIncrease,
              onPressed: onPlus,
              icon: const Icon(LucideIcons.plus)),
          IconButton(
              key: const Key('manual-remove-set'),
              tooltip: l.commonDelete,
              onPressed: onRemove,
              icon: const Icon(LucideIcons.trash2)),
        ],
      ),
    );
  }
}
