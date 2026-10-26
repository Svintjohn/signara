"""Train a small fingerspelling classifier on normalized hand landmarks.

Usage:
    pip install tensorflow numpy scikit-learn
    python training/train_fingerspelling.py \
        --data training/data/fingerspelling.npz \
        --out  training/runs/fingerspelling

Writes <out>/fingerspelling.tflite and <out>/labels.json.
Copy both into assets/models/ in the app once the accuracy looks right.

UNTESTED: written without a dataset or TensorFlow.

Things that will bite you:
- Letters J and Z involve motion; a single frame cannot classify them. Drop
  them here and handle them with the sequence model (train_signs.py, later).
- If the same person appears in train AND validation, accuracy is inflated.
  Split by person/session when the dataset gives you that information, and
  report that number in the thesis, not the random-split one.
- Check accuracy per letter (the report below), not only overall. M/N/S/T/A/E
  look alike and will be the weak ones.
"""

import argparse
import json
import os

import numpy as np

SKIP_LETTERS = {"J", "Z"}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--epochs", type=int, default=60)
    args = ap.parse_args()

    import tensorflow as tf
    from sklearn.metrics import classification_report
    from sklearn.model_selection import train_test_split

    d = np.load(args.data, allow_pickle=False)
    X, y, labels = d["X"], d["y"], [str(s) for s in d["labels"]]

    keep = np.array([labels[i] not in SKIP_LETTERS for i in y])
    X, y = X[keep], y[keep]
    used = sorted({int(i) for i in y})
    remap = {old: new for new, old in enumerate(used)}
    y = np.array([remap[int(i)] for i in y])
    names = [labels[i] for i in used]

    X_tr, X_va, y_tr, y_va = train_test_split(
        X, y, test_size=0.2, stratify=y, random_state=42
    )

    model = tf.keras.Sequential(
        [
            tf.keras.layers.Input(shape=(X.shape[1],)),
            tf.keras.layers.GaussianNoise(0.02),  # light augmentation
            tf.keras.layers.Dense(128, activation="relu"),
            tf.keras.layers.Dropout(0.2),
            tf.keras.layers.Dense(64, activation="relu"),
            tf.keras.layers.Dense(len(names), activation="softmax"),
        ]
    )
    model.compile(
        optimizer="adam",
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )
    model.fit(
        X_tr,
        y_tr,
        validation_data=(X_va, y_va),
        epochs=args.epochs,
        batch_size=64,
        callbacks=[
            tf.keras.callbacks.EarlyStopping(
                patience=8, restore_best_weights=True
            )
        ],
    )

    pred = model.predict(X_va).argmax(axis=1)
    print(classification_report(y_va, pred, target_names=names))

    os.makedirs(args.out, exist_ok=True)
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    tflite = converter.convert()
    with open(os.path.join(args.out, "fingerspelling.tflite"), "wb") as f:
        f.write(tflite)
    with open(os.path.join(args.out, "labels.json"), "w") as f:
        json.dump(names, f)
    print("Saved model and labels to", args.out)


if __name__ == "__main__":
    main()
