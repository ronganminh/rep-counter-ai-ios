enum RepSpeechCadence {
  everyRep,
  every5Reps,
  milestonesOnly,
}

import 'package:shared_preferences/shared_preferences.dart';

/// Device-local preferences. No camera data or AI configuration is stored here.
class TrainingPreferences {
  const TrainingPreferences({
    this.voice = true,
    this.haptics = true,
    this.sound = false,
    this.cues = true,
    this.repSpeechCadence = RepSpeechCadence.everyRep,
  });

  final bool voice, haptics, sound, cues;
  final RepSpeechCadence repSpeechCadence;

  static const voiceKey = 'training_voice_v1';
  static const soundKey = 'training_sound_v1';
  static const cuesKey = 'training_cues_v1';
  static const hapticsKey = 'training_haptics_v1';
  static const repSpeechCadenceKey = 'training_rep_speech_cadence_v1';

  static Future<TrainingPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    return TrainingPreferences(
      voice: prefs.getBool(voiceKey) ?? true,
      haptics: prefs.getBool(hapticsKey) ?? true,
      sound: prefs.getBool(soundKey) ?? false,
      cues: prefs.getBool(cuesKey) ?? true,
      repSpeechCadence: _parseCadence(
        prefs.getString(repSpeechCadenceKey),
      ),
    );
  }

  Future<TrainingPreferences> update({
    bool? voice,
    bool? haptics,
    bool? sound,
    bool? cues,
    RepSpeechCadence? repSpeechCadence,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (voice != null && !await prefs.setBool(voiceKey, voice)) {
      throw StateError('Cannot save voice setting');
    }
    if (haptics != null && !await prefs.setBool(hapticsKey, haptics)) {
      throw StateError('Cannot save haptic setting');
    }
    if (sound != null && !await prefs.setBool(soundKey, sound)) {
      throw StateError('Cannot save sound');
    }
    if (cues != null && !await prefs.setBool(cuesKey, cues)) {
      throw StateError('Cannot save cues');
    }
    if (repSpeechCadence != null &&
        !await prefs.setString(
          repSpeechCadenceKey,
          repSpeechCadence.name,
        )) {
      throw StateError('Cannot save rep speech cadence');
    }
    return TrainingPreferences(
      voice: voice ?? this.voice,
      haptics: haptics ?? this.haptics,
      sound: sound ?? this.sound,
      cues: cues ?? this.cues,
      repSpeechCadence: repSpeechCadence ?? this.repSpeechCadence,
    );
  }

  static RepSpeechCadence _parseCadence(String? value) {
    for (final cadence in RepSpeechCadence.values) {
      if (cadence.name == value) return cadence;
    }
    return RepSpeechCadence.everyRep;
  }
}
