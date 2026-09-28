import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/product_ui.dart';
import '../onboarding/presentation/onboarding_art.dart';
import 'legal_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.onDone});
  final VoidCallback onDone;
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = PageController();
  int _page = 0;
  bool _saving = false;
  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setBool('onboarding_v1', true)) {
        throw StateError('Could not save');
      }
      if (mounted) widget.onDone();
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(context.tr('Chưa lưu được. Vui lòng thử lại.',
                'Could not save. Please retry.'))));
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
          body: SafeArea(
              child: Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 12, 4),
            child: Row(children: [
              const Expanded(child: RepCoachWordmark()),
              if (_page < 2)
                TextButton(
                    onPressed: _saving ? null : _finish,
                    child: Text(context.tr('Bỏ qua', 'Skip'),
                        style: const TextStyle(color: AppColors.text2))),
              if (_page == 2) const SizedBox(height: 48),
            ])),
        Expanded(
            child: PageView(
                controller: _controller,
                onPageChanged: (value) => setState(() => _page = value),
                children: [
              _IntroPage(
                  art: Column(children: [
                    Text('12',
                        textScaler: TextScaler.noScaling,
                        style: AppTypography.hero
                            .copyWith(fontSize: 168, color: AppColors.accent)),
                    const SizedBox(height: 12),
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(30)),
                        child: Text(
                            context.tr(
                                'Đếm rep trực tiếp', 'Live rep counting'),
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.text2))),
                    const Expanded(child: OnboardingArt()),
                  ]),
                  title: context.tr('Điện thoại đếm rep.\nAI chấm và nhận xét.',
                      'Your phone counts.\nAI coaches.'),
                  body: Text(
                      context.tr(
                          'Bắt đầu với hít đất. Squat, gập bụng và nhiều bài khác sắp có.',
                          'Start with push-ups. Squats, sit-ups and more are coming.'),
                      style: AppTypography.body16
                          .copyWith(color: AppColors.text2))),
              _IntroPage(
                  art: Container(
                      decoration: BoxDecoration(
                          color: AppColors.surface,
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(16)),
                      child: Stack(children: [
                        const Positioned.fill(child: OnboardingArt(side: true)),
                        Positioned(
                            top: 14,
                            left: 14,
                            right: 14,
                            child: Text(
                                context.tr('NHÌN TỪ BÊN CẠNH', 'SIDE VIEW'),
                                style: AppTypography.caption12
                                    .copyWith(color: AppColors.text3))),
                        Positioned(
                            left: 12,
                            top: 100,
                            right: 12,
                            child: Text(
                                context.tr('Camera trước · máy dọc',
                                    'Front camera · portrait'),
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.accent))),
                        const Positioned(
                            bottom: 8,
                            left: 40,
                            child: Text('~1–1.5 m',
                                style: TextStyle(fontSize: 12))),
                      ])),
                  title: context.tr(
                      'Đặt điện thoại trước mặt, camera trước hướng vào bạn.',
                      'Place your phone in front, with the front camera facing you.'),
                  titleSize: 34,
                  body: Column(children: [
                    _Tip(
                        LucideIcons.smartphone,
                        context.tr('Dựng máy dọc, cách ~1–1,5 m',
                            'Phone upright, about 1–1.5 m away')),
                    _Tip(
                        LucideIcons.userRound,
                        context.tr('Thấy rõ vai, hai tay và hông',
                            'Keep shoulders, arms and hips visible')),
                    _Tip(
                        LucideIcons.sun,
                        context.tr('Đủ sáng, nền gọn',
                            'Good lighting, clear background')),
                  ])),
              _IntroPage(
                  art: const PrivacyArt(),
                  title: context.tr('Bạn kiểm soát\ndữ liệu của mình.',
                      'Your data.\nYour control.'),
                  body: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                            child: Column(children: [
                          _Tip(
                              LucideIcons.videoOff,
                              context.tr('Hình ảnh camera xử lý trên máy',
                                  'Camera images processed on device'),
                              privacy: true),
                          const Divider(),
                          _Tip(
                              LucideIcons.wifiOff,
                              context.tr('Đếm rep không cần mạng',
                                  'Count reps without internet'),
                              privacy: true),
                          const Divider(),
                          _Tip(
                              LucideIcons.sparkles,
                              context.tr(
                                  'AI chỉ nhận số liệu tổng hợp khi bạn yêu cầu hoặc đã bật nhận xét tự động.',
                                  'AI receives workout statistics only when you request feedback or enable automatic feedback.'),
                              privacy: true),
                        ])),
                        const SizedBox(height: 8),
                        Text(
                            context.tr(
                                'Tập theo khả năng và dừng nếu thấy đau.',
                                'Exercise within your limits. Stop if you feel pain.'),
                            style: const TextStyle(
                                color: AppColors.text3, fontSize: 12)),
                        Wrap(alignment: WrapAlignment.center, children: [
                          for (final kind in LegalKind.values)
                            TextButton(
                                onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => LegalPage(kind: kind))),
                                child: Text(kind == LegalKind.privacy
                                    ? context.tr('Quyền riêng tư', 'Privacy')
                                    : context.tr('Điều khoản', 'Terms'))),
                        ]),
                      ])),
            ])),
        Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: Column(children: [
              Semantics(
                  label: context.tr(
                      'Trang ${_page + 1} trên 3', 'Page ${_page + 1} of 3'),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                          3,
                          (i) => AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              height: 8,
                              width: i == _page ? 24 : 8,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                  color: i == _page
                                      ? AppColors.accent
                                      : AppColors.track,
                                  borderRadius: BorderRadius.circular(8)))))),
              const SizedBox(height: 24),
              FilledButton(
                  onPressed: _saving
                      ? null
                      : () {
                          if (_page == 2) {
                            _finish();
                          } else {
                            _controller.nextPage(
                                duration:
                                    MediaQuery.disableAnimationsOf(context)
                                        ? Duration.zero
                                        : const Duration(milliseconds: 280),
                                curve: Curves.easeOut);
                          }
                        },
                  child: Text(_page == 2
                      ? context.tr('Bắt đầu tập', 'Start training')
                      : context.tr('Tiếp tục', 'Continue'))),
            ])),
      ])));
}

class _IntroPage extends StatelessWidget {
  const _IntroPage(
      {required this.art,
      required this.title,
      required this.body,
      this.titleSize = 40});
  final Widget art, body;
  final String title;
  final double titleSize;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SizedBox(
                          height: (box.maxHeight * .60).clamp(260, 410),
                          child: ExcludeSemantics(child: art)),
                      Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(title,
                                    style: AppTypography.display40
                                        .copyWith(fontSize: titleSize)),
                                const SizedBox(height: 12),
                                body,
                              ])),
                    ])),
          ));
}

class _Tip extends StatelessWidget {
  const _Tip(this.icon, this.text, {this.privacy = false});
  final IconData icon;
  final String text;
  final bool privacy;
  @override
  Widget build(BuildContext context) => Padding(
      padding: EdgeInsets.symmetric(
          horizontal: privacy ? 16 : 0, vertical: privacy ? 14 : 6),
      child: Row(children: [
        Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon,
                size: 22,
                color: privacy && icon != LucideIcons.sparkles
                    ? AppColors.success
                    : AppColors.accent)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Text(text, style: const TextStyle(fontSize: 15, height: 1.4))),
      ]));
}
