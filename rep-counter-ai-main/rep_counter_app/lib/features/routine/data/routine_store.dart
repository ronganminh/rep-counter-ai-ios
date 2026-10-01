import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/routine_preset.dart';

class RoutineStore {
  static const _key = 'routine_presets_v1';
  static Future<void>? _pending;

  static Future<T> _serial<T>(Future<T> Function() operation) {
    final next =
        _pending == null ? operation() : _pending!.then((_) => operation());
    final barrier =
        next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    _pending = barrier;
    return next.whenComplete(() {
      if (identical(_pending, barrier)) _pending = null;
    });
  }

  Future<List<RoutinePreset>> load() => _serial(() async {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getStringList(_key) ?? const <String>[];
        final out = <RoutinePreset>[];
        for (final entry in raw) {
          try {
            out.add(RoutinePreset.fromJson(
              jsonDecode(entry) as Map<String, dynamic>,
            ));
          } catch (_) {
            // A malformed/future entry cannot make every valid local routine
            // unusable. Mutations rewrite only the readable v1 collection.
          }
        }
        return out;
      });

  Future<void> save(RoutinePreset preset) => _serial(() async {
        preset.validate();
        final prefs = await SharedPreferences.getInstance();
        final current = <RoutinePreset>[];
        for (final entry in prefs.getStringList(_key) ?? const <String>[]) {
          try {
            current.add(RoutinePreset.fromJson(
              jsonDecode(entry) as Map<String, dynamic>,
            ));
          } catch (_) {}
        }
        final index = current.indexWhere((item) => item.id == preset.id);
        if (index < 0) {
          current.add(preset);
        } else {
          current[index] = preset;
        }
        await _write(prefs, current);
      });

  Future<void> delete(String id) => _serial(() async {
        final prefs = await SharedPreferences.getInstance();
        final current = <RoutinePreset>[];
        for (final entry in prefs.getStringList(_key) ?? const <String>[]) {
          try {
            current.add(RoutinePreset.fromJson(
              jsonDecode(entry) as Map<String, dynamic>,
            ));
          } catch (_) {}
        }
        current.removeWhere((item) => item.id == id);
        await _write(prefs, current);
      });

  Future<void> _write(
    SharedPreferences prefs,
    List<RoutinePreset> presets,
  ) async {
    final raw = [
      for (final preset in presets) jsonEncode(preset.toJson()),
    ];
    if (!await prefs.setStringList(_key, raw)) {
      throw StateError('Cannot write routine presets');
    }
  }
}
