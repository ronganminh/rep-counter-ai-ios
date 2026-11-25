import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/i18n/app_strings.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/i18n/locale_controller.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_feedback.dart';
import '../../../widgets/product_ui.dart';
import '../../plan/application/plan_repository.dart';
import '../../plan/presentation/overload_page.dart';
import '../../plan/presentation/plan_copy.dart';
import '../../workout/data/workout_history_store.dart';
import '../../workout/data/workout_record.dart';
import '../ai_coach_v2.dart';
import '../ai_credits.dart';
import '../credits_controller.dart';
import 'credits_widgets.dart';

/// AI Coach (AI-1): chat and two credited analyses. Each request costs one
/// AI credit through `ai-request`; a retry reuses the request id, so it is
/// charged once at most. Running out is a neutral state with the reset day,
/// never a paywall (billing is off, D-14).
///
/// With [v2] (`ENABLE_AI_COACH_V2`, L-D43) it is the virtual PT: a workout
/// review and plan suggestions as cards whose targets can be applied to the
/// active plan through the PL-1c review (Accept / Edit / Dismiss).
class CoachPage extends StatefulWidget {
  const CoachPage(
      {super.key,
      required this.credits,
      this.loadWorkouts,
      this.v2 = AiCoachV2.enabled,
      this.planRepository});

  final CreditsController credits;
  final Future<List<WorkoutRecord>> Function()? loadWorkouts;
  final bool v2;
  final PlanRepository? planRepository;

  /// Whether the user agreed to send coach requests (asked once).
  static const consentKey = 'ai_coach_consent_v1';

  @override
  State<CoachPage> createState() => _CoachPageState();
}

class _CoachPageState extends State<CoachPage> {
  late final _conversation =
      CoachConversation(widget.credits, v2: widget.v2);
  late final _plans = widget.planRepository ?? PlanRepository();
  final _input = TextEditingController();
  List<WorkoutRecord> _workouts = const [];
  PlanView? _plan;

  @override
  void initState() {
    super.initState();
    _conversation.addListener(_changed);
    widget.credits.addListener(_changed);
    // Not during build: refresh notifies the scope above this page.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => widget.credits.refresh());
    _load();
  }

  Future<void> _load() async {
    try {
      final list =
          await (widget.loadWorkouts ?? WorkoutHistoryStore().load)();
      if (mounted) setState(() => _workouts = list);
    } catch (_) {}
    if (widget.v2) await _loadPlan();
  }

  Future<void> _loadPlan() async {
    try {
      final view = await _plans.load();
      if (mounted) setState(() => _plan = view);
    } catch (_) {}
  }

