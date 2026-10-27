import 'package:flutter/widgets.dart';

import '../../../core/i18n/app_strings.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/i18n/locale_controller.dart';
import '../../../exercise.dart';
import '../../../widgets/product_ui.dart';
import '../domain/local_date.dart';
import '../domain/workout_plan.dart';

/// EN / VI copy for plans. Final C ARB strings are used where their wording
/// fits (they are byte-identical to the handoff and cannot grow); the rest
/// follows the Phase 2 copy with `context.tr`, like other v2 screens.
extension PlanCopy on BuildContext {
  bool get _vi => language == AppLanguage.vi;

  String weekdayShort(int weekday) => _vi
      ? const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'][weekday - 1]
      : const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][weekday - 1];

  String weekdayLong(int weekday) => _vi
      ? const [
          'Thứ Hai',
          'Thứ Ba',
          'Thứ Tư',
          'Thứ Năm',
          'Thứ Sáu',
          'Thứ Bảy',
          'Chủ nhật'
        ][weekday - 1]
      : const [
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday'
        ][weekday - 1];

  String _month(int m) => const [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ][m - 1];

  /// "Mon, Nov 2" / "T2, 2/11".
  String dayLabel(LocalDate d) => _vi
      ? '${weekdayShort(d.weekday)}, ${d.day}/${d.month}'
      : '${weekdayShort(d.weekday)}, ${_month(d.month)} ${d.day}';

  String weekdaysList(List<int> days) => days.map(weekdayShort).join(', ');

  String goalLabel(PlanGoal g) => switch (g) {
        PlanGoal.strength => l10n.plansBuildStrength,
        PlanGoal.endurance => l10n.plansImproveFitness,
        PlanGoal.generalFitness => l10n.plansBuildConsistency,
        PlanGoal.muscle => tr('Tăng cơ', 'Build muscle'),
      };

  String levelLabel(PlanDifficulty d) => switch (d) {
        PlanDifficulty.beginner => tr('Người mới', 'Beginner'),
        PlanDifficulty.intermediate => l10n.plansIntermediate,
        PlanDifficulty.advanced => l10n.plansAdvanced,
      };

  String sessionStateLabel(SessionState s) => switch (s) {
        SessionState.scheduled => tr('Sắp tới', 'Planned'),
        SessionState.completed => tr('Đã xong', 'Done'),
        SessionState.partial => tr('Chưa trọn', 'Partial'),
        SessionState.missed => tr('Bỏ lỡ', 'Missed'),
        SessionState.skipped => tr('Đã bỏ qua', 'Skipped'),
        SessionState.cancelled => tr('Đã huỷ', 'Cancelled'),
      };

  String exerciseName(String id) => exerciseNameFor(id, s);

  /// "3 × 6 reps" / "45 s" / "2 × 45 s", plus "· manual".
  String targetText(ExerciseTarget t) {
    final body = t.isDuration
        ? (t.sets == 1
            ? tr('${t.seconds} giây', '${t.seconds} s')
            : tr('${t.sets} × ${t.seconds} giây', '${t.sets} × ${t.seconds} s'))
        : tr('${t.sets} × ${t.reps} rep', '${t.sets} × ${t.reps} reps');
    return t.tracking == TrackingMode.manual
        ? '$body · ${tr('ghi thủ công', 'manual log')}'
        : body;
  }

  String templateName(WorkoutPlan plan, String templateId) =>
      plan.template(templateId)?.name ?? templateId;

  String planSummary(WorkoutPlan p) => tr(
      '${goalLabel(p.goal)} · ${levelLabel(p.difficulty)} · ${p.weeklyFrequency} buổi/tuần',
      '${goalLabel(p.goal)} · ${levelLabel(p.difficulty)} · ${p.weeklyFrequency}× a week');
}
