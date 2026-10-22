import 'package:flutter/material.dart';

import '../../../core/i18n/locale_controller.dart';
import '../../../exercise.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/metric_widgets.dart';
import '../../plan/presentation/plan_today_sheet.dart';
import '../../workout/data/workout_history_store.dart';
import '../../workout/data/workout_record.dart';
import '../../workout/presentation/exercise_help_sheet.dart';
import '../../workout/presentation/exercise_icon.dart';

/// The user's own numbers for one exercise, derived from saved workouts only.
class ExerciseStats {
  const ExerciseStats({required this.workouts, required this.bestReps});

  final int workouts;

  /// Most reps in a single saved workout, or null if none was saved.
  final int? bestReps;

  factory ExerciseStats.from(Iterable<WorkoutRecord> records, String id) {
    var workouts = 0;
    int? best;
    for (final r in records.where((r) => r.exerciseId == id)) {
      workouts++;
      if (best == null || r.reps > best) best = r.reps;
    }
    return ExerciseStats(workouts: workouts, bestReps: best);
  }
}

/// Exercise detail (v2 P4–P5, roadmap E-1): what it is, how to set up the
/// phone, the user's records and a Start action. Only reached for exercises
/// that have a production engine profile and are enabled by feature flags.
class ExerciseDetailPage extends StatefulWidget {
  const ExerciseDetailPage({super.key, required this.profile, this.history});

  final ExerciseProfile profile;
  final WorkoutHistoryStore? history;

  @override
  State<ExerciseDetailPage> createState() => _ExerciseDetailPageState();
}

class _ExerciseDetailPageState extends State<ExerciseDetailPage> {
  late final Future<ExerciseStats> _stats =
      (widget.history ?? WorkoutHistoryStore())
          .load()
          .then((records) => ExerciseStats.from(records, widget.profile.id));

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final profile = widget.profile;
    return Scaffold(
      appBar: AppBar(actions: [ExerciseHelpButton(profile: profile)]),
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.screenPaddingV2.copyWith(bottom: 32),
          children: [
            Center(
              child: ExerciseIcon(
                  exerciseId: profile.id, color: AppColors.accent, size: 96),
            ),
            const SizedBox(height: 20),
            Semantics(
              header: true,
              child: Text(profile.localizedName(context.s).toUpperCase(),
                  style: AppTypography.display40),
            ),
            const SizedBox(height: 8),
            Text(profile.localizedHint(context.s),
                style: AppTypography.body16.copyWith(color: AppColors.text2)),
            const SizedBox(height: 24),
            FutureBuilder<ExerciseStats>(
              future: _stats,
              builder: (context, snapshot) {
                final stats = snapshot.data;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: StatTile(
                        key: const Key('exercise-best'),
                        label: l.legacyHistoryPagePersonalRecords,
                        value: stats == null
                            ? null
                            : stats.bestReps == null
                                ? '—'
                                : '${stats.bestReps}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatTile(
                        key: const Key('exercise-workouts'),
                        label: l.fbWorkouts,
                        value: stats == null ? null : '${stats.workouts}',
                        valueColor: AppColors.text,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),
            AppButton(
              key: const Key('exercise-start'),
              label: l.workoutStart,
              onPressed: () => showPlanTodaySheet(context, profile),
            ),
          ],
        ),
      ),
    );
  }
}
