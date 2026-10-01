import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/app_links.dart';
import '../ai/ai_preferences.dart';
import '../ai/presentation/ai_consent.dart';
import '../history/export/export_data_sheet.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/i18n/locale_controller.dart';
import '../../core/legal/legal_config.dart';
import '../../core/services/training_preferences.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/product_ui.dart';
import '../../exercise.dart';
import '../workout/data/calibration_store.dart';
import '../workout/data/workout_history_store.dart';
import '../workout/domain/quality_thresholds.dart';
import 'legal_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late Future<int> _count;
  TrainingPreferences? _training;
  bool _preferenceBusy = false;
  bool _autoAi = false, _aiBusy = true;
  @override
  void initState() {
    super.initState();
    _count = _loadCount();
    _loadTraining();
    _loadAi();
  }

  Future<void> _loadAi() async {
    try {
      final value = await AiPreferences.enabled();
      if (mounted) setState(() => _autoAi = value);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  Future<void> _setAi(bool value) async {
    if (_aiBusy) return;
    setState(() => _aiBusy = true);
    try {
      if (value) {
        final enabled = await requestAutomaticAiConsent(context);
        if (mounted) setState(() => _autoAi = enabled);
      } else {
        await AiPreferences.setEnabled(false);
        if (mounted) setState(() => _autoAi = false);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(context.tr('Chưa lưu được tùy chọn AI.',
                'Could not save AI preference.'))));
      }
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  Future<void> _contact() async {
    try {
      if (await AppLinks.feedback()) return;
    } catch (_) {}
    if (!mounted) return;
    showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text(context.tr('Gửi góp ý', 'Send feedback')),
                content: const SelectableText(LegalConfig.contactEmail),
                actions: [
                  TextButton(
                      onPressed: () async {
                        await Clipboard.setData(const ClipboardData(
                            text: LegalConfig.contactEmail));
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: Text(context.tr('Sao chép email', 'Copy email'))),
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(context.tr('Đóng', 'Close'))),
                ]));
  }

  Future<void> _review() async {
    try {
      if (await AppLinks.review()) return;
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.tr(
            Platform.isIOS && AppLinks.appStoreId.isEmpty
                ? 'Bản iOS chưa có trang App Store để đánh giá.'
                : 'Chưa mở được cửa hàng. Bản test cần tài khoản được mời.',
            Platform.isIOS && AppLinks.appStoreId.isEmpty
                ? 'This iOS build has no App Store listing yet.'
                : 'Could not open the store. Test builds require an invited account.'))));
  }

  Future<void> _loadTraining() async {
    try {
      final value = await TrainingPreferences.load();
      if (mounted) setState(() => _training = value);
    } catch (_) {
      if (mounted) setState(() => _training = const TrainingPreferences());
    }
  }

  Future<void> _setTraining(
      {bool? voice, bool? haptics, bool? sound, bool? cues}) async {
    if (_preferenceBusy || _training == null) return;
    setState(() => _preferenceBusy = true);
    try {
      final value = await _training!
          .update(voice: voice, haptics: haptics, sound: sound, cues: cues);
      if (mounted) setState(() => _training = value);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(context.tr('Chưa lưu được tùy chọn. Hãy thử lại.',
                'Could not save preferences. Please retry.'))));
      }
    } finally {
      if (mounted) setState(() => _preferenceBusy = false);
    }
  }

  Future<int> _loadCount() async => (await WorkoutHistoryStore().load()).length;
  Future<void> _deleteData() async {
    final confirmed = await showDialog<bool>(
        context: context, builder: (_) => const _DeleteDataDialog());
    if (confirmed != true) return;
    try {
      await WorkoutHistoryStore().clear();
      await const CalibrationStore().clearAll();
      if (!mounted) return;
      setState(() {
        _count = _loadCount();
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.s.historyCleared)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(context.tr('Không thể xóa dữ liệu. Hãy thử lại.',
                'Could not delete data. Please retry.'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final p = context.palette;
    return Scaffold(
        body: SafeArea(
            child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Text(s.settings.toUpperCase(), style: AppTypography.display40),
        const SizedBox(height: 28),
        SettingsGroup(title: context.tr('Tập luyện', 'Training'), children: [
          SettingsRow(
              icon: LucideIcons.volume2,
              title: context.tr('Đọc số rep', 'Speak rep count'),
              subtitle: context.tr(
                  'Giọng hệ thống theo ngôn ngữ app. Cần có giọng đọc đã cài trên máy.',
                  'System voice follows the app language. Requires a voice installed on your device.'),
              trailing: Switch(
                  key: const Key('voice-setting'),
                  value: _training?.voice ?? true,
                  onChanged: _training == null || _preferenceBusy
                      ? null
                      : (value) => _setTraining(voice: value))),
          SettingsRow(
              icon: LucideIcons.vibrate,
              title: context.tr('Rung phản hồi', 'Haptic feedback'),
              subtitle: context.tr('Khi đếm ngược, có rep và đạt mục tiêu',
                  'For countdown, reps and reaching your goal'),
              trailing: Switch(
                  key: const Key('haptics-setting'),
                  value: _training?.haptics ?? true,
                  onChanged: _training == null || _preferenceBusy
                      ? null
                      : (value) => _setTraining(haptics: value))),
          SettingsRow(
              icon: LucideIcons.bell,
              title: context.tr('Âm báo set', 'Set sounds'),
              subtitle: context.tr(
                  'Báo bắt đầu và kết thúc set', 'Signals set start and end'),
              trailing: Switch(
                  key: const Key('sound-setting'),
                  value: _training?.sound ?? false,
                  onChanged: _training == null || _preferenceBusy
                      ? null
                      : (v) => _setTraining(sound: v))),
          SettingsRow(
              icon: LucideIcons.messageCircle,
              title: context.tr('Nhắc tư thế', 'Posture reminders'),
              subtitle: context.tr(
                  'Dùng giọng đọc, có khoảng nghỉ giữa các lời nhắc',
                  'Uses voice, with a pause between reminders'),
              trailing: Switch(
                  key: const Key('cues-setting'),
                  value: _training?.cues ?? true,
                  onChanged: _training == null || _preferenceBusy
                      ? null
                      : (v) => _setTraining(cues: v))),
          SettingsRow(
              icon: LucideIcons.ruler,
              title: context.tr('Hiệu chỉnh lại biên độ', 'Reset calibration'),
              subtitle: context.tr('Theo từng bài tập', 'For each exercise'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const CalibrationSettingsPage()))),
          SettingsRow(
              icon: LucideIcons.languages,
              title: s.languageLabel,
              trailing: SizedBox(
                  width: MediaQuery.textScalerOf(context).scale(14) > 20
                      ? 240
                      : 132,
                  child: DropdownButtonHideUnderline(
                      child: DropdownButton<AppLanguage>(
                    isExpanded: true,
                    value: context.language,
                    onChanged: (v) {
                      if (v != null) context.setLanguage(v);
                    },
                    items: [
                      for (final l in AppLanguage.values)
                        DropdownMenuItem(
                            value: l,
                            child:
                                Text(l.label, overflow: TextOverflow.ellipsis))
                    ],
                  )))),
        ]),
        SettingsGroup(
            title: context.tr('AI & Quyền riêng tư', 'AI & privacy'),
            children: [
              SettingsRow(
                  icon: LucideIcons.sparkles,
                  title: context.tr(
                      'AI tự động sau buổi tập', 'Automatic workout feedback'),
                  subtitle: context.tr(
                      'Chỉ bật sau khi bạn đồng ý gửi số liệu tổng hợp',
                      'Enabled only with consent to send aggregate statistics'),
                  trailing: Switch(
                      key: const Key('auto-ai-setting'),
                      value: _autoAi,
                      onChanged: _aiBusy ? null : _setAi)),
              SettingsRow(
                  icon: LucideIcons.shieldCheck,
                  title: context.tr('Xử lý trên máy', 'Processed on device'),
                  subtitle: context.tr(
                      'Hình ảnh camera không rời điện thoại. Chỉ gửi số liệu tổng hợp khi bạn yêu cầu hoặc bật AI tự động.',
                      'Camera images stay on your phone. Only aggregate statistics are sent when you request AI or enable automatic feedback.')),
              SettingsRow(
                  icon: LucideIcons.lock,
                  title: s.privacyPolicy,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) =>
                          const LegalPage(kind: LegalKind.privacy)))),
            ]),
        SettingsGroup(title: context.tr('Dữ liệu', 'Data'), children: [
          SettingsRow(
              icon: LucideIcons.download,
              title: context.tr(
                  'Xuất lịch sử tập luyện', 'Export workout history'),
              subtitle: context.tr(
                  'Tạo CSV hoặc JSON trên thiết bị',
                  'Create CSV or JSON on this device'),
              onTap: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const ExportDataSheet())),
          FutureBuilder<int>(
              future: _count,
              builder: (context, snapshot) => SettingsRow(
                    icon: LucideIcons.trash2,
                    title: s.clearHistory,
                    destructive: true,
                    subtitle: context.tr(
                        '${snapshot.data ?? 0} buổi tập · bao gồm hiệu chỉnh đã lưu',
                        '${snapshot.data ?? 0} sessions · includes saved calibration'),
                    onTap: _deleteData,
                  )),
        ]),
        SettingsGroup(title: context.tr('Về app', 'About'), children: [
          SettingsRow(
              icon: LucideIcons.messageCircle,
              title: context.tr('Gửi góp ý', 'Send feedback'),
              onTap: _contact),
          SettingsRow(
              icon: LucideIcons.star,
              title: context.tr('Đánh giá app', 'Rate the app'),
              subtitle: Platform.isIOS && AppLinks.appStoreId.isEmpty
                  ? context.tr('Chờ phát hành trên App Store',
                      'Awaiting App Store release')
                  : null,
              onTap: _review),
          SettingsRow(
              icon: LucideIcons.info,
              title: s.versionLabel,
              trailing: Text('1.0.0 (2)', style: TextStyle(color: p.text2))),
          SettingsRow(
              icon: LucideIcons.fileText,
              title: s.termsOfUse,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const LegalPage(kind: LegalKind.terms)))),
          SettingsRow(
              icon: LucideIcons.heart,
              title: s.healthNotice,
              onTap: () => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                        title: Text(s.trainSafelyTitle),
                        content: SingleChildScrollView(
                            child: Text(s.trainSafelyBody)),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(context.tr('Đóng', 'Close')))
                        ],
                      ))),
        ]),
        Text(LegalConfig.appName.toUpperCase(),
            textAlign: TextAlign.center,
            style: AppTypography.title20.copyWith(color: p.text3)),
      ],
    )));
  }
}

