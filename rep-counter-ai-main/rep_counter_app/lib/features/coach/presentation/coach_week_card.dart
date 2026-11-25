import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_feedback.dart';
import '../../../widgets/product_ui.dart';
import '../../credits/credits_controller.dart';
import '../../plan/application/plan_repository.dart';
import '../../plan/domain/plan_schedule.dart';
import '../../plan/domain/workout_plan.dart';
import '../../plan/presentation/plan_copy.dart';
import '../../workout/data/workout_history_store.dart';
import '../../workout/data/workout_record.dart';
import '../coach_apply.dart';
import '../coach_v2.dart';
import '../coach_week.dart';
import 'coach_copy.dart';
import 'coach_widgets.dart';

/// AC-04 "Coach · next week" in My plan (`/home/plan`, tab bar visible, no
/// new tab, D-36). Shown with the flag, an account and consent; nothing
/// changes without Apply; Undo per day; "Keep my plan" hides it for the
/// week.
class CoachWeekCard extends StatefulWidget {
  const CoachWeekCard({
    super.key,
    required this.plans,
    this.credits,
    this.loadWorkouts,
    this.onChanged,
    this.consent = const CoachConsentStore(),
    this.newId,
  });

  final PlanRepository plans;
  final CreditsController? credits;
  final Future<List<WorkoutRecord>> Function()? loadWorkouts;

  /// Called after the plan changed (to refresh the page).
  final VoidCallback? onChanged;
  final CoachConsentStore consent;
  final String Function()? newId;

  @override
  State<CoachWeekCard> createState() => _CoachWeekCardState();
}