  Future<void> _apply(CoachAnswer answer) async {
    final view = _plan;
    if (view == null) return;
    final changes = CoachPlan.changes(view, answer.targets);
    if (changes.isEmpty) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => OverloadPage(repository: _plans, proposed: changes)));
    await _loadPlan();
  }

  Future<void> _forget() async {
    await CoachMemoryStore().clearAll();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.tr('HLV AI đã quên các ghi chú về bạn.',
            'The AI coach forgot its notes about you.'))));
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _conversation.removeListener(_changed);
    widget.credits.removeListener(_changed);
    _conversation.dispose();
    _input.dispose();
    super.dispose();
  }

  String get _locale => context.language == AppLanguage.vi ? 'vi' : 'en';

  Future<bool> _consent() async {
    final key = widget.v2 ? AiCoachV2.consentKey : CoachPage.consentKey;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(key) == true) return true;
    if (!mounted) return false;
    final l = context.l10n;
    final body = widget.v2
        ? context.tr(
            'Tin nhắn của bạn, tối đa 15 lượt gần nhất, ghi chú ngắn của HLV về bạn (lưu trên điện thoại này) và số liệu tập (buổi gần nhất, kế hoạch đang theo) được gửi tới máy chủ RepCoach rồi tới GroqCloud để soạn câu trả lời. Máy chủ còn đọc các buổi tập đã đồng bộ trong 4 tuần gần nhất của tài khoản để tính tổng và trung bình. Không gửi video, ảnh hay điểm khớp cơ thể. Cuộc trò chuyện không được lưu trên máy chủ. Kế hoạch chỉ thay đổi khi bạn chấp nhận. Đây không phải lời khuyên y tế.',
            'Your messages, up to the last 15 turns, the coach\'s short notes about you (kept on this phone) and workout numbers (your last workout, your active plan) go to the RepCoach server and then to GroqCloud to write the answer. The server also reads your account\'s synced workouts of the last 4 weeks to compute totals and averages. No video, photos or body keypoints. The conversation is not stored on our server. Your plan changes only if you accept. This is not medical advice.')
        : l.coachConsentBody;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.coachConsentTitle),
        content: SingleChildScrollView(child: Text(body)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.commonCancel)),
          FilledButton(
              key: const Key('coach-consent-accept'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.commonSend)),
        ],
      ),
    );
    if (ok != true) return false;
    await prefs.setBool(key, true);
    return true;
  }

  Future<void> _send() async {
    final text = _input.text;
    if (text.trim().isEmpty || !await _consent()) return;
    _input.clear();
    await _conversation.ask(text, locale: _locale);
  }

  Future<void> _analyze(CreditedRequest kind, String label,
      Map<String, Object?> data) async {
    if (!await _consent()) return;
    await _conversation.analyze(kind, label, data, locale: _locale);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final balance = widget.credits.balance;
    final blocked = _conversation.busy || widget.credits.outOfCredits;
    final latest = _workouts.isEmpty ? null : _workouts.first;
    final canReview = _workouts.length >= CoachContext.reviewMinimum;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.aiCoach),
        actions: [
          if (balance != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(child: CreditsChip(credits: balance.balance)),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(
              key: const Key('coach-list'),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              children: [
                Text(l.fbAskAboutTrainingEach,
                    style:
                        AppTypography.body14.copyWith(color: AppColors.text2)),
                const SizedBox(height: 4),
                Text(l.coachNoVideoPhotosKeypoints,
                    style:
                        AppTypography.body14.copyWith(color: AppColors.text2)),
                const SizedBox(height: 16),
                if (widget.v2) ...[
                  _Action(
                    key: const Key('coach-review-last'),
                    icon: LucideIcons.clipboardCheck,
                    title: context.tr(
                        'Nhận xét buổi tập gần nhất', 'Review my last workout'),
                    subtitle: latest == null
                        ? l.coachNoWorkoutsYetInsights
                        : l.coachUsesOneCredit,
                    onTap: latest == null || blocked
                        ? null
                        : () => _analyze(
                            CreditedRequest.workoutReview,
                            context.tr('Nhận xét buổi tập gần nhất',
                                'Review my last workout'),
                            {
                              ...CoachContext.lastWorkout(latest),
                              ...CoachPlan.context(_plan),
                            }),
                  ),
                  const SizedBox(height: 8),
                  for (final week in [false, true]) ...[
                    _Action(
                      key: Key(week ? 'coach-plan-week' : 'coach-plan-tomorrow'),
                      icon: LucideIcons.calendarDays,
                      title: week
                          ? context.tr('Gợi ý lịch tuần sau', 'Plan next week')
                          : context.tr('Gợi ý buổi ngày mai', 'Plan tomorrow'),
                      subtitle: l.coachUsesOneCredit,
                      onTap: blocked
                          ? null
                          : () => _analyze(
                              CreditedRequest.planSuggestion,
                              week
                                  ? context.tr(
                                      'Gợi ý lịch tuần sau', 'Plan next week')
                                  : context.tr(
                                      'Gợi ý buổi ngày mai', 'Plan tomorrow'),
                              {
                                'horizon': week ? 'next_week' : 'tomorrow',
                                ...CoachPlan.context(_plan),
                              }),
                    ),
                    const SizedBox(height: 8),
                  ],
                ] else
                _Action(
                  key: const Key('coach-analyze-last'),
                  icon: LucideIcons.chartColumn,
                  title: l.coachAnalyzeLastWorkout,
                  subtitle: latest == null
                      ? l.coachNoWorkoutsYetInsights
                      : l.coachUsesOneCredit,
                  onTap: latest == null || blocked
                      ? null
                      : () => _analyze(CreditedRequest.advancedAnalysis,
                          l.coachAnalyzeLastWorkout,
                          CoachContext.lastWorkout(latest)),
                ),
                const SizedBox(height: 8),
                _Action(
                  key: const Key('coach-review-progress'),
                  icon: LucideIcons.trendingUp,
                  title: l.coachReviewProgress,
                  subtitle: canReview
                      ? l.coachUsesOneCredit
                      : l.coachNotEnoughHistoryYet,
                  onTap: !canReview || blocked
                      ? null
                      : () => _analyze(
                          CreditedRequest.progressReview,
                          l.coachReviewProgress,
                          CoachContext.progress(_workouts,
                              now: DateTime.now())),
                ),
                const SizedBox(height: 16),
                for (final turn in _conversation.turns) ...[
                  _TurnView(
                      turn: turn,
                      plan: widget.v2 ? _plan : null,
                      onApply: _apply,
                      onRetry: () =>
                          _conversation.retry(turn, locale: _locale)),
                  const SizedBox(height: 12),
                ],
                if (widget.v2)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      key: const Key('coach-forget'),
                      onPressed: _forget,
                      child: Text(context.tr('Xoá ghi chú của HLV về tôi',
                          'Forget the coach\'s notes about me')),
                    ),
                  ),
                if (widget.credits.outOfCredits &&
                    !_conversation.turns.any(
                        (t) => t.state == CoachTurnState.outOfCredits))
                  _OutOfCredits(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  key: const Key('coach-input'),
                  controller: _input,
                  enabled: !widget.credits.outOfCredits,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 2000,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => blocked ? null : _send(),
                  decoration: InputDecoration(
                      hintText: l.coachAskCoach, counterText: ''),
                ),
              ),
              IconButton(
                key: const Key('coach-send'),
                tooltip: l.commonSend,
                onPressed: blocked ? null : _send,
                icon: const Icon(LucideIcons.send),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action(
      {super.key,
      required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});
  final IconData icon;
  final String title, subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          enabled: onTap != null,
          leading: Icon(icon, color: AppColors.text2),
          title: Text(title, style: AppTypography.body16),
          subtitle: Text(subtitle,
              style: AppTypography.body14.copyWith(color: AppColors.text2)),
          trailing: const Icon(LucideIcons.chevronRight, size: 18),
          onTap: onTap,
        ),
      );
}

