import 'package:flutter/foundation.dart';
import 'package:signara_landmarks/signara_landmarks.dart';

import 'landmark_features.dart';
import 'letter_classifier.dart';
import 'letter_stabilizer.dart';
import 'spelling_buffer.dart';

/// Landmarks in -> letters and words out. No camera or UI code in here, so it
/// can be tested without a phone.
class FingerspellingController extends ChangeNotifier {
  FingerspellingController({
    required this.classifier,
    LetterStabilizer? stabilizer,
    this.aspect = 3 / 4,
    this.flipX = false,
    this.wordGapFrames = 45,
  }) : stabilizer = stabilizer ?? LetterStabilizer();

  final LetterClassifier classifier;
  final LetterStabilizer stabilizer;

  /// Image width / height of the upright frames (portrait 480x640 -> 0.75).
  final double aspect;

  /// Must match how the training data was prepared (see training/README.md).
  final bool flipX;

  /// Frames with no hand after which the current word is ended (~1.5s at 30fps).
  final int wordGapFrames;

  final SpellingBuffer buffer = SpellingBuffer();

  /// What the classifier sees right now (not yet committed).
  LetterPrediction? live;

  int _noHandRun = 0;

  void onFrame(LandmarkFrame frame) {
    if (frame.hands.isEmpty) {
      live = null;
      stabilizer.update(null, 0);
      _noHandRun++;
      if (_noHandRun == wordGapFrames) buffer.endWord();
      notifyListeners();
      return;
    }
    _noHandRun = 0;

    final features = normalizeHand(
      frame.hands.first.xyz,
      aspect: aspect,
      flipX: flipX,
    );
    live = classifier.classify(features);

    final committed = stabilizer.update(live?.letter, live?.confidence ?? 0);
    if (committed != null) buffer.addLetter(committed);
    notifyListeners();
  }

  void backspace() {
    buffer.backspace();
    notifyListeners();
  }

  void endWord() {
    buffer.endWord();
    notifyListeners();
  }

  void clear() {
    buffer.clear();
    stabilizer.reset();
    live = null;
    notifyListeners();
  }
}
