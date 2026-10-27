"""Turn labeled sign VIDEOS into Signara sample JSON (landmark numbers only).

Run this on YOUR computer, on videos you are allowed to use. Nothing is uploaded,
and the output has no pictures, only hand-landmark numbers. The result can be
loaded in the app: Me -> Collect samples -> Import.

Layout (one folder per gloss, glosses must match assets/vocab/vocab_v0.json):

    videos/HELLO/clip1.mp4
    videos/THANK-YOU/clip7.mp4
    videos/A/img1.mp4        (letters work too, they become static samples)

Usage:
    pip install mediapipe opencv-python numpy
    python training/extract_video_landmarks.py \
        --videos videos --model android/app/src/main/assets/hand_landmarker.task \
        --out samples_from_videos.json --dataset-name "ASL Citizen" \
        --i-checked-the-license

LICENSE: many sign datasets are research-only and forbid redistribution
(ASL Citizen: non-commercial research, no redistribution, no hosted service).
Landmarks derived from them may count as "modifications", so do NOT commit the
output or ship it in the app until you have read the license and, if unclear,
asked the owner in writing. Keep it on your machine for training and testing.

UNTESTED against real videos (mediapipe is not installed where this was written).
The Dart/Python feature math is unit-tested.
"""

import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from landmark_features import normalize_hand  # noqa: E402
from sequence_features import build_sequence  # noqa: E402

VIDEO_EXT = {".mp4", ".mov", ".avi", ".mkv", ".webm"}
MIN_FRAMES = 6
MAX_FRAMES = 120


def r(v):
    return round(float(v), 4)


def read_hand_frames(path, landmarker, mirror):
    """Returns list of (xyz_flat_63, aspect) for frames where a hand was found."""
    import cv2
    import mediapipe as mp

    cap = cv2.VideoCapture(path)
    fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
    w = cap.get(cv2.CAP_PROP_FRAME_WIDTH)
    h = cap.get(cv2.CAP_PROP_FRAME_HEIGHT)
    aspect = (w / h) if h else 1.0
    frames, i = [], 0
    while True:
        ok, bgr = cap.read()
        if not ok:
            break
        if mirror:
            bgr = cv2.flip(bgr, 1)
        rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
        img = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)
        res = landmarker.detect_for_video(img, int(i * 1000 / fps))
        i += 1
        if res.hand_landmarks:
            lm = res.hand_landmarks[0]
            xyz = [c for p in lm for c in (p.x, p.y, p.z)]
            frames.append((xyz, aspect))
    cap.release()
    return frames


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--videos", required=True)
    ap.add_argument("--model", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--dataset-name", required=True, help="recorded in the output")
    ap.add_argument("--mirror", action="store_true",
                    help="flip videos horizontally (match how the phone front camera is handled)")
    ap.add_argument("--max-per-gloss", type=int, default=20)
    ap.add_argument("--i-checked-the-license", action="store_true",
                    help="required: confirms you read the dataset license")
    args = ap.parse_args()

    if not args.i_checked_the_license:
        sys.exit("Read the dataset license first, then pass --i-checked-the-license. "
                 "See the note at the top of this file.")

    import mediapipe as mp  # noqa: F401
    from mediapipe.tasks import python as mp_python
    from mediapipe.tasks.python import vision

    options = vision.HandLandmarkerOptions(
        base_options=mp_python.BaseOptions(model_asset_path=args.model),
        running_mode=vision.RunningMode.VIDEO,
        num_hands=1,
    )

    static, seq, skipped = [], [], {}
    glosses = sorted(d for d in os.listdir(args.videos)
                     if os.path.isdir(os.path.join(args.videos, d)))
    for gloss in glosses:
        folder = os.path.join(args.videos, gloss)
        files = sorted(f for f in os.listdir(folder)
                       if os.path.splitext(f)[1].lower() in VIDEO_EXT)[: args.max_per_gloss]
        for name in files:
            # fresh landmarker per clip: VIDEO mode needs increasing timestamps
            landmarker = vision.HandLandmarker.create_from_options(options)
            frames = read_hand_frames(os.path.join(folder, name), landmarker, args.mirror)
            landmarker.close()
            if len(frames) < MIN_FRAMES:
                skipped[gloss] = skipped.get(gloss, 0) + 1
                continue
            if len(gloss) == 1:  # a letter or digit: keep the middle frame as a pose
                xyz, aspect = frames[len(frames) // 2]
                static.append({"l": gloss, "f": [r(v) for v in normalize_hand(xyz, aspect=aspect)]})
            else:
                frames = frames[:MAX_FRAMES]
                seq.append({"g": gloss, "f": [[r(v) for v in fr] for fr in build_sequence(frames)]})

    out = {"version": 1, "source": args.dataset_name, "static": static, "seq": seq}
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(out, f)
    print(f"Wrote {len(static)} static + {len(seq)} sequence samples to {args.out}")
    if skipped:
        print("Skipped (hand not found / too short):", skipped)
    print("Reminder: do not commit or ship this file unless the license allows it.")


if __name__ == "__main__":
    main()
