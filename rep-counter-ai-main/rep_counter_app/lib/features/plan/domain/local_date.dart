import 'package:flutter/foundation.dart';

/// A calendar day in the user's local calendar, without a time or zone
/// (PL-1). Planned sessions are stored as local dates, so a session planned
/// for Monday stays on Monday when the phone's time zone changes; which day
/// is "today" is decided by the device's current local clock.
@immutable
class LocalDate implements Comparable<LocalDate> {
  factory LocalDate(int year, int month, int day) =>
      LocalDate._(DateTime.utc(year, month, day));

  const LocalDate._(this._utc);

  /// The local calendar day of [instant] as seen by this device.
  factory LocalDate.of(DateTime instant) {
    final local = instant.toLocal();
    return LocalDate(local.year, local.month, local.day);
  }

  /// The calendar day of [instant] at a fixed UTC [offset] (tests and
  /// time-zone change handling).
  factory LocalDate.atOffset(DateTime instant, Duration offset) {
    final shifted = instant.toUtc().add(offset);
    return LocalDate(shifted.year, shifted.month, shifted.day);
  }

  /// Parses `YYYY-MM-DD`.
  factory LocalDate.parse(String iso) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(iso);
    if (m == null) throw FormatException('Invalid local date: $iso');
    final date =
        LocalDate(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
    if (date.toIso() != iso) throw FormatException('Invalid local date: $iso');
    return date;
  }

  // Midnight UTC is only a carrier: arithmetic in UTC never meets a DST gap.
  final DateTime _utc;

  int get year => _utc.year;
  int get month => _utc.month;
  int get day => _utc.day;

  /// [DateTime.monday] (1) … [DateTime.sunday] (7).
  int get weekday => _utc.weekday;

  LocalDate addDays(int days) => LocalDate._(_utc.add(Duration(days: days)));

  int daysUntil(LocalDate other) => other._utc.difference(_utc).inDays;

  /// The Monday of this date's week.
  LocalDate get startOfWeek => addDays(1 - weekday);

  bool isBefore(LocalDate other) => _utc.isBefore(other._utc);
  bool isAfter(LocalDate other) => _utc.isAfter(other._utc);

  /// Local midnight at the start of this day on this device.
  DateTime get startLocal => DateTime(year, month, day);

  String toIso() => '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  @override
  int compareTo(LocalDate other) => _utc.compareTo(other._utc);

  @override
  bool operator ==(Object other) => other is LocalDate && other._utc == _utc;

  @override
  int get hashCode => _utc.hashCode;

  @override
  String toString() => toIso();
}
