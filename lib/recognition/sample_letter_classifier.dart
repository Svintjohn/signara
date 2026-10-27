import '../data/sample_store.dart';
import 'dtw.dart';
import 'finger_state.dart';
import 'letter_classifier.dart';

/// k-nearest-neighbour over the letter samples recorded on this device.
/// Falls back to the finger rules for hands it has no close sample for.
///
/// PROTOTYPE: thresholds need tuning on a real phone. Personalized (trained on
/// the people who recorded), so say that in the thesis: it is not a general
/// model.
class SampleLetterClassifier implements LetterClassifier {
  SampleLetterClassifier(
    this._samples, {
    this.fallback = const RuleLetterClassifier(),
    this.k = 5,
    this.maxDistance = 2.0,
  });

  /// Read at classify time, so new recordings are used right away.
  final List<StaticSample> Function() _samples;
  final LetterClassifier fallback;
  final int k;
  final double maxDistance;

  int get sampleCount => _samples().length;

  @override
  bool get isReady => true;

  @override
  LetterPrediction? classify(List<double> features) {
    final samples = _samples();
    if (samples.isEmpty) return fallback.classify(features);

    final scored = <MapEntry<double, String>>[
      for (final s in samples)
        MapEntry(frameDistance(features, s.features), s.label),
    ]..sort((a, b) => a.key.compareTo(b.key));

    if (scored.first.key > maxDistance) return fallback.classify(features);

    final top = scored.take(k);
    final votes = <String, double>{};
    var total = 0.0;
    for (final e in top) {
      final w = 1 / (e.key + 0.05);
      votes[e.value] = (votes[e.value] ?? 0) + w;
      total += w;
    }
    final best = votes.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return LetterPrediction(best.key, best.value / total);
  }
}
