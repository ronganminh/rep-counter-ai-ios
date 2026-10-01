import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

Never _fail(String message) => throw StateError(message);

Future<void> main() async {
  final base = (Platform.environment['STAGING_BASE_URL'] ??
          'http://127.0.0.1:8787')
      .replaceAll(RegExp(r'/$'), '');

  final health = await http.get(Uri.parse('$base/health'));
  if (health.statusCode != 200 ||
      (jsonDecode(health.body) as Map<String, dynamic>)['status'] != 'ok') {
    _fail('health failed: ${health.statusCode} ${health.body}');
  }

  final ready = await http.get(Uri.parse('$base/ready'));
  if (ready.statusCode != 200 ||
      (jsonDecode(ready.body) as Map<String, dynamic>)['status'] != 'ready') {
    _fail('readiness failed: ${ready.statusCode} ${ready.body}');
  }

  final fixture =
      await File('../contracts/workout_feedback_v2.json').readAsString();
  final feedback = await http.post(
    Uri.parse('$base/v1/workout-feedback'),
    headers: {'content-type': 'application/json'},
    body: fixture,
  );

  if (feedback.statusCode != 200) {
    _fail('feedback failed: ${feedback.statusCode} ${feedback.body}');
  }
  final decoded = jsonDecode(feedback.body) as Map<String, dynamic>;
  if (decoded['schema_version'] != 1 ||
      decoded['feedback'] is! String ||
      (decoded['feedback'] as String).trim().isEmpty) {
    _fail('unexpected response contract: ${feedback.body}');
  }
  final requestId = feedback.headers['x-request-id'];
  if (requestId == null || !RegExp(r'^[0-9a-f]{32}$').hasMatch(requestId)) {
    _fail('missing/invalid x-request-id: $requestId');
  }

  stdout.writeln(
      'Synthetic staging contract PASS: schema v2 -> response v1, request_id=$requestId');
}
