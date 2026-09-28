import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;

import '../../core/i18n/app_strings.dart';
import '../workout/data/workout_record.dart';

enum AiFeedbackFailure { notConfigured, timeout, offline, server }

class AiFeedbackException implements Exception {
  const AiFeedbackException(this.failure);
  final AiFeedbackFailure failure;
}

class AiFeedbackService {
  /// Địa chỉ backend. Không phải bí mật — chỉ là endpoint công khai — nên để
  /// mặc định ở đây cho bản build thường dùng được ngay, thay vì bắt mọi lệnh
  /// build phải nhớ truyền `--dart-define`.
  ///
  /// Vẫn ghi đè được khi cần trỏ sang máy chủ khác:
  ///   flutter build appbundle --release --dart-define=AI_BASE_URL=https://...
  ///
  /// KHÓA API vẫn nằm hoàn toàn ở phía server (ADR 0001) — app không bao giờ
  /// chứa key.
  static const defaultBaseUrl = 'https://repcoach-ai.duckdns.org';
  static const baseUrl =
      String.fromEnvironment('AI_BASE_URL', defaultValue: defaultBaseUrl);

  bool get isConfigured => baseUrl.trim().isNotEmpty;

  /// Chỉ chấp nhận HTTPS. Bản phát hành lỡ trỏ vào `http://` hay địa chỉ LAN
  /// thì hỏng cả quyền riêng tư lẫn điều kiện của Google Play (§14.1).
  bool get isSecure => Uri.tryParse(baseUrl)?.scheme == 'https';

  Future<String> analyze(WorkoutRecord workout, {AppLanguage? language}) async {
    if (!isConfigured || !isSecure) {
      throw const AiFeedbackException(AiFeedbackFailure.notConfigured);
    }
    late http.Response response;
    try {
      response = await http.post(
          Uri.parse('${baseUrl.replaceAll(RegExp(r'/$'), '')}/v1/workout-feedback'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({
            ...workout.toAiPayload(),
            // Backend dùng để chọn ngôn ngữ viết nhận xét.
            'locale': (language ?? AppLanguage.vi).code,
          }),
        ).timeout(const Duration(seconds: 25));
    } on TimeoutException {
      throw const AiFeedbackException(AiFeedbackFailure.timeout);
    } on http.ClientException {
      throw const AiFeedbackException(AiFeedbackFailure.offline);
    }
    if (response.statusCode != 200) {
      throw const AiFeedbackException(AiFeedbackFailure.server);
    }
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final feedback = body['feedback'] as String;
      if (feedback.trim().isEmpty) throw const FormatException();
      return feedback;
    } catch (_) {
      throw const AiFeedbackException(AiFeedbackFailure.server);
    }
  }
}
