import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../i18n/app_strings.dart';
import 'training_preferences.dart';
import 'set_sounds.dart';

abstract interface class SpeechDriver {
  Future<void> configure(String locale);
  Future<void> speak(String text);
  Future<void> stop();
}

class SystemSpeechDriver implements SpeechDriver {
  final _tts = FlutterTts();
  String? _locale;
  @override
  Future<void> configure(String locale) async {
    if (_locale == locale) return;
    if (await _tts.isLanguageAvailable(locale) != true) {
      throw StateError('Voice unavailable: $locale');
    }
    // Native calls return when accepted, not after the whole utterance. Each
    // new event explicitly stops the previous one, so old rep counts cannot queue.
    await _tts.awaitSpeakCompletion(false);
    if (Platform.isIOS) {
      await _tts.setSharedInstance(true);
      await _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.ambient,
          [IosTextToSpeechAudioCategoryOptions.mixWithOthers]);
    }
    if (Platform.isAndroid) await _tts.setQueueMode(0);
    await _tts.setLanguage(locale);
    await _tts.setSpeechRate(.5);
    _locale = locale;
  }

  @override
  Future<void> speak(String text) async {
    if (await _tts.speak(text) != 1) throw StateError('Speech rejected');
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
  }
}

/// Side effects consume events, never widget builds. The latest speech wins.
/// Serializing native commands prevents a late stop from silencing a newer rep.
class WorkoutFeedback {
  WorkoutFeedback(
      {SpeechDriver? speech,
      Future<void> Function(bool success)? haptic,
      this.onVoiceUnavailable,
      Future<void> Function(bool start)? sound})
      : _speech = speech ?? SystemSpeechDriver(),
        _sound = sound,
        _haptic = haptic ??
            ((success) => success
                ? HapticFeedback.mediumImpact()
                : HapticFeedback.lightImpact());
  final SpeechDriver _speech;
  final Future<void> Function(bool)? _sound;
  final _sounds = SetSounds();
  Duration? _lastCue;
  final Future<void> Function(bool) _haptic;
  final void Function()? onVoiceUnavailable;
  TrainingPreferences preferences = const TrainingPreferences();
  AppLanguage language = AppLanguage.vi;
  Future<void> _commands = Future.value();
  bool _disposed = false, _voiceFailed = false;
  int _generation = 0, _lastRep = 0;

  void configure(TrainingPreferences value, AppLanguage locale) {
    final changed = preferences.voice != value.voice ||
        preferences.repSpeechCadence != value.repSpeechCadence ||
        language != locale;
    if (preferences.sound && !value.sound) _sounds.stop();
    preferences = value;
    language = locale;
    if (changed) {
      _voiceFailed = false;
      stop();
    }
  }

  void rep(int number, {required bool goalReached, String? cue, Duration? at}) {
    if (_disposed || number <= _lastRep) return;
    _lastRep = number;
    _vibrate(goalReached);

    final cueText =
        cue != null && at != null && _canCue(at) ? cue : null;
    final speakCount = switch (preferences.repSpeechCadence) {
      RepSpeechCadence.everyRep => true,
      RepSpeechCadence.every5Reps => number % 5 == 0,
      RepSpeechCadence.milestonesOnly => goalReached,
    };

    if (goalReached) {
      _say(
        '$number. ${language == AppLanguage.vi ? 'Đạt mục tiêu!' : 'Goal reached!'}',
      );
    } else if (speakCount && cueText != null) {
      _say('$number. $cueText');
    } else if (speakCount) {
      _say('$number');
    } else if (cueText != null) {
      // Posture reminders are independent from the rep-count cadence.
      _say(cueText);
    }
  }

  void countdown(int value) {
    if (_disposed) return;
    _vibrate(false);
    _say(language == AppLanguage.vi
        ? const {3: 'Ba', 2: 'Hai', 1: 'Một'}[value]!
        : '$value');
  }

  void started() {
    _vibrate(true);
    _say(language == AppLanguage.vi ? 'Bắt đầu!' : 'Go!');
  }

  /// Time-driven final countdown. Speech follows the existing voice setting;
  /// haptics stay deliberately subtle and only mark the last three seconds.
  void challengeCountdown(int seconds) {
    if (_disposed || seconds < 1 || seconds > 10) return;
    if (seconds <= 3) _vibrate(false);
    _say('$seconds');
  }

  void routineRest({
    required int completedSet,
    required int restSeconds,
  }) {
    if (_disposed) return;
    _say(language == AppLanguage.vi
        ? 'Hoàn thành set $completedSet. Nghỉ $restSeconds giây.'
        : 'Set $completedSet complete. Rest for $restSeconds seconds.');
  }

  void routineResume(int nextSet) {
    if (_disposed) return;
    _say(language == AppLanguage.vi
        ? 'Bắt đầu set $nextSet.'
        : 'Start set $nextSet.');
  }

  bool _canCue(Duration at) {
    if (!preferences.voice || !preferences.cues || _disposed) return false;
    if (_lastCue != null && at - _lastCue! < const Duration(seconds: 8)) {
      return false;
    }
    _lastCue = at;
    return true;
  }

  void cue(String text, Duration at) {
    if (text.isNotEmpty && _canCue(at)) _say(text);
  }

  void setBoundary(bool start) {
    if (_disposed || !preferences.sound) return;
    unawaited(
        (_sound?.call(start) ?? _sounds.play(start)).catchError((Object _) {}));
  }

  void _vibrate(bool success) {
    if (!_disposed && preferences.haptics) {
      unawaited(_haptic(success).catchError((Object _) {}));
    }
  }

  void _say(String text) {
    if (_disposed || !preferences.voice || _voiceFailed) return;
    final generation = ++_generation;
    _commands = _commands.then((_) async {
      if (_disposed || generation != _generation) return;
      try {
        await _speech.stop().timeout(const Duration(seconds: 2));
        if (_disposed || generation != _generation) return;
        await _speech
            .configure(language == AppLanguage.vi ? 'vi-VN' : 'en-US')
            .timeout(const Duration(seconds: 3));
        if (_disposed || generation != _generation) return;
        await _speech.speak(text).timeout(const Duration(seconds: 2));
      } catch (_) {
        if (!_disposed && generation == _generation && !_voiceFailed) {
          _voiceFailed = true;
          onVoiceUnavailable?.call();
        }
      }
    });
  }

  /// Invalidate pending speech first. Pause/mute/dispose never replays old reps.
  void stop() {
    ++_generation;
    _sounds.stop();
    _commands = _commands.then((_) async {
      try {
        await _speech.stop().timeout(const Duration(seconds: 2));
      } catch (_) {/* No speech must block counting. */}
    });
  }

  Future<void> get settled => _commands;
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    stop();
    _sounds.dispose();
  }
}
