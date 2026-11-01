import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../camera_page.dart';
import '../../../exercise.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_feedback.dart';
import '../../../widgets/product_ui.dart';
import '../../../widgets/status_badges.dart';
import '../../routine/domain/routine_preset.dart';
import '../../workout/domain/workout_mode.dart';
import '../../workout/presentation/guided_timer_page.dart';
import '../../workout/presentation/manual_log_page.dart';
import '../application/plan_repository.dart';
import '../domain/plan_schedule.dart';
import '../domain/workout_plan.dart';
import 'plan_copy.dart';
import 'reschedule_sheet.dart';
import 'targets_editor_page.dart';

/// Opens the workout screen for one target of a session. Workouts are saved
/// by the existing camera / manual flows; the plan links the saved record
/// afterwards (same local day, same exercise), so the counting engine and
/// the record flow are unchanged.
typedef StartTarget = Future<void> Function(
    BuildContext context, WorkoutPlan plan, ExerciseTarget target);

Future<void> startPlanTarget(
    BuildContext context, WorkoutPlan plan, ExerciseTarget t) {
  final profile = allExercises.firstWhere((e) => e.id == t.exerciseId,
      orElse: () => pushUp);
  final Widget page = t.tracking == TrackingMode.manual
      ? (t.isDuration
          // W-4b: a timed target tracked by hand runs the guided timer.
          ? GuidedTimerPage(profile: profile, sets: t.sets, seconds: t.seconds!)
          : ManualLogPage(profile: profile))
      : t.isDuration
          ? CameraPage(
              profile: profile,
              timedChallenge: TimedChallengeConfig(durationSeconds: t.seconds!))
          : CameraPage(
              profile: profile,
              routine: RoutineSnapshot(
                id: 'plan-${plan.id}',
                name: plan.name,
                exerciseId: profile.id,
                targetReps: t.reps!,
                targetSets: t.sets,
                restSeconds: 60,
                voiceCoachEnabled: true,
              ));
  return Navigator.of(context, rootNavigator: true)
      .push(MaterialPageRoute(builder: (_) => page));
}

/// P2-06 session detail: targets with real recorded progress, start,
/// reschedule, skip and edit.
class SessionDetailPage extends StatefulWidget {
  const SessionDetailPage({
    super.key,
    required this.sessionId,
    this.repository,
    this.start = startPlanTarget,
  });

  final String sessionId;
  final PlanRepository? repository;
  final StartTarget start;

  @override
  State<SessionDetailPage> createState() => _SessionDetailPageState();
}

