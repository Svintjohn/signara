import 'package:flutter/widgets.dart';

import 'landmark_types.dart';
import 'landmarks_native.dart'
    if (dart.library.js_interop) 'landmarks_web.dart' as impl;

export 'landmark_types.dart';

/// Camera + hand landmarks. Same API on Android (Kotlin, MediaPipe) and on
/// the web (MediaPipe JS). Only landmarks reach the app, never frames.
class SignaraLandmarks {
  /// Starts the camera and the hand landmarker. Returns an id for
  /// [buildPreview].
  static Future<int?> start({
    bool front = false,
    int width = 640,
    int height = 480,
  }) =>
      impl.start(front: front, width: width, height: height);

  static Future<void> stop() => impl.stop();

  /// One event per processed camera frame (even when no hand is visible).
  static Stream<LandmarkFrame> get frames => impl.frames;

  /// The live camera picture. Pass the id returned by [start].
  static Widget buildPreview(int id) => impl.buildPreview(id);
}
