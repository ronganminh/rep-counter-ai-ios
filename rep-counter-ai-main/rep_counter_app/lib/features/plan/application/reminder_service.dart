import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/i18n/app_strings.dart';
import '../../../exercise.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/local_date.dart';
import '../domain/reminder_copy.dart';
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

/// The lines chosen for upcoming reminders and when each was last used
/// (NT-2 rotation), kept on the phone.
class ReminderCopyStore {
  static const key = 'reminder_copy_v1';

  Future<ReminderCopyState> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(key);
    if (raw == null) return const ReminderCopyState();
    try {
      return ReminderCopyState.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const ReminderCopyState();
    }
  }

  Future<void> save(ReminderCopyState state) async {
    await (await SharedPreferences.getInstance())
        .setString(key, jsonEncode(state.toJson()));
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
    ReminderCopyStore? copy,
    DateTime Function()? now,
  })  : _platform = platform ?? LocalNotificationsPlatform(),
        _prefs = prefs ?? ReminderPrefsStore(),
        _copy = copy ?? ReminderCopyStore(),
        _now = now ?? DateTime.now;

  final ReminderPlatform _platform;
  final ReminderPrefsStore _prefs;
  final ReminderCopyStore _copy;
  final DateTime Function() _now;

  /// The service's clock. Screens that list upcoming reminders use it too,
  /// so they agree with what [savePrefs] schedules.
  DateTime now() => _now();

  Future<ReminderPrefs> prefs() => _prefs.load();

  Future<ReminderPermission> permission() async {
    try {
      return await _platform.permission();
    } catch (_) {
      return ReminderPermission.unknown;
    }
  }

  /// Set once the OS notification prompt has been shown from the app, so a
  /// later visit shows the neutral "notifications are off" notice instead of
  /// the explanation (iOS never shows the prompt twice).
  static const askedKey = 'reminder_permission_asked_v1';

  Future<bool> permissionAsked() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(askedKey) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<ReminderPermission> requestPermission() async {
    ReminderPermission result;
    try {
      result = await _platform.requestPermission();
    } catch (_) {
      result = ReminderPermission.denied;
    }
    try {
      await (await SharedPreferences.getInstance()).setBool(askedKey, true);
    } catch (_) {/* Next visit shows the explanation again. */}
    return result;
  }

  Future<void> savePrefs(ReminderPrefs prefs, PlanView? view,
      {Locale? locale}) async {
    await _prefs.save(prefs);
    await sync(view, locale: locale);
  }

  /// Returns the reminders that are scheduled after the sync.
  ///
  /// [name], when known, lets the friendly lines greet the user by name.
  Future<List<PlannedReminder>> sync(PlanView? view,
      {Locale? locale, String? name}) async {
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
      final lines = prefs.friendly
          ? await _friendly(view!, wanted, prefs, l, name)
          : const <String, String>{};
      for (final r in wanted) {
        final plan = view!.plan;
        final title = plan.template(r.templateId)?.name ?? plan.name;
        await _platform.schedule(r, l.notifReminderTitle(title),
            lines[r.sessionId] ?? _body(view, r, l));
      }
      return wanted;
    } catch (_) {
      // No permission, plugin unavailable, …: plans and workouts carry on.
      return const [];
    }
  }

  /// NT-2 layer 1: a warm line per reminder, by situation, not repeated
  /// within 14 days. Any failure falls back to the neutral line.
  Future<Map<String, String>> _friendly(PlanView view,
      List<PlannedReminder> wanted, ReminderPrefs prefs, AppLocalizations l,
      String? name) async {
    try {
      final now = _now();
      final today = LocalDate.of(now);
      final streak = _streak(view, today);
      final slots = [
        for (final (i, r) in wanted.indexed)
          ReminderSlot(
              r.sessionId,
              r.date,
              ReminderCopy.situation(
                  plan: view.plan,
                  sessions: view.sessions,
                  today: today,
                  date: r.date,
                  minuteOfDay: r.fireAt.hour * 60 + r.fireAt.minute,
                  first: i == 0,
                  streak: streak))
      ];
      final hasName = name != null && name.trim().isNotEmpty;
      final (keys, state) = ReminderCopy.assign(slots, await _copy.load(),
          hasName: hasName, today: today);
      await _copy.save(state);
      final vi = l.localeName.startsWith('vi');
      final s = vi ? S.vi : S.en;
      String time(DateTime t) {
        final mm = t.minute.toString().padLeft(2, '0');
        if (vi) return '${t.hour}:$mm';
        final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
        return '$h:$mm ${t.hour < 12 ? 'AM' : 'PM'}';
      }
      return {
        for (final r in wanted)
          if (keys[r.sessionId] != null)
            r.sessionId: ReminderCopy.text(
                l, keys[r.sessionId]!, _vars(view, r, s, time, streak, name)),
      };
    } catch (_) {
      return const {};
    }
  }

  static ReminderVars _vars(PlanView view, PlannedReminder r, S s,
      String Function(DateTime) time, int streak, String? name) {
    final session = view.sessions.firstWhere((x) => x.id == r.sessionId);
    final targets = session.exerciseTargets;
    return ReminderVars(
      name: name?.trim() ?? '',
      exercise: targets.isEmpty ? '' : exerciseNameFor(targets.first.exerciseId, s),
      time: time(r.fireAt),
      streak: '$streak',
      sets: '${targets.fold(0, (sum, t) => sum + t.sets)}',
    );
  }

  /// Days in a row with a saved workout, up to today (or yesterday).
  static int _streak(PlanView view, LocalDate today) {
    final days = {
      for (final w in view.workouts.values)
        if (w.reps > 0 || w.durationSeconds > 0) w.date
    };
    var cursor = days.contains(today) ? today : today.addDays(-1);
    var n = 0;
    while (days.contains(cursor)) {
      n++;
      cursor = cursor.addDays(-1);
    }
    return n;
  }

  static String _body(PlanView view, PlannedReminder r, AppLocalizations l) {
    final session = view.sessions.firstWhere((s) => s.id == r.sessionId);
    final sets = session.exerciseTargets.fold(0, (sum, t) => sum + t.sets);
    // About 2 min per set (work + rest), rounded to 5 min.
    final minutes = ((sets * 2 / 5).ceil() * 5).clamp(5, 120);
    return l.notifReminderBody(minutes);
  }
}
