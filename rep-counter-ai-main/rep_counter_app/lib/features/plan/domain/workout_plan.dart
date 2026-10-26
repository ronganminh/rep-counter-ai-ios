import 'package:flutter/foundation.dart';

import 'local_date.dart';

/// PL-1 multi-day plans. Plans and planned sessions are local data, separate
/// from the WorkoutRecords that hold what was actually done: a session only
/// links to record ids, and nothing here ever edits a record.

enum PlanStatus { draft, active, paused, completed, archived }

enum PlanGoal { generalFitness, strength, muscle, endurance }

enum PlanDifficulty { beginner, intermediate, advanced }

enum SessionState { scheduled, completed, partial, missed, skipped, cancelled }

/// How a target is tracked: by the camera rep engine, or entered by hand
/// (never presented as camera-verified, D-18).
enum TrackingMode { camera, manual }

T _byName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

/// One exercise in a session: [sets] × [reps], or a timed effort of
/// [seconds] (duration targets are kept apart from rep targets, also for
/// progressive overload).
@immutable
class ExerciseTarget {
  const ExerciseTarget({
    required this.exerciseId,
    required this.sets,
    this.reps,
    this.seconds,
    this.tracking = TrackingMode.camera,
  });

  final String exerciseId;
  final int sets;
  final int? reps;
  final int? seconds;
  final TrackingMode tracking;

  bool get isDuration => seconds != null;

  /// Reps needed over all sets (rep targets only).
  int get totalReps => (reps ?? 0) * sets;

  void validate() {
    if (exerciseId.trim().isEmpty ||
        sets < 1 ||
        sets > 10 ||
        (reps == null) == (seconds == null) ||
        (reps != null && (reps! < 1 || reps! > 100)) ||
        (seconds != null && (seconds! < 5 || seconds! > 3600))) {
      throw const FormatException('Invalid exercise target');
    }
  }

  ExerciseTarget copyWith({int? sets, int? reps, int? seconds}) =>
      ExerciseTarget(
        exerciseId: exerciseId,
        sets: sets ?? this.sets,
        reps: isDuration ? null : (reps ?? this.reps),
        seconds: isDuration ? (seconds ?? this.seconds) : null,
        tracking: tracking,
      );

  Map<String, dynamic> toJson() => {
        'exercise_id': exerciseId,
        'sets': sets,
        if (reps != null) 'reps': reps,
        if (seconds != null) 'seconds': seconds,
        'tracking': tracking.name,
      };

  factory ExerciseTarget.fromJson(Map<String, dynamic> j) => ExerciseTarget(
        exerciseId: j['exercise_id'] as String,
        sets: (j['sets'] as num).toInt(),
        reps: (j['reps'] as num?)?.toInt(),
        seconds: (j['seconds'] as num?)?.toInt(),
        tracking:
            _byName(TrackingMode.values, j['tracking'], TrackingMode.camera),
      );

  @override
  bool operator ==(Object other) =>
      other is ExerciseTarget &&
      other.exerciseId == exerciseId &&
      other.sets == sets &&
      other.reps == reps &&
      other.seconds == seconds &&
      other.tracking == tracking;

  @override
  int get hashCode => Object.hash(exerciseId, sets, reps, seconds, tracking);
}

/// A named list of targets ("Full Body A").
@immutable
class WorkoutTemplate {
  const WorkoutTemplate(
      {required this.id, required this.name, required this.targets});

  final String id, name;
  final List<ExerciseTarget> targets;

  void validate() {
    if (id.trim().isEmpty || name.trim().isEmpty || targets.isEmpty) {
      throw const FormatException('Invalid workout template');
    }
    for (final t in targets) {
      t.validate();
    }
  }

  WorkoutTemplate copyWith({String? name, List<ExerciseTarget>? targets}) =>
      WorkoutTemplate(
          id: id, name: name ?? this.name, targets: targets ?? this.targets);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'targets': [for (final t in targets) t.toJson()],
      };

  factory WorkoutTemplate.fromJson(Map<String, dynamic> j) => WorkoutTemplate(
        id: j['id'] as String,
        name: j['name'] as String,
        targets: [
          for (final t in j['targets'] as List)
            ExerciseTarget.fromJson(t as Map<String, dynamic>)
        ],
      );
}

/// What a calendar day is, apart from any session on it.
enum DayKind {
  /// A planned training weekday.
  training,

  /// A non-training day: recovery is first-class (PL-1 rule 4); reminders
  /// skip it.
  recovery,

  /// A non-training day the user customised to be neither (no recovery
  /// guidance, no reminders).
  open,
}

@immutable
class WorkoutPlan {
  const WorkoutPlan({
    required this.id,
    this.ownerId,
    required this.name,
    required this.goal,
    required this.difficulty,
    required this.selectedWeekdays,
    required this.templates,
    required this.timezone,
    required this.startDate,
    required this.status,
    this.version = 1,
    this.dayOverrides = const {},
    this.progressiveOverload = false,
    required this.createdAt,
    required this.updatedAt,
  });