class _CoachWeekCardState extends State<CoachWeekCard> {
  CoachWeekController? _c;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final credits = widget.credits ?? CreditsScope.maybeOf(context);
    if (_c != null || credits == null) return;
    _c = CoachWeekController(
        credits: credits,
        plans: widget.plans,
        loadWorkouts: widget.loadWorkouts ?? WorkoutHistoryStore().load,
        consent: widget.consent,
        newId: widget.newId)
      ..addListener(_changed);
    _c!.load();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _c?.removeListener(_changed);
    _c?.dispose();
    super.dispose();
  }

  Future<void> _apply(String id) async {
    final c = _c!;
    final s = c.session(id);
    if (!await c.apply(id) || !mounted || s == null) return;
    widget.onChanged?.call();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      key: const Key('coach-week-toast'),
      content: Text(context.l10n
          .ptAppliedToast(context.weekdayLong(s.scheduledLocalDate.weekday))),
      action: SnackBarAction(
          label: context.l10n.commonUndo,
          onPressed: () async {
            await c.undo(id);
            widget.onChanged?.call();
          }),
    ));
  }

  Future<void> _applyAll() async {
    final c = _c!;
    final ids = c.pending;
    if (ids.isEmpty) return;
    final ok = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _ApplyAllSheet(controller: c, ids: ids));
    if (ok != true) return;
    await c.applyAll();
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null) return const SizedBox.shrink();
    final l = context.l10n;
    final Widget child;
    switch (c.phase) {
      case CoachWeekPhase.hidden:
      case CoachWeekPhase.dismissed:
        return const SizedBox.shrink();
      case CoachWeekPhase.noData:
        child = CoachCard(
          key: const Key('coach-week-no-data'),
          child: CoachStatus(
            icon: LucideIcons.calendarClock,
            title: l.ptWeekNoDataTitle,
            children: [
              Text(
                  l.ptWeekNoDataProgress(
                      c.historyDays.clamp(0, CoachMinimum.weekHistoryDays),
                      CoachMinimum.weekHistoryDays),
                  style: AppTypography.body14.copyWith(color: AppColors.text2)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.r6),
                child: LinearProgressIndicator(
                  value: c.historyDays / CoachMinimum.weekHistoryDays,
                  minHeight: 6,
                  color: AppColors.accent,
                  backgroundColor: AppColors.track,
                ),
              ),
            ],
          ),
        );
      case CoachWeekPhase.idle:
        child = _idle(c);
      case CoachWeekPhase.generating:
        child = CoachCard(
          key: const Key('coach-week-busy'),
          child: CoachBusy(
              title: context.tr('Coach đang lên kế hoạch tuần sau…',
                  'Coach is planning next week…'),
              body: l.ptThinkingSub,
              lines: 4),
        );
      case CoachWeekPhase.ready:
        child = _ready(c);
    }
    return Padding(padding: const EdgeInsets.only(top: 16), child: child);
  }

  String _range(CoachWeekController c) {
    final a = c.weekStart, b = c.weekStart.addDays(6);
    return '${context.dayLabel(a)} – ${context.dayLabel(b)}';
  }

  Widget _idle(CoachWeekController c) {
    final l = context.l10n;
    final b = c.credits.balance;
    final none = b != null && b.balance < 1;
    return CoachCard(
      key: const Key('coach-week-offer'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CoachCaption(l.ptWeekCap, trailing: const CoachChip()),
        const SizedBox(height: 8),
        Text(l.ptWeekTitle(c.weekNumber, _range(c)),
            style: AppTypography.title20),
        if (c.issue != null) ...[
          const SizedBox(height: 12),
          _issue(c),
        ],
        const SizedBox(height: 14),
        AppButton(
          key: const Key('coach-week-generate'),
          label: context.tr('Gợi ý tuần sau · ${CoachCost.weekPlan} lượt AI',
              'Suggest next week · ${CoachCost.weekPlan} AI credits'),
          icon: LucideIcons.sparkles,
          variant: AppButtonVariant.secondary,
          onPressed:
              none ? null : () => c.generate(locale: context.coachLocale),
        ),
        const SizedBox(height: 10),
        const CoachDisclaimer(),
      ]),
    );
  }

  Widget _issue(CoachWeekController c) {
    final l = context.l10n;
    return switch (c.issue!) {
      CoachWeekIssue.noCredits => AppBanner(
          key: const Key('coach-week-no-credits'),
          title: l.ptChatOutTitle,
          body: l.ptResetsOn(context.coachResetDate(c.credits.balance)),
          tone: AppBannerTone.neutral),
      CoachWeekIssue.offline => AppBanner(
          key: const Key('coach-week-offline'),
          title: l.ptOfflineTitle,
          body: context.tr(
              'Kế hoạch của bạn không thay đổi.', 'Your plan is unchanged.'),
          tone: AppBannerTone.warn),
      CoachWeekIssue.nothing => AppBanner(
          key: const Key('coach-week-nothing'),
          title: context.tr('Coach giữ nguyên tuần sau',
              'Coach suggests no change for next week'),
          tone: AppBannerTone.neutral),
      _ => AppBanner(
          key: const Key('coach-week-failed'),
          title:
              context.tr('Chưa tạo được gợi ý', 'Couldn\'t make a suggestion'),
          body: context.tr('Không dùng lượt AI nào. Kế hoạch không thay đổi.',
              'No AI credit was used. Your plan is unchanged.'),
          tone: AppBannerTone.neutral),
    };
  }

  Widget _ready(CoachWeekController c) {
    final l = context.l10n;
    final w = c.week!;
    final view = c.view!;
    final changed = w.proposed.length;
    final pending = c.pending;
    return Column(
      key: const Key('coach-week'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CoachCard(
          accent: true,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            CoachCaption(l.ptWeekCap, trailing: const CoachChip()),
            const SizedBox(height: 8),
            Text(l.ptWeekTitle(c.weekNumber, _range(c)),
                style: AppTypography.title20),
            if (w.summary.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(w.summary,
                  style: AppTypography.body14.copyWith(color: AppColors.text2)),
            ],
            if (c.issue == CoachWeekIssue.nothing) ...[
              const SizedBox(height: 12),
              _issue(c),
            ],
            const SizedBox(height: 8),
            // A table: one row per day, the day is the row header.
            for (final d in c.days) _day(c, view, d),
          ]),
        ),
        if (changed > 0) ...[
          const SizedBox(height: 14),
          AppButton(
              key: const Key('coach-week-apply-all'),
              label: l.ptApplyAll(pending.length),
              icon: LucideIcons.check,
              onPressed: pending.isEmpty ? null : _applyAll),
        ],
        const SizedBox(height: 6),
        AppButton(
            key: const Key('coach-week-keep'),
            label: l.ptKeepWeek,
            variant: AppButtonVariant.ghost,
            onPressed: c.keep),
        const SizedBox(height: 8),
        Text(l.ptWeekMade(context.dayLabel(w.madeOn), CoachCost.weekPlan),
            textAlign: TextAlign.center,
            style: AppTypography.caption12.copyWith(color: AppColors.text2)),
        const SizedBox(height: 8),
        const CoachDisclaimer(),
      ],
    );
  }

  Widget _day(CoachWeekController c, PlanView view, PlanDay d) {
    final l = context.l10n;
    final s = d.session;
    final proposed = s == null ? null : c.week!.proposed[s.id];
    final current = s == null
        ? (d.kind == DayKind.recovery
            ? l.commonNotifRecoveryDay
            : l.plansRestDay)
        : context.templateName(view.plan, s.workoutTemplateId);
    final applied = s != null && c.applied(s.id);
    final changes = s == null || proposed == null
        ? const <int>[]
        : CoachApply.changed(
            applied ? c.week!.previous[s.id]! : s.exerciseTargets, proposed);
    final dayText = context.coachDayShort(d.date);
    return Semantics(
      container: true,
      label: dayText,
      child: Container(
        key: Key('coach-week-day-${d.date.toIso()}'),
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border))),
        child: Row(children: [
          SizedBox(
            width: 64,
            child: Text(dayText,
                style: AppTypography.row15.copyWith(
                    color: changes.isEmpty ? AppColors.text2 : AppColors.text)),
          ),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (changes.isEmpty) ...[
                Text(current, style: AppTypography.row15),
                Text(l.ptNoChange,
                    // Q-1: text2 (7.0:1), not text3.
                    style: AppTypography.caption12
                        .copyWith(color: AppColors.text2)),
              ] else ...[
                Text(current,
                    style: AppTypography.caption12.copyWith(
                        color: AppColors.text2,
                        decoration: TextDecoration.lineThrough)),
                Row(children: [
                  const Icon(LucideIcons.sparkle,
                      size: 14, color: AppColors.accent),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                        [
                          for (final i in changes)
                            '${context.exerciseName(proposed![i].exerciseId)} ${context.coachAmount(proposed[i])}'
                        ].join(' · '),
                        style: AppTypography.row15
                            .copyWith(color: AppColors.accent)),
                  ),
                ]),
                if (c.week!.notes[s!.id] != null)
                  Text(c.week!.notes[s.id]!,
                      style: AppTypography.caption12
                          .copyWith(color: AppColors.text2)),
              ],
            ]),
          ),
          if (changes.isNotEmpty && s != null)
            applied
                ? Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(l.ptApplied,
                        style: AppTypography.caption12
                            .copyWith(color: AppColors.success)),
                    CoachLink(
                        key: Key('coach-week-undo-${s.id}'),
                        label: l.commonUndo,
                        onPressed: () async {
                          await c.undo(s.id);
                          widget.onChanged?.call();
                        }),
                  ])
                : OutlinedButton(
                    key: Key('coach-week-apply-${s.id}'),
                    onPressed: s.isUpcoming ? () => _apply(s.id) : null,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(64, 48),
                      foregroundColor: AppColors.accent,
                      side: const BorderSide(color: AppColors.accentBorder),
                      shape: const StadiumBorder(),
                    ),
                    child: Semantics(
                      label: l.ptApplyDay(dayText),
                      excludeSemantics: true,
                      child: Text(l.ptApply,
                          style: AppTypography.body14
                              .copyWith(fontWeight: FontWeight.w700)),
                    ),
                  ),
        ]),
      ),
    );
  }
}

