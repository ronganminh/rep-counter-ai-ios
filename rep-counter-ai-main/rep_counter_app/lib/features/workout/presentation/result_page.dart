import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/i18n/locale_controller.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/product_ui.dart';
import '../application/result_controller.dart';
import '../data/workout_record.dart';
import '../data/workout_history_store.dart';
import '../domain/workout_mode.dart';
import 'widgets/rep_pace_chart.dart';
import '../../share/story_page.dart';
import '../../ai/ai_preferences.dart';
import '../../achievements/achievement.dart';
import '../../achievements/achievement_service.dart';
import '../../achievements/presentation/achievement_earned_card.dart';
import 'widgets/form_score_details.dart';
import 'widgets/result_feedback_card.dart';
import 'widgets/result_hero.dart';
import 'widgets/timed_challenge_result.dart';

class ResultPage extends StatefulWidget {
  const ResultPage(
      {super.key,
      required this.record,
      this.readOnly = false,
      this.analyze,
      this.saveFeedback,
      this.aiConfigured,
      this.historyStore,
      this.timedBestLoader,
      this.offerAutomaticAi = false});
  final WorkoutRecord record;
  final bool readOnly;
  final AnalyzeWorkout? analyze;
  final SaveFeedback? saveFeedback;
  final bool? aiConfigured;
  final WorkoutHistoryStore? historyStore;
  final TimedPreviousBestLoader? timedBestLoader;
  final bool offerAutomaticAi;
  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  late ResultController _controller;
  late final _history = widget.historyStore ?? WorkoutHistoryStore();
  late final AchievementService _achievementService;
  List<AchievementId> _newAchievements = const <AchievementId>[];
  bool _deleting = false;
  @override
  void initState() {
    super.initState();
    _achievementService = AchievementService(history: _history);
    _createController();
    if (!widget.readOnly) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadAchievements());
    }
    if (widget.offerAutomaticAi && !widget.readOnly) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _automaticAi());
    }
  }

  Future<void> _loadAchievements() async {
    final recordId = widget.record.id;
    try {
      final earned =
          await _achievementService.claimAfterResult(widget.record);
      if (!mounted ||
          widget.readOnly ||
          widget.record.id != recordId) {
        return;
      }
      setState(() => _newAchievements = earned);
    } catch (_) {
      // Local achievement persistence must never block the saved result.
    }
  }

  Future<void> _automaticAi() async {
    final controller = _controller;
    try {
      final enabled = await AiPreferences.enabled();
      if (!mounted ||
          !identical(controller, _controller) ||
          !enabled ||
          controller.hasFeedback) {
        return;
      }
      await controller.request(context.language);
    } catch (_) {/* A preference failure must not block local results. */}
  }

  void _createController() {
    _controller = ResultController(widget.record,
        analyze: widget.analyze,
        saveFeedback: widget.saveFeedback ?? _history.saveFeedback,
        configured: widget.aiConfigured)
      ..addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void didUpdateWidget(ResultPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.record != widget.record) {
      _controller.dispose();
      _createController();
      _newAchievements = const <AchievementId>[];
      if (!widget.readOnly) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _loadAchievements());
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _deleteRecord() async {
    if (_deleting) return;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text(
                    context.tr('Xóa buổi tập này?', 'Delete this workout?')),
                content: Text(context.tr(
                    'Bạn có thể hoàn tác trong 5 giây sau khi xóa.',
                    'You can undo this for 5 seconds after deletion.')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(context.s.cancel)),
                  FilledButton(
                      key: const Key('confirm-delete-workout'),
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(context.s.delete)),
                ]));
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      final deleted = await _history.delete(_controller.record.id);
      if (mounted) Navigator.of(context).pop(deleted);
    } catch (_) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(context.tr('Không thể xóa. Hãy thử lại.',
                'Could not delete. Please retry.'))));
      }
    }
  }

  void _close() {
    if (_deleting) return;
    if (widget.readOnly) {
      Navigator.of(context).maybePop();
    } else {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s, r = _controller.record;
    final timed = r.mode == WorkoutMode.timed;
    final challengeSeconds = r.challengeSeconds ?? r.durationSeconds;
    return PopScope(
        canPop: widget.readOnly && !_deleting,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && !widget.readOnly) _close();
        },
        child: Scaffold(
          appBar: AppBar(
              centerTitle: true,
              leading: IconButton(
                  onPressed: _close,
                  tooltip: widget.readOnly
                      ? context.tr('Quay lại', 'Back')
                      : s.backHome,
                  icon: Icon(widget.readOnly
                      ? LucideIcons.chevronLeft
                      : LucideIcons.x)),
              title: Text(
                  timed
                      ? context.tr(
                          'THỬ THÁCH $challengeSeconds GIÂY',
                          '$challengeSeconds SEC CHALLENGE')
                      : widget.readOnly
                          ? '${r.startedAt.day}/${r.startedAt.month}/${r.startedAt.year} · ${r.startedAt.hour.toString().padLeft(2, '0')}:${r.startedAt.minute.toString().padLeft(2, '0')}'
                          : context.tr('Kết quả buổi tập', 'Workout results'),
                  style: const TextStyle(fontSize: 16))),
          bottomNavigationBar: DecoratedBox(
              decoration: const BoxDecoration(
                  color: AppColors.bg,
                  border: Border(top: BorderSide(color: AppColors.border))),
              child: SafeArea(
                  top: false,
                  child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                      child: Row(children: [
                        Expanded(
                            child: FilledButton(
                                key: const Key('result-done'),
                                onPressed: _deleting ? null : _close,
                                child: Text(context.tr('Xong', 'Done')))),
                        if (widget.readOnly) ...[
                          const SizedBox(width: 12),
                          IconButton.filledTonal(
                              key: const Key('delete-workout-detail'),
                              tooltip:
                                  context.tr('Xóa buổi tập', 'Delete workout'),
                              style: IconButton.styleFrom(
                                  minimumSize: const Size(56, 56),
                                  backgroundColor: AppColors.dangerTint,
                                  foregroundColor: AppColors.dangerText),
                              onPressed: _deleting ? null : _deleteRecord,
                              icon: const Icon(LucideIcons.trash2)),
                        ],
                        if (!timed || widget.readOnly) ...[
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                              key: const Key('open-story'),
                              tooltip: context.tr('Chia sẻ', 'Share'),
                              onPressed: _deleting
                                  ? null
                                  : () => Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(
                                          builder: (_) => StoryPage(
                                              record: _controller.record))),
                              icon: const Icon(LucideIcons.share2)),
                        ],
                      ])))),
          body: timed
              ? ListView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                  children: [
                    TimedChallengeResultSection(
                      record: r,
                      loadPreviousBest: widget.timedBestLoader,
                    ),
                    if (_newAchievements.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      for (var i = 0; i < _newAchievements.length; i++) ...[
                        AchievementEarnedCard(
                          achievement: _newAchievements[i],
                        ),
                        if (i != _newAchievements.length - 1)
                          const SizedBox(height: 16),
                      ],
                    ],
                    const SizedBox(height: 24),
                    Text(
                      s.resultDisclaimer,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.text3,
                        height: 1.5,
                      ),
                    ),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  children: [
                    ResultHero(record: r),
                    if (_newAchievements.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      for (var i = 0; i < _newAchievements.length; i++) ...[
                        AchievementEarnedCard(
                          achievement: _newAchievements[i],
                        ),
                        if (i != _newAchievements.length - 1)
                          const SizedBox(height: 16),
                      ],
                    ],
                    const SizedBox(height: 28),
                    ResultFeedbackCard(
                        controller: _controller, allowRefresh: !widget.readOnly),
                    const SizedBox(height: 24),
                    SectionLabel(context.tr('Điểm form', 'Form score')),
                    FormScoreSection(record: r),
                    const SizedBox(height: 24),
                    SectionLabel(context.tr('Nhịp từng rep', 'Rep pace')),
                    RepPaceChart(record: r),
                    const SizedBox(height: 24),
                    Text(s.resultDisclaimer,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.text3, height: 1.5)),
                  ]),
        ));
  }
}

