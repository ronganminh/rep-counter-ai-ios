import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_feedback.dart';
import '../../../widgets/product_ui.dart';
import '../../workout/data/workout_database.dart';
import '../application/plan_repository.dart';
import '../domain/workout_plan.dart';
import '../domain/plan_templates.dart';
import 'plan_calendar.dart';
import 'plan_copy.dart';

/// P2-01…03 plan setup: goal, level, training days, then a four-week
/// preview before anything is saved. Defaults to the PL-1 beginner plan
/// (Mon / Wed / Fri, Full Body A/B/C); every choice can be changed.
/// With [editing], changes the current plan's goal, level and days; only
/// sessions still to come are replanned.
class PlanSetupPage extends StatefulWidget {
  const PlanSetupPage({super.key, this.repository, this.editing});

  final PlanRepository? repository;
  final WorkoutPlan? editing;

  @override
  State<PlanSetupPage> createState() => _PlanSetupPageState();
}

class _PlanSetupPageState extends State<PlanSetupPage> {
  late final _repo = widget.repository ?? PlanRepository();
  late int _step = widget.editing == null ? 0 : 2;
  late PlanGoal _goal = widget.editing?.goal ?? PlanGoal.generalFitness;
  late PlanDifficulty _level =
      widget.editing?.difficulty ?? PlanDifficulty.beginner;
  late final Set<int> _days = {
    ...widget.editing?.selectedWeekdays ?? PlanTemplates.defaultWeekdays
  };
  bool _busy = false;
  String? _error;

  /// The first step closes the setup; nothing is saved before the end.
  bool get _closes => _step == (widget.editing == null ? 0 : 2);

  bool get _daysValid =>
      _days.length >= WorkoutPlan.minDays &&
      _days.length <= WorkoutPlan.maxDays;

  WorkoutPlan _draft() {
    final editing = widget.editing;
    final days = _days.toList()..sort();
    if (editing != null) {
      return editing.copyWith(
          goal: _goal,
          difficulty: _level,
          selectedWeekdays: days,
          // Templates only change when the level changes, and then only
          // for sessions still to come.
          templates: _level == editing.difficulty
              ? editing.templates
              : PlanTemplates.fullBody(_level));
    }
    return PlanTemplates.beginnerPlan(
      id: WorkoutDatabase.newClientId(),
      startDate: _repo.today,
      timezone: _repo.timezone,
      now: DateTime.now(),
      name: context.tr('Full Body · ${days.length} buổi/tuần',
          'Full Body · ${days.length} days'),
      goal: _goal,
      difficulty: _level,
      weekdays: days,
    );
  }

