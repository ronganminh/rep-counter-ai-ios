import 'package:flutter/material.dart';
import '../../../widgets/product_ui.dart';
import '../../../core/i18n/locale_controller.dart';
import '../../../core/legal/legal_config.dart';
import '../../legal/legal_page.dart';
import '../ai_preferences.dart';

const _groqVi =
    'RepCoach AI sẽ gửi bản tóm tắt giới hạn của buổi tập tới máy chủ RepCoach AI, sau đó máy chủ gửi prompt tối giản tới GroqCloud để tạo nhận xét. Dữ liệu có thể gồm tên bài, mục tiêu, số rep/set, thời gian, thống kê pose và điểm chất lượng. Không gửi video, ảnh, âm thanh hoặc tọa độ landmark thô.\n\nTheo tài liệu GroqCloud hiện hành, dữ liệu inference không được lưu mặc định, ngoại trừ khi cần cho độ tin cậy hệ thống hoặc điều tra lạm dụng; trường hợp đó có thể được giữ tối đa 30 ngày. RepCoach hiện không tuyên bố Zero Data Retention. Lịch sử cũ không tự tải lên; tắt AI không thu hồi yêu cầu đã gửi. Workout vẫn lưu trên máy nếu AI lỗi.';

const _groqEn =
    'RepCoach AI sends a limited workout summary to the RepCoach AI server, which sends a minimized prompt to GroqCloud to generate feedback. Data can include the exercise, goal, reps/sets, duration, pose statistics and quality scores. No video, photos, audio or raw landmark coordinates are sent.\n\nUnder GroqCloud\'s current documentation, inference customer data is not retained by default except when needed for system reliability or abuse investigation; in those cases it may be retained for up to 30 days. RepCoach does not currently claim Zero Data Retention. Older history is not uploaded automatically; disabling AI cannot recall requests already sent. The workout remains saved on device if AI fails.';

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
                    Text(context.tr(_groqVi, _groqEn)),
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
              'RepCoach AI sẽ gửi bản tóm tắt giới hạn của buổi tập này tới máy chủ RepCoach AI, sau đó máy chủ gửi prompt tối giản tới GroqCloud để tạo nhận xét. Không gửi video, ảnh, âm thanh hoặc tọa độ landmark thô.\n\nTheo tài liệu GroqCloud hiện hành, dữ liệu inference không được lưu mặc định, ngoại trừ khi cần cho độ tin cậy hệ thống hoặc điều tra lạm dụng; trường hợp đó có thể được giữ tối đa 30 ngày. RepCoach hiện không tuyên bố Zero Data Retention. Sự đồng ý này chỉ áp dụng cho yêu cầu bạn đang thực hiện.',
              'RepCoach AI sends a limited summary of this workout to the RepCoach AI server, which sends a minimized prompt to GroqCloud to generate feedback. No video, photos, audio or raw landmark coordinates are sent.\n\nUnder GroqCloud\'s current documentation, inference customer data is not retained by default except when needed for system reliability or abuse investigation; in those cases it may be retained for up to 30 days. RepCoach does not currently claim Zero Data Retention. This consent applies only to the request you are making now.',
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
