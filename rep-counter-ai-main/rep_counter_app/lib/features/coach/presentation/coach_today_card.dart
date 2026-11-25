import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../widgets/product_ui.dart';
import '../../../core/i18n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_feedback.dart';
import '../../credits/credits_controller.dart';
import '../../plan/application/plan_repository.dart';
import '../../plan/domain/workout_plan.dart';
import '../../plan/presentation/plan_copy.dart';
import '../../plan/presentation/session_detail_page.dart';
import '../../workout/data/workout_history_store.dart';
import '../../workout/data/workout_record.dart';
import '../coach_apply.dart';
import '../coach_pick.dart';
import '../coach_v2.dart';
import 'coach_copy.dart';
import 'coach_widgets.dart';

/// AC-01 Home "Coach's pick · today" (`/home`, tab 0). Shown only with the
/// flag, an account, AI Coach consent and a planned session today (D-30);
/// otherwise it takes no space and Home is unchanged. Training never waits:
/// Start opens the planned session in every state.
class CoachTodayCard extends StatefulWidget {
  const CoachTodayCard({
    super.key,
    this.credits,
    this.plans,
    this.loadWorkouts,
    this.openSession,
    this.onCameraWorkout,
    this.consent = const CoachConsentStore(),
    this.store,
  });

  final CreditsController? credits;
  final PlanRepository? plans;
  final Future<List<WorkoutRecord>> Function()? loadWorkouts;

  /// Opens the planned session (default: the session page, P2-07a flow).
  final Future<void> Function(BuildContext, String sessionId)? openSession;

  /// AC-01b "Start a camera workout".
  final VoidCallback? onCameraWorkout;
  final CoachConsentStore consent;
  final CoachPickStore? store;

  @override
  State<CoachTodayCard> createState() => _CoachTodayCardState();
}

class _CoachTodayCardState extends State<CoachTodayCard> {
  CoachPickController? _c;
  late final PlanRepository _plans = widget.plans ?? PlanRepository();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final credits = widget.credits ?? CreditsScope.maybeOf(context);
    if (_c != null || credits == null) return;
    _c = CoachPickController(
      credits: credits,
      plans: _plans,
      loadWorkouts: widget.loadWorkouts ?? WorkoutHistoryStore().load,
      consent: widget.consent,
      store: widget.store,
    )..addListener(_changed);
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

  String get _locale => context.coachLocale;

