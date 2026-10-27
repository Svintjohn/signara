import 'dart:math' as math;

import 'landmark_features.dart';

/// One hand in one frame, as it comes from the camera.
class RawHand {
  const RawHand(this.xyz, this.aspect);

  /// 21 landmarks flat [x0,y0,z0,...], x/y normalized 0..1.
  final List<double> xyz;

  /// Image width / height.
  final double aspect;
}

/// Per frame: the 60 hand-shape features + 2 numbers for where the wrist is
/// relative to where it started (so the path of the hand counts, not only the
/// shape). Frame size: [sequenceFrameLength].
const int sequenceFrameLength = featureLength + 2;

double _handSize2d(RawHand h) {
  // wrist is landmark 0, middle finger base is landmark 9.
  final dx = (h.xyz[27] - h.xyz[0]) * h.aspect;
  final dy = h.xyz[28] - h.xyz[1];
  return math.sqrt(dx * dx + dy * dy);
}

List<List<double>> buildSequence(List<RawHand> frames) {
  if (frames.isEmpty) return [];
  final first = frames.first;
  final x0 = first.xyz[0] * first.aspect;
  final y0 = first.xyz[1];
  var scale = _handSize2d(first);
  if (scale < 1e-6) scale = 1.0;

  return [
    for (final f in frames)
      [
        ...normalizeHand(f.xyz, aspect: f.aspect).map((v) => v.toDouble()),
        (f.xyz[0] * f.aspect - x0) / scale,
        (f.xyz[1] - y0) / scale,
      ],
  ];
}
