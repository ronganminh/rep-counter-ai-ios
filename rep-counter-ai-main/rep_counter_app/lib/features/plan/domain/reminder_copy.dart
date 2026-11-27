import 'package:flutter/foundation.dart';

import '../../../l10n/app_localizations.dart';
import 'local_date.dart';
import 'workout_plan.dart';

part 'reminder_copy_catalog.dart';

/// NT-2 friendly reminders, layer 1 (L-D44): warm, short lines from the ARB
/// catalog (EN/VI), chosen by situation, offline and free. No line blames
/// or hurries; at most one emoji; every reminder is for a session the user
/// planned.
enum ReminderSituation {
  /// The plan's first session (nothing done, missed or skipped yet).
  firstSession,

  /// The next session after one or more missed or skipped sessions.
  afterMissed,

  /// The next session while the user has trained 7+ days in a row (takes
  /// precedence over [afterMissed]).
  streak,

  /// Saturday or Sunday.
  weekend,

  /// Reminder at 18:00 or later.
  evening,

  /// Everything else.
  regular,
}

@immutable
class ReminderLine {
  const ReminderLine(this.key, this.situation, {this.usesName = false});

  /// The ARB key (`reminderNudge…`).
  final String key;
  final ReminderSituation situation;

  /// Uses {name}: only offered when a name is known.
  final bool usesName;
}

/// The values a line may use. All are plain text already formatted for the
/// reminder's language.
@immutable
class ReminderVars {
  const ReminderVars({
    this.name = '',
    required this.exercise,
    required this.time,
    required this.streak,
    required this.sets,
  });

  final String name, exercise, time, streak, sets;
}

/// One reminder to word: its session, day and situation.
@immutable
class ReminderSlot {
  const ReminderSlot(this.sessionId, this.date, this.situation);
  final String sessionId;
  final LocalDate date;
  final ReminderSituation situation;
}

/// What was chosen before (kept on the phone): the line per session, and
/// the day each line was last used, so a line does not come back within
/// [ReminderCopy.noRepeatDays].
@immutable
class ReminderCopyState {
  const ReminderCopyState({this.assigned = const {}, this.used = const {}});

  /// sessionId → (line key, situation name).
  final Map<String, ({String key, String situation})> assigned;

  /// line key → last day it is used (past or planned).
  final Map<String, LocalDate> used;

  Map<String, dynamic> toJson() => {
        'assigned': {
          for (final e in assigned.entries)
            e.key: {'key': e.value.key, 'situation': e.value.situation}
        },
        'used': {for (final e in used.entries) e.key: e.value.toIso()},
      };

  factory ReminderCopyState.fromJson(Map<String, dynamic> j) {
    final assigned = <String, ({String key, String situation})>{};
    final a = j['assigned'];
    if (a is Map) {
      for (final e in a.entries) {
        final v = e.value;
        if (v is Map && v['key'] is String && v['situation'] is String) {
          assigned['${e.key}'] =
              (key: v['key'] as String, situation: v['situation'] as String);
        }
      }
    }
    final used = <String, LocalDate>{};
    final u = j['used'];
    if (u is Map) {
      for (final e in u.entries) {
        try {
          used['${e.key}'] = LocalDate.parse('${e.value}');
        } catch (_) {}
      }
    }
    return ReminderCopyState(assigned: assigned, used: used);
  }
}

abstract final class ReminderCopy {
  /// A line is not used again within this many days (NT-2).
  static const noRepeatDays = 14;

  /// NT-2 layer 2: AI lines longer than this are not used.
  static const aiMaxChars = 120;

  /// Words an AI line must not contain (blame, body talk, diet, promotion,
  /// links). Same list as `ai-request` (`schema.ts`, REMINDER_BANNED).
  static const banned = [
    'lazy', 'fat', 'ugly', 'pathetic', 'loser', 'shame', 'guilt', 'diet',
    'weight loss', 'calorie', 'burn fat', 'hurry', 'last chance', 'buy',
    'subscribe', 'premium', 'discount', 'http', 'www.', 'lười', 'béo', 'mập',
    'xấu', 'thảm hại', 'xấu hổ', 'tội lỗi', 'ăn kiêng', 'giảm cân', 'calo',
    'nhanh lên', 'cơ hội cuối', 'mua', 'đăng ký', 'khuyến mãi', 'giảm giá',
  ];

