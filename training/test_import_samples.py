"""Run: python training/test_import_samples.py"""

import json
import os
import sys
import tempfile

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from import_samples import convert, resample, main  # noqa: E402


def sample_export():
    return {
        "version": 1,
        "static": [
            {"l": "A", "f": [0.1] * 60},
            {"l": "A", "f": [0.11] * 60},
            {"l": "B", "f": [0.9] * 60},
        ],
        "seq": [
            {"g": "HELLO", "f": [[i / 9.0] + [0.0] * 61 for i in range(10)]},
            {"g": "HELLO", "f": [[i / 14.0] + [0.0] * 61 for i in range(15)]},
            {"g": "THANK-YOU", "f": [[0.0, i / 4.0] + [0.0] * 60 for i in range(5)]},
        ],
    }


def test_resample():
    out = resample([[0.0], [10.0]], 5)
    assert out.shape == (5, 1)
    assert out[0, 0] == 0 and out[-1, 0] == 10 and abs(out[2, 0] - 5) < 1e-9
    one = resample([[3.0, 4.0]], 4)
    assert one.shape == (4, 2) and (one == [3.0, 4.0]).all()


def test_convert():
    s, q, report = convert(sample_export())
    assert s["X"].shape == (3, 60) and list(s["labels"]) == ["A", "B"]
    assert list(s["y"]) == [0, 0, 1]
    assert q["seq_X"].shape == (3, 24, 62) and list(q["seq_labels"]) == ["HELLO", "THANK-YOU"]
    assert list(q["seq_y"]) == [0, 0, 1]
    assert report == {"static": {"A": 2, "B": 1}, "seq": {"HELLO": 2, "THANK-YOU": 1}}
    # Different-length recordings of the same ramp end up (almost) identical.
    assert np.allclose(q["seq_X"][0], q["seq_X"][1], atol=1e-6)


def test_empty_and_bad_input():
    s, q, report = convert({"version": 1})
    assert s is None and q is None and report == {"static": {}, "seq": {}}
    try:
        convert({"static": [{"l": "A", "f": [0.0] * 10}]})
    except ValueError:
        pass
    else:
        raise AssertionError("wrong feature length should be rejected")


def test_cli_writes_files():
    d = tempfile.mkdtemp()
    src = os.path.join(d, "samples.json")
    with open(src, "w") as f:
        json.dump(sample_export(), f)
    out = os.path.join(d, "out")
    old = sys.argv
    sys.argv = ["import_samples.py", "--export", src, "--out", out]
    try:
        main()
    finally:
        sys.argv = old
    z = np.load(os.path.join(out, "fingerspelling.npz"), allow_pickle=False)
    assert z["X"].shape == (3, 60) and [str(l) for l in z["labels"]] == ["A", "B"]
    z2 = np.load(os.path.join(out, "signs.npz"), allow_pickle=False)
    assert z2["seq_X"].shape == (3, 24, 62)


if __name__ == "__main__":
    test_resample()
    test_convert()
    test_empty_and_bad_input()
    test_cli_writes_files()
    print("All import_samples checks passed.")
