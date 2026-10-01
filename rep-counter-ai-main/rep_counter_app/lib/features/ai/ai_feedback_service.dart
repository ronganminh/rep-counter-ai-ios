import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/i18n/app_strings.dart';
import '../../core/legal/legal_config.dart';
import '../workout/data/workout_record.dart';

enum AiFeedbackFailure { notConfigured, timeout, offline, server }

class AiFeedbackException implements Exception {
  const AiFeedbackException(this.failure);
  final AiFeedbackFailure failure;
}

class AiFeedbackService {
  /// Public backend endpoint. The provider API key remains server-side only.
  static const defaultBaseUrl = 'https://repcoach-ai.duckdns.org';
  static const baseUrl =
      String.fromEnvironment('AI_BASE_URL', defaultValue: defaultBaseUrl);

  AiFeedbackService({
    http.Client? client,
    String? baseUrlOverride,
    Duration requestTimeout = const Duration(seconds: 25),
  })  : _client = client,
        _baseUrl = baseUrlOverride ?? baseUrl,
        _requestTimeout = requestTimeout;

  final http.Client? _client;
  final String _baseUrl;
  final Duration _requestTimeout;

  bool get isConfigured => _baseUrl.trim().isNotEmpty;

  /// Production requests must use HTTPS. Tests can use MockClient with an HTTPS
  /// URL without opening a real socket.
  bool get isSecure => Uri.tryParse(_baseUrl)?.scheme == 'https';

  Future<http.Response> _post(Uri uri,
      {required Map<String, String> headers, required String body}) {
    final client = _client;
    return client == null
        ? http.post(uri, headers: headers, body: body)
        : client.post(uri, headers: headers, body: body);
  }

  Future<String> analyze(WorkoutRecord workout, {AppLanguage? language}) async {
    if (!isConfigured || !isSecure) {
      throw const AiFeedbackException(AiFeedbackFailure.notConfigured);
    }

    final requestBody = {
      ...workout.toAiPayload(),
      'schema_version': 2,
      'consent_version': LegalConfig.aiConsentVersion,
      'locale': (language ?? AppLanguage.vi).code,
    };

    late http.Response response;
    try {
      response = await _post(
        Uri.parse(
            '${_baseUrl.replaceAll(RegExp(r'/$'), '')}/v1/workout-feedback'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(_requestTimeout);
    } on TimeoutException {
      throw const AiFeedbackException(AiFeedbackFailure.timeout);
    } on http.ClientException {
      throw const AiFeedbackException(AiFeedbackFailure.offline);
    }

    if (response.statusCode != 200) {
      final errorCode = _readErrorCode(response);
      if (errorCode == 'AI_TIMEOUT') {
        throw const AiFeedbackException(AiFeedbackFailure.timeout);
      }
      throw const AiFeedbackException(AiFeedbackFailure.server);
    }

    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic> ||
          decoded['schema_version'] != 1 ||
          decoded['feedback'] is! String) {
        throw const FormatException();
      }
      final feedback = (decoded['feedback'] as String).trim();
      if (feedback.isEmpty) throw const FormatException();
      return feedback;
    } catch (_) {
      throw const AiFeedbackException(AiFeedbackFailure.server);
    }
  }

  static String? _readErrorCode(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return decoded is Map<String, dynamic> && decoded['error'] is String
          ? decoded['error'] as String
          : null;
    } catch (_) {
      return null;
    }
  }
}
