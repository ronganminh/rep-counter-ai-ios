import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/l10n.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_feedback.dart';
import '../../../widgets/product_ui.dart';
import '../application/plan_repository.dart';
import '../application/reminder_service.dart';
import '../domain/reminder_planner.dart';
import 'plan_copy.dart';

/// P10-02 / P10-03 workout reminders: an in-app explanation before the OS
/// prompt, the denied state (planning keeps working), reminder time, quiet
/// hours and the next reminders. Reminders follow planned sessions only:
/// never recovery days, never a session already done, missed or skipped.
class ReminderSettingsPage extends StatefulWidget {
  const ReminderSettingsPage(
      {super.key, required this.view, this.service, this.repository});

  final PlanView view;
  final ReminderService? service;
  final PlanRepository? repository;

  @override
  State<ReminderSettingsPage> createState() => _ReminderSettingsPageState();
}

class _ReminderSettingsPageState extends State<ReminderSettingsPage> {
  late final _service = widget.service ?? ReminderService();
  ReminderPrefs? _prefs;
  ReminderPermission _permission = ReminderPermission.unknown;
  List<PlannedReminder> _upcoming = const [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await _service.prefs();
    final permission = await _service.permission();
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _permission = permission;
      _upcoming = ReminderPlanner.plan(
          widget.view.plan, widget.view.sessions, prefs, DateTime.now());
    });
  }

  Future<void> _save(ReminderPrefs prefs) async {
    setState(() => _busy = true);
    await _service.savePrefs(prefs, widget.view,
        locale: Localizations.localeOf(context));
    if (!mounted) return;
    setState(() => _busy = false);
    await _load();
  }

  Future<void> _enable() async {
    final permission = await _service.requestPermission();
    if (!mounted) return;
    setState(() => _permission = permission);
    // Saved either way: if the OS says no, nothing is shown, and planning
    // and recording never depend on it.
    await _save(_prefs!.copyWith(enabled: true));
  }

  Future<void> _pickTime(int current, ValueChanged<int> onPicked) async {
    final t = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60));
    if (t != null) onPicked(t.hour * 60 + t.minute);
  }

  String _time(int minute) =>
      TimeOfDay(hour: minute ~/ 60, minute: minute % 60).format(context);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final prefs = _prefs;
    return Scaffold(
      appBar:
          AppBar(title: Text(context.tr('Lời nhắc tập', 'Workout reminders'))),
      body: SafeArea(
        child: prefs == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: prefs.enabled ? _settings(prefs) : _intro(l)),
      ),
    );
  }

  List<Widget> _intro(AppLocalizations l) => [
        const Icon(LucideIcons.bellRing, size: 40, color: AppColors.accent),
        const SizedBox(height: 16),
        Text(l.notifPrePermTitle, style: AppTypography.title22),
        const SizedBox(height: 8),
        Text(l.notifPrePermBody,
            key: const Key('reminder-intro-body'),
            style: AppTypography.body14.copyWith(color: AppColors.text2)),
        const SizedBox(height: 12),
        Text(
            context.tr(
                'Thông báo là tùy chọn. Kế hoạch và việc ghi buổi tập vẫn hoạt động đầy đủ khi không bật.',
                'Notifications are optional. Plans and workout recording work fully without them.'),
            style: AppTypography.body14.copyWith(color: AppColors.text2)),
        const SizedBox(height: 24),
        AppButton(
            key: const Key('reminder-enable'),
            label: l.notifTurnReminders,
            icon: LucideIcons.bell,
            loading: _busy,
            onPressed: _enable),
        const SizedBox(height: 8),
        AppButton(
            key: const Key('reminder-not-now'),
            label: context.tr('Để sau', 'Not now'),
            variant: AppButtonVariant.ghost,
            onPressed: () => Navigator.of(context).pop()),
      ];

  List<Widget> _settings(ReminderPrefs prefs) {
    final l = context.l10n;
    return [
      if (_permission == ReminderPermission.denied) ...[
        AppBanner(
            key: const Key('reminder-denied'),
            tone: AppBannerTone.warn,
            title: l.notifDenied,
            body: context.tr(
                'Bạn có thể bật trong cài đặt hệ thống. Kế hoạch và buổi tập vẫn hoạt động bình thường.',
                'You can turn them on in system settings. Your plan and workouts work as usual.')),
        const SizedBox(height: 12),
      ],
      SwitchListTile(
        key: const Key('reminder-toggle'),
        contentPadding: EdgeInsets.zero,
        title:
            Text(context.tr('Nhắc vào ngày tập', 'Remind me on training days')),
        subtitle: Text(widget.view.plan.name),
        value: prefs.enabled,
        onChanged: _busy ? null : (v) => _save(prefs.copyWith(enabled: v)),
      ),
      ListTile(
        key: const Key('reminder-time'),
        contentPadding: EdgeInsets.zero,
        title: Text(l.notifReminderTime),
        trailing: Text(_time(prefs.minuteOfDay), style: AppTypography.row15),
        onTap: () => _pickTime(
            prefs.minuteOfDay, (m) => _save(prefs.copyWith(minuteOfDay: m))),
      ),
      SwitchListTile(
        key: const Key('reminder-quiet'),
        contentPadding: EdgeInsets.zero,
        title: Text(l.notifQuietTitle),
        subtitle: Text('${_time(prefs.quietStart)} – ${_time(prefs.quietEnd)}'),
        value: prefs.quietHours,
        onChanged: (v) => _save(prefs.copyWith(quietHours: v)),
      ),
      if (prefs.quietHours && prefs.isQuiet(prefs.minuteOfDay))
        Text(
            context.tr(
                'Giờ nhắc nằm trong giờ yên lặng: lời nhắc đến lúc ${_time(prefs.quietEnd)}.',
                'Your reminder time is inside quiet hours: reminders arrive at ${_time(prefs.quietEnd)} instead.'),
            style: AppTypography.caption12.copyWith(color: AppColors.text2)),
      const SizedBox(height: 16),
      SectionLabel(context.tr('Sắp tới', 'Coming up')),
      if (_upcoming.isEmpty)
        Text(context.tr('Chưa có lời nhắc nào trong 14 ngày tới.',
            'No reminders in the next 14 days.'))
      else
        for (final r in _upcoming.take(7))
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
                '${context.dayLabel(r.date)} · ${_time(r.fireAt.hour * 60 + r.fireAt.minute)} · ${context.templateName(widget.view.plan, r.templateId)}',
                key: Key('reminder-${r.date.toIso()}'),
                style: AppTypography.body14),
          ),
      const SizedBox(height: 8),
      Text(
          context.tr(
              'Một lời nhắc cho mỗi buổi đã lên lịch. Không nhắc ngày phục hồi, buổi đã xong, đã bỏ lỡ hay đã bỏ qua. Dời buổi thì lời nhắc đi theo.',
              'One reminder per planned session. None on recovery days or for sessions already done, missed or skipped. A moved session takes its reminder along.'),
          style: AppTypography.caption12.copyWith(color: AppColors.text2)),
    ];
  }
}
