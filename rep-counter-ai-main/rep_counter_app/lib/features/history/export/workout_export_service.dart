import 'dart:convert';
import 'dart:typed_data';

import '../../workout/data/workout_record.dart';

enum WorkoutExportFormat { csv, json }

class EmptyWorkoutExport implements Exception {
  const EmptyWorkoutExport();
}

class WorkoutExportFile {
  const WorkoutExportFile({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String fileName;
  final String mimeType;
}

typedef WorkoutExportShare = Future<void> Function(WorkoutExportFile file);

/// Builds a privacy-preserving export from already-saved local workout records.
///
/// The export intentionally omits camera images, video, raw pose landmarks,
/// per-frame data, local secrets and API/backend credentials.
class WorkoutExportService {
  const WorkoutExportService();

  Future<void> createAndShare({
    required List<WorkoutRecord> records,
    required WorkoutExportFormat format,
    required bool includeSavedAiFeedback,
    required WorkoutExportShare share,
    DateTime? now,
  }) async {
    final file = build(
      records: records,
      format: format,
      includeSavedAiFeedback: includeSavedAiFeedback,
      now: now,
    );
    await share(file);
  }

  WorkoutExportFile build({
    required List<WorkoutRecord> records,
    required WorkoutExportFormat format,
    required bool includeSavedAiFeedback,
    DateTime? now,
  }) {
    if (records.isEmpty) throw const EmptyWorkoutExport();

    final stamp = _dateStamp(now ?? DateTime.now());
    return switch (format) {
      WorkoutExportFormat.csv => WorkoutExportFile(
          bytes: Uint8List.fromList(utf8.encode(_csv(records, includeSavedAiFeedback))),
          fileName: 'repcoach-workouts-$stamp.csv',
          mimeType: 'text/csv',
        ),
      WorkoutExportFormat.json => WorkoutExportFile(
          bytes: Uint8List.fromList(utf8.encode(_json(records, includeSavedAiFeedback))),
          fileName: 'repcoach-workouts-$stamp.json',
          mimeType: 'application/json',
        ),
    };
  }

  String _json(List<WorkoutRecord> records, bool includeAi) {
    final payload = <String, dynamic>{
      'schemaVersion': 1,
      'workouts': [
        for (final record in records) _record(record, includeAi),
      ],
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  String _csv(List<WorkoutRecord> records, bool includeAi) {
    final headers = <String>[
      'id',
      'startedAt',
      'exerciseId',
      'exerciseName',
      'mode',
      'reps',
      'sets',
      'durationSeconds',
      'targetReps',
      'goalReached',
      'placementScore',
      'challengeSeconds',
      'routineId',
      'routineName',
      'routineTargetReps',
      'routineTargetSets',
      'routineRestSeconds',
      'routineVoiceCoachEnabled',
      'flaggedReps',
      'avgRepSeconds',
      'avgAmplitude',
      'amplitudeDropPercent',
      'leftRightDiffPercent',
      'formScore',
      'rangeOfMotion',
      'cadenceConsistency',
      'leftRightBalance',
      'poseAlignment',
      'hasEnoughFormData',
      if (includeAi) 'aiFeedback',
    ];

    final out = StringBuffer()..writeln(headers.map(_csvCell).join(','));
    for (final record in records) {
      final quality = record.quality;
      final row = <Object?>[
        record.id,
        record.startedAt.toUtc().toIso8601String(),
        record.exerciseId,
        record.exerciseName,
        record.mode.name,
        record.reps,
        record.sets,
        record.durationSeconds,
        record.targetReps,
        record.goalReached,
        record.placementScore,
        record.challengeSeconds,
        record.routine?.id,
        record.routine?.name,
        record.routine?.targetReps,
        record.routine?.targetSets,
        record.routine?.restSeconds,
        record.routine?.voiceCoachEnabled,
        quality?.flaggedReps,
        quality?.avgRepSeconds,
        quality?.avgAmplitude,
        quality?.amplitudeDropPercent,
        quality?.leftRightDiffPercent,
        quality?.hasEnoughData == true ? quality!.qualityScore : null,
        quality?.hasEnoughData == true ? quality!.rangeOfMotion : null,
        quality?.hasEnoughData == true ? quality!.cadenceConsistency : null,
        quality?.hasEnoughData == true ? quality!.leftRightBalance : null,
        quality?.hasEnoughData == true ? quality!.poseAlignment : null,
        quality?.hasEnoughData,
        if (includeAi) record.aiFeedback,
      ];
      out.writeln(row.map(_csvCell).join(','));
    }
    return out.toString();
  }

  Map<String, dynamic> _record(WorkoutRecord record, bool includeAi) {
    final quality = record.quality;
    return <String, dynamic>{
      'id': record.id,
      'startedAt': record.startedAt.toUtc().toIso8601String(),
      'exerciseId': record.exerciseId,
      'exerciseName': record.exerciseName,
      'mode': record.mode.name,
      'reps': record.reps,
      'sets': record.sets,
      'durationSeconds': record.durationSeconds,
      'targetReps': record.targetReps,
      'goalReached': record.goalReached,
      'placementScore': record.placementScore,
      'challengeSeconds': record.challengeSeconds,
      if (record.routine != null)
        'routine': <String, dynamic>{
          'id': record.routine!.id,
          'name': record.routine!.name,
          'exerciseId': record.routine!.exerciseId,
          'targetReps': record.routine!.targetReps,
          'targetSets': record.routine!.targetSets,
          'restSeconds': record.routine!.restSeconds,
          'voiceCoachEnabled': record.routine!.voiceCoachEnabled,
        },
      if (quality != null)
        'quality': <String, dynamic>{
          'flaggedReps': quality.flaggedReps,
          'avgRepSeconds': quality.avgRepSeconds,
          'avgAmplitude': quality.avgAmplitude,
          'amplitudeDropPercent': quality.amplitudeDropPercent,
          'leftRightDiffPercent': quality.leftRightDiffPercent,
          'formScore': quality.hasEnoughData ? quality.qualityScore : null,
          'rangeOfMotion': quality.hasEnoughData ? quality.rangeOfMotion : null,
          'cadenceConsistency':
              quality.hasEnoughData ? quality.cadenceConsistency : null,
          'leftRightBalance':
              quality.hasEnoughData ? quality.leftRightBalance : null,
          'poseAlignment': quality.hasEnoughData ? quality.poseAlignment : null,
          'hasEnoughData': quality.hasEnoughData,
        },
      if (includeAi && record.aiFeedback != null)
        'aiFeedback': record.aiFeedback,
    };
  }

  String _csvCell(Object? value) {
    if (value == null) return '';
    final text = value.toString();
    if (!text.contains(',') &&
        !text.contains('"') &&
        !text.contains('\n') &&
        !text.contains('\r')) {
      return text;
    }
    return '"${text.replaceAll('"', '""')}"';
  }

  String _dateStamp(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}'
      '${value.month.toString().padLeft(2, '0')}'
      '${value.day.toString().padLeft(2, '0')}';
}
