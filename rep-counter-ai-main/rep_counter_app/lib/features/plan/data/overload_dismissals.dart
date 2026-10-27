import 'package:shared_preferences/shared_preferences.dart';

/// Suggestions the user dismissed (by suggestion key). A dismissed
/// suggestion returns only when its target changes.
class OverloadDismissals {
  static const key = 'overload_dismissed_v1';

  Future<Set<String>> load() async =>
      {...(await SharedPreferences.getInstance()).getStringList(key) ?? []};

  Future<void> add(String suggestionKey) async {
    final prefs = await SharedPreferences.getInstance();
    final next = {...prefs.getStringList(key) ?? <String>[], suggestionKey};
    await prefs.setStringList(key, next.toList());
  }
}
