import 'package:ears/audio/synth.dart';
import 'package:ears/model/theory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('note names use sharps', () {
    final g = allKeys.firstWhere((k) => k.name == 'G');
    final ds = allKeys.firstWhere((k) => k.name == 'D#');
    expect(
      [for (var d = 0; d < 7; d++) g.letterOf(d)],
      ['G', 'A', 'B', 'C', 'D', 'E', 'F♯'],
    );
    expect(
      [for (var d = 0; d < 7; d++) ds.letterOf(d)],
      ['D♯', 'F', 'G', 'G♯', 'A♯', 'C', 'D'],
    );
  });

  test('resolutions end on a tonic', () {
    const c = MusicKey(0, 'C');
    expect(Phrases.resolutionPath(c, 2), [64, 62, 60]);
    expect(Phrases.resolutionPath(c, 4), [67, 69, 71, 72]);
  });

  test('synth renders a valid WAV', () {
    final wav = Synth().render(
      Phrases.question(const MusicKey(0, 'C'), 4, const [0, 3, 4, 0]),
    );
    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(wav.length, greaterThan(44 + Synth.sampleRate * 2 * 3));
  });

  test('captions follow cadence and resolution', () {
    const c = MusicKey(0, 'C');
    expect(Phrases.questionCaptions(c, const [0, 3, 4, 0]).map((x) => x.text), [
      'C',
      'F',
      'G',
      'C',
      '?',
    ]);
    expect(Phrases.resolutionCaptions(c, 5).map((x) => x.text), [
      'A',
      'B',
      'C',
    ]);
  });

  test('pop cadence names minor chords', () {
    const c = MusicKey(0, 'C');
    expect(
      Phrases.questionCaptions(c, const [0, 5, 3, 4, 0]).map((x) => x.text),
      ['C', 'Am', 'F', 'G', 'C', '?'],
    );
  });
}
