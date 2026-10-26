# Signara

Offline-first, two-way sign language app for Android (ASL first, FSL-extensible).
Thesis project. Mascot: firefly (alitaptap).

> Prototype. Not a replacement for a human interpreter.

## Status

Scaffold only. **Nothing here has been compiled or run yet**: it was written in an
environment without the Flutter or Android toolchains. Expect small fixes on first build.

| Part | State |
|---|---|
| App shell (Translate / Learn / Emergency / Me) | written, not run |
| Streak + XP logic (`lib/core/streak_service.dart`) | written, tests in `test/` not run |
| Emergency mode with TTS (EN / FIL) | written, not run |
| Vocab v0 (26 letters, 10 numbers, 57 signs) | JSON validated; glosses **unverified** |
| Native plugin (CameraX + MediaPipe hand landmarks) | skeleton, not compiled |
| Recognition, learning feedback, speech → sign | not started |

## First-time setup

```bash
cd signara
flutter create --platforms=android --org com.signara .   # generates android/ runner
flutter pub get
```

1. In `android/app/build.gradle`, set `minSdk = 24` (or higher).
2. Add the camera permission to `android/app/src/main/AndroidManifest.xml`:
   `<uses-permission android:name="android.permission.CAMERA" />`
3. Download MediaPipe's `hand_landmarker.task` model and put it in
   `android/app/src/main/assets/` (create the folder). Commit it (it is small), so CI builds
   include it. Check the model's license first.
4. The logo is `assets/branding/signara_logo.png` (600x600, used as provided, unmodified).
   For the launcher icon, use `flutter_launcher_icons` pointed at that file.
5. `flutter test` then `flutter run` on a real device (the camera does not work well on emulators).

If Gradle complains about `packages/signara_landmarks/android/build.gradle`, generate a
fresh plugin template in a scratch folder (`flutter create --template=plugin --platforms=android x`)
and copy its Gradle/AGP/Kotlin versions. Keep the `dependencies` block.

## Week-1 spike (the one that decides the architecture)

Open **Translate → "Week-1 spike"**. It shows the camera preview with hand landmarks
drawn on top, plus fps and latency.

- **Pass:** >= 15 fps on a cheap, older Android phone, not only your dev phone.
- **Fail:** move the camera screen to a native PlatformView and keep Flutter for the rest.

Camera frames never cross into Dart. Only landmark arrays do.

## Layout

```
lib/                      Flutter app
  core/                   theme, streak/XP, progress controller
  data/                   vocab loader, emergency phrases
  features/               translate, learn, emergency, profile, spike
packages/signara_landmarks/   local plugin: Kotlin camera + MediaPipe, Dart API
assets/vocab/vocab_v0.json    vocab list (DRAFT)
assets/branding/              icon
training/                     model training (Python), see training/README.md
docs/                         notes for the thesis
```

## Open decisions / risks

- **Vocab is a draft.** Check every gloss exists in the dataset you train on
  (WLASL / ASL Citizen; check licenses) and that a Deaf signer agrees the sign is right.
- **LLM sentence smoothing vs offline-first:** use rule-based templates offline,
  LLM only when online. State this in the thesis.
- **J and Z** in fingerspelling are motion-based; handle them with the sequence model.
- **Deaf community validation:** reach out now. Filipino Deaf mainly use FSL, so tell
  them clearly this prototype is ASL.
- Emergency phrases and the wording "Deaf po ako" need Deaf review.