class _OutOfCredits extends StatelessWidget {
  @override
  Widget build(BuildContext context) => AppBanner(
        key: const Key('coach-out-of-credits'),
        title: context.l10n.creditsNoneLeftTitle,
        body: context.l10n.creditsNoneLeftBody,
        tone: AppBannerTone.neutral,
      );
}

class _TurnView extends StatelessWidget {
  const _TurnView(
      {required this.turn,
      required this.onRetry,
      this.plan,
      required this.onApply});
  final CoachTurn turn;
  final VoidCallback onRetry;
  final PlanView? plan;
  final Future<void> Function(CoachAnswer) onApply;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Text(turn.text, style: AppTypography.body14),
          ),
        ),
        const SizedBox(height: 8),
        switch (turn.state) {
          CoachTurnState.waiting => Semantics(
              liveRegion: true,
              child: Row(children: [
                const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 8),
                Text(l.coachWaitingReply,
                    style:
                        AppTypography.body14.copyWith(color: AppColors.text2)),
              ]),
            ),
          CoachTurnState.answered
              when CoachAnswer.parse(turn.kind, turn.data) != null =>
            _AnswerCard(
                answer: CoachAnswer.parse(turn.kind, turn.data)!,
                plan: plan,
                onApply: onApply),
          CoachTurnState.answered => Container(
              key: const Key('coach-answer'),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.border),
              ),
              child: SelectableText(turn.answer ?? '',
                  style: AppTypography.body14),
            ),
          CoachTurnState.outOfCredits => _OutOfCredits(),
          CoachTurnState.failed => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppBanner(
                  key: const Key('coach-failed'),
                  title: l.aiCoachMessageNotSent,
                  body: switch (turn.failure) {
                    CoachFailure.offline =>
                      l.progressWorkoutsSafeCheckConnection,
                    CoachFailure.limit => context.tr(
                        'Đã đạt giới hạn dùng HLV AI hôm nay. Bạn không bị trừ tín dụng; hãy thử lại vào ngày mai.',
                        'You reached today\'s AI coach limit. No credit was used; try again tomorrow.'),
                    CoachFailure.timeout ||
                    CoachFailure.provider =>
                      l.premiumIfFailedCreditComes,
                    _ => l.aiCoachChargedOnce,
                  },
                  tone: AppBannerTone.neutral,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: AppButton(
                    key: const Key('coach-retry'),
                    label: l.commonRetryNow,
                    variant: AppButtonVariant.secondary,
                    expand: false,
                    onPressed: onRetry,
                  ),
                ),
              ],
            ),
        },
      ],
    );
  }
}

