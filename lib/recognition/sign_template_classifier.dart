import '../data/sample_store.dart';
import 'dtw.dart';

class SignMatch {
  const SignMatch(this.gloss, this.distance, this.confidence);

  final String gloss;
  final double distance;

  /// 0..1. How clearly the best sign beat the runner-up.
  final double confidence;
}

/// Recognizes an isolated sign by comparing it to the recorded examples
/// (dynamic time warping, nearest example wins).
///
/// PROTOTYPE LIMITS, state them in the thesis:
/// - Personalized: it only knows the signs and signers that were recorded.
/// - One hand. Face and body are not seen.
/// - Needs a pause between signs (hands out of view) to find sign boundaries.
/// - Thresholds are first guesses; tune [maxDistance] on real recordings.
class SignTemplateClassifier {
  SignTemplateClassifier(
    List<SeqSample> samples, {
    this.resampleTo = 24,
    this.maxDistance = 1.2,
    this.minConfidence = 0.1,
    this.band = 6,
  }) : _templates = [
          for (final s in samples)
            if (s.frames.length >= 2) (s.gloss, resample(s.frames, resampleTo)),
        ];

  final int resampleTo;
  final double maxDistance;
  final double minConfidence;
  final int band;
  final List<(String, List<List<double>>)> _templates;

  bool get isReady => _templates.isNotEmpty;

  SignMatch? classify(List<List<double>> sequence) {
    if (!isReady || sequence.length < 2) return null;
    final query = resample(sequence, resampleTo);

    final bestPerGloss = <String, double>{};
    for (final (gloss, tpl) in _templates) {
      final d = dtwDistance(query, tpl, band: band);
      final cur = bestPerGloss[gloss];
      if (cur == null || d < cur) bestPerGloss[gloss] = d;
    }

    final ranked = bestPerGloss.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final best = ranked.first;
    if (best.value > maxDistance) return null;

    final confidence = ranked.length > 1
        ? (1 - best.value / ranked[1].value).clamp(0.0, 1.0)
        : (1 - best.value / maxDistance).clamp(0.0, 1.0);
    if (confidence < minConfidence) return null;

    return SignMatch(best.key, best.value, confidence.toDouble());
  }
}
