import 'package:shared_preferences/shared_preferences.dart';

class AiPreferences {
  static const key = 'automatic_ai_consent_v1';
  static Future<bool> enabled() async =>
      (await SharedPreferences.getInstance()).getBool(key) == true;
  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      if (!await prefs.setBool(key, value)) {
        throw StateError('Cannot save AI consent');
      }
    } catch (_) {
      try {
        await prefs.reload();
      } catch (_) {}
      rethrow;
    }
  }
}