class _DeleteDataDialog extends StatefulWidget {
  const _DeleteDataDialog();
  @override
  State<_DeleteDataDialog> createState() => _DeleteDataDialogState();
}

class _DeleteDataDialogState extends State<_DeleteDataDialog> {
  String _value = '';
  @override
  Widget build(BuildContext context) {
    final valid = context.language == AppLanguage.vi
        ? const ['XÓA', 'XOA'].contains(_value.trim().toUpperCase())
        : _value.trim().toUpperCase() == 'DELETE';
    return AlertDialog(
      icon: Icon(LucideIcons.trash2, color: context.palette.danger),
      title: Text(context.s.clearHistoryConfirm),
      content: SingleChildScrollView(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(context.tr(
                'Buổi tập, nhận xét AI và hiệu chỉnh trên máy sẽ bị xóa. Không thể hoàn tác.',
                'Sessions, AI feedback and calibration on this device will be deleted. This cannot be undone.')),
            const SizedBox(height: 20),
            TextField(
                key: const Key('delete-confirmation'),
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                    labelText: context.tr(
                        'Gõ XÓA để xác nhận', 'Type DELETE to confirm')),
                onChanged: (v) => setState(() => _value = v)),
          ])),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.s.cancel)),
        FilledButton(
            key: const Key('delete-data'),
            style:
                FilledButton.styleFrom(backgroundColor: context.palette.danger),
            onPressed: valid ? () => Navigator.pop(context, true) : null,
            child: Text(context.tr('Xóa vĩnh viễn', 'Delete permanently'))),
      ],
    );
  }
}

