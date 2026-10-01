import 'package:flutter/material.dart';
import '../../../widgets/product_ui.dart';
import '../../../core/i18n/locale_controller.dart';
import '../../../core/legal/legal_config.dart';
import '../../legal/legal_page.dart';
import '../ai_preferences.dart';

Future<bool> requestAutomaticAiConsent(BuildContext context) async {
  final consent = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
              title: Text(context.tr('Tự động nhận xét sau buổi tập?',
                  'Automatic workout feedback?')),
              content: SingleChildScrollView(
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(context.tr(
                        'AI dùng Gemini chỉ dành cho người từ 18 tuổi trở lên. Sau khi lưu buổi tập mới, app sẽ gửi tên bài, mục tiêu, số rep/set, thời gian, thống kê pose và điểm chất lượng tới máy chủ RepCoach AI. Máy chủ chỉ cho phép gửi tiếp tới Gemini khi project production đã được xác minh có billing. Không gửi video, ảnh, âm thanh hoặc tọa độ landmark thô.\n\nTheo điều khoản Paid Services hiện hành của Google, prompt/response không được dùng để cải thiện sản phẩm của Google, nhưng Google có thể log chúng trong một khoảng thời gian giới hạn để chống lạm dụng và đáp ứng yêu cầu pháp lý. Lịch sử cũ không tự tải lên. Bạn có thể tắt trong Cài đặt; việc tắt không thu hồi yêu cầu đã gửi. Workout vẫn lưu trên máy nếu AI lỗi.',
                        'Gemini-backed AI is for users aged 18 or older. After a new workout is saved, the app sends the exercise, goal, reps/sets, duration, pose statistics and quality scores to the RepCoach AI server. The server only forwards the request to Gemini when the production project has been verified as billing-enabled. No video, photos, audio or raw landmark coordinates are sent.\n\nUnder Google\'s current Paid Services terms, prompts/responses are not used to improve Google products, but Google may log them for a limited period for abuse prevention and required legal disclosures. Older history is not uploaded automatically. You can turn this off in Settings; disabling it cannot recall requests already sent. The workout remains saved on device if AI fails.')),
                    const SizedBox(height: 12),
                    Text(
                      context.tr(
                        'Phiên bản đồng ý: ${LegalConfig.aiConsentVersion}',
                        'Consent version: ${LegalConfig.aiConsentVersion}',
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    TextButton(
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                                builder: (_) =>
                                    const LegalPage(kind: LegalKind.privacy))),
                        child: Text(context.s.privacyPolicy)),
                  ])),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(context.tr('Để sau', 'Not now'))),
                FilledButton(
                    key: const Key('accept-automatic-ai'),
                    onPressed: () => Navigator.pop(context, true),
                    child:
                        Text(context.tr('Đồng ý và bật', 'Agree and enable'))),
              ]));
  if (consent != true) return false;
  await AiPreferences.setEnabled(true);
  return true;
}


Future<bool> requestManualAiConsent(BuildContext context) async {
  final consent = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.tr(
        'Gửi số liệu buổi tập cho AI?',
        'Send workout statistics to AI?',
      )),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr(
              'AI dùng Gemini chỉ dành cho người từ 18 tuổi trở lên. RepCoach AI sẽ gửi bản tóm tắt buổi tập này gồm tên bài, mục tiêu, số rep/set, thời gian, thống kê pose và điểm chất lượng qua máy chủ RepCoach AI. Máy chủ chỉ gửi tiếp tới Gemini khi project production đã được xác minh có billing. Không gửi video, ảnh, âm thanh hoặc tọa độ landmark thô.\n\nTheo điều khoản Paid Services hiện hành của Google, prompt/response không được dùng để cải thiện sản phẩm của Google, nhưng Google có thể log chúng trong một khoảng thời gian giới hạn để chống lạm dụng và đáp ứng yêu cầu pháp lý. Sự đồng ý này chỉ áp dụng cho yêu cầu bạn đang thực hiện.',
              'Gemini-backed AI is for users aged 18 or older. RepCoach AI will send a summary of this workout, including the exercise, goal, reps/sets, duration, pose statistics and quality scores, to the RepCoach AI server. The server only forwards it to Gemini when the production project has been verified as billing-enabled. No video, photos, audio or raw landmark coordinates are sent.\n\nUnder Google\'s current Paid Services terms, prompts/responses are not used to improve Google products, but Google may log them for a limited period for abuse prevention and required legal disclosures. This consent applies only to the request you are making now.',
            )),
            const SizedBox(height: 12),
            Text(
              context.tr(
                'Phiên bản đồng ý: ${LegalConfig.aiConsentVersion}',
                'Consent version: ${LegalConfig.aiConsentVersion}',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const LegalPage(kind: LegalKind.privacy),
                ),
              ),
              child: Text(context.s.privacyPolicy),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('cancel-manual-ai'),
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.s.cancel),
        ),
        FilledButton(
          key: const Key('accept-manual-ai'),
          onPressed: () => Navigator.pop(context, true),
          child: Text(context.tr('Đồng ý & gửi', 'Agree & send')),
        ),
      ],
    ),
  );
  return consent == true;
}
