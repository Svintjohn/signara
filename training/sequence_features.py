"""Python port of lib/recognition/sequence_features.dart (buildSequence).

MUST STAY IDENTICAL to the Dart version: per frame, 60 hand-shape numbers
(normalize_hand) + 2 numbers for the wrist path relative to the first frame.
"""

import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from landmark_features import normalize_hand  # noqa: E402

SEQUENCE_FRAME_LENGTH = 62


def _hand_size_2d(xyz, aspect):
    dx = (xyz[27] - xyz[0]) * aspect  # landmark 9 x - wrist x
    dy = xyz[28] - xyz[1]
    return float(np.hypot(dx, dy))


def build_sequence(frames):
    """frames: list of (xyz_flat_63, aspect). Returns list of 62-number frames."""
    if not frames:
        return []
    first_xyz, first_aspect = frames[0]
    x0 = first_xyz[0] * first_aspect
    y0 = first_xyz[1]
    scale = _hand_size_2d(first_xyz, first_aspect)
    if scale < 1e-6:
        scale = 1.0
    out = []
    for xyz, aspect in frames:
        shape = normalize_hand(xyz, aspect=aspect).astype(float).tolist()
        out.append(shape + [(xyz[0] * aspect - x0) / scale, (xyz[1] - y0) / scale])
    return out
