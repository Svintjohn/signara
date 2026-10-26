class LetterPrediction {
  const LetterPrediction(this.letter, this.confidence);

  final String letter;
  final double confidence;
}

/// Classifies one normalized hand (60 features from `normalizeHand`).
abstract class LetterClassifier {
  /// Whether a real model is loaded. The UI shows a banner when false.
  bool get isReady;

  /// Returns the best letter, or null if nothing can be predicted.
  LetterPrediction? classify(List<double> features);
}

/// Used until a trained model exists. Never predicts anything.
class NoModelClassifier implements LetterClassifier {
  const NoModelClassifier();

  @override
  bool get isReady => false;

  @override
  LetterPrediction? classify(List<double> features) => null;
}

// TODO(week 2): TfliteLetterClassifier. Decide between the `tflite_flutter`
// package (inference in Dart on the 60 features, simplest) and running the
// interpreter inside the Kotlin plugin. Landmarks are tiny, so Dart is fine.
// Load assets/models/fingerspelling.tflite and labels.json.
