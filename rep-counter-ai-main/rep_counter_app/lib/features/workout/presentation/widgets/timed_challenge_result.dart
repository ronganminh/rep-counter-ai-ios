import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/product_ui.dart';
import '../../data/workout_record.dart';
import '../../domain/workout_personal_records.dart';

typedef TimedPreviousBestLoader = Future<int?> Function(WorkoutRecord record);

class TimedChallengeOutcome {
  const TimedChallengeOutcome({
    required this.completed,
    required this.isNewPersonalRecord,
    required this.previousBest,
    required this.repsToBest,
    required this.matchedBest,
  });

  factory TimedChallengeOutcome.from({
    required WorkoutRecord record,
    required int? previousBest,
  }) {
    final completed = record.completedTimedChallenge;
    final isNew = completed &&
        (previousBest == null || record.reps > previousBest);
    final matched = completed &&
        previousBest != null &&
        record.reps == previousBest;
    final gap = completed &&
            previousBest != null &&
            record.reps < previousBest
        ? previousBest - record.reps
        : null;
    return TimedChallengeOutcome(
      completed: completed,
      isNewPersonalRecord: isNew,
      previousBest: previousBest,
      repsToBest: gap,
      matchedBest: matched,
    );
  }

  final bool completed;
  final bool isNewPersonalRecord;
  final int? previousBest;
  final int? repsToBest;
  final bool matchedBest;
}

class TimedChallengeResultSection extends StatefulWidget {
  const TimedChallengeResultSection({
    super.key,
    required this.record,
    this.loadPreviousBest,
  });

  final WorkoutRecord record;
  final TimedPreviousBestLoader? loadPreviousBest;

  @override
  State<TimedChallengeResultSection> createState() =>
      _TimedChallengeResultSectionState();
}

