import 'package:shared_preferences/shared_preferences.dart';

class AiPreferences {
  // Provider/data-processing wording changed for Groq production. A new key
  // deliberately makes older automatic-AI opt-in read as disabled.
  static const key = 'automatic_ai_consent_2026_10_01_groq';

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
