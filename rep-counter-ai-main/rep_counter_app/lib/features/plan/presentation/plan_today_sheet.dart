import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../camera_page.dart';
import '../../../exercise.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/product_ui.dart';
import '../../workout/presentation/goal_setup_page.dart';
import '../application/plan_repository.dart';
import '../domain/workout_plan.dart';
import 'plan_copy.dart';
import 'session_detail_page.dart';

/// The Train sheet (`/train`, APP_NAVIGATION_MAP §3): today's planned
/// session first when a plan is active (PL-2b), then a free workout.
///
/// [showPlan] is off when the sheet is opened for one exercise from its
/// detail page: that is a free workout by definition.
Future<void> showPlanTodaySheet(BuildContext context, ExerciseProfile profile,
        {bool showPlan = true, PlanRepository? repository}) =>
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (sheetContext) => SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                  24, 8, 24, 28 + MediaQuery.viewInsetsOf(sheetContext).bottom),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showPlan)
                      TodayPlanSection(
                          repository: repository,
                          onOpenSession: (sessionId) {
                            final navigator =
                                Navigator.of(context, rootNavigator: true);
                            Navigator.of(sheetContext).pop();
                            navigator.push(MaterialPageRoute(
                                builder: (_) => SessionDetailPage(
                                    sessionId: sessionId,
                                    repository: repository)));
                          }),
                    GoalSetupContent(
                        profile: profile,
                        onStart: (config) {
                          final navigator =
                              Navigator.of(context, rootNavigator: true);
                          Navigator.of(sheetContext).pop();
                          navigator.push(MaterialPageRoute(
                              builder: (_) => CameraPage(
                                    profile: profile,
                                    targetReps: config.targetReps,
                                    timedChallenge: config.timedChallenge,
                                    challengeBestReps: config.previousBestReps,
                                  )));
                        }),
                  ]),
            )));

/// Today's planned session at the top of the Train sheet. Shows nothing
/// without an active plan, so the sheet stays a free-workout sheet.
class TodayPlanSection extends StatefulWidget {
  const TodayPlanSection(
      {super.key, required this.onOpenSession, this.repository});

  final ValueChanged<String> onOpenSession;
  final PlanRepository? repository;

  @override
  State<TodayPlanSection> createState() => _TodayPlanSectionState();
}

class _TodayPlanSectionState extends State<TodayPlanSection> {
  late final Future<PlanView?> _view = () async {
    try {
      return await (widget.repository ?? PlanRepository()).load();
    } catch (_) {
      // A broken plan store never blocks a free workout.
      return null;
    }
  }();

  @override
  Widget build(BuildContext context) => FutureBuilder<PlanView?>(
      future: _view,
      builder: (context, snap) {
        final view = snap.data;
        if (view == null || view.plan.status != PlanStatus.active) {
          return const SizedBox.shrink();
        }
        final today = view.todaySession;
        final Widget body;
        if (today != null) {
          final name = context.templateName(view.plan, today.workoutTemplateId);
          final targets =
              view.plan.template(today.workoutTemplateId)?.targets ?? const [];
          final done = today.state == SessionState.completed;
          body = Column(
              key: const Key('train-today-plan'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(context.tr('Hôm nay · $name', 'Today · $name'),
                    style: AppTypography.title22),
                const SizedBox(height: 4),
                Text(
                    [
                      context.sessionStateLabel(today.state),
                      for (final t in targets)
                        '${context.exerciseName(t.exerciseId)} ${context.targetText(t)}',
                    ].join(' · '),
                    style:
                        AppTypography.body14.copyWith(color: AppColors.text2)),
                const SizedBox(height: 12),
                if (done)
                  Text(
                      key: const Key('train-today-done'),
                      context.tr(
                          'Buổi hôm nay đã xong. Bạn vẫn có thể tập tự do bên dưới.',
                          'Today\'s session is done. You can still do a free workout below.'),
                      style: AppTypography.body14)
                else
                  AppButton(
                      key: const Key('train-today-open'),
                      label: context.tr(
                          'Bắt đầu buổi hôm nay', 'Start today\'s session'),
                      icon: LucideIcons.calendarCheck,
                      onPressed: () => widget.onOpenSession(today.id)),
              ]);
        } else if (view.plan.dayKind(view.today) == DayKind.recovery) {
          body = Text(
              key: const Key('train-today-recovery'),
              context.tr(
                  'Hôm nay là ngày phục hồi trong kế hoạch. Tập nhẹ tự do nếu bạn muốn.',
                  'Today is a recovery day in your plan. A light free workout is fine if you want one.'),
              style: AppTypography.body14);
        } else {
          return const SizedBox.shrink();
        }
        return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  body,
                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Text(context.tr('Tập tự do', 'Free workout'),
                      style:
                          AppTypography.row15.copyWith(color: AppColors.text2)),
                ]));
      });
}
