import 'dart:math' as math;
import 'dart:typed_data';

/// One note scheduled inside a rendered clip.
class NoteEvent {
  final int midi;
  final double start; // seconds
  final double duration; // seconds
  final double velocity; // 0..1

  const NoteEvent(this.midi, this.start, this.duration, {this.velocity = 0.8});
}

/// Tiny offline synthesizer: renders note events to a 16-bit mono WAV.
///
/// The tone is a soft electric-piano-like additive sound (a few decaying
/// harmonics). Rendering whole phrases into one buffer keeps timing exact,
/// no matter how laggy the platform audio player is.
class Synth {
  static const int sampleRate = 22050;

  static double midiToHz(int midi) => 440.0 * math.pow(2, (midi - 69) / 12);

  /// Harmonic number -> relative amplitude, decay speed multiplier.
  static const List<List<double>> _partials = [
    [1, 1.0, 1.0],
    [2, 0.45, 1.6],
    [3, 0.22, 2.2],
    [4, 0.12, 2.8],
    [5, 0.06, 3.4],
  ];

  Uint8List render(List<NoteEvent> events, {double tail = 0.6}) {
    if (events.isEmpty) return _wav(Float32List(1));
    final end = events.map((e) => e.start + e.duration).reduce(math.max);
    final total = ((end + tail) * sampleRate).ceil();
    final buf = Float32List(total);

    for (final e in events) {
      final f = midiToHz(e.midi);
      final startIdx = (e.start * sampleRate).round();
      // Note rings a bit after its nominal duration, then releases.
      final ringLen = ((e.duration + tail) * sampleRate).round();
      final releaseAt = (e.duration * sampleRate).round();
      const attack = 0.006 * sampleRate;
      final release = 0.25 * sampleRate;
      // Lower notes decay slower, like real strings.
      final baseDecay = 1.6 + (e.midi - 48) * 0.035;

      for (var i = 0; i < ringLen && startIdx + i < total; i++) {
        final t = i / sampleRate;
        var s = 0.0;
        for (final p in _partials) {
          final hz = f * p[0];
          if (hz > sampleRate / 2) break;
          s +=
              p[1] *
              math.exp(-t * baseDecay * p[2]) *
              math.sin(2 * math.pi * hz * t);
        }
        var env = i < attack ? i / attack : 1.0;
        if (i > releaseAt) {
          env *= math.max(0, 1 - (i - releaseAt) / release);
        }
        buf[startIdx + i] += s * env * e.velocity;
      }
    }

    // Normalize with headroom so chords never clip.
    var peak = 0.0;
    for (final v in buf) {
      peak = math.max(peak, v.abs());
    }
    final gain = peak > 0 ? 0.85 / peak : 1.0;
    for (var i = 0; i < total; i++) {
      buf[i] *= gain;
    }
    return _wav(buf);
  }

  Uint8List _wav(Float32List samples) {
    final dataLen = samples.length * 2;
    final b = ByteData(44 + dataLen);
    void str(int off, String s) {
      for (var i = 0; i < s.length; i++) {
        b.setUint8(off + i, s.codeUnitAt(i));
      }
    }

    str(0, 'RIFF');
    b.setUint32(4, 36 + dataLen, Endian.little);
    str(8, 'WAVE');
    str(12, 'fmt ');
    b.setUint32(16, 16, Endian.little); // PCM chunk size
    b.setUint16(20, 1, Endian.little); // PCM
    b.setUint16(22, 1, Endian.little); // mono
    b.setUint32(24, sampleRate, Endian.little);
    b.setUint32(28, sampleRate * 2, Endian.little);
    b.setUint16(32, 2, Endian.little);
    b.setUint16(34, 16, Endian.little);
    str(36, 'data');
    b.setUint32(40, dataLen, Endian.little);
    for (var i = 0; i < samples.length; i++) {
      final v = (samples[i].clamp(-1.0, 1.0) * 32767).round();
      b.setInt16(44 + i * 2, v, Endian.little);
    }
    return b.buffer.asUint8List();
  }
}