/// A v2 answer as a card: summary, fixes, the proposed targets, and
/// "Apply to plan" (the PL-1c review; nothing changes without Accept).
class _AnswerCard extends StatelessWidget {
  const _AnswerCard(
      {required this.answer, required this.plan, required this.onApply});
  final CoachAnswer answer;
  final PlanView? plan;
  final Future<void> Function(CoachAnswer) onApply;

  String _target(BuildContext context, CoachTarget t) {
    final amount = t.isDuration
        ? context.tr('${t.sets} × ${t.seconds} giây', '${t.sets} × ${t.seconds} s')
        : context.tr('${t.sets} × ${t.reps} rep', '${t.sets} × ${t.reps} reps');
    final rest = context.tr('nghỉ ${t.restSeconds} giây', 'rest ${t.restSeconds} s');
    final change = switch (t.change) {
      TargetChange.increase => '↑',
      TargetChange.decrease => '↓',
      TargetChange.maintain => '=',
    };
    return '$change ${context.exerciseName(t.exerciseId)}: $amount · $rest';
  }

  @override
  Widget build(BuildContext context) {
    final a = answer;
    final view = plan;
    final changes =
        view == null ? const [] : CoachPlan.changes(view, a.targets);
    final muted = AppTypography.body14.copyWith(color: AppColors.text2);
    return Container(
      key: const Key('coach-card'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        switch (a) {
          CoachWorkoutReview(:final summary) ||
          CoachPlanSuggestion(:final summary) =>
            SelectableText(summary, style: AppTypography.body14),
        },
        if (a is CoachWorkoutReview) ...[
          const SizedBox(height: 10),
          Text(context.tr('Cần sửa', 'To fix'), style: AppTypography.row15),
          for (final f in a.fixes)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('• $f', style: AppTypography.body14),
            ),
          if (a.nextSession.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(context.tr('Buổi kế tiếp', 'Next session'),
                style: AppTypography.row15),
            for (final t in a.nextSession)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_target(context, t), style: AppTypography.body14),
              ),
          ],
        ],
        if (a is CoachPlanSuggestion)
          for (final s in a.sessions) ...[
            const SizedBox(height: 10),
            Text(
                [
                  s.dayOffset == 1
                      ? context.tr('Ngày mai', 'Tomorrow')
                      : context.tr('Sau ${s.dayOffset} ngày',
                          'In ${s.dayOffset} days'),
                  if (s.focus.isNotEmpty) s.focus,
                ].join(' · '),
                style: AppTypography.row15),
            for (final t in s.exercises)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_target(context, t), style: AppTypography.body14),
              ),
          ],
        if (a.targets.isNotEmpty) ...[
          const SizedBox(height: 12),
          AppButton(
            key: const Key('coach-apply'),
            label: context.tr('Áp dụng vào kế hoạch', 'Apply to plan'),
            variant: AppButtonVariant.secondary,
            onPressed: changes.isEmpty ? null : () => onApply(a),
          ),
          if (changes.isEmpty)
            Padding(
              key: const Key('coach-apply-unavailable'),
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                  view == null
                      ? context.tr(
                          'Tạo kế hoạch trong mục Kế hoạch để áp dụng gợi ý.',
                          'Create a plan in Plans to apply suggestions.')
                      : context.tr(
                          'Các bài này chưa có trong kế hoạch, hoặc mục tiêu đã giống gợi ý.',
                          'These exercises are not in your plan, or the targets already match.'),
                  style: muted),
            ),
        ],
        const SizedBox(height: 8),
        Text(
            context.tr('Thông tin tập luyện chung, không phải lời khuyên y tế.',
                'General training information, not medical advice.'),
            style: AppTypography.caption12.copyWith(color: AppColors.text2)),
      ]),
    );
  }
}