  Future<void> _open(String sessionId) async {
    final open = widget.openSession ??
        (context, id) => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    SessionDetailPage(sessionId: id, repository: _plans),
              ),
            );
    await open(context, sessionId);
    if (mounted) await _c?.load();
  }

  /// Start: with the coach's numbers chosen, they are written to today's
  /// planned session first (D-35: scheduled sessions only, Undo).
  Future<void> _start(CoachPick pick) async {
    if (pick.useSuggestion && pick.adjusted) {
      final applied =
          await CoachApplier(_plans).apply(pick.sessionId, pick.suggested);
      if (applied != null && mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.ptAppliedToast(
                context.weekdayLong(applied.date.weekday),
              ),
            ),
            action: SnackBarAction(
              label: context.l10n.commonUndo,
              onPressed: () => CoachApplier(_plans).undo(applied),
            ),
          ),
        );
      }
    }
    if (mounted) await _open(pick.sessionId);
  }

  Future<void> _edit(CoachPick pick) async {
    final use = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _EditSheet(pick: pick),
    );
    if (use != null) await _c?.choose(useSuggestion: use);
  }

  Future<void> _skip() async {
    await _c?.skip();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: const Key('coach-pick-skipped-toast'),
        content: Text(context.l10n.ptSkippedToast),
        action: SnackBarAction(
          label: context.l10n.commonUndo,
          onPressed: () => _c?.undoSkip(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null) return const SizedBox.shrink();
    final l = context.l10n;
    final Widget body;
    switch (c.phase) {
      case CoachPickPhase.hidden:
      case CoachPickPhase.loading:
        return const SizedBox.shrink();
      case CoachPickPhase.noData:
        body = CoachCard(
          key: const Key('coach-pick-no-data'),
          child: CoachStatus(
            icon: LucideIcons.sparkles,
            title: l.ptNoDataTitle,
            body: l.ptNoDataBody(CoachMinimum.pickWorkouts),
            children: [
              Text(
                l.ptNoDataProgress(c.workouts, CoachMinimum.pickWorkouts),
                style: AppTypography.body14.copyWith(color: AppColors.text2),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.r6),
                child: LinearProgressIndicator(
                  value: c.workouts / CoachMinimum.pickWorkouts,
                  minHeight: 6,
                  color: AppColors.accent,
                  backgroundColor: AppColors.track,
                ),
              ),
              if (widget.onCameraWorkout != null) ...[
                const SizedBox(height: 16),
                AppButton(
                  key: const Key('coach-pick-camera'),
                  label: l.ptNoDataCta,
                  icon: LucideIcons.camera,
                  variant: AppButtonVariant.secondary,
                  onPressed: widget.onCameraWorkout,
                ),
              ],
            ],
          ),
        );
      case CoachPickPhase.skipped:
        final pick = c.pick!;
        body = CoachCard(
          key: const Key('coach-pick-skipped'),
          child: CoachStatus(
            icon: LucideIcons.skipForward,
            title: l.ptSkippedTitle,
            body: l.ptSkippedBody,
            children: [
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      key: const Key('coach-pick-undo'),
                      label: l.commonUndo,
                      icon: LucideIcons.undo2,
                      variant: AppButtonVariant.secondary,
                      onPressed: c.undoSkip,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      key: const Key('coach-pick-train-anyway'),
                      label: l.ptTrainAnyway,
                      variant: AppButtonVariant.secondary,
                      onPressed: () => _open(pick.sessionId),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      case CoachPickPhase.ready:
        body = _ready(c, c.pick!);
    }
    return Padding(padding: const EdgeInsets.only(bottom: 16), child: body);
  }

  Widget _ready(CoachPickController c, CoachPick pick) {
    final l = context.l10n;
    final view = c.view;
    final name = view == null
        ? pick.templateId
        : context.templateName(view.plan, pick.templateId);
    final shown = pick.targets;
    final b = c.credits.balance;
    return CoachCard(
      key: const Key('coach-pick'),
      accent: true,
      semanticsLabel: l.ptTodayCardCap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CoachCaption(l.ptTodayCardCap, trailing: const CoachChip()),
          const SizedBox(height: 10),
          Text(
            name.toUpperCase(),
            style: AppTypography.display40.copyWith(fontSize: 26),
          ),
          const SizedBox(height: 4),
          Text(
            context.coachMeta(shown),
            style: AppTypography.body14.copyWith(color: AppColors.text2),
          ),
          if (c.regenerating) ...[
            const SizedBox(height: 14),
            CoachBusy(
              title: l.ptGenerating,
              body: l.ptGeneratingBody,
              lines: 2,
            ),
          ] else if (pick.reason != null) ...[
            const SizedBox(height: 14),
            Container(
              key: const Key('coach-pick-reason'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accentTintSoft,
                borderRadius: BorderRadius.circular(AppRadius.r12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    LucideIcons.sparkle,
                    size: 16,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(pick.reason!, style: AppTypography.body14),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          for (final t in shown) _row(t, pick.rest[t.exerciseId]),
          const SizedBox(height: 14),
          AppButton(
            key: const Key('coach-pick-start'),
            label: l.ptStart,
            icon: LucideIcons.play,
            onPressed: () => _start(pick),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  key: const Key('coach-pick-edit'),
                  label: l.ptEdit,
                  icon: LucideIcons.slidersHorizontal,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => _edit(pick),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton(
                  key: const Key('coach-pick-skip'),
                  label: l.ptSkip,
                  icon: LucideIcons.skipForward,
                  variant: AppButtonVariant.secondary,
                  onPressed: _skip,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            l.ptCreatedToday(c.weeks),
            textAlign: TextAlign.center,
            style: AppTypography.caption12.copyWith(color: AppColors.text2),
          ),
          if (c.issue != null) ...[const SizedBox(height: 12), _issue(c)],
          const SizedBox(height: 4),
          Center(
            child: CoachLink(
              key: const Key('coach-pick-regenerate'),
              label: l.ptRegenerate,
              icon: LucideIcons.refreshCw,
              onPressed: c.regenerating ||
                      (b != null && b.balance < CoachCost.newSuggestion)
                  ? null
                  : () => c.regenerate(locale: _locale),
            ),
          ),
        ],
      ),
    );
  }

  Widget _issue(CoachPickController c) {
    final l = context.l10n;
    return switch (c.issue!) {
      CoachRegenIssue.noCredits => AppBanner(
          key: const Key('coach-pick-no-credits'),
          title: l.ptRegenNoCreditsTitle,
          body:
              l.ptRegenNoCreditsBody(context.coachResetDate(c.credits.balance)),
          tone: AppBannerTone.neutral,
        ),
      CoachRegenIssue.offline => AppBanner(
          key: const Key('coach-pick-offline'),
          title: l.ptOfflineTitle,
          body: l.ptOfflineBody,
          tone: AppBannerTone.warn,
        ),
      CoachRegenIssue.failed || CoachRegenIssue.limit => AppBanner(
          key: const Key('coach-pick-failed'),
          title: context.tr(
            'Chưa tạo được đề xuất khác',
            'Couldn\'t make a new suggestion',
          ),
          body: c.issue == CoachRegenIssue.limit
              ? context.tr(
                  'Đã đạt giới hạn dùng AI hôm nay. Không dùng lượt AI nào; đề xuất hiện tại vẫn dùng được.',
                  'You reached today\'s AI limit. No AI credit was used; today\'s pick still works.',
                )
              : context.tr(
                  'Không dùng lượt AI nào. Đề xuất hiện tại vẫn dùng được.',
                  'No AI credit was used. Today\'s pick still works.',
                ),
          tone: AppBannerTone.neutral,
          actionLabel: c.issue == CoachRegenIssue.limit ? null : l.commonRetry,
          onAction: c.issue == CoachRegenIssue.limit
              ? null
              : () => c.regenerate(locale: _locale),
        ),
    };
  }

  Widget _row(ExerciseTarget t, int? rest) {
    final l = context.l10n;
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(AppRadius.r8),
            ),
            child: Icon(
              context.coachTrackingIcon(t),
              size: 16,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.exerciseName(t.exerciseId),
                  style: AppTypography.row15,
                ),
                Text(
                  [
                    context.coachTracking(t),
                    if (rest != null) l.ptMinRest(rest),
                  ].join(' · '),
                  style: AppTypography.caption12.copyWith(
                    color: AppColors.text2,
                  ),
                ),
              ],
            ),
          ),
          Text(
            context.coachAmount(t),
            style: AppTypography.stat30.copyWith(fontSize: 20),
          ),
        ],
      ),
    );
  }
}

