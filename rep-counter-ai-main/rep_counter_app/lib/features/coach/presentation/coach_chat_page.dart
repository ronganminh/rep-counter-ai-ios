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
import '../coach_safety.dart';
import 'coach_consent_page.dart';
import 'coach_copy.dart';
import 'coach_widgets.dart';

/// Opens the coach chat (AC-03): account and consent first (AC-03a).
Future<void> openCoachChat(BuildContext context, CreditsController credits,
    {String? ask}) async {
  if (!await CoachConsentPage.ensure(context) || !context.mounted) return;
  await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(
      builder: (_) => CoachChatPage(credits: credits, initial: ask)));
}

/// AC-03b–f `/coach/chat` (root navigator): the PT chat. Each message is
/// 1 AI credit (D-29) through `coach_chat` v2 (15 turns, memory on the
/// phone). A pain or injury message gets the fixed safety reply on the
/// phone, no request and no credit (D-34). At 0 credits the chips and the
/// composer pause until the reset day; training is never blocked.
class CoachChatPage extends StatefulWidget {
  const CoachChatPage(
      {super.key, required this.credits, this.initial, this.newId});
  final CreditsController credits;

  /// A question to send on open (e.g. "Ask a follow-up").
  final String? initial;
  final String Function()? newId;

  @override
  State<CoachChatPage> createState() => _CoachChatPageState();
}

/// One line of the chat: a credited turn, or a safety reply made here.
sealed class _Item {}

class _Ai extends _Item {
  _Ai(this.turn);
  final CoachTurn turn;
}

class _Safety extends _Item {
  _Safety(this.question);
  final String question;
}

