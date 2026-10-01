import 'package:flutter/material.dart';

import '../../../../core/i18n/locale_controller.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/product_ui.dart';
import '../../data/workout_record.dart';
import '../../domain/rule_based_feedback.dart';

Future<void> showFormScoreDetails(
  BuildContext context,
  WorkoutRecord record,
) async {
  final quality = record.quality;
  if (quality == null || !quality.hasEnoughData) return;

  final media = MediaQuery.of(context);
  final largeText = media.textScaler.scale(16) > 24;
  final useFullPage = media.size.width < 360 || largeText;

  if (useFullPage) {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _FormScoreDetailsPage(record: record),
      ),
    );
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.scrim,
    builder: (sheetContext) => SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * .72,
        child: FormScoreDetailsContent(
          record: record,
          showHandle: true,
        ),
      ),
    ),
  );
}

class FormScoreSection extends StatelessWidget {
  const FormScoreSection({
    super.key,
    required this.record,
  });

  final WorkoutRecord record;

  @override
  Widget build(BuildContext context) {
    final quality = record.quality;
    if (quality == null || !quality.hasEnoughData) {
      return FormScoreInsufficientState(record: record);
    }

    return Card(
      key: const Key('form-score-valid'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text.rich(
              TextSpan(
                text: '${quality.qualityScore}',
                style: AppTypography.metric64.copyWith(
                  color: AppColors.accent,
                ),
                children: [
                  TextSpan(
                    text: ' / 100',
                    style: AppTypography.title20.copyWith(
                      color: AppColors.text3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              key: const Key('form-score-explain'),
              onPressed: () => showFormScoreDetails(context, record),
              style: TextButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.zero,
                foregroundColor: AppColors.accent,
              ),
              child: Text(
                context.tr(
                  'Điểm này được tính thế nào?',
                  'How is this score calculated?',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FormScoreInsufficientState extends StatelessWidget {
  const FormScoreInsufficientState({
    super.key,
    required this.record,
  });

  final WorkoutRecord record;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('form-score-insufficient'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderStrong),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr(
                  '${record.reps} rep đã lưu',
                  '${record.reps} reps saved',
                ),
                key: const Key('form-score-saved-reps'),
                style: AppTypography.headline28.copyWith(
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr(
                  'Điểm form chưa khả dụng',
                  'Form score unavailable',
                ),
                style: AppTypography.body14.copyWith(
                  color: AppColors.text2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                image: true,
                label: context.tr(
                  'Thông tin điểm form',
                  'Form score information',
                ),
                child: ExcludeSemantics(
                  child: SizedBox(
                    width: 54,
                    height: 54,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.asset(
                          'assets/vnext/form_score_info_ellipse.png',
                          width: 54,
                          height: 54,
                        ),
                        Text(
                          'i',
                          style: AppTypography.headline28.copyWith(
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                context.tr(
                  'Chưa đủ dữ liệu chuyển động đáng tin cậy',
                  'Not enough reliable movement data',
                ),
                style: AppTypography.title20.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                context.tr(
                  'Số rep vẫn được lưu, nhưng chưa có đủ dữ liệu pose ổn định để chấm điểm form.',
                  'Your rep count is still saved, but there is not enough stable pose data to score your form.',
                ),
                style: AppTypography.body16.copyWith(
                  color: AppColors.text2,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderStrong),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(
                        '✓ Rep count đã lưu',
                        '✓ Rep count saved',
                      ),
                      style: AppTypography.body14.copyWith(
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.tr(
                        '✓ Không hiển thị điểm 0/100',
                        '✓ No 0/100 score is shown',
                      ),
                      style: AppTypography.body14.copyWith(
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                context.tr(
                  'Thử giữ phần thân trên rõ hơn trong khung hình ở buổi tiếp theo.',
                  'Try keeping your upper body more clearly visible in the frame next time.',
                ),
                textAlign: TextAlign.center,
                style: AppTypography.body14.copyWith(
                  color: AppColors.text3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class FormScoreDetailsContent extends StatelessWidget {
  const FormScoreDetailsContent({
    super.key,
    required this.record,
    this.showHandle = false,
  });

  final WorkoutRecord record;
  final bool showHandle;

  @override
  Widget build(BuildContext context) {
    final quality = record.quality;
    if (quality == null || !quality.hasEnoughData) {
      return Material(
        color: AppColors.bg,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: FormScoreInsufficientState(record: record),
        ),
      );
    }

    final factors = _factorTexts(context, record);
    return Material(
      key: const Key('form-score-details'),
      color: AppColors.surface,
      borderRadius: showHandle
          ? const BorderRadius.vertical(top: Radius.circular(28))
          : BorderRadius.zero,
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showHandle) ...[
              Align(
                child: Container(
                  width: 61,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.track,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            LayoutBuilder(
              builder: (context, constraints) {
                final largeText =
                    MediaQuery.textScalerOf(context).scale(16) > 24;
                final label = Text(
                  'FORM SCORE',
                  style: AppTypography.caption12.copyWith(
                    color: AppColors.text2,
                  ),
                );
                final score = Text(
                  '${quality.qualityScore} / 100',
                  key: const Key('form-score-details-overall'),
                  style: AppTypography.metric40.copyWith(
                    color: AppColors.accent,
                  ),
                );
                if (largeText || constraints.maxWidth < 280) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      label,
                      const SizedBox(height: 8),
                      score,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: label),
                    const SizedBox(width: 12),
                    score,
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            _MetricRow(
              label: context.tr(
                'Biên độ chuyển động',
                'Range of motion',
              ),
              value: quality.rangeOfMotion,
            ),
            _MetricRow(
              label: context.tr(
                'Độ ổn định nhịp',
                'Cadence consistency',
              ),
              value: quality.cadenceConsistency,
            ),
            _MetricRow(
              label: context.tr(
                'Cân bằng trái/phải',
                'Left/right balance',
              ),
              value: quality.leftRightBalance,
            ),
            _MetricRow(
              label: context.tr(
                'Căn chỉnh tư thế',
                'Pose alignment',
              ),
              value: quality.poseAlignment,
            ),
            const SizedBox(height: 12),
            Text(
              context.tr(
                'ĐIỀU ẢNH HƯỞNG ĐẾN BUỔI TẬP',
                'WHAT AFFECTED THIS WORKOUT',
              ),
              style: AppTypography.caption12.copyWith(
                color: AppColors.text2,
              ),
            ),
            const SizedBox(height: 14),
            for (final factor in factors)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Text(
                  '• $factor',
                  style: AppTypography.body14,
                ),
              ),
            const SizedBox(height: 26),
            Text(
              context.tr(
                'Nhận xét tư thế chỉ nhằm hỗ trợ tập luyện, không phải tư vấn y tế.',
                'Form feedback is exercise guidance, not medical advice.',
              ),
              textAlign: TextAlign.center,
              style: AppTypography.caption12.copyWith(
                color: AppColors.text3,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormScoreDetailsPage extends StatelessWidget {
  const _FormScoreDetailsPage({required this.record});

  final WorkoutRecord record;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(
            context.tr('Điểm form', 'Form score'),
            style: const TextStyle(fontSize: 16),
          ),
        ),
        body: FormScoreDetailsContent(record: record),
      );
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
  });

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: AppTypography.body14,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$value',
                  style: AppTypography.body14,
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              key: ValueKey('form-score-metric-$label'),
              semanticsLabel: label,
              semanticsValue: '$value%',
              value: (value / 100).clamp(0, 1),
              minHeight: 7,
              color: AppColors.accent,
              backgroundColor: AppColors.track,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
}

List<String> _factorTexts(BuildContext context, WorkoutRecord record) {
  final feedback = const RuleBasedFeedback().analyze(record);
  final notes = <FeedbackNote>[
    ...feedback.improvements,
    ...feedback.strengths,
  ];

  if (notes.isEmpty) {
    return [context.s.fbNothingYet];
  }

  return notes
      .take(3)
      .map((note) => _factorText(context, record, note))
      .toList();
}

String _factorText(
  BuildContext context,
  WorkoutRecord record,
  FeedbackNote note,
) {
  switch (note) {
    case FeedbackNote.goalReached:
      return context.s.fbGoalReached;
    case FeedbackNote.steadyCadence:
      return context.s.fbSteadyCadence;
    case FeedbackNote.goodRange:
      return context.s.fbGoodRange;
    case FeedbackNote.balancedSides:
      return context.s.fbBalancedSides;
    case FeedbackNote.goodCameraSetup:
      return context.s.fbGoodCameraSetup;
    case FeedbackNote.poseLostOften:
      return context.s.fbPoseLostOften;
    case FeedbackNote.amplitudeDropped:
      return context.s.fbAmplitudeDropped;
    case FeedbackNote.leftRightUneven:
      return context.s.fbLeftRightUneven;
    case FeedbackNote.repsTooFast:
      final fast = record.repDetails
              ?.where((rep) => rep.tooFast)
              .length ??
          0;
      if (fast > 0) {
        return context.tr(
          '$fast rep nhanh hơn ngưỡng phù hợp',
          '$fast reps were faster than the form threshold',
        );
      }
      return context.s.fbRepsTooFast;
    case FeedbackNote.shortSession:
      return context.s.fbShortSession;
  }
}
