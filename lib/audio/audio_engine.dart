import 'package:audioplayers/audioplayers.dart';

import 'synth.dart';

/// Plays phrases rendered by [Synth]. One player, newest phrase wins.
class AudioEngine {
  final _synth = Synth();
  final _player = AudioPlayer();

  AudioEngine() {
    _player.setReleaseMode(ReleaseMode.stop);
    AudioPlayer.global.setAudioContext(
      AudioContextConfig(
        // Play even when the iPhone mute switch is on: this is a music app.
        respectSilence: false,
      ).build(),
    );
  }

  Future<void> play(List<NoteEvent> events) async {
    final bytes = _synth.render(events);
    await _player.stop();
    await _player.play(BytesSource(bytes, mimeType: 'audio/wav'));
  }

  Future<void> stop() => _player.stop();

  void dispose() => _player.dispose();
}
