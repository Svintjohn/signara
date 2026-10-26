import 'package:flutter/services.dart';

/// 21 hand landmarks as a flat list: [x0, y0, z0, x1, y1, z1, ...].
/// x and y are normalized 0..1 in the (rotated, upright) camera image.
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
  });

  factory LandmarkFrame.fromMap(Map<Object?, Object?> m) => LandmarkFrame(
        timestampMs: (m['ts'] as num).toInt(),
        inferenceMs: (m['inferMs'] as num).toInt(),
        hands: (m['hands'] as List)
            .map((e) => HandLandmarks.fromMap(e as Map<Object?, Object?>))
            .toList(),
      );

  final int timestampMs;

  /// Time from frame submission to result, measured natively.
  final int inferenceMs;
  final List<HandLandmarks> hands;
}

class SignaraLandmarks {
  static const MethodChannel _method =
      MethodChannel('signara_landmarks/methods');
  static const EventChannel _events =
      EventChannel('signara_landmarks/events');

  /// Starts the camera and landmarker. Returns a Flutter texture id for the
  /// camera preview (use it with the `Texture` widget).
  static Future<int?> start({
    bool front = false,
    int width = 640,
    int height = 480,
  }) {
    return _method.invokeMethod<int>('start', {
      'front': front,
      'width': width,
      'height': height,
    });
  }

  static Future<void> stop() => _method.invokeMethod<void>('stop');

  /// One event per processed camera frame (even when no hand is visible).
  static Stream<LandmarkFrame> get frames => _events
      .receiveBroadcastStream()
      .map((e) => LandmarkFrame.fromMap(e as Map<Object?, Object?>));
}
