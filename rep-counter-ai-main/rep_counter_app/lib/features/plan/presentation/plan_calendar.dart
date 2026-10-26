import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/product_ui.dart';
import '../domain/local_date.dart';
import '../domain/plan_schedule.dart';
import '../domain/workout_plan.dart';
import 'plan_copy.dart';

/// How one calendar cell looks (P2-05 CalendarDay). State is carried by an
/// icon and a text label as well as colour; missed is warning, never red.
enum CalendarCellState {
  done,
  partial,
  planned,
  moved,
  missed,
  skipped,
  recovery,
  free,
}

CalendarCellState cellState(PlanDay day) {
  final s = day.session;
  if (s == null) {
    return day.kind == DayKind.recovery
        ? CalendarCellState.recovery
        : CalendarCellState.free;
  }
  return switch (s.state) {
    SessionState.completed => CalendarCellState.done,
    SessionState.partial => CalendarCellState.partial,
    SessionState.missed => CalendarCellState.missed,
    SessionState.skipped || SessionState.cancelled => CalendarCellState.skipped,
    SessionState.scheduled => s.rescheduledFrom != null
        ? CalendarCellState.moved
        : CalendarCellState.planned,
  };
}

(IconData, Color) cellStyle(CalendarCellState s) => switch (s) {
      CalendarCellState.done => (LucideIcons.check, AppColors.success),
      CalendarCellState.partial => (
          LucideIcons.circleDashed,
          AppColors.success
        ),
      CalendarCellState.planned => (LucideIcons.circle, AppColors.text),
      CalendarCellState.moved => (LucideIcons.arrowRight, AppColors.text),
      CalendarCellState.missed => (
          LucideIcons.clockArrowUp,
          AppColors.warningText
        ),
      CalendarCellState.skipped => (LucideIcons.minus, AppColors.text3),
      CalendarCellState.recovery => (LucideIcons.moon, AppColors.textMuted),
      CalendarCellState.free => (LucideIcons.minus, AppColors.text3),
    };

extension CalendarCellCopy on BuildContext {
  String cellLabel(CalendarCellState s) => switch (s) {
        CalendarCellState.done => tr('Đã xong', 'Done'),
        CalendarCellState.partial => tr('Chưa trọn', 'Partial'),
        CalendarCellState.planned => tr('Sắp tới', 'Planned'),
        CalendarCellState.moved => tr('Đã dời', 'Moved'),
        CalendarCellState.missed => tr('Bỏ lỡ', 'Missed'),
        CalendarCellState.skipped => tr('Bỏ qua', 'Skipped'),
        CalendarCellState.recovery => tr('Phục hồi', 'Recovery'),
        CalendarCellState.free => tr('Ngày trống', 'Free day'),
      };
}

/// Weeks of days, Monday first, with a legend (P2-05).
class PlanCalendar extends StatelessWidget {
  const PlanCalendar({
    super.key,
    required this.days,
    required this.today,
    required this.onDay,
  });

  final List<PlanDay> days;
  final LocalDate today;
  final ValueChanged<PlanDay> onDay;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();
    final first = days.first.date.startOfWeek;
    final byDate = {for (final d in days) d.date: d};
    final weeks = (first.daysUntil(days.last.date) ~/ 7) + 1;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        for (var w = 1; w <= 7; w++)
          Expanded(
              child: ExcludeSemantics(
                  child: Text(context.weekdayShort(w),
                      textAlign: TextAlign.center,
                      style: AppTypography.caption12
                          .copyWith(color: AppColors.text2)))),
      ]),
      const SizedBox(height: 6),
      for (var w = 0; w < weeks; w++)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                  child: _Cell(
                      day: byDate[first.addDays(w * 7 + i)],
                      date: first.addDays(w * 7 + i),
                      today: today,
                      onTap: onDay)),
          ]),
        ),
      const SizedBox(height: 4),
      Wrap(spacing: 12, runSpacing: 6, children: [
        for (final s in const [
          CalendarCellState.done,
          CalendarCellState.planned,
          CalendarCellState.recovery,
          CalendarCellState.missed,
          CalendarCellState.moved,
        ])
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(cellStyle(s).$1, size: 14, color: cellStyle(s).$2),
            const SizedBox(width: 4),
            Text(context.cellLabel(s),
                style:
                    AppTypography.caption12.copyWith(color: AppColors.text2)),
          ]),
      ]),
    ]);
  }
}

class _Cell extends StatelessWidget {
  const _Cell(
      {required this.day,
      required this.date,
      required this.today,
      required this.onTap});

  final PlanDay? day;
  final LocalDate date, today;
  final ValueChanged<PlanDay> onTap;

  @override
  Widget build(BuildContext context) {
    final d = day;
    if (d == null) return const SizedBox(height: 56);
    final state = cellState(d);
    final (icon, color) = cellStyle(state);
    final isToday = date == today;
    final label =
        '${context.dayLabel(date)}, ${context.cellLabel(state)}${isToday ? ', ${context.tr('hôm nay', 'today')}' : ''}';
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        key: Key('plan-day-${date.toIso()}'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => onTap(d),
        child: Container(
          height: 56,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isToday ? AppColors.accent : AppColors.border,
                width: isToday ? 1.5 : 1),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('${date.day}',
                style: AppTypography.body14.copyWith(
                    color: isToday ? AppColors.accent : AppColors.text,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Icon(icon, size: 14, color: color),
          ]),
        ),
      ),
    );
  }
}
