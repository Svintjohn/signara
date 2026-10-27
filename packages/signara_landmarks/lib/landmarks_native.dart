import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'landmark_types.dart';

// Android implementation: Kotlin plugin (CameraX + MediaPipe).

const MethodChannel _method = MethodChannel('signara_landmarks/methods');
const EventChannel _events = EventChannel('signara_landmarks/events');

Future<int?> start({bool front = false, int width = 640, int height = 480}) {
  return _method.invokeMethod<int>('start', {
    'front': front,
    'width': width,
    'height': height,
  });
}

Future<void> stop() => _method.invokeMethod<void>('stop');

Stream<LandmarkFrame> get frames => _events
    .receiveBroadcastStream()
    .map((e) => LandmarkFrame.fromMap(e as Map<Object?, Object?>));

/// [id] is the value returned by [start].
Widget buildPreview(int id) => Texture(textureId: id);
