import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/product_ui.dart';
import '../../credits/ai_coach_v2.dart';
import '../../credits/ai_credits.dart';
import '../../credits/credits_controller.dart';
import '../../plan/application/plan_repository.dart';
import '../../plan/domain/local_date.dart';
import '../../plan/domain/workout_plan.dart';
import '../../plan/presentation/plan_copy.dart';
import '../../workout/data/workout_history_store.dart';
import '../../workout/data/workout_record.dart';
import '../coach_apply.dart';
import '../coach_trend.dart';
import '../coach_v2.dart';
import 'coach_apply_sheet.dart';
import 'coach_copy.dart';
import 'coach_widgets.dart';

/// AC-02 `/workout/:id/coach-review` (root navigator, no tab bar): the
/// coach's review of one saved workout, 1 AI credit (D-29). Basic feedback
/// on Results stays free (D-07). The workout is saved before anything is
/// asked; a failed or invalid answer is not charged and Retry reuses the
/// request id (D-09, D-33).
class CoachReviewPage extends StatefulWidget {
  const CoachReviewPage({
    super.key,
    required this.record,
    required this.credits,
    this.plans,
    this.loadWorkouts,
    this.onAskFollowUp,
    this.newId,
  });

  final WorkoutRecord record;
  final CreditsController credits;
  final PlanRepository? plans;
  final Future<List<WorkoutRecord>> Function()? loadWorkouts;

  /// "Ask a follow-up" (AC-03 chat); hidden when null.
  final VoidCallback? onAskFollowUp;
  final String Function()? newId;

  @override
  State<CoachReviewPage> createState() => _CoachReviewPageState();
}

class _CoachReviewPageState extends State<CoachReviewPage> {
  late final _plans = widget.plans ?? PlanRepository();
  late CoachConversation _conversation = _newConversation();
  List<WorkoutRecord> _all = const [];
  PlanView? _view;
  bool _started = false;

  CoachConversation _newConversation() =>
      CoachConversation(widget.credits, v2: true, newId: widget.newId)
        ..addListener(_changed);

  @override
  void initState() {
    super.initState();
    widget.credits.addListener(_changed);
    _load();
  }

  Future<void> _load() async {
    try {
      final all = await (widget.loadWorkouts ?? WorkoutHistoryStore().load)();
      if (mounted) setState(() => _all = all);
    } catch (_) {}
    try {
      final v = await _plans.load();
      if (mounted) setState(() => _view = v);
    } catch (_) {}
    if (!mounted) return;
    final b = widget.credits.balance;
    if (b == null || b.balance >= CoachCost.review) _ask();
  }

  void _ask() {
    _started = true;
    _conversation.analyze(
        CreditedRequest.workoutReview,
        context.l10n.ptReviewTitle,
        {
          ...CoachContext.lastWorkout(widget.record),
          ...CoachPlan.context(_view)
        },
        locale: context.coachLocale);
  }

