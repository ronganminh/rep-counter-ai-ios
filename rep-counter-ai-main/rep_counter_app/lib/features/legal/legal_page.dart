import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/product_ui.dart';
import '../../theme/app_typography.dart';

import '../../core/i18n/app_strings.dart';
import '../../core/i18n/locale_controller.dart';
import '../../core/legal/legal_config.dart';

enum LegalKind { privacy, terms }

class LegalPage extends StatelessWidget {
  const LegalPage({super.key, required this.kind});
  final LegalKind kind;

  @override
  Widget build(BuildContext context) {
    final privacy = kind == LegalKind.privacy;
    final s = context.s;
    return Scaffold(
      appBar: AppBar(title: Text(privacy ? s.privacyPolicy : s.termsOfUse)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: privacy ? _privacy(context, s) : _terms(context, s),
      ),
    );
  }

  List<Widget> _privacy(BuildContext context, S s) => [
        _intro('${s.legalEffective}: ${s.legalDate}',
            '${LegalConfig.appName} ${s.privacyIntroBody}'),
        _section(context, s.privCameraTitle, s.privCameraBody),
        _section(context, s.privWorkoutTitle, s.privWorkoutBody),
        _section(context, s.privAiTitle, s.privAiBody),
        _section(
            context,
            context.tr(
                'AI tự động và ảnh chia sẻ', 'Automatic AI and shared images'),
            context.tr(
                'AI tự động mặc định tắt. Chỉ sau khi bạn đồng ý, app gửi số liệu tổng hợp của buổi tập mới đã lưu đến máy chủ RepCoach AI để nhận xét bằng Gemini. Có thể tắt trong Cài đặt; không tự gửi lại lịch sử cũ. Tắt không thu hồi yêu cầu đã gửi. Ảnh story do app tạo chỉ chứa số liệu và trích nhận xét, không có ảnh camera. Ảnh chỉ được lưu vào thư viện hoặc gửi qua ứng dụng bạn chọn khi bạn bấm thao tác tương ứng.',
                'Automatic AI is off by default. With your consent, aggregate statistics from newly saved workouts are sent to the RepCoach AI server for Gemini feedback. Disable it in Settings; old history is not automatically uploaded. Disabling cannot recall requests already sent. Generated story images contain statistics and feedback excerpts, never camera images. Images are saved to Photos or shared with an app you choose only when you select the corresponding action.')),
        _section(context, s.privRetentionTitle, s.privRetentionBody),
        _section(context, s.privSecurityTitle, s.privSecurityBody),
        _section(context, s.privChildrenTitle, s.privChildrenBody),
        _section(context, s.privChoicesTitle, s.privChoicesBody),
        _section(context, s.privChangesTitle, s.privChangesBody),
        _section(context, s.privContactTitle,
            '${LegalConfig.developerName}\n${LegalConfig.contactEmail}'),
      ];

  List<Widget> _terms(BuildContext context, S s) => [
        _intro('${s.legalEffective}: ${s.legalDate}',
            '${s.termsIntroPrefix} ${LegalConfig.appName}${s.termsIntroSuffix}'),
        _section(context, s.termsPurposeTitle, s.termsPurposeBody),
        _section(context, s.termsNotMedicalTitle, s.termsNotMedicalBody),
        _section(context, s.termsSafetyTitle, s.termsSafetyBody),
        _section(context, s.termsLiabilityTitle, s.termsLiabilityBody),
        _section(context, s.termsUseTitle, s.termsUseBody),
        _section(context, s.termsChangesTitle, s.termsChangesBody),
        _section(context, s.termsContactTitle,
            '${s.termsContactBody}\n${LegalConfig.contactEmail}'),
      ];

  Widget _intro(String overline, String body) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(overline, style: const TextStyle(color: AppColors.text3)),
          const SizedBox(height: 12),
          Text(body,
              style: const TextStyle(
                  fontSize: 17, height: 1.5, fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _section(BuildContext context, String title, String body) => Padding(
        padding: const EdgeInsets.only(bottom: 22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: AppTypography.title20),
          const SizedBox(height: 7),
          Text(body,
              style: const TextStyle(color: AppColors.text2, height: 1.55)),
        ]),
      );
}
