"""Convert a Signara samples export (Me -> Collect samples -> Export) into
training files.

Usage:
    python training/import_samples.py --export samples.json --out training/data

Writes:
    fingerspelling.npz  X (n,60), y, labels, names   -> train_fingerspelling.py
    signs.npz           seq_X (n,T,62), seq_y, seq_labels   -> future train_signs.py

Also prints how many samples each label has. Aim for 30+ varied poses per
letter and 8+ recordings per sign, from more than one person, before you
trust any accuracy number. Report accuracy on people NOT in the training set.
"""

import argparse
import json
import os

import numpy as np

STATIC_LEN = 60
SEQ_LEN = 62
RESAMPLE_TO = 24


def resample(frames, n):
    """Linear resample of a (T, D) array to (n, D). Same as lib/recognition/dtw.dart."""
    a = np.asarray(frames, dtype=np.float64)
    if len(a) == 0:
        raise ValueError("empty sequence")
    if len(a) == 1 or n == 1:
        return np.repeat(a[:1], n, axis=0)
    pos = np.arange(n) * (len(a) - 1) / (n - 1)
    lo = np.floor(pos).astype(int)
    hi = np.minimum(lo + 1, len(a) - 1)
    t = (pos - lo)[:, None]
    return a[lo] + (a[hi] - a[lo]) * t


def convert(data, resample_to=RESAMPLE_TO):
    """Returns (static_dict, seq_dict, report). Either dict is None if empty."""
    statics = data.get("static", [])
    seqs = data.get("seq", [])

    static_out = None
    if statics:
        labels = sorted({s["l"] for s in statics})
        index = {l: i for i, l in enumerate(labels)}
        X = np.asarray([s["f"] for s in statics], dtype=np.float32)
        if X.shape[1] != STATIC_LEN:
            raise ValueError(f"static samples must have {STATIC_LEN} numbers, got {X.shape[1]}")
        y = np.asarray([index[s["l"]] for s in statics], dtype=np.int64)
        static_out = {
            "X": X,
            "y": y,
            "labels": np.asarray(labels),
            "names": np.asarray([f"rec{i}" for i in range(len(statics))]),
        }

    seq_out = None
    if seqs:
        labels = sorted({s["g"] for s in seqs})
        index = {l: i for i, l in enumerate(labels)}
        for s in seqs:
            if len(s["f"][0]) != SEQ_LEN:
                raise ValueError(f"sequence frames must have {SEQ_LEN} numbers")
        X = np.stack([resample(s["f"], resample_to) for s in seqs]).astype(np.float32)
        y = np.asarray([index[s["g"]] for s in seqs], dtype=np.int64)
        seq_out = {"seq_X": X, "seq_y": y, "seq_labels": np.asarray(labels)}

    report = {
        "static": {str(l): int((static_out["y"] == i).sum()) for i, l in enumerate(static_out["labels"])}
        if static_out
        else {},
        "seq": {str(l): int((seq_out["seq_y"] == i).sum()) for i, l in enumerate(seq_out["seq_labels"])}
        if seq_out
        else {},
    }
    return static_out, seq_out, report


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--export", required=True, help="JSON from Collect samples -> Export")
    ap.add_argument("--out", required=True, help="output folder")
    args = ap.parse_args()

    with open(args.export, encoding="utf-8") as f:
        data = json.load(f)

    static_out, seq_out, report = convert(data)
    os.makedirs(args.out, exist_ok=True)
    if static_out:
        np.savez_compressed(os.path.join(args.out, "fingerspelling.npz"), **static_out)
    if seq_out:
        np.savez_compressed(os.path.join(args.out, "signs.npz"), **seq_out)

    print("Letters/numbers per label:", report["static"] or "none")
    print("Signs per gloss:", report["seq"] or "none")


if __name__ == "__main__":
    main()
