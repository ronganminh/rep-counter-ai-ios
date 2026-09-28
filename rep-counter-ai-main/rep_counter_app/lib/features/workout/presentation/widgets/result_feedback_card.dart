import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/i18n/locale_controller.dart';
import '../../../../theme/app_colors.dart';
import '../../../../widgets/product_ui.dart';
import '../../../ai/ai_feedback_service.dart';
import '../../application/result_controller.dart';
import '../feedback_card.dart';

class ResultFeedbackCard extends StatelessWidget {
  const ResultFeedbackCard(
      {super.key, required this.controller, this.allowRefresh = true});
  final ResultController controller;
  final bool allowRefresh;

  @override
  Widget build(BuildContext context) {
    final c = controller, s = context.s;
    final loading = c.phase == ResultFeedbackPhase.loading;
    final unavailable = c.phase == ResultFeedbackPhase.unavailable;
    final hasError = c.phase == ResultFeedbackPhase.offline ||
        c.phase == ResultFeedbackPhase.error;
    final error = switch (c.failure) {
      AiFeedbackFailure.timeout => s.aiTimeout,
      AiFeedbackFailure.offline => s.aiOffline,
      AiFeedbackFailure.server => s.aiServerBusy,
      AiFeedbackFailure.notConfigured => s.aiNotConfigured,
      null => s.aiUnknownError,
    };
    return Container(
      key: const Key('result-feedback-card'),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.accentBorder),
          boxShadow: const [
            BoxShadow(color: AppColors.accentTintSoft, spreadRadius: 4)
          ]),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  color: AppColors.accentTint,
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(LucideIcons.sparkles,
                  color: AppColors.accent, size: 18)),
          const SizedBox(width: 10),
          Expanded(
              child: Text(
                  context.tr('RepCoach AI nhận xét', 'RepCoach AI feedback'),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 12),
        Align(
            alignment: Alignment.centerLeft,
            child: Container(
                key: const Key('feedback-source'),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                    color: c.hasFeedback
                        ? AppColors.accentTint
                        : AppColors.surface3,
                    borderRadius: BorderRadius.circular(6)),
                child: Text(
                    c.hasFeedback
                        ? context.tr('Nhận xét AI', 'AI feedback')
                        : context.tr('Nhận xét nhanh · trên máy',
                            'Quick feedback · on device'),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: c.hasFeedback
                            ? AppColors.accent
                            : AppColors.text2)))),
        const SizedBox(height: 16),
        if (loading) ...[
          Semantics(
              liveRegion: true,
              child: Text(context.tr(
                  'AI đang đọc số liệu…', 'AI is reviewing your statistics…'))),
          const SizedBox(height: 10),
          LinearProgressIndicator(
              key: const Key('ai-loading'),
              value: MediaQuery.disableAnimationsOf(context) ? 0 : null),
          const SizedBox(height: 16),
        ],
        if (hasError || unavailable) ...[
          _Notice(
              icon: c.phase == ResultFeedbackPhase.offline
                  ? LucideIcons.wifiOff
                  : LucideIcons.info,
              text: unavailable ? s.aiNotConfigured : error),
          const SizedBox(height: 16),
        ],
        // Existing feedback remains visible during refresh or network failure.
        if (c.hasFeedback)
          Text(c.record.aiFeedback!,
              key: const Key('ai-feedback-text'),
              style: const TextStyle(fontSize: 18, height: 1.4))
        else
          FeedbackCard(record: c.record, embedded: true),
        if (c.saveFailed) ...[
          const SizedBox(height: 16),
          _Notice(
              icon: LucideIcons.info,
              text: context.tr(
                  'Đã nhận nhận xét nhưng chưa lưu được. Số liệu buổi tập vẫn còn; hãy thử lưu lại trước khi rời màn hình.',
                  'Feedback received but could not be saved. Your workout statistics are intact; retry saving before leaving.')),
          const SizedBox(height: 12),
          OutlinedButton.icon(
              key: const Key('retry-feedback-save'),
              onPressed: c.busy ? null : c.retrySave,
              icon: const Icon(LucideIcons.save, size: 18),
              label: Text(context.tr('Thử lưu lại', 'Retry saving'))),
        ],
        if (c.saving) ...[
          const SizedBox(height: 12),
          Text(context.tr('Đang lưu nhận xét…', 'Saving feedback…'),
              style: const TextStyle(color: AppColors.text2)),
        ],
        if (c.configured &&
            !unavailable &&
            !c.saveFailed &&
            (allowRefresh || !c.hasFeedback || hasError)) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
              key: const Key('ask-result-ai'),
              onPressed: c.busy ? null : () => c.request(context.language),
              icon: Icon(
                  hasError ? LucideIcons.refreshCw : LucideIcons.sparkles,
                  size: 18),
              label: Text(hasError
                  ? s.retry
                  : c.hasFeedback
                      ? s.aiAskAgain
                      : context.tr('Nhận nhận xét AI', 'Get AI feedback'))),
        ],
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(LucideIcons.shieldCheck,
              color: AppColors.success, size: 16),
          const SizedBox(width: 8),
          Expanded(
              child: Text(
                  context.tr(
                      'Chỉ gửi số liệu tổng hợp khi bạn yêu cầu hoặc đã bật AI tự động. Video không rời máy.',
                      'Only aggregate statistics are sent when you request AI or enable automatic feedback. Video stays on your device.'),
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.text3, height: 1.4))),
        ]),
      ]),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Semantics(
      liveRegion: true,
      child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: AppColors.warningTint,
              borderRadius: BorderRadius.circular(12)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: AppColors.warningText, size: 18),
            const SizedBox(width: 8),
            Expanded(
                child: Text(text,
                    style: const TextStyle(
                        color: AppColors.warningText, height: 1.4))),
          ])));
}
