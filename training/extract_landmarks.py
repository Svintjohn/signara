"""Turn a folder of labeled hand images into a landmark feature file.

Expected layout (one folder per label, e.g. the Kaggle "ASL Alphabet" dataset):

    data/images/A/*.jpg
    data/images/B/*.jpg
    ...

Usage:
    pip install mediapipe numpy
    python training/extract_landmarks.py \
        --images training/data/images \
        --model  android/app/src/main/assets/hand_landmarker.task \
        --out    training/data/fingerspelling.npz

Uses the same hand_landmarker.task model as the phone, so the landmarks match.
UNTESTED: written without a dataset or the mediapipe package.
"""

import argparse
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from landmark_features import normalize_hand  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--images", required=True)
    ap.add_argument("--model", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument(
        "--flip-left",
        action="store_true",
        help="mirror hands MediaPipe labels as Left (must match the phone)",
    )
    args = ap.parse_args()

    import mediapipe as mp
    from mediapipe.tasks import python as mp_python
    from mediapipe.tasks.python import vision

    options = vision.HandLandmarkerOptions(
        base_options=mp_python.BaseOptions(model_asset_path=args.model),
        running_mode=vision.RunningMode.IMAGE,
        num_hands=1,
    )
    landmarker = vision.HandLandmarker.create_from_options(options)

    labels = sorted(
        d for d in os.listdir(args.images)
        if os.path.isdir(os.path.join(args.images, d))
    )
    X, y, groups = [], [], []
    skipped = {}

    for li, label in enumerate(labels):
        folder = os.path.join(args.images, label)
        for name in sorted(os.listdir(folder)):
            if not name.lower().endswith((".jpg", ".jpeg", ".png")):
                continue
            image = mp.Image.create_from_file(os.path.join(folder, name))
            result = landmarker.detect(image)
            if not result.hand_landmarks:
                skipped[label] = skipped.get(label, 0) + 1
                continue

            pts = result.hand_landmarks[0]
            xyz = [v for p in pts for v in (p.x, p.y, p.z)]
            is_left = (
                result.handedness
                and result.handedness[0][0].category_name == "Left"
            )
            feat = normalize_hand(
                xyz,
                aspect=image.width / image.height,
                flip_x=bool(args.flip_left and is_left),
            )
            X.append(feat)
            y.append(li)
            groups.append(name)

    np.savez_compressed(
        args.out,
        X=np.stack(X).astype(np.float32),
        y=np.asarray(y, dtype=np.int64),
        labels=np.asarray(labels),
        names=np.asarray(groups),
    )
    print(f"Saved {len(X)} samples, {len(labels)} labels -> {args.out}")
    if skipped:
        print("No hand detected (skipped):", skipped)


if __name__ == "__main__":
    main()