  Future<void> _create({bool replace = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.editing != null) {
        await _repo.edit(_draft());
      } else {
        await _repo.activate(_draft(), replaceCurrent: replace);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on PlanAlreadyActive {
      if (!mounted) return;
      setState(() => _busy = false);
      final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
                title: Text(c.tr(
                    'Thay kế hoạch hiện tại?', 'Replace your current plan?')),
                content: Text(c.tr(
                    'Kế hoạch cũ được lưu trữ; các buổi đã tập vẫn giữ nguyên trong lịch sử.',
                    'Your current plan is archived. Workouts you did stay in your history.')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: Text(c.tr('Huỷ', 'Cancel'))),
                  FilledButton(
                      key: const Key('plan-replace-confirm'),
                      onPressed: () => Navigator.pop(c, true),
                      child: Text(c.tr('Thay kế hoạch', 'Replace plan'))),
                ],
              ));
      if (ok == true) await _create(replace: true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = context.tr('Chưa lưu được kế hoạch. Thử lại nhé.',
              'Could not save the plan. Please try again.');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final steps = [
      l.plansStep,
      l.plansStep2,
      l.plansStep3,
      context.tr('Xem trước 4 tuần', 'Four-week preview'),
    ];
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: _closes
              ? context.tr('Đóng', 'Close')
              : context.tr('Quay lại', 'Back'),
          icon: Icon(_closes ? LucideIcons.x : LucideIcons.arrowLeft),
          onPressed: () =>
              _closes ? Navigator.of(context).pop() : setState(() => _step--),
        ),
        title: Text(steps[_step], style: AppTypography.body14),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            ...switch (_step) {
              0 => _goalStep(),
              1 => _levelStep(),
              2 => _daysStep(),
              _ => _previewStep(),
            },
            if (_error != null) ...[
              const SizedBox(height: 12),
              AppBanner(title: _error!, tone: AppBannerTone.err),
            ],
            const SizedBox(height: 24),
            AppButton(
              key: const Key('plan-setup-next'),
              label: _step < 3
                  ? context.tr('Tiếp tục', 'Continue')
                  : widget.editing != null
                      ? context.tr('Lưu thay đổi', 'Save changes')
                      : l.plansCreateMyPlan,
              loading: _busy,
              onPressed: _step == 2 && !_daysValid
                  ? null
                  : _step < 3
                      ? () => setState(() => _step++)
                      : _create,
            ),
          ],
        ),
      ),
    );
  }

  Widget _option(
          {required Key key,
          required String title,
          required String body,
          required bool selected,
          required VoidCallback onTap}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Semantics(
          selected: selected,
          button: true,
          child: InkWell(
            key: key,
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 80),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: selected ? AppColors.accent : AppColors.border,
                    width: selected ? 1.5 : 1),
              ),
              child: Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title, style: AppTypography.row15),
                      const SizedBox(height: 4),
                      Text(body,
                          style: AppTypography.body14
                              .copyWith(color: AppColors.text2)),
                    ])),
                Icon(selected ? LucideIcons.circleCheck : LucideIcons.circle,
                    color: selected ? AppColors.accent : AppColors.text3),
              ]),
            ),
          ),
        ),
      );

  List<Widget> _goalStep() {
    final l = context.l10n;
    return [
      Text(l.plansWhatSMainGoal, style: AppTypography.title22),
      const SizedBox(height: 8),
      Text(l.plansPickOneCanChange,
          style: AppTypography.body14.copyWith(color: AppColors.text2)),
      const SizedBox(height: 20),
      for (final (goal, title, body) in [
        (
          PlanGoal.generalFitness,
          l.plansBuildConsistency,
          l.plansShortSessionsFitBusy
        ),
        (PlanGoal.strength, l.plansBuildStrength, l.plansMoreRepsLongerHolds),
        (
          PlanGoal.endurance,
          l.plansImproveFitness,
          l.plansMixStrengthCardioMoves
        ),
      ])
        _option(
            key: Key('plan-goal-${goal.name}'),
            title: title,
            body: body,
            selected: _goal == goal,
            onTap: () => setState(() => _goal = goal)),
    ];
  }

  List<Widget> _levelStep() {
    final l = context.l10n;
    return [
      Text(l.plansHowMuchDoTrain, style: AppTypography.title22),
      const SizedBox(height: 8),
      Text(l.plansSetsStartingTargets,
          style: AppTypography.body14.copyWith(color: AppColors.text2)),
      const SizedBox(height: 20),
      for (final (level, body) in [
        (PlanDifficulty.beginner, l.plansNewBodyweightTrainingComing),
        (PlanDifficulty.intermediate, l.plansTrainTimesWeekPush),
        (PlanDifficulty.advanced, l.plansTrainMoreTimesWeek),
      ])
        _option(
            key: Key('plan-level-${level.name}'),
            title: context.levelLabel(level),
            body: body,
            selected: _level == level,
            onTap: () => setState(() => _level = level)),
      Text(l.plansTargetsGeneralFitnessGuidance,
          style: AppTypography.caption12.copyWith(color: AppColors.text2)),
    ];
  }

  List<Widget> _daysStep() {
    final l = context.l10n;
    final days = _days.toList()..sort();
    return [
      Text(l.plansWhenCanTrain, style: AppTypography.title22),
      const SizedBox(height: 8),
      Text(
          context.tr(
              'Chọn 2–6 ngày tập mỗi tuần. Các ngày còn lại là ngày phục hồi.',
              'Pick 2–6 training days a week. The other days are recovery days.'),
          style: AppTypography.body14.copyWith(color: AppColors.text2)),
      const SizedBox(height: 20),
      SectionLabel(l.plansDaysReFree),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (var d = DateTime.monday; d <= DateTime.sunday; d++)
          SegmentChip(
              key: Key('plan-day-chip-$d'),
              label: context.weekdayShort(d),
              selected: _days.contains(d),
              onTap: () => setState(
                  () => _days.contains(d) ? _days.remove(d) : _days.add(d))),
      ]),
      const SizedBox(height: 16),
      if (_days.length < WorkoutPlan.minDays)
        AppBanner(
            key: const Key('plan-days-too-few'),
            title: context.tr('Chọn ít nhất 2 ngày', 'Pick at least 2 days'),
            tone: AppBannerTone.warn)
      else if (_days.length > WorkoutPlan.maxDays)
        AppBanner(
            key: const Key('plan-days-too-many'),
            title: context.tr(
                'Tối đa 6 ngày: nên giữ ít nhất một ngày phục hồi.',
                'Up to 6 days: keep at least one recovery day.'),
            tone: AppBannerTone.warn)
      else
        Text(
            context.tr(
                '${days.length} buổi/tuần · ${context.weekdaysList(days)}',
                '${days.length} sessions a week · ${context.weekdaysList(days)}'),
            key: const Key('plan-days-summary'),
            style: AppTypography.body14),
    ];
  }

  List<Widget> _previewStep() {
    final draft = _draft();
    final days = _repo.preview(draft);
    return [
      Text(draft.name, style: AppTypography.title22),
      const SizedBox(height: 4),
      Text(context.planSummary(draft),
          style: AppTypography.body14.copyWith(color: AppColors.text2)),
      const SizedBox(height: 16),
      PlanCalendar(days: days, today: _repo.today, onDay: (_) {}),
      const SizedBox(height: 16),
      for (final t in draft.templates)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.name, style: AppTypography.row15),
              const SizedBox(height: 4),
              for (final x in t.targets)
                Text(
                    '${context.exerciseName(x.exerciseId)} · ${context.targetText(x)}',
                    style:
                        AppTypography.body14.copyWith(color: AppColors.text2)),
            ]),
          ),
        ),
      Text(
          context.tr(
              'Bạn có thể đổi ngày, bài tập và mục tiêu bất cứ lúc nào. Kế hoạch lưu trên điện thoại này, không cần tài khoản.',
              'You can change days, exercises and targets any time. The plan is saved on this phone; no account needed.'),
          style: AppTypography.caption12.copyWith(color: AppColors.text2)),
    ];
  }
}
