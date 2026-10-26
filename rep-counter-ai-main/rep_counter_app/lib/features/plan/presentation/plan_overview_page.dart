import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_feedback.dart';
import '../../../widgets/product_ui.dart';
import '../../../widgets/status_badges.dart';
import '../application/plan_repository.dart';
import '../domain/local_date.dart';
import '../domain/plan_schedule.dart';
import '../domain/workout_plan.dart';
import 'plan_calendar.dart';
import 'plan_copy.dart';
import 'overload_page.dart';
import 'plan_setup_page.dart';
import 'reschedule_sheet.dart';
import 'session_detail_page.dart';
import 'targets_editor_page.dart';

/// P2-04a / P2-05 plan overview: today, missed sessions (offered a move,
/// never moved for the user), and the next four weeks.
class PlanOverviewPage extends StatefulWidget {
  const PlanOverviewPage(
      {super.key, this.repository, this.start = startPlanTarget});

  final PlanRepository? repository;
  final StartTarget start;

  @override
  State<PlanOverviewPage> createState() => _PlanOverviewPageState();
}

class _PlanOverviewPageState extends State<PlanOverviewPage> {
  late final _repo = widget.repository ?? PlanRepository();
  PlanView? _view;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final view = await _repo.load();
      if (!mounted) return;
      setState(() {
        _view = view;
        _loading = false;
        _failed = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  Future<void> _openSession(PlannedSession s) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => SessionDetailPage(
            sessionId: s.id, repository: _repo, start: widget.start)));
    await _load();
  }

  Future<void> _openDay(PlanDay day) async {
    final s = day.session;
    if (s != null) return _openSession(s);
    await showRecoveryDaySheet(context,
        repository: _repo, view: _view!, date: day.date);
    await _load();
  }

  Future<void> _move(PlannedSession s) async {
    final to = await showRescheduleSheet(context,
        repository: _repo, view: _view!, session: s);
    if (to == null || !mounted) return;
    AppToast.show(
        context,
        context.tr('Đã dời sang ${context.dayLabel(to)}',
            'Moved to ${context.dayLabel(to)}'));
    await _load();
  }

  Future<void> _menu(String action) async {
    final view = _view!;
    switch (action) {
      case 'days':
        await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) =>
                PlanSetupPage(repository: _repo, editing: view.plan)));
      case 'workouts':
        await _editTemplates(view.plan);
      case 'overload':
        await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => OverloadPage(repository: _repo)));
      case 'pause':
        await _repo.setStatus(PlanStatus.paused);
      case 'resume':
        await _repo.setStatus(PlanStatus.active);
      case 'end':
        final ok = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
                  title: Text(c.tr('Kết thúc kế hoạch?', 'End this plan?')),
                  content: Text(c.tr(
                      'Kế hoạch được lưu trữ. Các buổi đã tập vẫn ở trong lịch sử.',
                      'The plan is archived. Workouts you did stay in your history.')),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: Text(c.tr('Huỷ', 'Cancel'))),
                    FilledButton(
                        key: const Key('plan-end-confirm'),
                        onPressed: () => Navigator.pop(c, true),
                        child: Text(c.tr('Kết thúc', 'End plan'))),
                  ],
                ));
        if (ok == true) await _repo.setStatus(PlanStatus.archived);
    }
    await _load();
  }

  Future<void> _editTemplates(WorkoutPlan plan) async {
    final template = await showModalBottomSheet<WorkoutTemplate>(
        context: context,
        builder: (c) => SafeArea(
                child: ListView(shrinkWrap: true, children: [
              for (final t in plan.templates)
                ListTile(
                    key: Key('edit-template-${t.id}'),
                    title: Text(t.name),
                    subtitle: Text(t.targets
                        .map((x) =>
                            '${c.exerciseName(x.exerciseId)} ${c.targetText(x)}')
                        .join(' · ')),
                    onTap: () => Navigator.pop(c, t)),
            ])));
    if (template == null || !mounted) return;
    final targets = await Navigator.of(context).push<
        List<
            ExerciseTarget>>(MaterialPageRoute(
        builder: (_) => TargetsEditorPage(
            title: template.name,
            note: context.tr(
                'Áp dụng cho các buổi sắp tới. Buổi đã tập không đổi.',
                'Applies to upcoming sessions. Sessions already done stay as they are.'),
            targets: template.targets)));
    if (targets == null) return;
    await _repo.edit(plan.copyWith(templates: [
      for (final t in plan.templates)
        t.id == template.id ? t.copyWith(targets: targets) : t
    ]));
  }

  @override
  Widget build(BuildContext context) {
    final view = _view;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Kế hoạch', 'Plan')),
        actions: [
          if (view != null)
            PopupMenuButton<String>(
              key: const Key('plan-menu'),
              tooltip: context.tr('Tuỳ chọn kế hoạch', 'Plan options'),
              onSelected: _menu,
              itemBuilder: (c) => [
                PopupMenuItem(
                    value: 'days', child: Text(c.l10n.plansChangeTrainingDays)),
                PopupMenuItem(
                    value: 'workouts',
                    child: Text(c.tr('Sửa bài tập', 'Edit workouts'))),
                PopupMenuItem(
                    value: 'overload',
                    child: Text(
                        c.tr('Gợi ý tăng dần', 'Progression suggestions'))),
                if (view.plan.status == PlanStatus.active)
                  PopupMenuItem(
                      value: 'pause',
                      child: Text(c.tr('Tạm dừng kế hoạch', 'Pause plan'))),
                if (view.plan.status == PlanStatus.paused)
                  PopupMenuItem(
                      value: 'resume',
                      child: Text(c.tr('Tiếp tục kế hoạch', 'Resume plan'))),
                PopupMenuItem(
                    value: 'end',
                    child: Text(c.tr('Kết thúc kế hoạch', 'End plan'))),
              ],
            ),
        ],
      ),
      body: SafeArea(child: _body(view)),
    );
  }

  Widget _body(PlanView? view) {
    final l = context.l10n;
    if (_loading) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 12),
        Text(context.tr('Đang tải kế hoạch…', 'Loading your plan…')),
      ]));
    }
    if (_failed) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: AppBanner(
            tone: AppBannerTone.err,
            title: l.plansCouldnTLoadPlan,
            body: context.tr(
                'Các buổi tập đã lưu trên điện thoại này vẫn an toàn.',
                'Workouts saved on this phone are safe.'),
            actionLabel: context.tr('Thử lại', 'Retry'),
            onAction: _load),
      );
    }
    if (view == null) {
      return ListView(padding: const EdgeInsets.all(20), children: [
        Text(l.plansNoPlanYet, style: AppTypography.title22),
        const SizedBox(height: 8),
        Text(l.plansAnswerQuestionsGetWeekly,
            style: AppTypography.body14.copyWith(color: AppColors.text2)),
        const SizedBox(height: 20),
        AppButton(
            key: const Key('plan-create'),
            label: l.plansCreatePlan,
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => PlanSetupPage(repository: _repo)));
              await _load();
            }),
      ]);
    }
    final plan = view.plan;
    final week = view.calendar(view.today.startOfWeek, days: 7);
    final weekSessions = [
      for (final d in week)
        if (d.session != null) d.session!
    ];
    final weekDone =
        weekSessions.where((s) => s.state == SessionState.completed).length;
    final today = view.todaySession;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(plan.name, style: AppTypography.title22),
          const SizedBox(height: 4),
          Text(context.planSummary(plan),
              style: AppTypography.body14.copyWith(color: AppColors.text2)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            const SyncStatusBadge(state: SyncBadgeState.guestOnly),
            if (plan.status == PlanStatus.paused)
              Chip(
                  key: const Key('plan-paused'),
                  label: Text(context.tr('Đang tạm dừng', 'Paused'))),
          ]),
          const SizedBox(height: 16),
          _todayCard(view, today),
          for (final s in view.missed)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: AppBanner(
                key: Key('missed-${s.id}'),
                tone: AppBannerTone.warn,
                title: context.tr(
                    '${context.templateName(plan, s.workoutTemplateId)} ngày ${context.dayLabel(s.scheduledLocalDate)} chưa được tập.',
                    '${context.dayLabel(s.scheduledLocalDate)}: ${context.templateName(plan, s.workoutTemplateId)} didn\'t happen.'),
                body: context.tr('Dời sang ngày khác hoặc bỏ qua.',
                    'Move it to another day or skip it.'),
                actionLabel: l.plansMove,
                onAction: () => _move(s),
              ),
            ),
          const SizedBox(height: 20),
          SectionLabel(context.tr('4 tuần tới', 'Next four weeks')),
          PlanCalendar(
              days: view.calendar(view.today.startOfWeek),
              today: view.today,
              onDay: _openDay),
          const SizedBox(height: 12),
          Text(
              context.tr(
                  'Tuần này · xong $weekDone/${weekSessions.length} buổi',
                  'This week · $weekDone of ${weekSessions.length} sessions done'),
              key: const Key('plan-week-summary'),
              style: AppTypography.body14.copyWith(color: AppColors.text2)),
        ],
      ),
    );
  }

  Widget _todayCard(PlanView view, PlannedSession? s) {
    final plan = view.plan;
    final recovery = s == null && plan.dayKind(view.today) == DayKind.recovery;
    return Container(
      key: const Key('plan-today'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
            context.tr('Hôm nay · ${context.dayLabel(view.today)}',
                'Today · ${context.dayLabel(view.today)}'),
            style: AppTypography.caption12.copyWith(color: AppColors.text2)),
        const SizedBox(height: 6),
        if (s != null) ...[
          Text(context.templateName(plan, s.workoutTemplateId),
              style: AppTypography.title20),
          const SizedBox(height: 4),
          Text(
              s.exerciseTargets
                  .map((t) =>
                      '${context.exerciseName(t.exerciseId)} ${context.targetText(t)}')
                  .join(' · '),
              style: AppTypography.body14.copyWith(color: AppColors.text2)),
          const SizedBox(height: 12),
          AppButton(
              key: const Key('plan-open-today'),
              label: s.state == SessionState.completed
                  ? context.l10n.plansViewSummary
                  : context.tr('Xem buổi tập', 'View workout'),
              onPressed: () => _openSession(s)),
        ] else if (recovery) ...[
          Row(children: [
            const Icon(LucideIcons.moon, color: AppColors.textMuted),
            const SizedBox(width: 8),
            Text(context.tr('Ngày phục hồi', 'Recovery day'),
                style: AppTypography.title20),
          ]),
          const SizedBox(height: 4),
          Text(context.l10n.plansPlannedRestDayBetween,
              style: AppTypography.body14.copyWith(color: AppColors.text2)),
          const SizedBox(height: 8),
          AppButton(
              key: const Key('plan-open-recovery'),
              label: context.l10n.plansOpenRecoveryDay,
              variant: AppButtonVariant.secondary,
              onPressed: () =>
                  _openDay(PlanDay(view.today, DayKind.recovery, null))),
        ] else
          Text(context.l10n.plansNoSession, style: AppTypography.title20),
      ]),
    );
  }
}

