import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rep_counter_app/core/i18n/app_strings.dart';
import 'package:rep_counter_app/features/ai/ai_feedback_service.dart';
import 'package:rep_counter_app/features/workout/data/workout_record.dart';

WorkoutRecord syntheticWorkout() => WorkoutRecord(
      id: 'local-only-id',
      exerciseId: 'push_up',
      exerciseName: 'Push-up',
      startedAt: DateTime.utc(2026, 10, 1, 2),
      durationSeconds: 120,
      reps: 20,
      sets: 2,
      targetReps: 20,
      poseFrames: 1000,
      readyFrames: 950,
      lostFrames: 20,
      repDetails: const [
        StoredRep(seconds: 1.5, setIndex: 1, flagged: false),
      ],
      quality: const WorkoutQuality(
        flaggedReps: 1,
        avgRepSeconds: 1.5,
        avgAmplitude: 52.0,
        amplitudeDropPercent: 5.0,
        leftRightDiffPercent: 4.0,
        qualityScore: 88,
        rangeOfMotion: 90,
        cadenceConsistency: 88,
        leftRightBalance: 86,
        poseAlignment: 91,
        hasEnoughData: true,
      ),
    );

void main() {
  test('Flutter request matches the shared synthetic v2 contract exactly',
      () async {
    late Map<String, dynamic> sent;
    final client = MockClient((request) async {
      expect(request.url.toString(),
          'https://staging.example.test/v1/workout-feedback');
      expect(request.headers['content-type'], 'application/json');
      sent = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'schema_version': 1,
          'feedback': 'Synthetic staging feedback',
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final service = AiFeedbackService(
      client: client,
      baseUrlOverride: 'https://staging.example.test/',
    );

    final feedback =
        await service.analyze(syntheticWorkout(), language: AppLanguage.en);
    final expected = jsonDecode(
      await File('../contracts/workout_feedback_v2.json').readAsString(),
    ) as Map<String, dynamic>;

    expect(feedback, 'Synthetic staging feedback');
    expect(sent, equals(expected));
    expect(sent, isNot(contains('id')));
    expect(sent, isNot(contains('started_at')));
    expect(sent, isNot(contains('rep_details')));
    expect(sent, isNot(contains('video')));
    expect(sent, isNot(contains('landmarks')));
  });

  test('backend AI_TIMEOUT maps to timeout UI state', () async {
    final service = AiFeedbackService(
      client: MockClient((_) async => http.Response(
            jsonEncode({'error': 'AI_TIMEOUT'}),
            504,
          )),
      baseUrlOverride: 'https://staging.example.test',
    );

    expect(
      () => service.analyze(syntheticWorkout(), language: AppLanguage.en),
      throwsA(isA<AiFeedbackException>().having(
        (error) => error.failure,
        'failure',
        AiFeedbackFailure.timeout,
      )),
    );
  });

  test('client-side timeout remains timeout', () async {
    final completer = Completer<http.Response>();
    final service = AiFeedbackService(
      client: MockClient((_) => completer.future),
      baseUrlOverride: 'https://staging.example.test',
      requestTimeout: const Duration(milliseconds: 1),
    );

    expect(
      () => service.analyze(syntheticWorkout(), language: AppLanguage.en),
      throwsA(isA<AiFeedbackException>().having(
        (error) => error.failure,
        'failure',
        AiFeedbackFailure.timeout,
      )),
    );
  });

  test('offline transport failure remains offline', () async {
    final service = AiFeedbackService(
      client: MockClient((request) async {
        throw http.ClientException('offline', request.url);
      }),
      baseUrlOverride: 'https://staging.example.test',
    );

    expect(
      () => service.analyze(syntheticWorkout(), language: AppLanguage.en),
      throwsA(isA<AiFeedbackException>().having(
        (error) => error.failure,
        'failure',
        AiFeedbackFailure.offline,
      )),
    );
  });

  test('stable backend non-timeout error maps to server state', () async {
    final service = AiFeedbackService(
      client: MockClient((_) async => http.Response(
            jsonEncode({'error': 'AI_UNAVAILABLE'}),
            503,
          )),
      baseUrlOverride: 'https://staging.example.test',
    );

    expect(
      () => service.analyze(syntheticWorkout(), language: AppLanguage.en),
      throwsA(isA<AiFeedbackException>().having(
        (error) => error.failure,
        'failure',
        AiFeedbackFailure.server,
      )),
    );
  });

  test('success response requires response schema version 1', () async {
    final service = AiFeedbackService(
      client: MockClient((_) async => http.Response(
            jsonEncode({'schema_version': 2, 'feedback': 'future response'}),
            200,
          )),
      baseUrlOverride: 'https://staging.example.test',
    );

    expect(
      () => service.analyze(syntheticWorkout(), language: AppLanguage.en),
      throwsA(isA<AiFeedbackException>().having(
        (error) => error.failure,
        'failure',
        AiFeedbackFailure.server,
      )),
    );
  });

  test('release client still refuses insecure AI endpoint', () async {
    final service = AiFeedbackService(
      client: MockClient((_) async => http.Response('{}', 200)),
      baseUrlOverride: 'http://staging.example.test',
    );

    expect(service.isSecure, isFalse);
    expect(
      () => service.analyze(syntheticWorkout()),
      throwsA(isA<AiFeedbackException>().having(
        (error) => error.failure,
        'failure',
        AiFeedbackFailure.notConfigured,
      )),
    );
  });
}
