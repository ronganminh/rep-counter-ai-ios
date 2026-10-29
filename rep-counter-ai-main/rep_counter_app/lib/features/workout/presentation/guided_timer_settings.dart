import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/l10n.dart';
import '../../../core/services/training_preferences.dart';
import '../../../widgets/product_ui.dart';

/// X-2: Settings › Guided timer. Spoken cues and keeping the screen on
/// while the timer counts; both on by default.
class GuidedTimerSettingsGroup extends StatefulWidget {
  const GuidedTimerSettingsGroup(
      {super.key, this.load = TrainingPreferences.load});

  final Future<TrainingPreferences> Function() load;

  @override
  State<GuidedTimerSettingsGroup> createState() =>
      _GuidedTimerSettingsGroupState();
}

class _GuidedTimerSettingsGroupState extends State<GuidedTimerSettingsGroup> {
  TrainingPreferences? _prefs;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    widget.load().then((p) {
      if (mounted) setState(() => _prefs = p);
    }, onError: (Object _) {
      if (mounted) setState(() => _prefs = const TrainingPreferences());
    });
  }

  Future<void> _set({bool? voice, bool? keepAwake}) async {
    if (_busy || _prefs == null) return;
    setState(() => _busy = true);
    try {
      final next =
          await _prefs!.update(timerVoice: voice, timerKeepAwake: keepAwake);
      if (mounted) setState(() => _prefs = next);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(context.l10n.legacySettingsPageCouldNotSavePreferences)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _prefs;
    final enabled = p != null && !_busy;
    return SettingsGroup(title: context.l10n.commonHomeGuidedTimer, children: [
      SettingsRow(
          icon: LucideIcons.volume2,
          title: context.tr('Giọng đọc nhắc', 'Voice cues'),
          subtitle: context.tr(
              'Đọc set, nửa chặng, đếm ngược và nghỉ. Dùng giọng hệ thống theo ngôn ngữ app.',
              'Speaks sets, halfway, countdown and rest. System voice in the app language.'),
          trailing: Switch(
              key: const Key('timer-voice-setting'),
              value: p?.timerVoice ?? true,
              onChanged: enabled ? (v) => _set(voice: v) : null)),
      SettingsRow(
          icon: LucideIcons.sun,
          title: context.tr('Giữ màn hình sáng', 'Keep screen on'),
          subtitle: context.tr(
              'Chỉ khi đang đếm giờ; tắt khi tạm dừng hoặc rời màn.',
              'Only while the timer counts; off when paused or when you leave.'),
          trailing: Switch(
              key: const Key('timer-awake-setting'),
              value: p?.timerKeepAwake ?? true,
              onChanged: enabled ? (v) => _set(keepAwake: v) : null)),
    ]);
  }
}
