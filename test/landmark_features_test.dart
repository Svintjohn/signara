import 'package:flutter_test/flutter_test.dart';
import 'package:signara/recognition/landmark_features.dart';

/// Same formula as `synthetic()` in training/test_landmark_features.py.
List<double> synthetic() => [
      for (var i = 0; i < 21; i++) ...[
        0.50 + 0.010 * i,
        0.40 + 0.02 * ((i * 7) % 5),
        -0.005 * i,
      ],
    ];

const goldenIndices = [0, 1, 2, 27, 28, 29, 57, 58, 59];

// Printed by `python training/test_landmark_features.py`.
const goldenA = [
  0.08535792,
  0.34143168,
  -0.04267896,
  0.85357922,
  0.0,
  -0.42678961,
  1.70715845,
  0.0,
  -0.85357922,
];
const goldenB = [
  -0.07432941,
  0.39642355,
  -0.04955294,
  -0.74329412,
  0.0,
  -0.49552944,
  -1.48658824,
  0.0,
  -0.99105889,
];

void expectGolden(List<double> got, List<double> golden) {
  expect(got.length, featureLength);
  for (var k = 0; k < goldenIndices.length; k++) {
    expect(got[goldenIndices[k]], closeTo(golden[k], 1e-5),
        reason: 'feature index ${goldenIndices[k]}');
  }
}

void main() {
  test('matches the Python implementation (aspect 1.0, no flip)', () {
    expectGolden(normalizeHand(synthetic()), goldenA);
  });

  test('matches the Python implementation (aspect 0.75, flipped)', () {
    expectGolden(normalizeHand(synthetic(), aspect: 0.75, flipX: true), goldenB);
  });

  test('is invariant to position and size', () {
    final base = synthetic();
    final moved = [
      for (var i = 0; i < base.length; i++)
        i % 3 == 0 ? base[i] + 0.2 : (i % 3 == 1 ? base[i] - 0.1 : base[i]),
    ];
    final a = normalizeHand(base);
    final b = normalizeHand(moved);
    for (var i = 0; i < a.length; i++) {
      expect(b[i], closeTo(a[i], 1e-6));
    }
  });

  test('a degenerate hand gives finite numbers', () {
    final flat = [for (var i = 0; i < 21; i++) ...[0.5, 0.5, 0.0]];
    for (final v in normalizeHand(flat)) {
      expect(v.isFinite, isTrue);
    }
  });

  test('rejects the wrong number of values', () {
    expect(() => normalizeHand([0.1, 0.2]), throwsArgumentError);
  });
}
