# Training (Python)

## Done

- `landmark_features.py`: normalizes 21 hand landmarks into 60 position- and
  size-independent features. **Must match `lib/recognition/landmark_features.dart`.**
- `test_landmark_features.py`: checks the properties and prints golden values for the
  Dart test (`python training/test_landmark_features.py`). Passes.

## Written but never run (no dataset or TensorFlow here)

- `extract_landmarks.py`: labeled hand images -> `.npz` of features, using the same
  `hand_landmarker.task` as the phone.
- `train_fingerspelling.py`: small MLP on one frame of landmarks, per-letter report,
  exports `fingerspelling.tflite` + `labels.json`.

Expect small fixes on first run.

## Next

1. Pick a fingerspelling dataset and check its license. Decide how left hands and a
   mirrored front camera are handled (`flip_x`), and use the same rule on the phone.
2. Run extract -> train, read the per-letter report, and fix the weak letters.
3. `train_signs.py`: sequence model (small GRU / 1D-conv) over ~30-60 frames of landmarks
   for the isolated signs in `assets/vocab/`. This also handles J and Z.
4. Export to TFLite and measure latency on a low-end phone, not on your laptop.

Datasets and run outputs are git-ignored (`training/data/`, `training/runs/`). Models that
ship in the app go in `assets/models/` and ARE committed. Get consent for any data you
collect yourselves.