  static final _emoji = RegExp(
      r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}]',
      unicode: true);

  /// An AI-written line the app may show, or null (then layer 1 is used).
  static String? cleanAi(Object? v) {
    if (v is! String) return null;
    final t = v.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.isEmpty || t.length > aiMaxChars) return null;
    if (_emoji.allMatches(t).length > 1) return null;
    final lower = t.toLowerCase();
    if (banned.any(lower.contains)) return null;
    return t;
  }

  /// Streak needed for the streak lines.
  static const streakDays = 7;

  static List<ReminderLine> get lines => _lines;

  /// In Vietnamese the exercise name ("Hít đất") is lower case inside a
  /// sentence ("Khởi động rồi hít đất") and keeps its capital at the start
  /// of one. English keeps the name as it is.
  static String text(AppLocalizations l, String key, ReminderVars v) {
    if (!l.localeName.startsWith('vi') || v.exercise.isEmpty) {
      return _text(l, key, v);
    }
    const mark = '\u{E000}';
    final raw = _text(
        l,
        key,
        ReminderVars(
            name: v.name,
            exercise: mark,
            time: v.time,
            streak: v.streak,
            sets: v.sets));
    return raw.replaceAllMapped(RegExp(mark), (m) {
      final before = raw.substring(0, m.start).trimRight();
      final starts = before.isEmpty || _sentenceEnd.hasMatch(before);
      return starts ? capitalized(v.exercise) : midSentence(v.exercise);
    });
  }

  static final _sentenceEnd = RegExp(r'[.!?…]$');

  /// [name] with its first letter in lower case.
  static String midSentence(String name) =>
      name.isEmpty ? name : name[0].toLowerCase() + name.substring(1);

  /// [name] with its first letter in upper case.
  static String capitalized(String name) =>
      name.isEmpty ? name : name[0].toUpperCase() + name.substring(1);

  /// The situation of the reminder on [date] at [minuteOfDay]. Only the
  /// first upcoming reminder ([first]) can be "first session", "after
  /// missed" or "streak": later ones are worded by day and time.
  static ReminderSituation situation({
    required WorkoutPlan plan,
    required List<PlannedSession> sessions,
    required LocalDate today,
    required LocalDate date,
    required int minuteOfDay,
    required bool first,
    required int streak,
  }) {
    if (first) {
      final own = sessions.where((s) => s.planId == plan.id).toList();
      final started = own.any((s) =>
          s.state != SessionState.scheduled &&
          s.state != SessionState.cancelled);
      if (!started) return ReminderSituation.firstSession;
      // Training every day beats a missed plan session: celebrate the streak.
      if (streak >= streakDays) return ReminderSituation.streak;
      final past = own
          .where((s) =>
              s.scheduledLocalDate.isBefore(today) &&
              s.state != SessionState.cancelled)
          .toList()
        ..sort((a, b) => b.scheduledLocalDate.compareTo(a.scheduledLocalDate));
      if (past.isNotEmpty &&
          (past.first.state == SessionState.missed ||
              past.first.state == SessionState.skipped)) {
        return ReminderSituation.afterMissed;
      }
    }
    if (date.weekday >= DateTime.saturday) return ReminderSituation.weekend;
    if (minuteOfDay >= 18 * 60) return ReminderSituation.evening;
    return ReminderSituation.regular;
  }

  /// Chooses a line for every slot. A session keeps its line while its
  /// situation stays the same; a new line is one not used within
  /// [noRepeatDays] of the slot's day (by any other reminder), starting at
  /// a position derived from the session id so neighbours differ. When every
  /// line of a situation is too recent, the least recently used one is
  /// taken. Returns the lines by session id and the updated state.
  static (Map<String, String>, ReminderCopyState) assign(
    List<ReminderSlot> slots,
    ReminderCopyState state, {
    required bool hasName,
    required LocalDate today,
  }) {
    final used = <String, LocalDate>{
      // Forget what can no longer block anything.
      for (final e in state.used.entries)
        if (!e.value.isBefore(today.addDays(-noRepeatDays))) e.key: e.value,
    };
    final assigned = <String, ({String key, String situation})>{};
    final out = <String, String>{};
    // Lines already planned for other sessions of this batch.
    final planned = <String, LocalDate>{};

    bool free(String key, LocalDate day) {
      for (final d in [used[key], planned[key]]) {
        if (d != null && (d.daysUntil(day)).abs() < noRepeatDays) return false;
      }
      return true;
    }

    // Keep valid earlier choices first, so a re-sync changes nothing.
    final pending = <ReminderSlot>[];
    for (final s in slots) {
      final before = state.assigned[s.sessionId];
      final line = before == null ? null : _byKey[before.key];
      if (before != null &&
          before.situation == s.situation.name &&
          line != null &&
          (hasName || !line.usesName) &&
          (planned[before.key] == null)) {
        out[s.sessionId] = before.key;
        planned[before.key] = s.date;
        assigned[s.sessionId] = before;
      } else {
        pending.add(s);
      }
    }
    for (final s in pending) {
      // An earlier use of this session's own previous line does not count.
      final previous = state.assigned[s.sessionId]?.key;
      if (previous != null && used[previous] == s.date) used.remove(previous);
      final pool = _lines
          .where((l) => l.situation == s.situation && (hasName || !l.usesName))
          .toList();
      final start = _hash(s.sessionId) % pool.length;
      String? pick;
      for (var i = 0; i < pool.length; i++) {
        final l = pool[(start + i) % pool.length];
        if (free(l.key, s.date)) {
          pick = l.key;
          break;
        }
      }
      pick ??= (pool.toList()
            ..sort((a, b) {
              final da = planned[a.key] ?? used[a.key];
              final db = planned[b.key] ?? used[b.key];
              if (da == null) return -1;
              if (db == null) return 1;
              return da.compareTo(db);
            }))
          .first
          .key;
      out[s.sessionId] = pick;
      planned[pick] = s.date;
      assigned[s.sessionId] = (key: pick, situation: s.situation.name);
    }
    for (final e in planned.entries) {
      final d = used[e.key];
      if (d == null || d.isBefore(e.value)) used[e.key] = e.value;
    }
    return (out, ReminderCopyState(assigned: assigned, used: used));
  }

  static final Map<String, ReminderLine> _byKey = {
    for (final l in _lines) l.key: l
  };

  static int _hash(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h & 0x7fffffff;
  }
}
