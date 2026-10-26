"""Run: python training/test_landmark_features.py

Checks the normalization properties and prints golden values for the Dart test.
"""

import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from landmark_features import FEATURE_LEN, normalize_hand  # noqa: E402


def synthetic():
    return [
        v
        for i in range(21)
        for v in (0.50 + 0.010 * i, 0.40 + 0.02 * ((i * 7) % 5), -0.005 * i)
    ]


def main():
    base = np.asarray(synthetic()).reshape(21, 3)
    f = normalize_hand(base.reshape(-1))
    assert f.shape == (FEATURE_LEN,) and FEATURE_LEN == 60
    assert np.all(np.isfinite(f))

    # Moving the hand around the frame must not change the features.
    moved = base + np.array([0.2, -0.1, 0.0])
    assert np.allclose(normalize_hand(moved.reshape(-1)), f, atol=1e-6)

    # Making the hand bigger or smaller (distance to camera) must not either.
    scaled = (base - base[0]) * 2.5 + base[0]
    assert np.allclose(normalize_hand(scaled.reshape(-1)), f, atol=1e-6)

    # Mirroring: flip_x on a mirrored hand gives the original features back.
    mirrored = base.copy()
    mirrored[:, 0] = 1.0 - mirrored[:, 0]
    assert np.allclose(
        normalize_hand(mirrored.reshape(-1), flip_x=True), f, atol=1e-6
    )

    # A degenerate hand (all points equal) must not produce NaN or inf.
    flat = np.tile([0.5, 0.5, 0.0], (21, 1))
    assert np.all(np.isfinite(normalize_hand(flat.reshape(-1))))

    print("All normalization checks passed.\n")

    idx = [0, 1, 2, 27, 28, 29, 57, 58, 59]
    a = normalize_hand(synthetic())
    b = normalize_hand(synthetic(), aspect=0.75, flip_x=True)
    print("GOLDEN case A (aspect=1.0, flip=false):")
    print("  indices", idx)
    print("  values ", [round(float(a[i]), 8) for i in idx])
    print("GOLDEN case B (aspect=0.75, flip=true):")
    print("  values ", [round(float(b[i]), 8) for i in idx])


if __name__ == "__main__":
    main()