/// P2-12b: what a recovery day is, the next session, and — only if the user
/// asks — a workout on this day after a non-blocking recovery warning.
Future<void> showRecoveryDaySheet(BuildContext context,
    {required PlanRepository repository,
    required PlanView view,
    required LocalDate date}) {
  final plan = view.plan;
  PlannedSession? next;
  for (final s in view.sessions) {
    if (s.isUpcoming && s.scheduledLocalDate.isAfter(date)) {
      next = s;
      break;
    }
  }
  final recovery = plan.dayKind(date) == DayKind.recovery;
  final canAdd = !date.isBefore(view.today) && plan.templates.isNotEmpty;
  return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (c) => SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(c.dayLabel(date),
                        style: AppTypography.caption12
                            .copyWith(color: AppColors.text2)),
                    const SizedBox(height: 4),
                    Text(
                        recovery
                            ? c.tr('Ngày phục hồi', 'Recovery day')
                            : c.l10n.plansFreeDay,
                        key: const Key('recovery-title'),
                        style: AppTypography.title22),
                    const SizedBox(height: 8),
                    Text(
                        recovery
                            ? c.l10n.plansPlannedRestDayBetween
                            : c.l10n.plansAvailableIfNeedMove,
                        style: AppTypography.body14
                            .copyWith(color: AppColors.text2)),
                    if (next != null) ...[
                      const SizedBox(height: 12),
                      Text(
                          c.tr(
                              'Buổi tiếp theo · ${c.dayLabel(next.scheduledLocalDate)} · ${c.templateName(plan, next.workoutTemplateId)}',
                              'Next session · ${c.dayLabel(next.scheduledLocalDate)} · ${c.templateName(plan, next.workoutTemplateId)}'),
                          style: AppTypography.body14),
                    ],
                    const SizedBox(height: 20),
                    if (canAdd)
                      AppButton(
                          key: const Key('recovery-add-workout'),
                          label: c.tr('Thêm buổi tập ngày này',
                              'Add a workout on this day'),
                          variant: AppButtonVariant.secondary,
                          onPressed: () async {
                            if (recovery &&
                                !await confirmRecoveryDay(c, date)) {
                              return;
                            }
                            final result = await repository.addSession(
                                date, PlanSchedule.templateFor(plan, date).id,
                                confirmRecovery: recovery);
                            if (c.mounted && result is ScheduleApplied) {
                              Navigator.of(c).pop();
                            }
                          }),
                    const SizedBox(height: 8),
                    AppButton(
                        key: const Key('recovery-close'),
                        label: c.tr('Về kế hoạch', 'Back to plan'),
                        variant: AppButtonVariant.ghost,
                        onPressed: () => Navigator.of(c).pop()),
                  ]),
            ),
          ));
}
