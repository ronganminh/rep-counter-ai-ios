import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/product_ui.dart';
import '../application/plan_repository.dart';
import '../domain/workout_plan.dart';
import 'plan_copy.dart';
import 'plan_overview_page.dart';
import 'plan_setup_page.dart';

/// Home entry to the plan (`/home/plan`): today's session, a recovery day,
/// missed sessions waiting for the user's choice, or "No plan yet".
class PlanHomeCard extends StatefulWidget {
  const PlanHomeCard({super.key, this.repository});

  final PlanRepository? repository;

  @override
  State<PlanHomeCard> createState() => _PlanHomeCardState();
}

class _PlanHomeCardState extends State<PlanHomeCard> {
  late final _repo = widget.repository ?? PlanRepository();
  late Future<PlanView?> _view = _safeLoad();

  Future<PlanView?> _safeLoad() async {
    try {
      return await _repo.load();
    } catch (_) {
      return null;
    }
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) setState(() => _view = _safeLoad());
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<PlanView?>(
        future: _view,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const SizedBox(height: 88);
          }
          final view = snap.data;
          final l = context.l10n;
          final (String title, String body, IconData icon) = view == null
              ? (
                  l.plansNoPlanYet,
                  l.plansAnswerQuestionsGetWeekly,
                  LucideIcons.calendarPlus
                )
              : _summary(context, view);
          return Card(
            child: ListTile(
              key: const Key('plan-home-card'),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              leading: Icon(icon, color: AppColors.accent, size: 28),
              title: Text(title, style: AppTypography.row15),
              subtitle: Text(body,
                  style: AppTypography.body14.copyWith(color: AppColors.text2)),
              trailing: const Icon(LucideIcons.chevronRight),
              onTap: () => _open(view == null
                  ? PlanSetupPage(repository: _repo)
                  : PlanOverviewPage(repository: _repo)),
            ),
          );
        },
      );

  (String, String, IconData) _summary(BuildContext context, PlanView view) {
    final plan = view.plan;
    final today = view.todaySession;
    final missed = view.missed.length;
    final note = missed == 0
        ? ''
        : context.tr(' · $missed buổi chờ dời hoặc bỏ qua',
            ' · $missed to move or skip');
    if (plan.status == PlanStatus.paused) {
      return (
        plan.name,
        context.tr('Đang tạm dừng', 'Paused'),
        LucideIcons.calendarOff
      );
    }
    if (today != null) {
      return (
        context.tr(
            'Hôm nay · ${context.templateName(plan, today.workoutTemplateId)}',
            'Today · ${context.templateName(plan, today.workoutTemplateId)}'),
        '${context.sessionStateLabel(today.state)}$note',
        LucideIcons.calendarCheck
      );
    }
    if (plan.dayKind(view.today) == DayKind.recovery) {
      return (
        context.tr('Hôm nay · ngày phục hồi', 'Today · recovery day'),
        '${plan.name}$note',
        LucideIcons.moon
      );
    }
    return (
      plan.name,
      '${context.planSummary(plan)}$note',
      LucideIcons.calendar
    );
  }
}