  void _retry() {
    final turn = _conversation.turns.lastOrNull;
    if (turn != null && turn.state == CoachTurnState.failed) {
      _conversation.retry(turn, locale: context.coachLocale);
      return;
    }
    // An invalid answer was not charged: ask again with a new request.
    _conversation
      ..removeListener(_changed)
      ..dispose();
    setState(() => _conversation = _newConversation());
    _ask();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.credits.removeListener(_changed);
    _conversation
      ..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final turn = _conversation.turns.lastOrNull;
    final answer =
        turn == null ? null : CoachAnswer.parse(turn.kind, turn.data);
    final b = widget.credits.balance;
    final Widget body;
    if (turn == null && _started) {
      body = _busy();
    } else if (turn == null) {
      body = b != null && b.balance < CoachCost.review ? _noCredits() : _busy();
    } else {
      body = switch (turn.state) {
        CoachTurnState.waiting => _busy(),
        CoachTurnState.outOfCredits => _noCredits(),
        CoachTurnState.answered when answer is CoachWorkoutReview =>
          _ready(answer),
        _ => _failed(),
      };
    }
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          tooltip: l.ptReviewBackResults,
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(l.ptReviewTitle, style: AppTypography.row15),
      ),
      body: SafeArea(
        child: ListView(
          key: const Key('coach-review'),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [_header(), const SizedBox(height: 16), body],
        ),
      ),
    );
  }

  Widget _header() {
    final r = widget.record;
    final l = context.l10n;
    final when = LocalDate.of(r.startedAt);
    final time =
        '${r.startedAt.hour.toString().padLeft(2, '0')}:${r.startedAt.minute.toString().padLeft(2, '0')}';
    final d = r.durationSeconds;
    final q = r.quality;
    final recorded = [
      context.tr('${r.reps} rep', '${r.reps} reps'),
      '${d ~/ 60}:${(d % 60).toString().padLeft(2, '0')}',
      if (q != null && q.hasEnoughData)
        context.tr('tư thế ${q.qualityScore}', 'form ${q.qualityScore}'),
    ].join(' · ');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('${context.dayLabel(when)} · $time'.toUpperCase(),
          style: AppTypography.caption12.copyWith(
              color: AppColors.text2,
              fontWeight: FontWeight.w700,
              letterSpacing: .6)),
      const SizedBox(height: 4),
      Text(context.exerciseName(r.exerciseId).toUpperCase(),
          style: AppTypography.display40.copyWith(fontSize: 28)),
      const SizedBox(height: 6),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.surface3,
              borderRadius: BorderRadius.circular(AppRadius.r6),
            ),
            child: Text(l.coachRecorded,
                style: AppTypography.caption12.copyWith(color: AppColors.text)),
          ),
          Text(recorded, style: AppTypography.row15),
        ],
      ),
    ]);
  }

  Widget _busy() => CoachCard(
        key: const Key('coach-review-busy'),
        child: CoachBusy(
            title: context.l10n.ptReviewGenerating,
            body: context.l10n.ptReviewSaved,
            lines: 5),
      );

  Widget _failed() {
    final l = context.l10n;
    return CoachCard(
      key: const Key('coach-review-failed'),
      child: CoachStatus(
        icon: LucideIcons.cloudOff,
        title: l.ptReviewErrorTitle,
        body: l.ptReviewErrorBody,
        children: [
          CoachNote(l.aiCoachChargedOnce, icon: LucideIcons.info),
          const SizedBox(height: 12),
          AppButton(
              key: const Key('coach-review-retry'),
              label: l.commonRetry,
              icon: LucideIcons.refreshCw,
              variant: AppButtonVariant.secondary,
              onPressed: _retry),
        ],
      ),
    );
  }

  Widget _noCredits() {
    final l = context.l10n;
    return CoachCard(
      key: const Key('coach-review-no-credits'),
      child: CoachStatus(
        icon: LucideIcons.zapOff,
        title: l.ptReviewNoCreditsTitle,
        body: l.ptReviewNoCreditsBody(
            context.coachResetDate(widget.credits.balance)),
        children: [
          // Disabled but readable (aria-disabled): no request is sent.
          AppButton(
              key: const Key('coach-review-get'),
              label: l.ptGetReview,
              onPressed: null),
          const SizedBox(height: 8),
          CoachNote(l.ptUsesOneCredit, center: true),
        ],
      ),
    );
  }

  Widget _ready(CoachWorkoutReview a) {
    final l = context.l10n;
    final view = _view;
    final session = view == null ? null : CoachApply.nextSession(view);
    final proposed = session == null
        ? null
        : CoachApply.merge(session.exerciseTargets, a.nextSession);
    final changed = session == null
        ? const <int>[]
        : CoachApply.changed(session.exerciseTargets, proposed!);
    Widget item(IconData icon, Color color, String text, {String? sr}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Semantics(
            container: true,
            label: sr == null ? text : '$sr. $text',
            excludeSemantics: true,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(AppRadius.r8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(text, style: AppTypography.body14)),
            ]),
          ),
        );
    return Column(
      key: const Key('coach-review-ready'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CoachCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            CoachCaption(l.ptStrengths, trailing: const CoachChip()),
            const SizedBox(height: 6),
            item(LucideIcons.check, AppColors.success, a.summary),
          ]),
        ),
        const SizedBox(height: 12),
        CoachCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            CoachCaption(l.ptFixes),
            const SizedBox(height: 6),
            for (final f in a.fixes.take(3))
              item(LucideIcons.gauge, AppColors.warningText, f),
          ]),
        ),
        const SizedBox(height: 12),
        CoachCard(
          key: const Key('coach-review-trend'),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            CoachCaption(l.ptTrend),
            const SizedBox(height: 6),
            for (final t in CoachTrend.rows(widget.record, _all))
              item(
                  switch (t.direction) {
                    TrendDirection.up => LucideIcons.trendingUp,
                    TrendDirection.down => LucideIcons.trendingDown,
                    _ => LucideIcons.minus,
                  },
                  switch (t.direction) {
                    TrendDirection.none ||
                    TrendDirection.same =>
                      AppColors.text2,
                    TrendDirection.up when !t.lowerIsBetter => AppColors.accent,
                    TrendDirection.down when t.lowerIsBetter =>
                      AppColors.accent,
                    _ => AppColors.warningText,
                  },
                  _trendText(t),
                  sr: switch (t.direction) {
                    TrendDirection.up => l.ptTrendUp,
                    TrendDirection.down => l.ptTrendDown,
                    _ => l.ptTrendSame,
                  }),
          ]),
        ),
        if (session != null && a.nextSession.isNotEmpty) ...[
          const SizedBox(height: 12),
          CoachCard(
            key: const Key('coach-review-next'),
            accent: changed.isNotEmpty,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CoachCaption(l.ptNextSession, trailing: const CoachChip()),
                  const SizedBox(height: 8),
                  Text(
                      '${context.dayLabel(session.scheduledLocalDate)} · ${context.templateName(view!.plan, session.workoutTemplateId)}',
                      style: AppTypography.title20),
                  const SizedBox(height: 6),
                  Text(
                      changed.isEmpty
                          ? [
                              for (final t in a.nextSession)
                                '${context.exerciseName(t.exerciseId)} ${t.isDuration ? '${t.sets} × ${t.seconds}s' : '${t.sets} × ${t.reps}'}'
                            ].join(' · ')
                          : [
                              for (final i in changed)
                                '${context.exerciseName(proposed![i].exerciseId)} ${context.coachAmount(session.exerciseTargets[i])} → ${context.coachAmount(proposed[i])}'
                            ].join('\n'),
                      style: AppTypography.body14
                          .copyWith(color: AppColors.textMuted)),
                  if (changed.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    AppButton(
                        key: const Key('coach-review-apply'),
                        label: l.ptApplyToPlan,
                        icon: LucideIcons.calendar,
                        onPressed: () => _apply(view, session, proposed!)),
                  ],
                ]),
          ),
        ],
        const SizedBox(height: 14),
        const CoachDisclaimer(),
        const SizedBox(height: 8),
        CoachNote(l.ptUsedOneCredit),
        if (widget.onAskFollowUp != null) ...[
          const SizedBox(height: 14),
          AppButton(
              key: const Key('coach-review-ask'),
              label: l.ptAskFollowUp,
              icon: LucideIcons.messageCircle,
              variant: AppButtonVariant.secondary,
              onPressed: widget.onAskFollowUp),
        ],
      ],
    );
  }

  Future<void> _apply(PlanView view, PlannedSession session,
      List<ExerciseTarget> proposed) async {
    await showCoachApplySheet(context,
        plans: _plans, view: view, session: session, proposed: proposed);
    try {
      final v = await _plans.load();
      if (mounted) setState(() => _view = v);
    } catch (_) {}
  }

  String _trendText(TrendRow t) {
    final name = context.exerciseName(widget.record.exerciseId);
    final at =
        t.beforeAt == null ? '' : context.dayLabel(LocalDate.of(t.beforeAt!));
    return switch (t.metric) {
      _ when t.direction == TrendDirection.none => context.tr(
          '$name ${t.now} rep · chưa có buổi trước để so',
          '$name ${t.now} reps · no earlier workout to compare'),
      'form' => context.tr('Điểm tư thế ${t.now} · trước là ${t.before} ($at)',
          'Form score ${t.now} · was ${t.before} ($at)'),
      'flagged' => context.tr(
          'Rep bị đánh dấu ${t.now} · trước là ${t.before} ($at)',
          'Flagged reps ${t.now} · was ${t.before} ($at)'),
      _ => context.tr('$name ${t.now} rep · trước là ${t.before} ($at)',
          '$name ${t.now} reps · was ${t.before} ($at)'),
    };
  }
}
