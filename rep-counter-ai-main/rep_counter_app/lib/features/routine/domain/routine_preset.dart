import 'package:flutter/foundation.dart';

@immutable
class RoutinePreset {
  const RoutinePreset({
    required this.id,
    required this.name,
    required this.exerciseId,
    required this.targetReps,
    required this.targetSets,
    required this.restSeconds,
    required this.voiceCoachEnabled,
  });

  static const schemaVersion = 1;

  final String id;
  final String name;
  final String exerciseId;
  final int targetReps;
  final int targetSets;
  final int restSeconds;
  final bool voiceCoachEnabled;

  RoutineSnapshot toSnapshot() => RoutineSnapshot(
        id: id,
        name: name,
        exerciseId: exerciseId,
        targetReps: targetReps,
        targetSets: targetSets,
        restSeconds: restSeconds,
        voiceCoachEnabled: voiceCoachEnabled,
      );

  RoutinePreset copyWith({
    String? name,
    String? exerciseId,
    int? targetReps,
    int? targetSets,
    int? restSeconds,
    bool? voiceCoachEnabled,
  }) =>
      RoutinePreset(
        id: id,
        name: name ?? this.name,
        exerciseId: exerciseId ?? this.exerciseId,
        targetReps: targetReps ?? this.targetReps,
        targetSets: targetSets ?? this.targetSets,
        restSeconds: restSeconds ?? this.restSeconds,
        voiceCoachEnabled: voiceCoachEnabled ?? this.voiceCoachEnabled,
      );

  Map<String, dynamic> toJson() => {
        'schema_version': schemaVersion,
        'id': id,
        'name': name,
        'exercise_id': exerciseId,
        'target_reps': targetReps,
        'target_sets': targetSets,
        'rest_seconds': restSeconds,
        'voice_coach_enabled': voiceCoachEnabled,
      };

  factory RoutinePreset.fromJson(Map<String, dynamic> json) {
    _checkVersion(json);
    final preset = RoutinePreset(
      id: json['id'] as String,
      name: json['name'] as String,
      exerciseId: json['exercise_id'] as String,
      targetReps: (json['target_reps'] as num).toInt(),
      targetSets: (json['target_sets'] as num).toInt(),
      restSeconds: (json['rest_seconds'] as num).toInt(),
      voiceCoachEnabled: json['voice_coach_enabled'] as bool? ?? true,
    );
    preset.validate();
    return preset;
  }

  void validate() {
    if (id.trim().isEmpty ||
        name.trim().isEmpty ||
        exerciseId.trim().isEmpty ||
        targetReps <= 0 ||
        targetSets <= 0 ||
        restSeconds < 0) {
      throw const FormatException('Invalid routine preset');
    }
  }

  static void _checkVersion(Map<String, dynamic> json) {
    final version = (json['schema_version'] as num?)?.toInt() ?? 1;
    if (version < 1 || version > schemaVersion) {
      throw FormatException(
        'Unsupported routine schema_version $version',
      );
    }
  }
}

/// Immutable workout-history snapshot. Editing/deleting the preset later must
/// never change the routine metadata attached to an old WorkoutRecord.
@immutable
class RoutineSnapshot {
  const RoutineSnapshot({
    required this.id,
    required this.name,
    required this.exerciseId,
    required this.targetReps,
    required this.targetSets,
    required this.restSeconds,
    required this.voiceCoachEnabled,
  });

  static const schemaVersion = 1;

  final String id;
  final String name;
  final String exerciseId;
  final int targetReps;
  final int targetSets;
  final int restSeconds;
  final bool voiceCoachEnabled;

  Map<String, dynamic> toJson() => {
        'schema_version': schemaVersion,
        'id': id,
        'name': name,
        'exercise_id': exerciseId,
        'target_reps': targetReps,
        'target_sets': targetSets,
        'rest_seconds': restSeconds,
        'voice_coach_enabled': voiceCoachEnabled,
      };

  factory RoutineSnapshot.fromJson(Map<String, dynamic> json) {
    final version = (json['schema_version'] as num?)?.toInt() ?? 1;
    if (version < 1 || version > schemaVersion) {
      throw FormatException(
        'Unsupported routine snapshot schema_version $version',
      );
    }
    final snapshot = RoutineSnapshot(
      id: json['id'] as String,
      name: json['name'] as String,
      exerciseId: json['exercise_id'] as String,
      targetReps: (json['target_reps'] as num).toInt(),
      targetSets: (json['target_sets'] as num).toInt(),
      restSeconds: (json['rest_seconds'] as num).toInt(),
      voiceCoachEnabled: json['voice_coach_enabled'] as bool? ?? true,
    );
    if (snapshot.id.trim().isEmpty ||
        snapshot.name.trim().isEmpty ||
        snapshot.exerciseId.trim().isEmpty ||
        snapshot.targetReps <= 0 ||
        snapshot.targetSets <= 0 ||
        snapshot.restSeconds < 0) {
      throw const FormatException('Invalid routine snapshot');
    }
    return snapshot;
  }
}
