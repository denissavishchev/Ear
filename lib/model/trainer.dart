import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio/audio_engine.dart';
import '../audio/synth.dart';
import 'theory.dart';

enum Phase { idle, listening, wrong, correct }

/// Correct answers in a row needed to unlock the next level.
const int unlockStreak = 10;

class Trainer extends ChangeNotifier {
  final AudioEngine _audio;
  final _rng = math.Random();
  SharedPreferences? _prefs;
  Timer? _nextTimer;
  final List<Timer> _captionTimers = [];
  int _playGen = 0;

  Trainer(this._audio);

  // Settings
  int level = 0;
  int unlockedLevel = 0;
  int keyIndex = 0;
  bool cadenceEveryTime = true;
  CadenceStyle cadenceStyle = CadenceStyle.classic;

  // Session
  Phase phase = Phase.idle;
  int? degree;

  /// Cadence picked for the current question; replays reuse it.
  List<int> _progression = progressions[CadenceStyle.classic]!.first;
  final Set<int> wrongTries = {};
  int streak = 0;
  int correct = 0;
  int total = 0;
  int questionsAsked = 0;
  bool justUnlocked = false;

  /// What the circle shows right now, in sync with the sound.
  Caption? caption;
  int captionTick = 0;

  MusicKey get key => allKeys[keyIndex];
  List<int> get degrees => levels[level];

  Future<void> load() async {
    final p = _prefs = await SharedPreferences.getInstance();
    unlockedLevel = p.getInt('unlocked') ?? 0;
    level = (p.getInt('level') ?? 0).clamp(0, unlockedLevel);
    keyIndex = (p.getInt('key') ?? 0).clamp(0, allKeys.length - 1);
    cadenceEveryTime = p.getBool('cadence') ?? true;
    cadenceStyle =
        CadenceStyle.values[(p.getInt('style') ?? 0).clamp(
          0,
          CadenceStyle.values.length - 1,
        )];
    notifyListeners();
  }

  void _save() {
    final p = _prefs;
    if (p == null) return;
    p.setInt('unlocked', unlockedLevel);
    p.setInt('level', level);
    p.setInt('key', keyIndex);
    p.setBool('cadence', cadenceEveryTime);
    p.setInt('style', cadenceStyle.index);
  }

  // ---- Flow ---------------------------------------------------------------

  /// Tap on the big circle: start, or replay the current question.
  void tapCircle() {
    if (phase == Phase.idle || phase == Phase.correct) {
      next();
    } else {
      _play(
        Phrases.question(key, degree!, _progression),
        Phrases.questionCaptions(key, _progression),
      );
    }
  }

  /// Plays a phrase and steps [caption] through [captions] as it sounds.
  Future<void> _play(List<NoteEvent> events, List<Caption> captions) async {
    final gen = ++_playGen;
    _clearCaptions();
    await _audio.play(events);
    // Timers start once playback has started, so labels match the sound.
    if (gen != _playGen) return;
    for (final c in captions) {
      _captionTimers.add(
        Timer(Duration(milliseconds: (c.at * 1000).round()), () {
          caption = c;
          captionTick++;
          notifyListeners();
        }),
      );
    }
  }

  void _clearCaptions() {
    for (final t in _captionTimers) {
      t.cancel();
    }
    _captionTimers.clear();
    caption = null;
  }

  void next() {
    _nextTimer?.cancel();
    final pool = degrees;
    var d = pool[_rng.nextInt(pool.length)];
    // Make immediate repeats less likely.
    if (d == degree && pool.length > 1 && _rng.nextBool()) {
      d = pool[_rng.nextInt(pool.length)];
    }
    degree = d;
    wrongTries.clear();
    justUnlocked = false;
    phase = Phase.listening;
    _progression = Phrases.pickProgression(cadenceStyle, _rng);
    final cadence = cadenceEveryTime || questionsAsked % 5 == 0
        ? _progression
        : null;
    questionsAsked++;
    _play(
      Phrases.question(key, d, cadence),
      Phrases.questionCaptions(key, cadence),
    );
    notifyListeners();
  }

  void answer(int choice) {
    if (phase != Phase.listening && phase != Phase.wrong) return;
    if (wrongTries.contains(choice)) return;
    final firstTry = wrongTries.isEmpty;

    if (choice == degree) {
      if (firstTry) {
        correct++;
        total++;
        streak++;
        if (streak >= unlockStreak &&
            level == unlockedLevel &&
            unlockedLevel < levels.length - 1) {
          unlockedLevel++;
          justUnlocked = true;
          _save();
        }
      }
      phase = Phase.correct;
      _play(
        Phrases.resolution(key, choice),
        Phrases.resolutionCaptions(key, choice),
      );
      final wait = Phrases.resolutionLength(key, choice) + 0.7;
      _nextTimer = Timer(Duration(milliseconds: (wait * 1000).round()), next);
    } else {
      if (firstTry) {
        total++;
        streak = 0;
      }
      wrongTries.add(choice);
      phase = Phase.wrong;
      // Let the ear compare: your answer, then the real note.
      _play(
        [
          NoteEvent(key.midiOf(choice), 0, 0.5, velocity: 0.6),
          NoteEvent(key.midiOf(degree!), 0.75, 1.0, velocity: 0.9),
        ],
        [
          Caption(0, key.letterOf(choice), romanNames[choice]),
          const Caption(0.75, '?'),
        ],
      );
    }
    notifyListeners();
  }

  // ---- Settings -----------------------------------------------------------

  void setLevel(int l) {
    if (l < 0 || l > unlockedLevel || l == level) return;
    level = l;
    streak = 0;
    _restart();
  }

  void setKey(int i) {
    keyIndex = i;
    _restart();
  }

  void setCadenceStyle(CadenceStyle s) {
    cadenceStyle = s;
    _save();
    notifyListeners();
  }

  void setCadenceEveryTime(bool v) {
    cadenceEveryTime = v;
    _save();
    notifyListeners();
  }

  void _restart() {
    _nextTimer?.cancel();
    _playGen++;
    _clearCaptions();
    _audio.stop();
    phase = Phase.idle;
    degree = null;
    wrongTries.clear();
    questionsAsked = 0;
    _save();
    notifyListeners();
  }

  @override
  void dispose() {
    _nextTimer?.cancel();
    _clearCaptions();
    _audio.dispose();
    super.dispose();
  }
}