class CalibrationSettingsPage extends StatefulWidget {
  const CalibrationSettingsPage({super.key});
  @override
  State<CalibrationSettingsPage> createState() =>
      _CalibrationSettingsPageState();
}

class _CalibrationSettingsPageState extends State<CalibrationSettingsPage> {
  final _store = const CalibrationStore();
  late Future<Map<String, CalibrationSnapshot?>> _snapshots;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _snapshots = _load();
  }

  Future<Map<String, CalibrationSnapshot?>> _load() async => {
        for (final profile in allExercises)
          profile.id: await _store.load(profile.id),
      };
  Future<void> _reset(ExerciseProfile profile) async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title:
                  Text(context.tr('Đặt lại hiệu chỉnh?', 'Reset calibration?')),
              content: Text(profile.localizedName(context.s)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(context.s.cancel)),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(context.tr('Đặt lại', 'Reset'))),
              ],
            ));
    if (yes != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _store.reset(profile.id);
      if (!mounted) return;
      setState(() {
        _snapshots = _load();
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.tr(
              'Đã đặt lại. Bấm Hiệu chỉnh ở màn tập để đo lại biên độ.',
              'Reset. Use Calibrate on the workout screen to measure your range again.'))));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(context.tr('Không thể đặt lại. Hãy thử lại.',
                'Could not reset. Please retry.'))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(context.tr('Hiệu chỉnh biên độ', 'Calibration'))),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Text(
              context.tr(
                  'Đặt lại khi đổi góc máy hoặc chỗ tập. Trong màn tập, bấm Hiệu chỉnh, làm vài rep tự nhiên rồi bấm hoàn tất.',
                  'Reset after changing the camera angle or workout location. In the workout screen, tap Calibrate, perform a few natural reps, then finish calibration.'),
              style: TextStyle(color: context.palette.text2)),
          const SizedBox(height: 24),
          FutureBuilder<Map<String, CalibrationSnapshot?>>(
              future: _snapshots,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return TextButton(
                      onPressed: () {
                        setState(() {
                          _snapshots = _load();
                        });
                      },
                      child: Text(context.tr('Thử lại', 'Retry')));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return SettingsGroup(
                    title:
                        context.tr('Đã lưu trên máy', 'Saved on this device'),
                    children: [
                      for (final profile in allExercises)
                        SettingsRow(
                            icon: LucideIcons.ruler,
                            title: profile.localizedName(context.s),
                            subtitle: snapshot.data![profile.id] == null
                                ? context.tr(
                                    'Chưa hiệu chỉnh', 'Not calibrated')
                                : context.tr(
                                    'Đã lưu hiệu chỉnh', 'Calibration saved'),
                            trailing: TextButton(
                                onPressed:
                                    _busy || snapshot.data![profile.id] == null
                                        ? null
                                        : () => _reset(profile),
                                child: Text(context.tr('Đặt lại', 'Reset')))),
                    ]);
              }),
        ]),
      );
}
