import 'package:flutter/material.dart';
import '../../../widgets/product_ui.dart';
import '../../../core/i18n/locale_controller.dart';
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
                        'Sau khi lưu buổi tập mới, app sẽ gửi tên bài, mục tiêu, số rep/set, thời gian, thống kê pose và điểm chất lượng tới máy chủ RepCoach AI để tạo nhận xét bằng Gemini. Không gửi video, ảnh hoặc tọa độ khớp.\n\nLịch sử cũ không tự tải lên. Bạn có thể tắt trong Cài đặt; việc tắt không thu hồi yêu cầu đã gửi. Kết quả vẫn lưu trên máy khi mạng lỗi.',
                        'After a new workout is saved, the app sends the exercise, goal, reps/sets, duration, pose statistics and quality scores to the RepCoach AI server for Gemini feedback. No video, photos or landmark coordinates are sent.\n\nOlder history is not uploaded automatically. You can turn this off in Settings; disabling it cannot recall requests already sent. Workouts remain saved on device if the network fails.')),
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
              'RepCoach AI sẽ gửi bản tóm tắt buổi tập này gồm tên bài, mục tiêu, số rep/set, thời gian, thống kê pose và điểm chất lượng qua máy chủ RepCoach AI đến Google Gemini để tạo nhận xét. Không gửi video, ảnh, âm thanh hoặc tọa độ khớp thô.\n\nSự đồng ý này chỉ áp dụng cho yêu cầu bạn đang thực hiện.',
              'RepCoach AI will send a summary of this workout, including the exercise, goal, reps/sets, duration, pose statistics and quality scores, through the RepCoach AI server to Google Gemini to generate feedback. No video, photos, audio or raw landmark coordinates are sent.\n\nThis consent applies only to the request you are making now.',
            )),
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
