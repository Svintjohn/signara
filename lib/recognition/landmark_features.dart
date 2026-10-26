import 'dart:math' as math;

/// Hand-landmark feature extraction.
///
/// THIS MUST STAY IDENTICAL to training/landmark_features.py. If you change
/// one, change the other and update the golden values in
/// test/landmark_features_test.dart. A mismatch silently ruins accuracy.
const int numLandmarks = 21;
const int wristIndex = 0;
const int middleMcpIndex = 9;
const int featureLength = (numLandmarks - 1) * 3;
const double _eps = 1e-6;

/// [xyz] is 21 landmarks flat: [x0, y0, z0, x1, y1, z1, ...], x/y normalized
/// 0..1 in the upright image. Returns 60 features that do not depend on where
/// the hand is in the frame or how big it appears.
///
/// [aspect] is image width / height. [flipX] mirrors the hand.
List<double> normalizeHand(
  List<double> xyz, {
  double aspect = 1.0,
  bool flipX = false,
}) {
  if (xyz.length != numLandmarks * 3) {
    throw ArgumentError(
      'Expected ${numLandmarks * 3} values, got ${xyz.length}.',
    );
  }

  final a = List<double>.from(xyz);
  for (var i = 0; i < numLandmarks; i++) {
    a[i * 3] *= aspect;
  }

  // The wrist becomes the origin.
  final wx = a[wristIndex * 3];
  final wy = a[wristIndex * 3 + 1];
  final wz = a[wristIndex * 3 + 2];
  for (var i = 0; i < numLandmarks; i++) {
    a[i * 3] -= wx;
    a[i * 3 + 1] -= wy;
    a[i * 3 + 2] -= wz;
  }

  if (flipX) {
    for (var i = 0; i < numLandmarks; i++) {
      a[i * 3] = -a[i * 3];
    }
  }

  // Hand size = distance from wrist to the base of the middle finger.
  final mx = a[middleMcpIndex * 3];
  final my = a[middleMcpIndex * 3 + 1];
  final mz = a[middleMcpIndex * 3 + 2];
  var scale = math.sqrt(mx * mx + my * my + mz * mz);
  if (scale < _eps) scale = 1.0;

  // Drop the wrist (always 0,0,0 after normalizing).
  return [for (var i = 3; i < a.length; i++) a[i] / scale];
}
