import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../camera_page.dart';
import '../../../core/i18n/locale_controller.dart';
import '../../../exercise.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/product_ui.dart';
import '../domain/workout_mode.dart';
import '../domain/workout_personal_records.dart';
import 'exercise_icon.dart';

typedef TimedBestLoader = Future<int?> Function(
  String exerciseId,
  int durationSeconds,
);

class GoalSetupPage extends StatelessWidget {
  const GoalSetupPage({super.key, required this.profile});

  final ExerciseProfile profile;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(profile.localizedName(context.s))),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: GoalSetupContent(
              profile: profile,
              onStart: (config) => Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => CameraPage(
                    profile: profile,
                    targetReps: config.targetReps,
                    timedChallenge: config.timedChallenge,
                    challengeBestReps: config.previousBestReps,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class GoalSetupContent extends StatefulWidget {
  const GoalSetupContent({
    super.key,
    required this.profile,
    required this.onStart,
    this.loadTimedBest,
  });

  final ExerciseProfile profile;
  final ValueChanged<WorkoutStartConfig> onStart;
  final TimedBestLoader? loadTimedBest;

  @override
  State<GoalSetupContent> createState() => _GoalSetupContentState();
}

class _GoalSetupContentState extends State<GoalSetupContent> {
  final _customReps = TextEditingController();
  final _customSeconds = TextEditingController();

  WorkoutMode _mode = WorkoutMode.targetReps;
  int? _goal = 20;
  int? _challengeSeconds = 60;
  bool _customTime = false;
  Future<int?>? _bestFuture;

  @override
  void dispose() {
    _customReps.dispose();
    _customSeconds.dispose();
    super.dispose();
  }

  Future<int?> _loadBest(int seconds) {
    final loader = widget.loadTimedBest;
    if (loader != null) return loader(widget.profile.id, seconds);
    return WorkoutPersonalRecordStore().bestTimedReps(
      exerciseId: widget.profile.id,
      challengeSeconds: seconds,
    );
  }

  void _selectMode(WorkoutMode mode) {
    setState(() {
      _mode = mode;
      if (mode == WorkoutMode.timed) {
        _challengeSeconds ??= 60;
        _refreshBest();
      }
    });
  }

  void _refreshBest() {
    final seconds = _challengeSeconds;
    _bestFuture = seconds == null ? null : _loadBest(seconds);
  }

  void _selectChallenge(int seconds) {
    setState(() {
      _customTime = false;
      _customSeconds.clear();
      _challengeSeconds = seconds;
      _refreshBest();
    });
  }

  void _selectCustomTime() {
    setState(() {
      _customTime = true;
      _challengeSeconds = null;
      _customSeconds.clear();
      _bestFuture = null;
    });
  }

  void _customTimeChanged(String text) {
    final seconds = int.tryParse(text);
    setState(() {
      _challengeSeconds = seconds != null && seconds > 0 ? seconds : null;
      _refreshBest();
    });
  }

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ExerciseIcon(
                exerciseId: widget.profile.id,
                color: AppColors.accent,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.profile.localizedName(context.s),
                  style: AppTypography.title20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _ModeSelector(
            selected: _mode,
            onSelected: _selectMode,
          ),
          const SizedBox(height: 24),
          if (_mode == WorkoutMode.timed)
            _timedContent(context)
          else if (_mode == WorkoutMode.free)
            _freeContent(context)
          else
            _targetContent(context),
        ],
      );

  Widget _targetContent(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr('KẾ HOẠCH HÔM NAY', "TODAY'S PLAN"),
            style: AppTypography.display40,
          ),
          const SizedBox(height: 12),
          Text(
            context.tr(
              'Chọn mục tiêu. Bạn vẫn có thể tập tiếp sau khi đạt.',
              'Choose a goal. You can keep going after reaching it.',
            ),
            style: const TextStyle(color: AppColors.text2, height: 1.5),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final value in [10, 20, 30, 50])
                ChoiceChip(
                  label: Text('$value rep'),
                  selected: _goal == value && _customReps.text.isEmpty,
                  onSelected: (_) => setState(() {
                    _goal = value;
                    _customReps.clear();
                  }),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('custom-rep-goal'),
            controller: _customReps,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            decoration: InputDecoration(
              labelText: context.s.goalOther,
              suffixText: 'rep',
              filled: true,
              fillColor: AppColors.surface2,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
            onChanged: (text) => setState(() {
              final n = int.tryParse(text);
              _goal = n != null && n > 0 ? n : null;
            }),
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            key: const Key('start-target-workout'),
            onPressed: _goal == null
                ? null
                : () => widget.onStart(WorkoutStartConfig.target(_goal!)),
            icon: const Icon(LucideIcons.play, size: 22),
            label: Text(context.tr('BẮT ĐẦU', 'START')),
          ),
          const SizedBox(height: 12),
          _hint(context),
        ],
      );

  Widget _freeContent(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr('TẬP TỰ DO', 'FREE WORKOUT'),
            style: AppTypography.display40,
          ),
          const SizedBox(height: 12),
          Text(
            context.tr(
              'Tập theo nhịp của bạn, không có mục tiêu rep hay giới hạn thời gian.',
              'Train at your own pace with no rep target or time limit.',
            ),
            style: const TextStyle(color: AppColors.text2, height: 1.5),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.infinity, color: AppColors.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.tr(
                      'Mọi rep được engine xác nhận vẫn được lưu bình thường.',
                      'Every rep accepted by the engine is saved normally.',
                    ),
                    style: const TextStyle(color: AppColors.text2, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            key: const Key('start-free-workout'),
            onPressed: () => widget.onStart(const WorkoutStartConfig.free()),
            icon: const Icon(LucideIcons.play, size: 22),
            label: Text(context.tr('BẮT ĐẦU', 'START')),
          ),
          const SizedBox(height: 12),
          _hint(context),
        ],
      );

  Widget _timedContent(BuildContext context) {
    final seconds = _challengeSeconds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.accent),
            ),
            child: Text(
              context.tr('THỬ THÁCH THỜI GIAN', 'TIME CHALLENGE'),
              style: AppTypography.caption12.copyWith(color: AppColors.accent),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          context.tr('THỬ THÁCH THỜI GIAN', 'TIME CHALLENGE'),
          style: AppTypography.display40,
        ),
        const SizedBox(height: 18),
        Text(
          context.tr('Chọn thời lượng', 'Choose duration'),
          style: AppTypography.body14.copyWith(color: AppColors.text2),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in [30, 60, 90])
              _TimeChip(
                label: context.tr('$value giây', '$value sec'),
                selected: !_customTime && seconds == value,
                onTap: () => _selectChallenge(value),
              ),
            _TimeChip(
              label: context.tr('Tùy chỉnh', 'Custom'),
              selected: _customTime,
              onTap: _selectCustomTime,
            ),
          ],
        ),
        if (_customTime) ...[
          const SizedBox(height: 14),
          TextField(
            key: const Key('custom-challenge-seconds'),
            controller: _customSeconds,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            decoration: InputDecoration(
              labelText: context.tr('Thời lượng', 'Duration'),
              suffixText: context.tr('giây', 'sec'),
              filled: true,
              fillColor: AppColors.surface2,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onChanged: _customTimeChanged,
          ),
        ],
        if (seconds != null) ...[
          const SizedBox(height: 24),
          FutureBuilder<int?>(
            future: _bestFuture ??= _loadBest(seconds),
            builder: (context, snapshot) {
              final best = snapshot.data;
              if (best == null) return const SizedBox.shrink();
              return _PersonalBestCard(
                seconds: seconds,
                reps: best,
              );
            },
          ),
        ],
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            context.tr(
              'Mục tiêu: làm nhiều rep tốt nhất có thể trong thời gian đã chọn.',
              'Goal: complete as many good reps as possible in the selected time.',
            ),
            style: AppTypography.body14.copyWith(color: AppColors.text2),
          ),
        ),
        const SizedBox(height: 28),
        FilledButton(
          key: const Key('start-time-challenge'),
          onPressed: seconds == null
              ? null
              : () async {
                  final best = await (_bestFuture ?? _loadBest(seconds));
                  if (!mounted) return;
                  widget.onStart(
                    WorkoutStartConfig.timed(
                      seconds,
                      previousBestReps: best,
                    ),
                  );
                },
          child: Text(
            context.tr('Bắt đầu thử thách', 'Start challenge'),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          key: const Key('cancel-time-challenge'),
          onPressed: () => _selectMode(WorkoutMode.targetReps),
          child: Text(context.s.cancel),
        ),
      ],
    );
  }

  Widget _hint(BuildContext context) => Text(
        widget.profile.localizedHint(context.s),
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.text3,
          fontSize: 12,
          height: 1.5,
        ),
      );
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({
    required this.selected,
    required this.onSelected,
  });

  final WorkoutMode selected;
  final ValueChanged<WorkoutMode> onSelected;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _ModeChip(
            key: const Key('mode-free'),
            label: context.tr('Tự do', 'Free'),
            selected: selected == WorkoutMode.free,
            onTap: () => onSelected(WorkoutMode.free),
          ),
          _ModeChip(
            key: const Key('mode-target'),
            label: context.tr('Mục tiêu rep', 'Target reps'),
            selected: selected == WorkoutMode.targetReps,
            onTap: () => onSelected(WorkoutMode.targetReps),
          ),
          _ModeChip(
            key: const Key('mode-timed'),
            label: context.tr('Thời gian', 'Time challenge'),
            selected: selected == WorkoutMode.timed,
            onTap: () => onSelected(WorkoutMode.timed),
          ),
        ],
      );
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      );
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 140),
          constraints: const BoxConstraints(minWidth: 80, minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppColors.surface3 : AppColors.surface2,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.border,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.body14.copyWith(
              color: selected ? AppColors.accent : AppColors.text2,
            ),
          ),
        ),
      );
}

class _PersonalBestCard extends StatelessWidget {
  const _PersonalBestCard({
    required this.seconds,
    required this.reps,
  });

  final int seconds;
  final int reps;

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('timed-personal-best-card'),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.borderStrong),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 18, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr(
                          'KỶ LỤC CỦA BẠN · $seconds GIÂY',
                          'YOUR BEST · $seconds SEC',
                        ),
                        style: AppTypography.caption12.copyWith(
                          color: AppColors.text2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$reps',
                            style: AppTypography.metric64.copyWith(
                              color: AppColors.accent,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 7),
                            child: Text(
                              'rep',
                              style: AppTypography.body14.copyWith(
                                color: AppColors.text2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
