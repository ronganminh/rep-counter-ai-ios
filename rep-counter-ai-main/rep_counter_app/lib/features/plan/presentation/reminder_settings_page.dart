import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/i18n/l10n.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/permission_off_notice.dart';
import '../../../widgets/product_ui.dart';
import '../application/plan_repository.dart';
import '../application/reminder_service.dart';
import '../domain/reminder_planner.dart';
import 'plan_copy.dart';

/// P10-02 / P10-03 workout reminders: an in-app explanation before the OS
/// prompt, reminder time, quiet hours and the next reminders.
///
/// App Store 5.1.1(iv) (L-D24, rejections of 1.0.0 (6) and (7)):
/// - the explanation's only action is "Continue", which always shows the OS
///   prompt; no "Not now" and no back before it;
/// - "Don't Allow" in the OS prompt returns to the previous screen: no denied
///   banner, Settings is not opened, nothing is asked again;
/// - opening reminders later while notifications are off shows only the
///   neutral [PermissionOffNotice] (Back / Open Settings, equal buttons).
/// Planning and recording never depend on notifications. Reminders follow
/// planned sessions only: never recovery days, never a session already done,
/// missed or skipped.
class ReminderSettingsPage extends StatefulWidget {
  const ReminderSettingsPage(
      {super.key, required this.view, this.service, this.repository});

  final PlanView view;
  final ReminderService? service;
  final PlanRepository? repository;

  @override
  State<ReminderSettingsPage> createState() => _ReminderSettingsPageState();
}

class _ReminderSettingsPageState extends State<ReminderSettingsPage>
    with WidgetsBindingObserver {
  late final _service = widget.service ?? ReminderService();
  ReminderPrefs? _prefs;
  ReminderPermission _permission = ReminderPermission.unknown;
  List<PlannedReminder> _upcoming = const [];
  bool _busy = false;
  bool _asked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Back from Settings with the notice open: show the settings if
  /// notifications are on now. Nothing is asked.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _off) _load();
  }

  Future<void> _load() async {
    final prefs = await _service.prefs();
    final permission = await _service.permission();
    final asked = await _service.permissionAsked();
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _permission = permission;
      _asked = asked;
      _upcoming = ReminderPlanner.plan(
          widget.view.plan, widget.view.sessions, prefs, _service.now());
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
    setState(() => _busy = true);
    final permission = await _service.requestPermission();
    if (!mounted) return;
    if (permission != ReminderPermission.granted) {
      // "Don't Allow": back to the previous screen, nothing else.
      final nav = Navigator.of(context);
      if (nav.canPop()) {
        nav.pop();
      } else {
        setState(() {
          _busy = false;
          _asked = true;
          _permission = permission;
        });
      }
      return;
    }
    setState(() {
      _busy = false;
      _asked = true;
      _permission = permission;
    });
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

  /// Notifications are off and the app already asked (or reminders were
  /// turned on earlier): the neutral notice.
  bool get _off =>
      _prefs != null &&
      _permission != ReminderPermission.granted &&
      (_asked || _prefs!.enabled);

  /// The pre-permission explanation: the OS has not granted notifications
  /// and the app has never asked.
  bool get _beforePrompt =>
      _prefs != null && _permission != ReminderPermission.granted && !_off;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final prefs = _prefs;
    if (_off) {
      return PermissionOffNotice(
        keyPrefix: 'reminder-off',
        message: context.tr(
            'Thông báo của RepCoach đang tắt. Lời nhắc tập cần thông báo.',
            'Notifications are off for RepCoach. Workout reminders need notifications.'),
        backLabel: context.tr('Quay lại', 'Back'),
        settingsLabel: l.cameraOpenSettings,
        onBack: () => Navigator.of(context).maybePop(),
        onOpenSettings: () => openAppSettings(),
      );
    }
    final intro = _beforePrompt;
    return PopScope(
      canPop: !intro,
      child: Scaffold(
        appBar: AppBar(
            automaticallyImplyLeading: !intro,
            title: Text(context.tr('Lời nhắc tập', 'Workout reminders'))),
        body: SafeArea(
          child: prefs == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: intro ? _intro(l) : _settings(prefs)),
        ),
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
            label: l.commonContinue,
            loading: _busy,
            onPressed: _enable),
      ];

  List<Widget> _settings(ReminderPrefs prefs) {
    final l = context.l10n;
    return [
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