/// AC-01f Edit today's session (registry #10 sheet): the same choices as
/// the plan's review, never an AI call.
class _EditSheet extends StatefulWidget {
  const _EditSheet({required this.pick});
  final CoachPick pick;

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late bool _use = widget.pick.useSuggestion;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = widget.pick;
    Widget option(bool value, String title, String sub) => RadioListTile<bool>(
          key: Key(value ? 'coach-edit-use' : 'coach-edit-keep'),
          value: value,
          // ignore: deprecated_member_use
          groupValue: _use,
          // ignore: deprecated_member_use
          onChanged: (v) => setState(() => _use = v!),
          activeColor: AppColors.accent,
          contentPadding: EdgeInsets.zero,
          title: Text(title, style: AppTypography.row15),
          subtitle: Text(
            sub,
            style: AppTypography.caption12.copyWith(color: AppColors.text2),
          ),
        );
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(l.ptEditTitle, style: AppTypography.title20),
            ),
            const SizedBox(height: 12),
            if (p.adjusted)
              option(true, l.ptEditOpt1, context.coachMeta(p.suggested)),
            option(false, l.ptEditOpt2, context.coachMeta(p.planned)),
            const SizedBox(height: 8),
            Text(
              l.ptEditNoCharge,
              style: AppTypography.caption12.copyWith(color: AppColors.text2),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: l.commonCancel,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    key: const Key('coach-edit-save'),
                    label: l.commonSave,
                    onPressed: () =>
                        Navigator.of(context).pop(p.adjusted ? _use : false),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
