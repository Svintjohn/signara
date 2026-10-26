# Training (Python)

Not implemented yet. Plan:

1. `extract_landmarks.py`: run MediaPipe (hand + pose) over dataset videos and save
   per-frame landmark arrays (`.npy`). Work on landmarks, not pixels.
2. `train_fingerspelling.py`: small classifier on a single frame of hand landmarks
   (A-Z minus J/Z, then add motion handling).
3. `train_signs.py`: sequence model (small GRU / 1D-conv / tiny transformer) over
   ~30-60 frames of landmarks for the isolated-sign vocabulary in `assets/vocab/`.
4. Export to TFLite and measure latency on a low-end phone, not on your laptop.

Normalize landmarks (translate to wrist or shoulder midpoint, scale by hand / shoulder
width) so it works at any camera distance. Record accuracy per sign, not only overall.

Datasets are git-ignored (`training/data/`). Check each dataset's license before use,
and get consent for any data you collect yourselves.
