import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_button.dart';
import '../../plan/application/plan_repository.dart';
import '../../plan/domain/workout_plan.dart';
import '../../plan/presentation/plan_copy.dart';
import '../../plan/presentation/targets_editor_page.dart';
import '../coach_apply.dart';
import 'coach_copy.dart';

enum _Choice { accept, edit, dismiss }

/// AC-02d / D-35 "Apply to plan": the existing Accept / Edit / Dismiss
/// review for one planned session. Accept writes that session only; Edit
/// opens the targets editor (P4-04b) first; Dismiss changes nothing.
/// Logged workouts are never changed, and a toast offers Undo.
/// Returns the applied change, or null.
Future<CoachApplied?> showCoachApplySheet(
  BuildContext context, {
  required PlanRepository plans,
  required PlanView view,
  required PlannedSession session,
  required List<ExerciseTarget> proposed,
}) async {
  final choice = await showModalBottomSheet<_Choice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) =>
        _ApplySheet(view: view, session: session, proposed: proposed),
  );
  if (choice == null || choice == _Choice.dismiss || !context.mounted) {
    return null;
  }
  var targets = proposed;
  if (choice == _Choice.edit) {
    final edited = await Navigator.of(context).push<List<ExerciseTarget>>(
        MaterialPageRoute(
            builder: (_) => TargetsEditorPage(
                title: context.l10n.ptEditTitle,
                note: context.l10n.ptApplySheetNote,
                targets: proposed)));
    if (edited == null || !context.mounted) return null;
    targets = edited;
  }
  final applier = CoachApplier(plans);
  final applied = await applier.apply(session.id, targets);
  if (applied != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      key: const Key('coach-applied-toast'),
      content: Text(context.l10n
          .ptAppliedToast(context.weekdayLong(applied.date.weekday))),
      action: SnackBarAction(
          label: context.l10n.commonUndo,
          onPressed: () => applier.undo(applied)),
    ));
  }
  return applied;
}

class _ApplySheet extends StatelessWidget {
  const _ApplySheet(
      {required this.view, required this.session, required this.proposed});
  final PlanView view;
  final PlannedSession session;
  final List<ExerciseTarget> proposed;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final current = session.exerciseTargets;
    final date = session.scheduledLocalDate;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        key: const Key('coach-apply-sheet'),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                  l.ptApplySheetTitle(context.weekdayLong(date.weekday)),
                  style: AppTypography.title20),
            ),
            const SizedBox(height: 6),
            Text(
                l.ptApplySheetBody(
                    context.templateName(view.plan, session.workoutTemplateId),
                    context.dayLabel(date)),
                style: AppTypography.body14.copyWith(color: AppColors.text2)),
            const SizedBox(height: 12),
            for (var i = 0; i < current.length; i++)
              Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: const BoxDecoration(
                    border:
                        Border(bottom: BorderSide(color: AppColors.border))),
                child: Row(children: [
                  Expanded(
                    child: Text(context.exerciseName(current[i].exerciseId),
                        style: AppTypography.row15),
                  ),
                  if (i < proposed.length && proposed[i] != current[i])
                    Text(
                        '${context.coachAmount(current[i])} → ${context.coachAmount(proposed[i])}',
                        style: AppTypography.row15
                            .copyWith(color: AppColors.accent))
                  else
                    Text(l.ptDiffSame,
                        style: AppTypography.body14
                            .copyWith(color: AppColors.text2)),
                ]),
              ),
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(LucideIcons.shieldCheck,
                  size: 16, color: AppColors.text2),
              const SizedBox(width: 8),
              Expanded(
                child: Text(l.ptApplySheetNote,
                    style: AppTypography.caption12
                        .copyWith(color: AppColors.text2)),
              ),
            ]),
            const SizedBox(height: 16),
            AppButton(
                key: const Key('coach-apply-accept'),
                label: l.ptAccept,
                icon: LucideIcons.check,
                onPressed: () => Navigator.of(context).pop(_Choice.accept)),
            const SizedBox(height: 10),
            AppButton(
                key: const Key('coach-apply-edit'),
                label: l.ptEdit,
                icon: LucideIcons.slidersHorizontal,
                variant: AppButtonVariant.secondary,
                onPressed: () => Navigator.of(context).pop(_Choice.edit)),
            const SizedBox(height: 6),
            AppButton(
                key: const Key('coach-apply-dismiss'),
                label: l.ptDismiss,
                variant: AppButtonVariant.ghost,
                onPressed: () => Navigator.of(context).pop(_Choice.dismiss)),
          ],
        ),
      ),
    );
  }
}
