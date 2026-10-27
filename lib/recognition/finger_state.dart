import 'dart:math' as math;

import 'letter_classifier.dart';

/// Which fingers are extended, read from normalized hand features
/// (the 60 values from `normalizeHand`; wrist is the origin, wrist -> middle
/// finger base has length 1).
///
/// PROTOTYPE: thresholds are first guesses and need tuning on a real phone.
/// This is rule-based, not a trained model.
const List<String> fingerNames = [
  'thumb',
  'index finger',
  'middle finger',
  'ring finger',
  'pinky',
];

// A finger is "extended" when its tip is this much farther from the wrist
// than its middle joint (PIP).
const double _extendRatio = 1.1;

// The thumb is "extended" when its tip is farther than this from the base of
// the index finger (units of palm length).
const double _thumbOut = 0.75;

List<double> _p(List<double> f, int lm) => lm == 0
    ? const [0.0, 0.0, 0.0]
    : [f[(lm - 1) * 3], f[(lm - 1) * 3 + 1], f[(lm - 1) * 3 + 2]];

double _d(List<double> a, List<double> b) {
  final dx = a[0] - b[0];
  final dy = a[1] - b[1];
  final dz = a[2] - b[2];
  return math.sqrt(dx * dx + dy * dy + dz * dz);
}

class FingerStates {
  const FingerStates(this.extended);

  /// [thumb, index, middle, ring, pinky]
  final List<bool> extended;

  factory FingerStates.fromFeatures(List<double> f) {
    if (f.length != 60) {
      throw ArgumentError('Expected 60 features, got ${f.length}.');
    }
    final wrist = _p(f, 0);
    bool finger(int tip, int pip) =>
        _d(_p(f, tip), wrist) > _d(_p(f, pip), wrist) * _extendRatio;

    return FingerStates([
      _d(_p(f, 4), _p(f, 5)) > _thumbOut,
      finger(8, 6),
      finger(12, 10),
      finger(16, 14),
      finger(20, 18),
    ]);
  }

  @override
  String toString() => extended.map((e) => e ? '1' : '0').join();
}

/// Finger patterns [thumb, index, middle, ring, pinky] for letters that a
/// finger-state check can tell apart. Many letters (C, E, F, M, N, O, P, Q,
/// R, T, U, X, ...) cannot be told apart this way and are NOT included.
/// U looks the same as V here, so U is left out on purpose.
const Map<String, List<bool>> letterRules = {
  'A': [true, false, false, false, false],
  'S': [false, false, false, false, false],
  'B': [false, true, true, true, true],
  'D': [false, true, false, false, false],
  'I': [false, false, false, false, true],
  'L': [true, true, false, false, false],
  'V': [false, true, true, false, false],
  'W': [false, true, true, true, false],
  'Y': [true, false, false, false, true],
};

class FingerFeedback {
  const FingerFeedback({
    required this.hasRule,
    required this.correct,
    required this.hints,
  });

  /// False when this letter has no rule (needs the trained model).
  final bool hasRule;
  final bool correct;
  final List<String> hints;
}

FingerFeedback feedbackFor(String letter, FingerStates actual) {
  final expected = letterRules[letter];
  if (expected == null) {
    return const FingerFeedback(
      hasRule: false,
      correct: false,
      hints: ['No quick check for this letter yet. It needs the trained model.'],
    );
  }
  final hints = <String>[];
  for (var i = 0; i < 5; i++) {
    if (expected[i] && !actual.extended[i]) {
      hints.add('Extend your ${fingerNames[i]}');
    } else if (!expected[i] && actual.extended[i]) {
      hints.add('Curl your ${fingerNames[i]}');
    }
  }
  if (hints.isEmpty) {
    return const FingerFeedback(
      hasRule: true,
      correct: true,
      hints: ['Looks right!'],
    );
  }
  return FingerFeedback(hasRule: true, correct: false, hints: hints);
}

/// Demo recognizer for the few letters in [letterRules]. Lets the app work
/// end to end before a trained model exists. Not accurate enough to be the
/// final answer: say so in the thesis.
class RuleLetterClassifier implements LetterClassifier {
  const RuleLetterClassifier();

  @override
  bool get isReady => true;

  @override
  LetterPrediction? classify(List<double> features) {
    final states = FingerStates.fromFeatures(features).extended;
    for (final e in letterRules.entries) {
      var same = true;
      for (var i = 0; i < 5; i++) {
        if (e.value[i] != states[i]) {
          same = false;
          break;
        }
      }
      if (same) return LetterPrediction(e.key, 0.85);
    }
    return null;
  }
}
