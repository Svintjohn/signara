"""Run: python training/test_sequence_features.py"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sequence_features import build_sequence, SEQUENCE_FRAME_LENGTH  # noqa: E402


def hand(dx=0.0, dy=0.0):
    pts = []
    for i in range(21):
        pts += [0.5 + dx + 0.01 * i, 0.5 + dy + 0.02 * i, 0.001 * i]
    return pts


def test_shape_and_first_frame_path_zero():
    s = build_sequence([(hand(), 1.0), (hand(0.1, 0.0), 1.0)])
    assert len(s) == 2 and len(s[0]) == SEQUENCE_FRAME_LENGTH
    assert abs(s[0][60]) < 1e-9 and abs(s[0][61]) < 1e-9
    assert s[1][60] > 0 and abs(s[1][61]) < 1e-9  # moved right only


def test_empty():
    assert build_sequence([]) == []


def test_translation_invariant_shape():
    a = build_sequence([(hand(), 1.0)])[0][:60]
    b = build_sequence([(hand(0.2, 0.1), 1.0)])[0][:60]
    assert np.allclose(a, b, atol=1e-6)


if __name__ == "__main__":
    test_shape_and_first_frame_path_zero()
    test_empty()
    test_translation_invariant_shape()
    print("All sequence_features checks passed.")
