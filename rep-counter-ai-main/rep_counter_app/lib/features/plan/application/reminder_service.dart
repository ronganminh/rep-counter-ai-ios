import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../../l10n/app_localizations.dart';
import '../domain/reminder_planner.dart';
import 'plan_repository.dart';

enum ReminderPermission { granted, denied, unknown }

/// The OS side of reminders, behind an interface so the rules are tested
/// without a device.
abstract interface class ReminderPlatform {
  Future<ReminderPermission> permission();

  /// Shows the OS prompt (only after the in-app explanation).
  Future<ReminderPermission> requestPermission();

  /// Payloads of pending notifications by id.
  Future<Map<int, String?>> pending();
  Future<void> schedule(PlannedReminder reminder, String title, String body);
  Future<void> cancel(int id);
}

/// flutter_local_notifications, scheduled at absolute instants (UTC), so no
/// time-zone database lookup of the device zone is needed; a time-zone
/// change is handled by the next sync, which re-plans in local time.
class LocalNotificationsPlatform implements ReminderPlatform {
  LocalNotificationsPlatform([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _ready;

  static final _opened = StreamController<String>.broadcast();

  /// Payloads of reminders the user tapped while the app was running
  /// (N-2a). Every instance initialises the plugin with the same callback.
  static Stream<String> get opened => _opened.stream;

  /// The payload of the reminder that launched the app, if any.
  Future<String?> launchPayload() async {
    await _init();
    final details = await _plugin.getNotificationAppLaunchDetails();
    return details?.didNotificationLaunchApp == true
        ? details!.notificationResponse?.payload
        : null;
  }

  static const _channel = AndroidNotificationDetails(
    'workout_reminders',
    'Workout reminders',
    channelDescription: 'One reminder per planned workout session',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  Future<void> _init() => _ready ??= () async {
        tzdata.initializeTimeZones();
        await _plugin.initialize(
          settings: const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher'),
            // Permission is asked from the reminder settings, never at launch.
            iOS: DarwinInitializationSettings(
                requestAlertPermission: false,
                requestBadgePermission: false,
                requestSoundPermission: false),
          ),
          onDidReceiveNotificationResponse: (response) {
            final payload = response.payload;
            if (payload != null) _opened.add(payload);
          },
        );
      }();

  @override
  Future<ReminderPermission> permission() async {
    await _init();
    if (defaultTargetPlatform == TargetPlatform.android) {
      final ok = await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.areNotificationsEnabled();
      return ok == null
          ? ReminderPermission.unknown
          : ok
              ? ReminderPermission.granted
              : ReminderPermission.denied;
    }
    final ios = await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.checkPermissions();
    if (ios == null) return ReminderPermission.unknown;
    return ios.isEnabled
        ? ReminderPermission.granted
        : ReminderPermission.unknown;
  }

  @override
  Future<ReminderPermission> requestPermission() async {
    await _init();
    bool? ok;
    if (defaultTargetPlatform == TargetPlatform.android) {
      ok = await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } else {
      ok = await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: false, sound: true);
    }
    return ok == true ? ReminderPermission.granted : ReminderPermission.denied;
  }

  @override
  Future<Map<int, String?>> pending() async {
    await _init();
    return {
      for (final r in await _plugin.pendingNotificationRequests())
        r.id: r.payload
    };
  }

  @override
  Future<void> schedule(
      PlannedReminder reminder, String title, String body) async {
    await _init();
    await _plugin.zonedSchedule(
      id: reminder.id,
      scheduledDate: tz.TZDateTime.from(reminder.fireAt.toUtc(), tz.UTC),
      notificationDetails: const NotificationDetails(
          android: _channel, iOS: DarwinNotificationDetails()),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: title,
      body: body,
      payload: reminder.payload,
    );
  }

  @override
  Future<void> cancel(int id) async {
    await _init();
    await _plugin.cancel(id: id);
  }
}

class ReminderPrefsStore {
  static const key = 'reminder_prefs_v1';

  Future<ReminderPrefs> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(key);
    if (raw == null) return const ReminderPrefs();
    try {
      return ReminderPrefs.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const ReminderPrefs();
    }
  }

  Future<void> save(ReminderPrefs prefs) async {
    await (await SharedPreferences.getInstance())
        .setString(key, jsonEncode(prefs.toJson()));
  }
}

/// Keeps the phone's pending reminders equal to what the plan needs now.
/// Idempotent: our reminders that are no longer wanted (session done,
/// missed, skipped, moved, plan paused or ended, reminders off) are
/// cancelled, and wanted ones are (re)scheduled under their stable ids, so
/// a retry or a second sync never leaves a duplicate. Failures never block
/// planning or recording workouts.
class ReminderService {
  ReminderService({
    ReminderPlatform? platform,
    ReminderPrefsStore? prefs,
    DateTime Function()? now,
  })  : _platform = platform ?? LocalNotificationsPlatform(),
        _prefs = prefs ?? ReminderPrefsStore(),
        _now = now ?? DateTime.now;

  final ReminderPlatform _platform;
  final ReminderPrefsStore _prefs;
  final DateTime Function() _now;

  Future<ReminderPrefs> prefs() => _prefs.load();

  Future<ReminderPermission> permission() async {
    try {
      return await _platform.permission();
    } catch (_) {
      return ReminderPermission.unknown;
    }
  }

  Future<ReminderPermission> requestPermission() async {
    try {
      return await _platform.requestPermission();
    } catch (_) {
      return ReminderPermission.denied;
    }
  }

  Future<void> savePrefs(ReminderPrefs prefs, PlanView? view,
      {Locale? locale}) async {
    await _prefs.save(prefs);
    await sync(view, locale: locale);
  }

  /// Returns the reminders that are scheduled after the sync.
  Future<List<PlannedReminder>> sync(PlanView? view, {Locale? locale}) async {
    try {
      final prefs = await _prefs.load();
      final wanted = ReminderPlanner.plan(
          view?.plan, view?.sessions ?? const [], prefs, _now());
      final pending = await _platform.pending();
      final wantedIds = {for (final r in wanted) r.id};
      for (final e in pending.entries) {
        final ours =
            e.value?.startsWith(ReminderPlanner.payloadPrefix) ?? false;
        if (ours && !wantedIds.contains(e.key)) await _platform.cancel(e.key);
      }
      if (wanted.isEmpty) return wanted;
      final l = lookupAppLocalizations(locale ?? const Locale('en'));
      for (final r in wanted) {
        final plan = view!.plan;
        final name = plan.template(r.templateId)?.name ?? plan.name;
        await _platform.schedule(
            r, l.notifReminderTitle(name), _body(view, r, l));
      }
      return wanted;
    } catch (_) {
      // No permission, plugin unavailable, …: plans and workouts carry on.
      return const [];
    }
  }

  static String _body(PlanView view, PlannedReminder r, AppLocalizations l) {
    final session = view.sessions.firstWhere((s) => s.id == r.sessionId);
    final sets = session.exerciseTargets.fold(0, (sum, t) => sum + t.sets);
    // About 2 min per set (work + rest), rounded to 5 min.
    final minutes = ((sets * 2 / 5).ceil() * 5).clamp(5, 120);
    return l.notifReminderBody(minutes);
  }
}