  static const minDays = 2, maxDays = 6;

  final String id;

  /// Null for a guest plan; guests create, follow and save plans locally.
  final String? ownerId;
  final String name;
  final PlanGoal goal;
  final PlanDifficulty difficulty;

  /// [DateTime.monday] … [DateTime.sunday], sorted.
  final List<int> selectedWeekdays;

  /// Rotated over the training days in order (A, B, C, A, …).
  final List<WorkoutTemplate> templates;

  /// The device time zone when the plan was saved (IANA name when known,
  /// otherwise the platform abbreviation). Dates are local calendar dates.
  final String timezone;
  final LocalDate startDate;
  final PlanStatus status;

  /// Bumped on every edit of the schedule or targets; sessions record the
  /// version they were generated from.
  final int version;

  /// Days the user customised (recovery → open, or a confirmed workout on a
  /// recovery day → training).
  final Map<LocalDate, DayKind> dayOverrides;

  /// Progressive-overload suggestions: OFF unless the user opts in. Even
  /// then they are only proposals the user accepts, edits or dismisses.
  final bool progressiveOverload;
  final DateTime createdAt, updatedAt;

  int get weeklyFrequency => selectedWeekdays.length;

  DayKind dayKind(LocalDate date) =>
      dayOverrides[date] ??
      (selectedWeekdays.contains(date.weekday)
          ? DayKind.training
          : DayKind.recovery);

  WorkoutTemplate? template(String id) {
    for (final t in templates) {
      if (t.id == id) return t;
    }
    return null;
  }

  void validate() {
    final days = selectedWeekdays.toSet();
    if (id.trim().isEmpty ||
        name.trim().isEmpty ||
        days.length != selectedWeekdays.length ||
        days.length < minDays ||
        days.length > maxDays ||
        days.any((d) => d < DateTime.monday || d > DateTime.sunday) ||
        templates.isEmpty) {
      throw const FormatException('Invalid workout plan');
    }
    for (final t in templates) {
      t.validate();
    }
  }

  WorkoutPlan copyWith({
    String? ownerId,
    String? name,
    PlanGoal? goal,
    PlanDifficulty? difficulty,
    List<int>? selectedWeekdays,
    List<WorkoutTemplate>? templates,
    String? timezone,
    LocalDate? startDate,
    PlanStatus? status,
    int? version,
    Map<LocalDate, DayKind>? dayOverrides,
    bool? progressiveOverload,
    DateTime? updatedAt,
  }) =>
      WorkoutPlan(
        id: id,
        ownerId: ownerId ?? this.ownerId,
        name: name ?? this.name,
        goal: goal ?? this.goal,
        difficulty: difficulty ?? this.difficulty,
        selectedWeekdays: selectedWeekdays ?? this.selectedWeekdays,
        templates: templates ?? this.templates,
        timezone: timezone ?? this.timezone,
        startDate: startDate ?? this.startDate,
        status: status ?? this.status,
        version: version ?? this.version,
        dayOverrides: dayOverrides ?? this.dayOverrides,
        progressiveOverload: progressiveOverload ?? this.progressiveOverload,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        if (ownerId != null) 'owner_id': ownerId,
        'name': name,
        'goal': goal.name,
        'difficulty': difficulty.name,
        'weekdays': selectedWeekdays,
        'templates': [for (final t in templates) t.toJson()],
        'timezone': timezone,
        'start_date': startDate.toIso(),
        'status': status.name,
        'version': version,
        'day_overrides': {
          for (final e in dayOverrides.entries) e.key.toIso(): e.value.name
        },
        'progressive_overload': progressiveOverload,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  factory WorkoutPlan.fromJson(Map<String, dynamic> j) {
    final plan = WorkoutPlan(
      id: j['id'] as String,
      ownerId: j['owner_id'] as String?,
      name: j['name'] as String,
      goal: _byName(PlanGoal.values, j['goal'], PlanGoal.generalFitness),
      difficulty: _byName(
          PlanDifficulty.values, j['difficulty'], PlanDifficulty.beginner),
      selectedWeekdays: [
        for (final d in j['weekdays'] as List) (d as num).toInt()
      ]..sort(),
      templates: [
        for (final t in j['templates'] as List)
          WorkoutTemplate.fromJson(t as Map<String, dynamic>)
      ],
      timezone: j['timezone'] as String? ?? '',
      startDate: LocalDate.parse(j['start_date'] as String),
      status: _byName(PlanStatus.values, j['status'], PlanStatus.draft),
      version: (j['version'] as num?)?.toInt() ?? 1,
      dayOverrides: {
        for (final e in ((j['day_overrides'] as Map?) ?? const {}).entries)
          LocalDate.parse(e.key as String):
              _byName(DayKind.values, e.value, DayKind.recovery)
      },
      progressiveOverload: j['progressive_overload'] as bool? ?? false,
      createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(j['updated_at'] as String).toLocal(),
    );
    plan.validate();
    return plan;
  }
}

enum SessionEventKind {
  created,
  completed,
  partial,
  missed,
  skipped,
  cancelled,
  rescheduled,
  targetsEdited,
}

/// An append-only line in a session's history.
@immutable
class SessionEvent {
  const SessionEvent(this.kind, this.at, {this.from, this.to});

