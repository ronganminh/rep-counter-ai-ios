import 'local_date.dart';
import 'workout_plan.dart';

/// PL-1 default: three workouts a week, Monday / Wednesday / Friday, rotating
/// Full Body A / B / C. A starting template, not a fixed schedule: every day,
/// exercise and target can be edited.
///
/// Only exercises the rep engine supports today are used (push-up, pull-up,
/// dumbbell curl, overhead extension); squat, plank and other moves stay
/// "coming soon" until engine profiles exist (D-28). Targets are general
/// fitness guidance, not medical advice.
class PlanTemplates {
  const PlanTemplates._();

  static const defaultWeekdays = [
    DateTime.monday,
    DateTime.wednesday,
    DateTime.friday,
  ];

  static const fullBodyA = 'full_body_a',
      fullBodyB = 'full_body_b',
      fullBodyC = 'full_body_c';

  /// Beginner targets; [scaled] raises reps for other levels.
  static const _beginner = [
    WorkoutTemplate(id: fullBodyA, name: 'Full Body A', targets: [
      ExerciseTarget(exerciseId: 'push_up', sets: 3, reps: 6),
      ExerciseTarget(exerciseId: 'curl', sets: 3, reps: 10),
      ExerciseTarget(exerciseId: 'overhead_extension', sets: 2, reps: 10),
    ]),
    WorkoutTemplate(id: fullBodyB, name: 'Full Body B', targets: [
      ExerciseTarget(exerciseId: 'pull_up', sets: 3, reps: 3),
      ExerciseTarget(exerciseId: 'push_up', sets: 2, reps: 6),
      ExerciseTarget(exerciseId: 'curl', sets: 2, reps: 10),
    ]),
    WorkoutTemplate(id: fullBodyC, name: 'Full Body C', targets: [
      // A timed effort: as many good push-ups as feel right in 45 s.
      ExerciseTarget(exerciseId: 'push_up', sets: 1, seconds: 45),
      ExerciseTarget(exerciseId: 'overhead_extension', sets: 3, reps: 10),
      ExerciseTarget(exerciseId: 'pull_up', sets: 2, reps: 3),
    ]),
  ];

  static List<WorkoutTemplate> fullBody(PlanDifficulty level) => [
        for (final t in _beginner)
          t.copyWith(targets: [for (final x in t.targets) scaled(x, level)])
      ];

  /// Rep targets grow with the level; durations and sets stay.
  static ExerciseTarget scaled(ExerciseTarget t, PlanDifficulty level) {
    if (t.isDuration || level == PlanDifficulty.beginner) return t;
    final factor = level == PlanDifficulty.intermediate ? 1.5 : 2.0;
    return t.copyWith(reps: (t.reps! * factor).round());
  }

  /// The default beginner plan, as a draft to preview and confirm.
  static WorkoutPlan beginnerPlan({
    required String id,
    required LocalDate startDate,
    required String timezone,
    required DateTime now,
    String name = 'Full Body · 3 days',
    PlanGoal goal = PlanGoal.generalFitness,
    PlanDifficulty difficulty = PlanDifficulty.beginner,
    List<int> weekdays = defaultWeekdays,
    String? ownerId,
  }) =>
      WorkoutPlan(
        id: id,
        ownerId: ownerId,
        name: name,
        goal: goal,
        difficulty: difficulty,
        selectedWeekdays: [...weekdays]..sort(),
        templates: fullBody(difficulty),
        timezone: timezone,
        startDate: startDate,
        status: PlanStatus.draft,
        createdAt: now,
        updatedAt: now,
      );
}
