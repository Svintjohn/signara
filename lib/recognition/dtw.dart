import 'dart:math' as math;

/// Euclidean distance between two equal-length frames.
double frameDistance(List<double> a, List<double> b) {
  var s = 0.0;
  for (var i = 0; i < a.length; i++) {
    final d = a[i] - b[i];
    s += d * d;
  }
  return math.sqrt(s);
}

/// Resamples a sequence to exactly [n] frames (linear interpolation) so that
/// fast and slow versions of the same sign line up.
List<List<double>> resample(List<List<double>> seq, int n) {
  if (seq.isEmpty || n <= 0) return [];
  if (seq.length == 1 || n == 1) {
    return List.generate(n, (_) => List<double>.from(seq.first));
  }
  final out = <List<double>>[];
  for (var i = 0; i < n; i++) {
    final pos = i * (seq.length - 1) / (n - 1);
    final lo = pos.floor();
    final hi = math.min(lo + 1, seq.length - 1);
    final t = pos - lo;
    final a = seq[lo];
    final b = seq[hi];
    out.add([for (var k = 0; k < a.length; k++) a[k] + (b[k] - a[k]) * t]);
  }
  return out;
}

/// Dynamic time warping distance, divided by (a.length + b.length) so
/// sequences of different lengths can be compared. [band] limits how far the
/// two sequences may drift apart in time (Sakoe-Chiba band).
double dtwDistance(
  List<List<double>> a,
  List<List<double>> b, {
  int? band,
}) {
  final n = a.length;
  final m = b.length;
  if (n == 0 || m == 0) return double.infinity;

  final w = math.max(band ?? math.max(n, m), (n - m).abs());
  final inf = double.infinity;
  final d = List.generate(n + 1, (_) => List<double>.filled(m + 1, inf));
  d[0][0] = 0;

  for (var i = 1; i <= n; i++) {
    final jStart = math.max(1, i - w);
    final jEnd = math.min(m, i + w);
    for (var j = jStart; j <= jEnd; j++) {
      final cost = frameDistance(a[i - 1], b[j - 1]);
      final best = math.min(d[i - 1][j], math.min(d[i][j - 1], d[i - 1][j - 1]));
      d[i][j] = cost + best;
    }
  }
  return d[n][m] / (n + m);
}
