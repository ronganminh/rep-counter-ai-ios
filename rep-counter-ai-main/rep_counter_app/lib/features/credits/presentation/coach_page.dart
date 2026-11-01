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
import '../../workout/data/workout_history_store.dart';
import '../../workout/data/workout_record.dart';
import '../ai_credits.dart';
import '../credits_controller.dart';
import 'credits_widgets.dart';

/// AI Coach (AI-1): chat and two credited analyses. Each request costs one
/// AI credit through `ai-request`; a retry reuses the request id, so it is
/// charged once at most. Running out is a neutral state with the reset day,
/// never a paywall (billing is off, D-14).
class CoachPage extends StatefulWidget {
  const CoachPage({super.key, required this.credits, this.loadWorkouts});

  final CreditsController credits;
  final Future<List<WorkoutRecord>> Function()? loadWorkouts;

  /// Whether the user agreed to send coach requests (asked once).
  static const consentKey = 'ai_coach_consent_v1';

  @override
  State<CoachPage> createState() => _CoachPageState();
}

class _CoachPageState extends State<CoachPage> {
  late final _conversation = CoachConversation(widget.credits);
  final _input = TextEditingController();
  List<WorkoutRecord> _workouts = const [];

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
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(CoachPage.consentKey) == true) return true;
    if (!mounted) return false;
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.coachConsentTitle),
        content: SingleChildScrollView(child: Text(l.coachConsentBody)),
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
    await prefs.setBool(CoachPage.consentKey, true);
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
                      onRetry: () =>
                          _conversation.retry(turn, locale: _locale)),
                  const SizedBox(height: 12),
                ],
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
  const _TurnView({required this.turn, required this.onRetry});
  final CoachTurn turn;
  final VoidCallback onRetry;

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
