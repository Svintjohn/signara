"""Hand-landmark feature extraction for Signara.

THIS MUST STAY IDENTICAL to lib/recognition/landmark_features.dart.
If you change one, change the other and update the golden values in
test/landmark_features_test.dart (run `python training/test_landmark_features.py`
to print them). A mismatch silently ruins accuracy on the phone.

Input : 21 MediaPipe hand landmarks, flat [x0,y0,z0, x1,y1,z1, ...],
        x/y normalized 0..1 in the upright image.
Output: 60 floats (the 20 non-wrist landmarks), invariant to hand position
        and size in the frame.
"""

import numpy as np

NUM_LANDMARKS = 21
WRIST = 0
MIDDLE_MCP = 9
FEATURE_LEN = (NUM_LANDMARKS - 1) * 3
_EPS = 1e-6


def normalize_hand(xyz, aspect=1.0, flip_x=False):
    """Normalize one hand.

    aspect: image width / height. x is in units of image width and y in units
            of image height, so x is multiplied by aspect to make both axes
            use the same unit before measuring hand size.
    flip_x: mirror the hand (use it to make left hands look like right hands,
            or to undo a mirrored front camera). Training and the phone must
            make the same choice.
    """
    a = np.asarray(xyz, dtype=np.float64).reshape(NUM_LANDMARKS, 3).copy()
    a[:, 0] *= aspect
    a -= a[WRIST]  # wrist becomes the origin
    if flip_x:
        a[:, 0] = -a[:, 0]
    scale = float(np.linalg.norm(a[MIDDLE_MCP]))  # wrist -> middle finger base
    if scale < _EPS:
        scale = 1.0
    a /= scale
    return a[1:].reshape(-1).astype(np.float32)
