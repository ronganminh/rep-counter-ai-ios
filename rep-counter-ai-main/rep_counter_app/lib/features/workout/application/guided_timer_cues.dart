import 'dart:async';
import 'dart:io';

import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/i18n/app_strings.dart';
import '../../../core/services/training_preferences.dart';
import '../../../core/services/workout_feedback.dart'
    show SpeechDriver, SystemSpeechDriver;

/// Keeps the screen on; replaced in tests.
abstract interface class ScreenAwake {
  Future<void> set(bool on);
}

class WakelockScreenAwake implements ScreenAwake {
  const WakelockScreenAwake();

  @override
  Future<void> set(bool on) => WakelockPlus.toggle(enable: on);
}

/// X-2: what the guided timer says and whether it keeps the screen on.
///
/// Speech uses the app's system voice in the app language (the same
/// [SystemSpeechDriver] as live coaching: mixes with music, normal rate)
/// and follows the existing settings: it needs [TrainingPreferences.voice]
/// and the timer's own [TrainingPreferences.timerVoice] (on by default).
/// Like workout feedback, the latest cue wins and a failing voice never
/// blocks the timer. The screen stays on only while the timer counts
/// (work or rest, not paused, not done) and [TrainingPreferences.timerKeepAwake]
/// is on; leaving the page always releases it.
class GuidedTimerCues {
  GuidedTimerCues({SpeechDriver? speech, ScreenAwake? awake})
      : _speech = speech ?? (_inTests ? _NoSpeech() : SystemSpeechDriver()),
        _awake = awake ?? (_inTests ? _NoAwake() : const WakelockScreenAwake());

  /// Widget tests have no TTS or wakelock plugin; they inject fakes to
  /// check the cues.
  static final bool _inTests = Platform.environment.containsKey('FLUTTER_TEST');

  final SpeechDriver _speech;
  final ScreenAwake _awake;
  TrainingPreferences preferences = const TrainingPreferences();
  AppLanguage language = AppLanguage.en;
  Future<void> _commands = Future.value();
  int _generation = 0;
  bool _disposed = false, _voiceFailed = false, _awakeOn = false;
  bool _spoke = false;

  bool get _vi => language == AppLanguage.vi;
  bool get speaks => preferences.voice && preferences.timerVoice;

  void configure(TrainingPreferences value, AppLanguage locale) {
    preferences = value;
    language = locale;
  }

  void setStarted(int set, int sets) =>
      _say(_vi ? 'Set $set trên $sets. Bắt đầu!' : 'Set $set of $sets. Go!');

  void halfway() => _say(_vi ? 'Được một nửa.' : 'Halfway.');

  /// The last three seconds of a set or of a rest.
  void countdown(int seconds) {
    if (seconds >= 1 && seconds <= 3) {
      _say(_vi ? const {3: 'Ba', 2: 'Hai', 1: 'Một'}[seconds]! : '$seconds');
    }
  }

  void rest(int seconds) =>
      _say(_vi ? 'Nghỉ $seconds giây.' : 'Rest for $seconds seconds.');

  void finished() => _say(_vi ? 'Hoàn thành!' : 'Done!');

  /// Called whenever the timer's state changes.
  void counting(bool active) {
    final want = active && preferences.timerKeepAwake && !_disposed;
    if (want == _awakeOn) return;
    _awakeOn = want;
    unawaited(_awake.set(want).catchError((Object _) {}));
  }

  void _say(String text) {
    if (_disposed || !speaks || _voiceFailed) return;
    final generation = ++_generation;
    _spoke = true;
    _commands = _commands.then((_) async {
      if (_disposed || generation != _generation) return;
      try {
        await _speech.stop().timeout(const Duration(seconds: 2));
        if (_disposed || generation != _generation) return;
        await _speech
            .configure(_vi ? 'vi-VN' : 'en-US')
            .timeout(const Duration(seconds: 3));
        if (_disposed || generation != _generation) return;
        await _speech.speak(text).timeout(const Duration(seconds: 2));
      } catch (_) {
        _voiceFailed = true; // the on-screen timer carries on
      }
    });
  }

  Future<void> get settled => _commands;

  void dispose() {
    if (_disposed) return;
    counting(false);
    _disposed = true;
    ++_generation; // pending cues are dropped
    if (_spoke) {
      // Fire and forget: leaving the page must not wait on the voice.
      unawaited(_speech.stop().catchError((Object _) {}));
    }
  }
}

class _NoSpeech implements SpeechDriver {
  @override
  Future<void> configure(String locale) async {}
  @override
  Future<void> speak(String text) async {}
  @override
  Future<void> stop() async {}
}

class _NoAwake implements ScreenAwake {
  @override
  Future<void> set(bool on) async {}
}
