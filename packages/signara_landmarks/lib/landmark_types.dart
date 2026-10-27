/// 21 hand landmarks as a flat list: [x0, y0, z0, x1, y1, z1, ...].
/// x and y are normalized 0..1 in the (upright) camera image.
class HandLandmarks {
  const HandLandmarks({required this.handedness, required this.xyz});

  factory HandLandmarks.fromMap(Map<Object?, Object?> m) => HandLandmarks(
        handedness: m['handedness'] as String? ?? '?',
        xyz: (m['xyz'] as List).map((e) => (e as num).toDouble()).toList(),
      );

  final String handedness;
  final List<double> xyz;
}

class LandmarkFrame {
  const LandmarkFrame({
    required this.timestampMs,
    required this.inferenceMs,
    required this.hands,
    this.aspect,
  });

  factory LandmarkFrame.fromMap(Map<Object?, Object?> m) => LandmarkFrame(
        timestampMs: (m['ts'] as num).toInt(),
        inferenceMs: (m['inferMs'] as num).toInt(),
        aspect: (m['aspect'] as num?)?.toDouble(),
        hands: (m['hands'] as List)
            .map((e) => HandLandmarks.fromMap(e as Map<Object?, Object?>))
            .toList(),
      );

  final int timestampMs;

  /// Time spent on this frame, measured on the platform side.
  final int inferenceMs;
  final List<HandLandmarks> hands;

  /// Image width / height, when the platform reports it (the web does).
  /// Null means "use the default portrait 3/4".
  final double? aspect;
}
