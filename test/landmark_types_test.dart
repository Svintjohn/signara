import 'package:flutter_test/flutter_test.dart';
import 'package:signara_landmarks/signara_landmarks.dart';

void main() {
  final hand = {
    'handedness': 'Right',
    'xyz': [for (var i = 0; i < 63; i++) i * 0.01],
  };

  test('parses a frame without aspect (Android)', () {
    final f = LandmarkFrame.fromMap({
      'ts': 100,
      'inferMs': 12,
      'hands': [hand],
    });
    expect(f.aspect, isNull);
    expect(f.inferenceMs, 12);
    expect(f.hands.single.xyz.length, 63);
    expect(f.hands.single.handedness, 'Right');
  });

  test('parses a frame with aspect (web)', () {
    final f = LandmarkFrame.fromMap({
      'ts': 100.0,
      'inferMs': 8.0,
      'aspect': 1.3333,
      'hands': <Object?>[],
    });
    expect(f.aspect, closeTo(1.3333, 1e-9));
    expect(f.timestampMs, 100);
    expect(f.hands, isEmpty);
  });
}
