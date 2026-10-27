import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/config/build_info.dart';
import '../../core/services/app_links.dart';
import '../ai/ai_preferences.dart';
import '../ai/presentation/ai_consent.dart';
import '../history/export/export_data_sheet.dart';
import '../achievements/achievement_service.dart';
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
import 'voice_cadence_page.dart';
import '../../core/i18n/l10n.dart';

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
            content: Text(context.l10n.legacySettingsPageCouldNotSaveAi)));
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
                title: Text(context.l10n.legacySettingsPageSendFeedback),
                content: const SelectableText(LegalConfig.contactEmail),
                actions: [
                  TextButton(
                      onPressed: () async {
                        await Clipboard.setData(const ClipboardData(
                            text: LegalConfig.contactEmail));
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: Text(context.l10n.legacySettingsPageCopyEmail)),
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(context.l10n.navClose)),
                ]));
  }

  Future<void> _review() async {
    try {
      if (await AppLinks.review()) return;
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.tr(
            Platform.isIOS && !AppLinks.hasAppStoreListing
                ? 'Bản iOS chưa có trang App Store để đánh giá.'
                : 'Chưa mở được cửa hàng. Bản test cần tài khoản được mời.',
            Platform.isIOS && !AppLinks.hasAppStoreListing
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
      {bool? coachingEnabled,
      bool? voice,
      bool? haptics,
      bool? sound,
      bool? cues}) async {
    if (_preferenceBusy || _training == null) return;
    setState(() => _preferenceBusy = true);
    try {
      final value = await _training!
          .update(
              coachingEnabled: coachingEnabled,
              voice: voice,
              haptics: haptics,
              sound: sound,
              cues: cues);
      if (mounted) setState(() => _training = value);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(context.l10n.legacySettingsPageCouldNotSavePreferences)));
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
      await AchievementService.clearAll();
      if (!mounted) return;
      setState(() {
        _count = _loadCount();
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.s.historyCleared)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(context.l10n.legacySettingsPageCouldNotDeleteData)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final p = context.palette;
    return Scaffold(
        // Settings lives under Profile in v2 (N-1) and is pushed, so it needs
        // a back button there.
        appBar: (ModalRoute.of(context)?.canPop ?? false) ? AppBar() : null,
        body: SafeArea(
            child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Text(s.settings.toUpperCase(), style: AppTypography.display40),
        const SizedBox(height: 28),
        SettingsGroup(title: context.l10n.legacySettingsPageTraining, children: [
          SettingsRow(
              icon: LucideIcons.sparkles,
              title: context.l10n.legacySettingsPageLiveCoaching,
              subtitle: context.l10n.legacySettingsPageOffDefaultAppOnly,
              trailing: Switch(
                  key: const Key('live-coaching-setting'),
                  value: _training?.coachingEnabled ?? false,
                  onChanged: _training == null || _preferenceBusy
                      ? null
                      : (value) =>
                          _setTraining(coachingEnabled: value))),
          if (_training?.coachingEnabled ?? false) SettingsRow(
              icon: LucideIcons.volume2,
              title: context.l10n.legacySettingsPageSpeakRepCount,
              subtitle: context.l10n.legacySettingsPageSystemVoiceFollowsApp,
              onTap: _training == null
                  ? null
                  : () async {
                      await Navigator.of(context).push(MaterialPageRoute<void>(
                          builder: (_) => const VoiceCadencePage()));
                      if (mounted) await _loadTraining();
                    },
              trailing: Switch(
                  key: const Key('voice-setting'),
                  value: _training?.voice ?? true,
                  onChanged: _training == null || _preferenceBusy
                      ? null
                      : (value) => _setTraining(voice: value))),
          SettingsRow(
              icon: LucideIcons.vibrate,
              title: context.l10n.legacySettingsPageHapticFeedback,
              subtitle: context.l10n.legacySettingsPageCountdownRepsReachingGoal,
              trailing: Switch(
                  key: const Key('haptics-setting'),
                  value: _training?.haptics ?? true,
                  onChanged: _training == null || _preferenceBusy
                      ? null
                      : (value) => _setTraining(haptics: value))),
          SettingsRow(
              icon: LucideIcons.bell,
              title: context.tr('Âm báo set', 'Set sounds'),
              subtitle: context.l10n.legacySettingsPageSignalsSetStartEnd,
              trailing: Switch(
                  key: const Key('sound-setting'),
                  value: _training?.sound ?? false,
                  onChanged: _training == null || _preferenceBusy
                      ? null
                      : (v) => _setTraining(sound: v))),
          if (_training?.coachingEnabled ?? false) SettingsRow(
              icon: LucideIcons.messageCircle,
              title: context.l10n.legacyVoiceCadencePostureReminders,
              subtitle: context.l10n.legacySettingsPageUsesVoicePauseBetween,
              trailing: Switch(
                  key: const Key('cues-setting'),
                  value: _training?.cues ?? true,
                  onChanged: _training == null || _preferenceBusy
                      ? null
                      : (v) => _setTraining(cues: v))),
          SettingsRow(
              icon: LucideIcons.ruler,
              title: context.l10n.legacySettingsPageResetCalibration,
              subtitle: context.l10n.legacySettingsPageEachExercise,
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
            title: context.l10n.legacySettingsPageAiPrivacy,
            children: [
              SettingsRow(
                  icon: LucideIcons.sparkles,
                  title: context.l10n.legacySettingsPageAutomaticWorkoutFeedback,
                  subtitle: context.l10n.legacySettingsPageEnabledOnlyConsentSend,
                  trailing: Switch(
                      key: const Key('auto-ai-setting'),
                      value: _autoAi,
                      onChanged: _aiBusy ? null : _setAi)),
              SettingsRow(
                  icon: LucideIcons.shieldCheck,
                  title: context.l10n.legacySettingsPageProcessedDevice,
                  subtitle: context.l10n.legacySettingsPageCameraImagesStayPhone),
              SettingsRow(
                  icon: LucideIcons.lock,
                  title: s.privacyPolicy,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) =>
                          const LegalPage(kind: LegalKind.privacy)))),
            ]),
        SettingsGroup(title: context.l10n.legacySettingsPageData, children: [
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
          SettingsRow(
              icon: LucideIcons.download,
              title: context.tr(
                  'Xuất lịch sử tập luyện', 'Export workout history'),
              subtitle: context.l10n.legacySettingsPageCreateCsvJsonDevice,
              onTap: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const ExportDataSheet())),
        ]),
        SettingsGroup(title: context.l10n.legacySettingsPageAbout, children: [
          SettingsRow(
              key: const Key('settings-help-support'),
              icon: LucideIcons.lifeBuoy,
              title: context.l10n.fbHelpSupport,
              subtitle: LegalConfig.supportUrl,
              onTap: () => AppLinks.open(LegalConfig.supportUrl)),
          SettingsRow(
              icon: LucideIcons.messageCircle,
              title: context.l10n.legacySettingsPageSendFeedback,
              subtitle: LegalConfig.contactEmail,
              onTap: _contact),
          if (!Platform.isIOS || AppLinks.hasAppStoreListing)
            SettingsRow(
                icon: LucideIcons.star,
                title: context.l10n.legacySettingsPageRateApp,
                onTap: _review),
          SettingsRow(
              icon: LucideIcons.info,
              title: s.versionLabel,
              trailing: AppVersionText(style: TextStyle(color: p.text2))),
          SettingsRow(
              key: const Key('settings-website'),
              icon: LucideIcons.globe,
              // A URL needs no translation (settings stay on ARB strings).
              title: Uri.parse(LegalConfig.websiteUrl).host,
              subtitle: LegalConfig.websiteUrl,
              onTap: () => AppLinks.open(LegalConfig.websiteUrl)),
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
                              child: Text(context.l10n.navClose))
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
            Text(context.l10n.legacySettingsPageSessionsAiFeedbackCalibration),
            const SizedBox(height: 20),
            TextField(
                key: const Key('delete-confirmation'),
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                    labelText: context.l10n.legacySettingsPageTypeDeleteConfirm),
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
            child: Text(context.l10n.legacySettingsPageDeletePermanently)),
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
                  Text(context.l10n.legacySettingsPageResetCalibration2),
              content: Text(profile.localizedName(context.s)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(context.s.cancel)),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(context.l10n.legacySettingsPageReset)),
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
          content: Text(context.l10n.legacySettingsPageResetUseCalibrateWorkout)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(context.l10n.legacySettingsPageCouldNotResetPlease)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(context.l10n.legacySettingsPageCalibration)),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Text(
              context.l10n.legacySettingsPageResetAfterChangingCamera,
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
                      child: Text(context.l10n.resultAiRetry));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return SettingsGroup(
                    title:
                        context.l10n.legacySettingsPageSavedDevice,
                    children: [
                      for (final profile in allExercises)
                        SettingsRow(
                            icon: LucideIcons.ruler,
                            title: profile.localizedName(context.s),
                            subtitle: snapshot.data![profile.id] == null
                                ? context.l10n.legacySettingsPageNotCalibrated
                                : context.l10n.legacySettingsPageCalibrationSaved,
                            trailing: TextButton(
                                onPressed:
                                    _busy || snapshot.data![profile.id] == null
                                        ? null
                                        : () => _reset(profile),
                                child: Text(context.l10n.legacySettingsPageReset))),
                    ]);
              }),
        ]),
      );
}