class _CoachChatPageState extends State<CoachChatPage> {
  late final _conversation =
      CoachConversation(widget.credits, v2: true, newId: widget.newId)
        ..addListener(_changed);
  final _items = <_Item>[];
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.credits.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.credits.refresh();
      final q = widget.initial;
      if (q != null && q.trim().isNotEmpty) _send(q);
    });
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
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool get _out => widget.credits.outOfCredits;

  Future<void> _send(String text) async {
    final q = text.trim();
    if (q.isEmpty || _conversation.busy) return;
    _input.clear();
    if (CoachSafety.isPain(q)) {
      setState(() => _items.add(_Safety(q)));
      return;
    }
    if (_out) return;
    final before = _conversation.turns.length;
    final future = _conversation.ask(q, locale: context.coachLocale);
    if (_conversation.turns.length > before) {
      setState(() => _items.add(_Ai(_conversation.turns.last)));
    }
    await future;
    if (!mounted || !_scroll.hasClients) return;
    _scroll.jumpTo(_scroll.position.maxScrollExtent);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final b = widget.credits.balance;
    final busy = _conversation.busy;
    final paused = _out;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          tooltip: l.navBack,
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(l.ptChatTitle, style: AppTypography.row15),
        actions: [
          if (b != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                  child: CoachCreditsChip(
                      remaining: b.balance, allowance: b.weeklyAllowance)),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child:
                CoachNote(l.ptChatSub, icon: LucideIcons.eyeOff, center: true),
          ),
          Expanded(
            child: ListView(
              key: const Key('coach-chat'),
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              children: [
                if (_items.isEmpty) _empty(disabled: paused || busy),
                for (final item in _items) ...[
                  _bubble(switch (item) {
                    _Ai(:final turn) => turn.text,
                    _Safety(:final question) => question,
                  }),
                  const SizedBox(height: 10),
                  switch (item) {
                    _Ai(:final turn) => _reply(turn),
                    _Safety() => _safety(),
                  },
                  const SizedBox(height: 16),
                ],
                if (paused) _outOfCredits(),
              ],
            ),
          ),
          _composer(disabled: paused || busy, paused: paused),
        ]),
      ),
    );
  }

  Widget _empty({required bool disabled}) {
    final l = context.l10n;
    return Column(
      key: const Key('coach-chat-empty'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.accentTint,
            borderRadius: BorderRadius.circular(AppRadius.r14),
          ),
          child: const Icon(LucideIcons.messageCircle,
              color: AppColors.accent, size: 26),
        ),
        const SizedBox(height: 16),
        Semantics(
            header: true,
            child: Text(l.ptChatEmptyTitle,
                style: AppTypography.title22.copyWith(fontSize: 26))),
        const SizedBox(height: 8),
        Text(l.ptChatEmptyBody,
            style: AppTypography.body16.copyWith(color: AppColors.textMuted)),
        const SizedBox(height: 16),
        for (final (i, q) in [
          l.ptChipToday,
          l.ptChipPain,
          l.ptChipNextWeek,
          l.ptChipLast,
        ].indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton(
              key: Key('coach-chip-$i'),
              onPressed: disabled && i != 1 ? null : () => _send(q),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                foregroundColor: AppColors.text,
                backgroundColor: AppColors.surface2,
                side: const BorderSide(color: AppColors.borderStrong),
                shape: const StadiumBorder(),
              ),
              child: Text(q,
                  style: AppTypography.body14
                      .copyWith(fontWeight: FontWeight.w700)),
            ),
          ),
      ],
    );
  }

  Widget _bubble(String text) => Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(AppRadius.r14),
            ),
            child: Text(text,
                style: AppTypography.body14.copyWith(
                    color: AppColors.onAccent, fontWeight: FontWeight.w600)),
          ),
        ),
      );

  Widget _coachLabel() => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          const Icon(LucideIcons.sparkles, size: 12, color: AppColors.accent),
          const SizedBox(width: 4),
          Text(context.l10n.ptChatTitle,
              style: AppTypography.caption12.copyWith(color: AppColors.text2)),
        ]),
      );

  Widget _reply(CoachTurn turn) {
    final l = context.l10n;
    return switch (turn.state) {
      CoachTurnState.waiting => Semantics(
          key: const Key('coach-chat-thinking'),
          liveRegion: true,
          label: '${l.ptThinking} ${l.ptThinkingSub}',
          excludeSemantics: true,
          child: Row(children: [
            const _Dots(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.ptThinking, style: AppTypography.row15),
                    Text(l.ptThinkingSub,
                        style: AppTypography.caption12
                            .copyWith(color: AppColors.text2)),
                  ]),
            ),
          ]),
        ),
      CoachTurnState.answered => Column(
          key: const Key('coach-chat-reply'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _coachLabel(),
            CoachCard(
              child: SelectableText(turn.answer ?? '',
                  style: AppTypography.body14),
            ),
          ],
        ),
      CoachTurnState.outOfCredits => const SizedBox.shrink(),
      CoachTurnState.failed => Column(
          key: const Key('coach-chat-failed'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppBanner(
              title: l.aiCoachMessageNotSent,
              body: switch (turn.failure) {
                CoachFailure.offline => l.ptOfflineBody,
                CoachFailure.limit => context.tr(
                    'Đã đạt giới hạn dùng AI hôm nay. Không dùng lượt AI nào; hãy thử lại vào ngày mai.',
                    'You reached today\'s AI limit. No AI credit was used; try again tomorrow.'),
                _ => l.aiCoachChargedOnce,
              },
              tone: AppBannerTone.neutral,
            ),
            if (turn.failure != CoachFailure.limit) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: AppButton(
                  key: const Key('coach-chat-retry'),
                  label: l.commonRetry,
                  variant: AppButtonVariant.secondary,
                  expand: false,
                  onPressed: () =>
                      _conversation.retry(turn, locale: context.coachLocale),
                ),
              ),
            ],
          ],
        ),
    };
  }

  /// AC-03e: fixed template, then an optional no-load session (shown, not
  /// applied: these exercises are manual-log moves outside the plan's
  /// exercise list, D-28).
  Widget _safety() {
    final l = context.l10n;
    final rows = [
      (l.commonHomeSquat, '2 × 15'),
      (l.legacyExercisePickerLunge, '2 × 10'),
      (l.coachGluteBridge, '2 × 12'),
    ];
    return Column(
      key: const Key('coach-chat-safety'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _coachLabel(),
        CoachCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningTint,
                borderRadius: BorderRadius.circular(AppRadius.r12),
              ),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(LucideIcons.triangleAlert,
                    size: 18, color: AppColors.warningText),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(l.ptReplyPain1, style: AppTypography.body14)),
              ]),
            ),
            const SizedBox(height: 12),
            Text(l.ptReplyPain2, style: AppTypography.body14),
            const SizedBox(height: 12),
            CoachCard(
              accent: true,
              padding: const EdgeInsets.all(12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CoachCaption(l.ptWorkoutCardCap),
                    const SizedBox(height: 6),
                    Text(
                        context
                            .tr('Thân dưới · không tải lên vai',
                                'Lower body · no shoulder load')
                            .toUpperCase(),
                        style: AppTypography.display40.copyWith(fontSize: 20)),
                    Text(l.ptPainCardMeta(3, 6, 14),
                        style: AppTypography.caption12
                            .copyWith(color: AppColors.text2)),
                    const SizedBox(height: 6),
                    for (final (name, amount) in rows)
                      Container(
                        constraints: const BoxConstraints(minHeight: 40),
                        decoration: const BoxDecoration(
                            border: Border(
                                bottom: BorderSide(color: AppColors.border))),
                        child: Row(children: [
                          Expanded(
                              child: Text(name, style: AppTypography.row15)),
                          Text(amount,
                              style:
                                  AppTypography.stat30.copyWith(fontSize: 18)),
                        ]),
                      ),
                  ]),
            ),
            const SizedBox(height: 10),
            CoachNote(l.ptPainNoCharge),
          ]),
        ),
      ],
    );
  }

  Widget _outOfCredits() {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: CoachCard(
        key: const Key('coach-chat-out'),
        child: CoachStatus(
          icon: LucideIcons.zapOff,
          title: l.ptChatOutTitle,
          body: l.ptChatOutBody,
          children: [
            CoachNote(
                l.ptResetsOn(context.coachResetDate(widget.credits.balance)),
                icon: LucideIcons.calendar),
          ],
        ),
      ),
    );
  }

  Widget _composer({required bool disabled, required bool paused}) {
    final l = context.l10n;
    return DecoratedBox(
      decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border))),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(
              child: TextField(
                key: const Key('coach-chat-input'),
                controller: _input,
                enabled: !disabled,
                minLines: 1,
                maxLines: 4,
                maxLength: 2000,
                textInputAction: TextInputAction.send,
                onSubmitted: disabled ? null : _send,
                decoration: InputDecoration(
                  hintText: paused ? l.ptChatPaused : l.ptComposer,
                  // The hint keeps text2 contrast even when disabled (Q-2).
                  hintStyle:
                      AppTypography.body14.copyWith(color: AppColors.text2),
                  counterText: '',
                  filled: true,
                  fillColor: AppColors.surface2,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox.square(
              dimension: 52,
              child: IconButton.filled(
                key: const Key('coach-chat-send'),
                tooltip: l.commonSend,
                onPressed: disabled ? null : () => _send(_input.text),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.onAccent,
                  disabledBackgroundColor: AppColors.surface3,
                  disabledForegroundColor: AppColors.text3,
                ),
                icon: const Icon(LucideIcons.send),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          CoachNote(l.ptEachMessage, center: true),
        ]),
      ),
    );
  }
}

/// Three dots; still under Reduce Motion (they never animate here, the
/// ring-free "thinking" state of AC-03c).
class _Dots extends StatelessWidget {
  const _Dots();

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: i == 0 ? AppColors.accent : AppColors.text3,
                shape: BoxShape.circle,
              ),
            ),
        ],
      );
}
