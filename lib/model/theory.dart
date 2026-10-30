/// Music theory helpers for a major key: degrees, names, cadence, resolutions.
library;

import 'dart:math' as math;

import '../audio/synth.dart';

/// Semitone offsets of the major scale degrees I..VII.
const List<int> majorSteps = [0, 2, 4, 5, 7, 9, 11];

const List<String> romanNames = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII'];
const List<String> solfegeNames = ['Do', 'Re', 'Mi', 'Fa', 'Sol', 'La', 'Si'];

class MusicKey {
  /// Pitch class of the tonic (0 = C).
  final int pc;
  final String name;

  const MusicKey(this.pc, this.name);

  /// Tonic MIDI note kept in a comfortable middle register (F#3..F4).
  int get tonicMidi => pc <= 5 ? 60 + pc : 48 + pc;

  int midiOf(int degree) => tonicMidi + majorSteps[degree];

  /// Note name of a degree, always spelled with sharps (e.g. A♯, never B♭).
  String letterOf(int degree) =>
      sharpNames[(pc + majorSteps[degree]) % 12].replaceAll('#', '♯');

  String display() => name.replaceAll('#', '♯');

  /// Name of the diatonic triad on [degree], e.g. Am for vi in C.
  String chordName(int degree) =>
      '${letterOf(degree)}${const {1, 2, 5}.contains(degree) ? 'm' : ''}';

  /// Relative minor, a minor sixth up from the tonic (C -> Am).
  String relativeMinor() =>
      '${sharpNames[(pc + 9) % 12].replaceAll('#', '♯')}m';
}

const List<String> sharpNames = [
  'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B', //
];

final List<MusicKey> allKeys = [
  for (var pc = 0; pc < 12; pc++) MusicKey(pc, sharpNames[pc]),
];

/// Diatonic chords are major on I, IV, V and minor on ii, iii, vi.
const List<String> chordRomans = ['I', 'ii', 'iii', 'IV', 'V', 'vi', 'vii°'];

enum CadenceStyle { classic, pop, jazz, mix }

/// Cadence progressions per style, as scale degrees. Each ends on I so the
/// tonic is unmistakable before the test note.
const Map<CadenceStyle, List<List<int>>> progressions = {
  CadenceStyle.classic: [
    [0, 3, 4, 0], // I IV V I
    [0, 3, 0, 4, 0], // I IV I V I
  ],
  CadenceStyle.pop: [
    [0, 5, 3, 4, 0], // I vi IV V I
    [0, 4, 5, 3, 0], // I V vi IV I
  ],
  CadenceStyle.jazz: [
    [0, 1, 4, 0], // I ii V I
    [0, 5, 1, 4, 0], // I vi ii V I
  ],
};

/// Progression: each level adds degrees, starting from tonic + dominant.
const List<List<int>> levels = [
  [0, 4], // I V
  [0, 3, 4], // I IV V
  [0, 2, 4], // I III V
  [0, 2, 3, 4], // I III IV V
  [0, 1, 2, 3, 4], // I..V
  [0, 1, 2, 3, 4, 5], // I..VI
  [0, 1, 2, 3, 4, 5, 6], // full scale
];

/// A label shown in the circle while a phrase plays, [at] seconds in.
class Caption {
  final double at;
  final String text;
  final String? sub;

  const Caption(this.at, this.text, [this.sub]);
}

/// Phrases rendered by [Synth].
class Phrases {
  static const _chordLen = 0.55;

  /// Chord on scale degree [d]: bass root below, triad folded into the
  /// octave above the tonic so consecutive chords move smoothly.
  static List<int> _chord(MusicKey key, int d) {
    final t = key.tonicMidi;
    int fold(int x) {
      var m = t + majorSteps[x % 7];
      while (m >= t + 12) {
        m -= 12;
      }
      return m;
    }

    var bass = t - 12 + majorSteps[d];
    if (bass > t - 5) bass -= 12;
    return [bass, fold(d), fold(d + 2), fold(d + 4)];
  }

  /// Chord progression that sets the tonal centre; always ends on I.
  static List<NoteEvent> cadence(MusicKey key, List<int> progression) {
    final out = <NoteEvent>[];
    for (var i = 0; i < progression.length; i++) {
      final last = i == progression.length - 1;
      for (final m in _chord(key, progression[i])) {
        out.add(
          NoteEvent(m, i * _chordLen, last ? 0.9 : _chordLen, velocity: 0.55),
        );
      }
    }
    return out;
  }

  static double cadenceLength(List<int> progression) =>
      _chordLen * (progression.length - 1) + 0.9;

  static List<int> pickProgression(CadenceStyle style, math.Random rng) {
    final pool = style == CadenceStyle.mix
        ? [for (final s in progressions.values) ...s]
        : progressions[style]!;
    return pool[rng.nextInt(pool.length)];
  }

  /// Chord names during the cadence, then "?" for the hidden test note.
  /// A null [progression] means the question is played without a cadence.
  static List<Caption> questionCaptions(
    MusicKey key,
    List<int>? progression,
  ) => [
    if (progression != null)
      for (var i = 0; i < progression.length; i++)
        Caption(
          i * _chordLen,
          key.chordName(progression[i]),
          chordRomans[progression[i]],
        ),
    Caption(progression == null ? 0 : cadenceLength(progression) + 0.45, '?'),
  ];

  /// Cadence, pause, then the test note.
  static List<NoteEvent> question(
    MusicKey key,
    int degree,
    List<int>? progression,
  ) {
    final start = progression == null ? 0.0 : cadenceLength(progression) + 0.45;
    return [
      if (progression != null) ...cadence(key, progression),
      NoteEvent(key.midiOf(degree), start, 1.1, velocity: 0.9),
    ];
  }

  /// Step-wise path from a degree to the nearest tonic
  /// (V, VI, VII go up; the rest go down), as in functional ear training.
  static List<int> resolutionDegrees(int degree) {
    if (degree == 0) return [0];
    if (degree >= 4) return [for (var d = degree; d < 7; d++) d, 0];
    return [for (var d = degree; d >= 0; d--) d];
  }

  static List<int> resolutionPath(MusicKey key, int degree) {
    final ds = resolutionDegrees(degree);
    return [
      for (var i = 0; i < ds.length; i++)
        // The upward path ends on the tonic an octave higher.
        key.midiOf(ds[i]) + (i > 0 && ds[i] == 0 && degree >= 4 ? 12 : 0),
    ];
  }

  static List<Caption> resolutionCaptions(MusicKey key, int degree) {
    final ds = resolutionDegrees(degree);
    return [
      for (var i = 0; i < ds.length; i++)
        Caption(i * 0.32, key.letterOf(ds[i]), romanNames[ds[i]]),
    ];
  }

  static List<NoteEvent> resolution(MusicKey key, int degree) {
    final path = resolutionPath(key, degree);
    return [
      for (var i = 0; i < path.length; i++)
        NoteEvent(
          path[i],
          i * 0.32,
          i == path.length - 1 ? 0.8 : 0.32,
          velocity: 0.8,
        ),
    ];
  }

  /// Total seconds a resolution phrase lasts (used to schedule the next one).
  static double resolutionLength(MusicKey key, int degree) =>
      (resolutionPath(key, degree).length - 1) * 0.32 + 0.8;
}