class _SessionDetailPageState extends State<SessionDetailPage> {
  late final _repo = widget.repository ?? PlanRepository();
  PlanView? _view;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final view = await _repo.load();
    if (!mounted) return;
    setState(() {
      _view = view;
      _loading = false;
    });
  }

  PlannedSession? get _session {
    for (final s in _view?.sessions ?? const <PlannedSession>[]) {
      if (s.id == widget.sessionId) return s;
    }
    return null;
  }

  Future<void> _start(ExerciseTarget t) async {
    await widget.start(context, _view!.plan, t);
    await _load();
  }

  Future<void> _reschedule() async {
    final to = await showRescheduleSheet(context,
        repository: _repo, view: _view!, session: _session!);
    if (to == null || !mounted) return;
    AppToast.show(
        context,
        context.tr('Đã dời sang ${context.dayLabel(to)}',
            'Moved to ${context.dayLabel(to)}'));
    await _load();
  }

  Future<void> _skip() async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
              title: Text(c.tr('Bỏ qua buổi này?', 'Skip this session?')),
              content: Text(c.tr(
                  'Buổi này được đánh dấu bỏ qua, không phải đã tập. Các buổi khác không đổi.',
                  'It is marked skipped, not done. Your other sessions stay as they are.')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: Text(c.tr('Không', 'No'))),
                FilledButton(
                    key: const Key('skip-confirm'),
                    onPressed: () => Navigator.pop(c, true),
                    child: Text(c.tr('Bỏ qua', 'Skip'))),
              ],
            ));
    if (ok != true) return;
    await _repo.skip(widget.sessionId);
    await _load();
  }

  Future<void> _edit() async {
    final s = _session!;
    final targets = await Navigator.of(context).push<
        List<
            ExerciseTarget>>(MaterialPageRoute(
        builder: (_) => TargetsEditorPage(
            title: context.tr('Sửa buổi này', 'Edit this session'),
            note: context.tr(
                'Chỉ đổi buổi ngày ${context.dayLabel(s.scheduledLocalDate)}.',
                'Changes only the session on ${context.dayLabel(s.scheduledLocalDate)}.'),
            targets: s.exerciseTargets)));
    if (targets == null) return;
    await _repo.editTargets(s.id, targets);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final view = _view;
    final s = _session;
    if (_loading || view == null || s == null) {
      return Scaffold(
          appBar: AppBar(),
          body: Center(
              child: _loading
                  ? const CircularProgressIndicator()
                  : Text(context.tr('Không tìm thấy buổi tập này.',
                      'This session is no longer in your plan.'))));
    }
    final isToday = s.scheduledLocalDate == view.today;
    final canStart = isToday &&
        (s.state == SessionState.scheduled || s.state == SessionState.partial);
    final movable =
        s.state == SessionState.scheduled || s.state == SessionState.missed;
    final progress = PlanSchedule.progress(s, view.workouts);
    return Scaffold(
      appBar: AppBar(
          title: Text(context.templateName(view.plan, s.workoutTemplateId))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text(
                '${isToday ? context.tr('Hôm nay · ', 'Today · ') : ''}${context.dayLabel(s.scheduledLocalDate)}',
                style: AppTypography.body14.copyWith(color: AppColors.text2)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _StateChip(state: s.state),
              const SyncStatusBadge(state: SyncBadgeState.guestOnly),
            ]),
            if (s.rescheduledFrom != null) ...[
              const SizedBox(height: 8),
              Text(
                  context.tr(
                      'Dời từ ${context.dayLabel(s.originalScheduledDate)}',
                      'Moved from ${context.dayLabel(s.originalScheduledDate)}'),
                  style: AppTypography.body14.copyWith(color: AppColors.text2)),
            ],
            if (s.state == SessionState.missed) ...[
              const SizedBox(height: 12),
              AppBanner(
                  tone: AppBannerTone.warn,
                  title: context.tr('Buổi này chưa được tập.',
                      'This session didn\'t happen.'),
                  body: context.tr(
                      'Không sao cả. Bạn có thể dời sang ngày khác hoặc bỏ qua. Không có gì tự dời.',
                      'That\'s okay. Move it to another day or skip it. Nothing moves on its own.')),
            ],
            const SizedBox(height: 16),
            for (final p in progress)
              _TargetRow(
                  progress: p,
                  linked: s.completedWorkoutIds.isNotEmpty,
                  onStart: canStart ? () => _start(p.target) : null),
            const SizedBox(height: 8),
            if (canStart)
              Text(context.planTapHint,
                  style:
                      AppTypography.caption12.copyWith(color: AppColors.text2)),
            const SizedBox(height: 20),
            if (movable)
              AppButton(
                  key: const Key('session-reschedule'),
                  label: context.tr('Dời buổi tập', 'Move session'),
                  icon: LucideIcons.calendarClock,
                  variant: AppButtonVariant.secondary,
                  onPressed: _reschedule),
            if (s.state == SessionState.scheduled) ...[
              const SizedBox(height: 8),
              AppButton(
                  key: const Key('session-edit'),
                  label: context.tr(
                      'Sửa bài tập và mục tiêu', 'Edit exercises and targets'),
                  icon: LucideIcons.pencil,
                  variant: AppButtonVariant.secondary,
                  onPressed: _edit),
            ],
            if (movable) ...[
              const SizedBox(height: 8),
              AppButton(
                  key: const Key('session-skip'),
                  label: context.tr('Bỏ qua buổi này', 'Skip this session'),
                  variant: AppButtonVariant.ghost,
                  onPressed: _skip),
            ],
          ],
        ),
      ),
    );
  }
}

extension on BuildContext {
  String get planTapHint => tr(
      'Mỗi bài được lưu như một buổi tập; kế hoạch tự cập nhật khi bạn lưu.',
      'Each exercise saves as its own workout; the plan updates when you save.');
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.state});
  final SessionState state;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (state) {
      SessionState.completed => (LucideIcons.circleCheck, AppColors.success),
      SessionState.partial => (LucideIcons.circleDashed, AppColors.success),
      SessionState.missed => (LucideIcons.clockArrowUp, AppColors.warningText),
      SessionState.scheduled => (LucideIcons.calendar, AppColors.text),
      _ => (LucideIcons.minus, AppColors.text3),
    };
    return Container(
      key: Key('session-state-${state.name}'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: AppColors.surface2, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(context.sessionStateLabel(state),
            style: AppTypography.caption12.copyWith(color: color)),
      ]),
    );
  }
}

class _TargetRow extends StatelessWidget {
  const _TargetRow(
      {required this.progress, required this.linked, required this.onStart});

  final TargetProgress progress;
  final bool linked;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final t = progress.target;
    final done = t.isDuration
        ? context.tr('${progress.seconds}/${t.seconds! * t.sets} giây',
            '${progress.seconds}/${t.seconds! * t.sets} s')
        : context.tr('${progress.reps}/${t.totalReps} rep',
            '${progress.reps}/${t.totalReps} reps');
    return Container(
      key: Key('target-row-${t.exerciseId}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Icon(progress.met ? LucideIcons.circleCheck : LucideIcons.circle,
            color: progress.met ? AppColors.success : AppColors.text3),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.exerciseName(t.exerciseId),
                style: AppTypography.row15),
            Text(context.targetText(t),
                style: AppTypography.body14.copyWith(color: AppColors.text2)),
            if (linked)
              Text(
                  progress.manual
                      ? '$done · ${context.tr('ghi thủ công, không có điểm form', 'manual, no form score')}'
                      : done,
                  style: AppTypography.caption12
                      .copyWith(color: AppColors.textMuted)),
          ]),
        ),
        if (onStart != null && !progress.met)
          TextButton(
              key: Key('start-${t.exerciseId}'),
              onPressed: onStart,
              child: Text(t.tracking == TrackingMode.manual
                  ? context.tr('Ghi', 'Log')
                  : context.tr('Bắt đầu', 'Start'))),
      ]),
    );
  }
}