  final SessionEventKind kind;
  final DateTime at;
  final LocalDate? from, to;

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'at': at.toUtc().toIso8601String(),
        if (from != null) 'from': from!.toIso(),
        if (to != null) 'to': to!.toIso(),
      };

  factory SessionEvent.fromJson(Map<String, dynamic> j) => SessionEvent(
        _byName(SessionEventKind.values, j['kind'], SessionEventKind.created),
        DateTime.parse(j['at'] as String).toLocal(),
        from: j['from'] == null ? null : LocalDate.parse(j['from'] as String),
        to: j['to'] == null ? null : LocalDate.parse(j['to'] as String),
      );
}

@immutable
class PlannedSession {
  const PlannedSession({
    required this.id,
    required this.planId,
    required this.planVersion,
    required this.scheduledLocalDate,
    required this.workoutTemplateId,
    required this.exerciseTargets,
    this.state = SessionState.scheduled,
    this.completedWorkoutIds = const [],
    required this.originalScheduledDate,
    this.rescheduledFrom,
    this.history = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  final String id, planId;
  final int planVersion;
  final LocalDate scheduledLocalDate;
  final String workoutTemplateId;

  /// A copy of the template's targets when the session was planned; editing
  /// the plan later only changes sessions that are still to come.
  final List<ExerciseTarget> exerciseTargets;
  final SessionState state;

  /// Ids of the saved WorkoutRecords this session is linked to (a set: the
  /// same record saved or synced twice is linked once).
  final List<String> completedWorkoutIds;
  final LocalDate originalScheduledDate;
  final LocalDate? rescheduledFrom;
  final List<SessionEvent> history;
  final DateTime createdAt, updatedAt;

  /// The first linked record, for the PL-1 `completedWorkoutId` field.
  String? get completedWorkoutId =>
      completedWorkoutIds.isEmpty ? null : completedWorkoutIds.first;

  /// Still to be done (the only state reminders may announce).
  bool get isUpcoming => state == SessionState.scheduled;

  /// Holds the day: a second session cannot be placed on it.
  bool get occupiesDay =>
      state != SessionState.cancelled && state != SessionState.skipped;

  PlannedSession copyWith({
    LocalDate? scheduledLocalDate,
    List<ExerciseTarget>? exerciseTargets,
    String? workoutTemplateId,
    int? planVersion,
    SessionState? state,
    List<String>? completedWorkoutIds,
    LocalDate? rescheduledFrom,
    SessionEvent? event,
    required DateTime updatedAt,
  }) =>
      PlannedSession(
        id: id,
        planId: planId,
        planVersion: planVersion ?? this.planVersion,
        scheduledLocalDate: scheduledLocalDate ?? this.scheduledLocalDate,
        workoutTemplateId: workoutTemplateId ?? this.workoutTemplateId,
        exerciseTargets: exerciseTargets ?? this.exerciseTargets,
        state: state ?? this.state,
        completedWorkoutIds: completedWorkoutIds ?? this.completedWorkoutIds,
        originalScheduledDate: originalScheduledDate,
        rescheduledFrom: rescheduledFrom ?? this.rescheduledFrom,
        history: event == null ? history : [...history, event],
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'plan_id': planId,
        'plan_version': planVersion,
        'date': scheduledLocalDate.toIso(),
        'template_id': workoutTemplateId,
        'targets': [for (final t in exerciseTargets) t.toJson()],
        'state': state.name,
        'workout_ids': completedWorkoutIds,
        'original_date': originalScheduledDate.toIso(),
        if (rescheduledFrom != null)
          'rescheduled_from': rescheduledFrom!.toIso(),
        'history': [for (final e in history) e.toJson()],
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  factory PlannedSession.fromJson(Map<String, dynamic> j) => PlannedSession(
        id: j['id'] as String,
        planId: j['plan_id'] as String,
        planVersion: (j['plan_version'] as num?)?.toInt() ?? 1,
        scheduledLocalDate: LocalDate.parse(j['date'] as String),
        workoutTemplateId: j['template_id'] as String,
        exerciseTargets: [
          for (final t in j['targets'] as List)
            ExerciseTarget.fromJson(t as Map<String, dynamic>)
        ],
        state: _byName(SessionState.values, j['state'], SessionState.scheduled),
        completedWorkoutIds: [
          for (final id in (j['workout_ids'] as List?) ?? const []) id as String
        ],
        originalScheduledDate: LocalDate.parse(j['original_date'] as String),
        rescheduledFrom: j['rescheduled_from'] == null
            ? null
            : LocalDate.parse(j['rescheduled_from'] as String),
        history: [
          for (final e in (j['history'] as List?) ?? const [])
            SessionEvent.fromJson(e as Map<String, dynamic>)
        ],
        createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
        updatedAt: DateTime.parse(j['updated_at'] as String).toLocal(),
      );
}