/// AC-04c Apply all · confirm: every change listed; reminders move with
/// their sessions; logged workouts never change.
class _ApplyAllSheet extends StatelessWidget {
  const _ApplyAllSheet({required this.controller, required this.ids});
  final CoachWeekController controller;
  final List<String> ids;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = controller;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        key: const Key('coach-week-apply-all-sheet'),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(l.ptApplyAllTitle(ids.length, c.weekNumber),
                  style: AppTypography.title20),
            ),
            const SizedBox(height: 12),
            for (final id in ids)
              if (c.session(id) case final s?)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    SizedBox(
                      width: 64,
                      child: Text(context.coachDayShort(s.scheduledLocalDate),
                          style: AppTypography.row15),
                    ),
                    Expanded(
                      child: Text(
                          [
                            for (final i in CoachApply.changed(
                                s.exerciseTargets, c.week!.proposed[id]!))
                              '${context.exerciseName(s.exerciseTargets[i].exerciseId)} ${context.coachAmount(s.exerciseTargets[i])} → ${context.coachAmount(c.week!.proposed[id]![i])}'
                          ].join('\n'),
                          style: AppTypography.body14),
                    ),
                  ]),
                ),
            const SizedBox(height: 12),
            Text(l.ptApplyAllNote,
                style:
                    AppTypography.caption12.copyWith(color: AppColors.text2)),
            const SizedBox(height: 16),
            AppButton(
                key: const Key('coach-week-apply-all-confirm'),
                label: l.ptAccept,
                icon: LucideIcons.check,
                onPressed: () => Navigator.of(context).pop(true)),
            const SizedBox(height: 10),
            AppButton(
                label: l.commonCancel,
                variant: AppButtonVariant.secondary,
                onPressed: () => Navigator.of(context).pop(false)),
          ],
        ),
      ),
    );
  }
}
