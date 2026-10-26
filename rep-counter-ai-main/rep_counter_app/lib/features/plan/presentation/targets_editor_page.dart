import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../exercise.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/product_ui.dart';
import '../domain/workout_plan.dart';
import 'plan_copy.dart';

/// Edits a list of exercise targets: exercises, sets, rep or duration
/// targets and tracking mode (camera or manual log). Returns the new list,
/// or null when cancelled. Saving never touches workouts already done.
class TargetsEditorPage extends StatefulWidget {
  const TargetsEditorPage(
      {super.key, required this.title, required this.targets, this.note});

  final String title;
  final List<ExerciseTarget> targets;
  final String? note;

  @override
  State<TargetsEditorPage> createState() => _TargetsEditorPageState();
}

class _TargetsEditorPageState extends State<TargetsEditorPage> {
  late final List<ExerciseTarget> _targets = [...widget.targets];

  void _set(int i, ExerciseTarget t) => setState(() => _targets[i] = t);

  Future<void> _add() async {
    final picked = await showModalBottomSheet<(String, bool)>(
        context: context,
        builder: (c) => SafeArea(
              child: ListView(shrinkWrap: true, children: [
                for (final e in allExercises) ...[
                  ListTile(
                      key: Key('add-${e.id}-reps'),
                      title: Text(c.exerciseName(e.id)),
                      subtitle: Text(c.tr('Mục tiêu rep', 'Rep target')),
                      onTap: () => Navigator.pop(c, (e.id, false))),
                  ListTile(
                      key: Key('add-${e.id}-time'),
                      title: Text(c.exerciseName(e.id)),
                      subtitle:
                          Text(c.tr('Mục tiêu thời gian', 'Duration target')),
                      onTap: () => Navigator.pop(c, (e.id, true))),
                ]
              ]),
            ));
    if (picked == null) return;
    setState(() => _targets.add(picked.$2
        ? ExerciseTarget(exerciseId: picked.$1, sets: 1, seconds: 45)
        : ExerciseTarget(exerciseId: picked.$1, sets: 3, reps: 8)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            if (widget.note != null) ...[
              Text(widget.note!,
                  style: AppTypography.body14.copyWith(color: AppColors.text2)),
              const SizedBox(height: 12),
            ],
            for (var i = 0; i < _targets.length; i++) _card(i),
            AppButton(
                key: const Key('targets-add'),
                label: context.tr('Thêm bài tập', 'Add exercise'),
                icon: LucideIcons.plus,
                variant: AppButtonVariant.secondary,
                onPressed: _add),
            const SizedBox(height: 16),
            AppButton(
                key: const Key('targets-save'),
                label: context.tr('Lưu', 'Save'),
                onPressed: _targets.isEmpty
                    ? null
                    : () => Navigator.of(context).pop(_targets)),
          ],
        ),
      ),
    );
  }

  Widget _card(int i) {
    final t = _targets[i];
    return Container(
      key: Key('target-$i'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(context.exerciseName(t.exerciseId),
                  style: AppTypography.row15)),
          IconButton(
              key: Key('target-$i-remove'),
              tooltip: context.tr('Xoá bài tập', 'Remove exercise'),
              onPressed: () => setState(() => _targets.removeAt(i)),
              icon: const Icon(LucideIcons.trash2, size: 18)),
        ]),
        _Stepper(
            key: Key('target-$i-sets'),
            label: context.tr('Số set', 'Sets'),
            value: t.sets,
            min: 1,
            max: 10,
            step: 1,
            onChanged: (v) => _set(i, t.copyWith(sets: v))),
        if (t.isDuration)
          _Stepper(
              key: Key('target-$i-seconds'),
              label: context.tr('Giây mỗi set', 'Seconds per set'),
              value: t.seconds!,
              min: 5,
              max: 600,
              step: 5,
              onChanged: (v) => _set(i, t.copyWith(seconds: v)))
        else
          _Stepper(
              key: Key('target-$i-reps'),
              label: context.tr('Rep mỗi set', 'Reps per set'),
              value: t.reps!,
              min: 1,
              max: 100,
              step: 1,
              onChanged: (v) => _set(i, t.copyWith(reps: v))),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          SegmentChip(
              key: Key('target-$i-camera'),
              label: context.tr('Camera đếm', 'Camera count'),
              selected: t.tracking == TrackingMode.camera,
              onTap: () => _set(i, _tracking(t, TrackingMode.camera))),
          SegmentChip(
              key: Key('target-$i-manual'),
              label: context.tr('Ghi thủ công', 'Manual log'),
              selected: t.tracking == TrackingMode.manual,
              onTap: () => _set(i, _tracking(t, TrackingMode.manual))),
        ]),
      ]),
    );
  }

  static ExerciseTarget _tracking(ExerciseTarget t, TrackingMode m) =>
      ExerciseTarget(
          exerciseId: t.exerciseId,
          sets: t.sets,
          reps: t.reps,
          seconds: t.seconds,
          tracking: m);
}

class _Stepper extends StatelessWidget {
  const _Stepper(
      {super.key,
      required this.label,
      required this.value,
      required this.min,
      required this.max,
      required this.step,
      required this.onChanged});

  final String label;
  final int value, min, max, step;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: Text(label, style: AppTypography.body14)),
        IconButton(
            key: const Key('minus'),
            tooltip: context.tr('Giảm $label', 'Decrease $label'),
            onPressed:
                value - step < min ? null : () => onChanged(value - step),
            icon: const Icon(LucideIcons.minus)),
        SizedBox(
            width: 44,
            child: Text('$value',
                textAlign: TextAlign.center, style: AppTypography.row15)),
        IconButton(
            key: const Key('plus'),
            tooltip: context.tr('Tăng $label', 'Increase $label'),
            onPressed:
                value + step > max ? null : () => onChanged(value + step),
            icon: const Icon(LucideIcons.plus)),
      ]);
}
