import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_feedback.dart';
import '../../../widgets/product_ui.dart';
import '../application/plan_repository.dart';
import '../domain/local_date.dart';
import '../domain/plan_schedule.dart';
import '../domain/workout_plan.dart';
import 'plan_copy.dart';

/// Asks before using a recovery day (PL-1: a non-blocking warning the user
/// confirms). Returns true when they still want it.
Future<bool> confirmRecoveryDay(BuildContext context, LocalDate date) async =>
    await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
              title: Text(c.tr('${c.dayLabel(date)} là ngày phục hồi',
                  '${c.dayLabel(date)} is a recovery day')),
              content: Text(c.tr(
                  'Nghỉ giữa các buổi giúp cơ thể hồi phục. Bạn vẫn có thể tập hôm đó nếu thấy khỏe; đừng tập khi đang đau.',
                  'Rest between sessions helps you recover. You can still train that day if you feel fine; don\'t train through pain.')),
              actions: [
                TextButton(
                    key: const Key('recovery-warning-cancel'),
                    onPressed: () => Navigator.pop(c, false),
                    child: Text(c.tr('Chọn ngày khác', 'Pick another day'))),
                FilledButton(
                    key: const Key('recovery-warning-confirm'),
                    onPressed: () => Navigator.pop(c, true),
                    child: Text(c.tr('Vẫn tập ngày này', 'Train that day'))),
              ],
            )) ==
    true;

/// P2-12a: move a scheduled or missed session to a day the user picks.
/// Nothing moves without the user's choice and confirmation; taken and past
/// days cannot be picked; recovery days ask first. Returns the new date.
Future<LocalDate?> showRescheduleSheet(BuildContext context,
        {required PlanRepository repository,
        required PlanView view,
        required PlannedSession session}) =>
    showModalBottomSheet<LocalDate>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _RescheduleSheet(
            repository: repository, view: view, session: session));

class _RescheduleSheet extends StatefulWidget {
  const _RescheduleSheet(
      {required this.repository, required this.view, required this.session});

  final PlanRepository repository;
  final PlanView view;
  final PlannedSession session;

  @override
  State<_RescheduleSheet> createState() => _RescheduleSheetState();
}

class _RescheduleSheetState extends State<_RescheduleSheet> {
  LocalDate? _picked;
  bool _busy = false;
  String? _error;

  late final List<LocalDate> _options = [
    for (var i = 0; i < 7; i++) widget.view.today.addDays(i)
  ];
  late final Set<LocalDate> _recommended = {
    ...PlanSchedule.alternatives(widget.view.plan, widget.view.sessions,
        widget.session.scheduledLocalDate, widget.view.today,
        exceptSessionId: widget.session.id)
  };

  Future<void> _move() async {
    final to = _picked;
    if (to == null || _busy) return;
    var confirm = false;
    if (widget.view.plan.dayKind(to) == DayKind.recovery) {
      confirm = await confirmRecoveryDay(context, to);
      if (!confirm || !mounted) return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await widget.repository
        .reschedule(widget.session.id, to, confirmRecovery: confirm);
    if (!mounted) return;
    if (result is ScheduleApplied) {
      Navigator.of(context).pop(to);
    } else {
      setState(() {
        _busy = false;
        _error = context.tr('Ngày này không còn trống. Chọn ngày khác nhé.',
            'That day is no longer free. Pick another one.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    final s = widget.session;
    final name = context.templateName(view.plan, s.workoutTemplateId);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(context.tr('Dời $name', 'Move $name'),
              style: AppTypography.title22),
          const SizedBox(height: 8),
          Text(
              s.state == SessionState.missed
                  ? context.tr(
                      'Lỡ buổi ${context.dayLabel(s.scheduledLocalDate)}? Chuyện bình thường thôi. Hãy chọn một ngày khác.',
                      'Missed ${context.dayLabel(s.scheduledLocalDate)}? That happens. Pick another day.')
                  : context.tr('Chọn ngày mới cho buổi này.',
                      'Pick a new day for this session.'),
              style: AppTypography.body14.copyWith(color: AppColors.text2)),
          const SizedBox(height: 16),
          for (final d in _options) _row(d),
          if (_error != null) ...[
            const SizedBox(height: 8),
            AppBanner(title: _error!, tone: AppBannerTone.warn),
          ],
          const SizedBox(height: 16),
          AppButton(
            key: const Key('reschedule-confirm'),
            label: _picked == null
                ? context.tr('Chọn một ngày', 'Pick a day')
                : context.tr('Dời sang ${context.dayLabel(_picked!)}',
                    'Move to ${context.dayLabel(_picked!)}'),
            loading: _busy,
            onPressed: _picked == null ? null : _move,
          ),
          const SizedBox(height: 8),
          AppButton(
            key: const Key('reschedule-cancel'),
            label: context.tr('Để nguyên', 'Keep as is'),
            variant: AppButtonVariant.ghost,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ]),
      ),
    );
  }

  Widget _row(LocalDate d) {
    final view = widget.view;
    final other = PlanSchedule.sessionOn(view.sessions, d);
    final taken = other != null && other.id != widget.session.id;
    final current = d == widget.session.scheduledLocalDate &&
        widget.session.state == SessionState.scheduled;
    final kind = view.plan.dayKind(d);
    final note = taken
        ? context.tr(
            'Đã có ${context.templateName(view.plan, other.workoutTemplateId)}',
            '${context.templateName(view.plan, other.workoutTemplateId)} already planned')
        : current
            ? context.tr('Ngày hiện tại', 'Current day')
            : kind == DayKind.recovery
                ? context.tr('Ngày phục hồi', 'Recovery day')
                : _recommended.contains(d)
                    ? context.l10n.plansFreeDayRecommended
                    : context.l10n.plansFreeDay;
    final enabled = !taken && !current;
    final selected = _picked == d;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        selected: selected,
        enabled: enabled,
        button: true,
        child: InkWell(
          key: Key('reschedule-${d.toIso()}'),
          borderRadius: BorderRadius.circular(14),
          onTap: enabled ? () => setState(() => _picked = d) : null,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: selected ? AppColors.accent : AppColors.border,
                  width: selected ? 1.5 : 1),
            ),
            child: Row(children: [
              SizedBox(
                width: 64,
                child: Text(context.dayLabel(d),
                    style: AppTypography.row15.copyWith(
                        color: enabled ? AppColors.text : AppColors.text3)),
              ),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(note,
                      style: AppTypography.body14.copyWith(
                          color: enabled ? AppColors.text2 : AppColors.text3))),
              if (kind == DayKind.recovery && !taken)
                const Icon(LucideIcons.moon,
                    size: 16, color: AppColors.textMuted),
              if (selected)
                const Icon(LucideIcons.circleCheck, color: AppColors.accent),
            ]),
          ),
        ),
      ),
    );
  }
}
