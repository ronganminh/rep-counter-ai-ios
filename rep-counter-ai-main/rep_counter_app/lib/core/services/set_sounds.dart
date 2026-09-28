import 'package:audioplayers/audioplayers.dart';

/// Lazily creates native audio resources only when sound is enabled.
class SetSounds {
  AudioPlayer? _player;
  bool _disposed = false;
  int _generation = 0;
  Future<void> _pending = Future.value();
  Future<void> play(bool start) {
    final generation = ++_generation;
    return _pending = _pending.then((_) async {
      if (_disposed || generation != _generation) return;
      try {
        final player = _player ??= AudioPlayer();
        await player.setAudioContext(AudioContext(
            iOS: AudioContextIOS(
                category: AVAudioSessionCategory.ambient,
                options: const {AVAudioSessionOptions.mixWithOthers}),
            android: const AudioContextAndroid(
                usageType: AndroidUsageType.assistanceSonification,
                audioFocus: AndroidAudioFocus.none)));
        if (_disposed || generation != _generation) return;
        await player.play(
            AssetSource(start ? 'audio/set-start.wav' : 'audio/set-end.wav'));
      } catch (_) {/* Audio cannot block the workout. */}
    });
  }

  void stop() {
    _generation++;
    _pending = _pending.then((_) async {
      try {
        await _player?.stop();
      } catch (_) {}
    });
  }

  void dispose() {
    _disposed = true;
    _generation++;
    _pending = _pending.then((_) async {
      try {
        await _player?.dispose();
      } catch (_) {}
    });
  }
}
