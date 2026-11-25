import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/l10n.dart';
import '../../credits/ai_credits.dart';
import '../../plan/domain/local_date.dart';
import '../../plan/domain/workout_plan.dart';
import '../../plan/presentation/plan_copy.dart';

/// Formatting shared by the coach screens.
extension CoachCopy on BuildContext {
  /// The language AI text is written in (`ai-request` locale).
  String get coachLocale =>
      Localizations.localeOf(this).languageCode == 'vi' ? 'vi' : 'en';

  /// "3 × 12", "2 × 0:40", "0:40".
  String coachAmount(ExerciseTarget t) {
    if (t.isDuration) {
      final s = t.seconds!;
      final time = '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
      return t.sets == 1 ? time : '${t.sets} × $time';
    }
    return '${t.sets} × ${t.reps}';
  }

  /// "Camera count" / "Manual log" / "Guided timer" (reused keys).
  String coachTracking(ExerciseTarget t) => t.isDuration
      ? l10n.commonHomeGuidedTimer
      : t.tracking == TrackingMode.camera
          ? l10n.commonHomeCameraCount
          : l10n.commonHomeManualLog;

  IconData coachTrackingIcon(ExerciseTarget t) => t.isDuration
      ? LucideIcons.timer
      : t.tracking == TrackingMode.camera
          ? LucideIcons.camera
          : LucideIcons.check;

  /// "{exercises} exercises · {sets} sets · about {minutes} min".
  String coachMeta(List<ExerciseTarget> targets) => l10n.ptTodayMeta(
        targets.length,
        targets.fold(0, (n, t) => n + t.sets),
        coachMinutes(targets),
      );

  /// "Mon 26" / "T2 26".
  String coachDayShort(LocalDate d) => '${weekdayShort(d.weekday)} ${d.day}';

  /// The day credits come back: the Monday after the balance's week start.
  String coachResetDate(CreditBalance? b) {
    final start = b?.weekStart ?? AiCredits.weekStart(DateTime.now());
    final next = start.add(const Duration(days: 7));
    return dayLabel(LocalDate(next.year, next.month, next.day));
  }
}

/// Rough session length: ~3 s a rep or the hold, plus 60 s between sets.
int coachMinutes(List<ExerciseTarget> targets) {
  var seconds = 0;
  for (final t in targets) {
    final work = t.isDuration ? t.seconds! : (t.reps ?? 0) * 3;
    seconds += t.sets * work + (t.sets - 1) * 60;
  }
  final m = (seconds / 60).round();
  return m < 1 ? 1 : m;
}