class _TimedChallengeResultSectionState
    extends State<TimedChallengeResultSection> {
  late Future<int?> _previousBest;

  @override
  void initState() {
    super.initState();
    _previousBest = _load();
  }

  @override
  void didUpdateWidget(TimedChallengeResultSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.record.id != widget.record.id ||
        oldWidget.record.reps != widget.record.reps ||
        oldWidget.loadPreviousBest != widget.loadPreviousBest) {
      _previousBest = _load();
    }
  }

  Future<int?> _load() {
    final custom = widget.loadPreviousBest;
    if (custom != null) return custom(widget.record);
    final seconds = widget.record.challengeSeconds;
    if (seconds == null) return Future<int?>.value(null);
    return WorkoutPersonalRecordStore().bestTimedReps(
      exerciseId: widget.record.exerciseId,
      challengeSeconds: seconds,
      excludeRecordId: widget.record.id,
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<int?>(
        future: _previousBest,
        builder: (context, snapshot) {
          final outcome = TimedChallengeOutcome.from(
            record: widget.record,
            previousBest: snapshot.data,
          );
          return _TimedChallengeResultBody(
            record: widget.record,
            outcome: outcome,
            loadingBest: snapshot.connectionState == ConnectionState.waiting,
          );
        },
      );
}

class _TimedChallengeResultBody extends StatelessWidget {
  const _TimedChallengeResultBody({
    required this.record,
    required this.outcome,
    required this.loadingBest,
  });

  final WorkoutRecord record;
  final TimedChallengeOutcome outcome;
  final bool loadingBest;

  @override
  Widget build(BuildContext context) {
    final challengeSeconds = record.challengeSeconds ?? record.durationSeconds;
    final quality = record.quality;
    final formScore =
        quality != null && quality.hasEnoughData ? '${quality.qualityScore}' : '—';

    return Column(
      key: const Key('timed-challenge-result'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.tr(
            'THỬ THÁCH $challengeSeconds GIÂY',
            '$challengeSeconds SEC CHALLENGE',
          ),
          textAlign: TextAlign.center,
          style: AppTypography.caption12.copyWith(color: AppColors.text2),
        ),
        const SizedBox(height: 34),
        Semantics(
          label: '${record.reps} rep',
          child: ExcludeSemantics(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${record.reps}',
                key: const Key('timed-result-reps'),
                textScaler: TextScaler.noScaling,
                style: AppTypography.hero.copyWith(
                  fontSize: 180,
                  color: AppColors.accent,
                ),
              ),
            ),
          ),
        ),
        Text(
          'rep',
          textAlign: TextAlign.center,
          style: AppTypography.display40.copyWith(color: AppColors.text2),
        ),
        const SizedBox(height: 28),
        Container(
          height: 4,
          decoration: BoxDecoration(
            color: outcome.isNewPersonalRecord
                ? AppColors.accent
                : AppColors.borderStrong,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 10),
        _PersonalRecordResultCard(
          outcome: outcome,
          loading: loadingBest,
        ),
        const SizedBox(height: 18),
        Container(
          key: const Key('timed-result-form-score'),
          constraints: const BoxConstraints(minHeight: 94),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('Điểm form', 'Form score'),
                  style: AppTypography.body14.copyWith(
                    color: AppColors.text2,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                formScore,
                style: AppTypography.display40.copyWith(
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PersonalRecordResultCard extends StatelessWidget {
  const _PersonalRecordResultCard({
    required this.outcome,
    required this.loading,
  });

  final TimedChallengeOutcome outcome;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (!outcome.completed) {
      return _ResultCard(
        key: const Key('timed-result-early'),
        accent: false,
        title: context.tr(
          'Thử thách kết thúc sớm',
          'Challenge ended early',
        ),
        subtitle: outcome.previousBest == null
            ? context.tr(
                'Chưa cập nhật kỷ lục cá nhân.',
                'Personal record was not updated.',
              )
            : context.tr(
                'Kỷ lục vẫn là ${outcome.previousBest} rep.',
                'Your best remains ${outcome.previousBest} reps.',
              ),
      );
    }

    if (loading) {
      return _ResultCard(
        key: const Key('timed-result-best-loading'),
        accent: false,
        title: context.tr('Đang kiểm tra kỷ lục…', 'Checking your best…'),
      );
    }

    if (outcome.isNewPersonalRecord) {
      return _ResultCard(
        key: const Key('timed-result-new-pr'),
        accent: true,
        title: context.tr(
          '★ KỶ LỤC CÁ NHÂN MỚI',
          '★ NEW PERSONAL RECORD',
        ),
        subtitle: outcome.previousBest == null
            ? context.tr(
                'Kỷ lục đầu tiên cho thời lượng này.',
                'Your first record for this duration.',
              )
            : context.tr(
                'Kỷ lục trước: ${outcome.previousBest}',
                'Previous best: ${outcome.previousBest}',
              ),
      );
    }

    if (outcome.matchedBest) {
      return _ResultCard(
        key: const Key('timed-result-matched-pr'),
        accent: false,
        title: context.tr(
          'Kỷ lục: ${outcome.previousBest}',
          'Best: ${outcome.previousBest}',
        ),
        subtitle: context.tr(
          'Bạn đã bằng kỷ lục hiện tại.',
          'You matched your current best.',
        ),
      );
    }

    return _ResultCard(
      key: const Key('timed-result-no-pr'),
      accent: false,
      title: context.tr(
        'Kỷ lục: ${outcome.previousBest}',
        'Best: ${outcome.previousBest}',
      ),
      subtitle: outcome.repsToBest == null
          ? null
          : context.tr(
              'Còn ${outcome.repsToBest} rep để chạm kỷ lục',
              '${outcome.repsToBest} reps to match your best',
            ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    super.key,
    required this.accent,
    required this.title,
    this.subtitle,
  });

  final bool accent;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 106),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: accent ? AppColors.accent : AppColors.borderStrong,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment:
              accent ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            Text(
              title,
              textAlign: accent ? TextAlign.center : TextAlign.start,
              style: AppTypography.title20.copyWith(
                color: accent ? AppColors.accent : AppColors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 10),
              Text(
                subtitle!,
                textAlign: accent ? TextAlign.center : TextAlign.start,
                style: AppTypography.body14.copyWith(
                  color: AppColors.text2,
                ),
              ),
            ],
          ],
        ),
      );
}
