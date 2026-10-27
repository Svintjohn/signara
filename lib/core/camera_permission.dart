import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';

/// Android asks through permission_handler. In the browser, getUserMedia asks
/// by itself when the camera starts, so there is nothing to do first.
Future<bool> ensureCameraPermission() async {
  if (kIsWeb) return true;
  final status = await Permission.camera.request();
  return status.isGranted;
}
