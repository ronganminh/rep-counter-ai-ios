import 'package:flutter/foundation.dart';

import 'local_date.dart';
import 'workout_plan.dart';

/// NT-1 reminder settings. Off until the user turns them on (the OS
/// permission is asked only then, never at launch). Defaults follow Phase
/// 10: 5:30 PM, quiet hours 10:00 PM – 7:00 AM.
@immutable
class ReminderPrefs {
  const ReminderPrefs({
    this.enabled = false,
    this.minuteOfDay = 17 * 60 + 30,
    this.quietHours = true,
    this.quietStart = 22 * 60,
    this.quietEnd = 7 * 60,
  });

  final bool enabled;
  final int minuteOfDay;
  final bool quietHours;
  final int quietStart, quietEnd;

  ReminderPrefs copyWith(
          {bool? enabled,
          int? minuteOfDay,
          bool? quietHours,
          int? quietStart,
          int? quietEnd}) =>
      ReminderPrefs(
        enabled: enabled ?? this.enabled,
        minuteOfDay: minuteOfDay ?? this.minuteOfDay,
        quietHours: quietHours ?? this.quietHours,
        quietStart: quietStart ?? this.quietStart,
        quietEnd: quietEnd ?? this.quietEnd,
      );

  /// Whether [minute] (0…1439) falls in quiet hours, which may wrap midnight.
  bool isQuiet(int minute) {
    if (!quietHours || quietStart == quietEnd) return false;
    return quietStart < quietEnd
        ? minute >= quietStart && minute < quietEnd
        : minute >= quietStart || minute < quietEnd;
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'minute': minuteOfDay,
        'quiet': quietHours,
        'quiet_start': quietStart,
        'quiet_end': quietEnd,
      };

  factory ReminderPrefs.fromJson(Map<String, dynamic> j) {
    int minute(Object? v, int fallback) {
      final m = (v as num?)?.toInt();
      return m == null || m < 0 || m >= 1440 ? fallback : m;
    }

    const d = ReminderPrefs();
    return ReminderPrefs(
      enabled: j['enabled'] as bool? ?? false,
      minuteOfDay: minute(j['minute'], d.minuteOfDay),
      quietHours: j['quiet'] as bool? ?? true,
      quietStart: minute(j['quiet_start'], d.quietStart),
      quietEnd: minute(j['quiet_end'], d.quietEnd),
    );
  }
}

/// One local notification to schedule, tied to a planned session.
@immutable
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.sessionId,
    required this.date,
    required this.fireAt,
    required this.templateId,
  });

  /// Stable notification id derived from the session id: moving or
  /// re-syncing a session replaces its reminder instead of adding one.
  final int id;
  final String sessionId;
  final LocalDate date;

  /// Local wall-clock time on this device.
  final DateTime fireAt;
  final String templateId;

  /// Payload stored with the notification, used to find our reminders.
  String get payload => '${ReminderPlanner.payloadPrefix}$sessionId';

  @override
  bool operator ==(Object other) =>
      other is PlannedReminder &&
      other.id == id &&
      other.sessionId == sessionId &&
      other.fireAt == fireAt;

  @override
  int get hashCode => Object.hash(id, sessionId, fireAt);
}

class ReminderPlanner {
  const ReminderPlanner._();

  static const payloadPrefix = 'plan-session:';

  /// iOS keeps at most 64 pending notifications: plan two weeks ahead and
  /// re-sync on every app open, plan change or settings change.
  static const horizonDays = 14;

  /// 31-bit FNV-1a of the session id (positive, fits Android's int ids).
  static int notificationId(String sessionId) {
    var h = 0x811c9dc5;
    for (final c in sessionId.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h & 0x7fffffff;
  }

  /// The reminders that should exist now: one per upcoming (scheduled)
  /// session of an active plan, on its day, at the reminder time moved out
  /// of quiet hours, and only if still in the future. Completed, partial,
  /// missed, skipped and cancelled sessions and recovery days get none.
  static List<PlannedReminder> plan(
    WorkoutPlan? plan,
    List<PlannedSession> sessions,
    ReminderPrefs prefs,
    DateTime now,
  ) {
    if (plan == null || !prefs.enabled || plan.status != PlanStatus.active) {
      return const [];
    }
    final today = LocalDate.of(now);
    final last = today.addDays(horizonDays - 1);
    final out = <PlannedReminder>[];
    final days = <LocalDate>{};
    for (final s in sessions) {
      final d = s.scheduledLocalDate;
      if (s.planId != plan.id ||
          !s.isUpcoming ||
          d.isBefore(today) ||
          d.isAfter(last) ||
          plan.dayKind(d) == DayKind.recovery ||
          !days.add(d)) {
        continue;
      }
      var minute = prefs.minuteOfDay;
      // Inside quiet hours: arrive when they end (same day) instead.
      if (prefs.isQuiet(minute)) minute = prefs.quietEnd;
      final fireAt =
          DateTime(d.year, d.month, d.day, minute ~/ 60, minute % 60);
      if (!fireAt.isAfter(now)) continue;
      out.add(PlannedReminder(
        id: notificationId(s.id),
        sessionId: s.id,
        date: d,
        fireAt: fireAt,
        templateId: s.workoutTemplateId,
      ));
    }
    out.sort((a, b) => a.fireAt.compareTo(b.fireAt));
    return out;
  }
}
