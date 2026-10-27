# Signara

Offline-first, two-way sign language app for Android (ASL first, FSL-extensible).
Thesis project. Mascot: firefly (alitaptap).

> Prototype. Not a replacement for a human interpreter.

## Status

Scaffold only. **Nothing here has been compiled or run yet**: it was written in an
environment without the Flutter or Android toolchains. Expect small fixes on first build.

All features exist as a **prototype** (functional, not designed). UI/UX comes later.

| Feature | State |
|---|---|
| Fingerspelling: camera -> letters -> word -> voice | letters you **record yourself** (nearest example), plus finger rules (A B D I L S V W Y) as fallback. Personalized, not a general trained model. |
| Sign recognition (Signs mode) | by example: dynamic time warping against signs you **record** in Collect samples. One hand, needs a pause between signs, personalized. |
| Collect samples (Me tab) | records hand landmark numbers (no pictures), export/import as JSON; `training/import_samples.py` turns an export into training files |
| Reference animation | recorded samples play as a moving hand skeleton in lessons and Voice -> Sign (stand-in for video/avatar) |
| Microphone input | speech-to-text in Voice -> Sign (EN/FIL), needs `setup_android.ps1` for the permission |
| Sentence smoothing (gloss -> EN/FIL sentence) | rule-based, ~12 templates; used by Phrases mode |
| Phrases mode | input is **simulated** (tap signs); smoothing + TTS are real |
| Voice -> Sign | spoken or typed text -> signs / fingerspelling steps, word-for-word (real ASL grammar differs) |
| Recognizer as teacher | camera feedback ("Extend your thumb") for the 9 rule letters; thresholds need tuning on a phone |
| Streak, XP, spaced repetition (Leitner), daily practice | done, tested |
| Situational lessons | flashcards for basics / emergency / hospital / school / questions; **no sign clips yet** |
| Emergency mode (EN/FIL, one tap, voice) | done; wording needs Deaf review |
| Deaf culture section | **draft** by hearing devs; needs Deaf review |
| Community contribution | **mock**; saved on device only, goes nowhere |
| Offline-first | everything runs on device; sentence LLM not used yet |
| Native plugin (CameraX + MediaPipe) | written, needs on-device verification |
| Landmarks from licensed videos (`training/extract_video_landmarks.py`) | written, untested; run locally on videos you are allowed to use; output stays on your machine unless the license allows sharing |
| Vocab cross-check vs ASL-LEX (`tools/vocab_crosscheck.py`) | done (tested with a fake CSV); gloss spelling only, not sign correctness |
| Outreach + consent drafts (`docs/`) | drafts, need adviser/ethics review |
| Trained neural models (TFLite) | not built. The recognizers are example-based for now; export samples and train later if the thesis needs it |
| LLM sentence smoothing (online) | not built; rule-based smoothing only |
| Web: fully offline (PWA, bundled wasm) | not built; first web load needs internet |

## Web and Android

The same app runs on both. The camera + hand landmarks sit behind one API
(`packages/signara_landmarks`): Kotlin + MediaPipe on Android, MediaPipe JS (WebAssembly)
in the browser. Frames never leave the device on either.

Web notes:
- Camera needs **https or localhost** (Vercel is https). The browser asks for permission.
- The first load needs internet (MediaPipe JS + wasm come from the jsdelivr CDN).
  Run `.\tools\setup_web.ps1` to serve the hand model from your own site too.
  A fully offline web build (PWA + bundled wasm) is future work.
- Performance depends on the browser and device; measure it with the spike screen.
- Web camera code is **untested**. If `flutter run -d chrome` shows an error when you tap
  Start camera, send me the message.

## First-time setup

```bash
cd signara
flutter create --platforms=android --org com.signara .   # generates android/ runner
flutter pub get
```

1. Run `.\tools\setup_android.ps1` (PowerShell, from the repo root). It sets `minSdk = 24`
   and downloads MediaPipe's `hand_landmarker.task` into `android/app/src/main/assets/`.
   Check the result with `git diff`. Do it by hand if the script fails.
2. The camera permission comes from the plugin's manifest and is merged automatically.
   If the camera is denied at runtime, add
   `<uses-permission android:name="android.permission.CAMERA" />` to the app manifest.
3. Commit the model (it is small) so CI builds include it. Check its license first.
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

- **Dataset licenses.** ASL Citizen is non-commercial research only, no redistribution,
  no hosted service: do not bundle its videos or derived data in the app or on Vercel
  without written permission. ASL-LEX is CC BY-NC 4.0 (credit, non-commercial). FSL-105
  states no license on its page: ask the authors. WLASL and SignAvatars: not yet checked.
  Do not use TikTok or other creators' videos without their permission.
- **Idea from a demo video (not built):** show facial expression/emotion next to the
  gloss stream, since ASL grammar uses the face. Needs Deaf guidance and more data.
- **Vocab is a draft.** Check every gloss exists in the dataset you train on
  (WLASL / ASL Citizen; check licenses) and that a Deaf signer agrees the sign is right.
- **LLM sentence smoothing vs offline-first:** use rule-based templates offline,
  LLM only when online. State this in the thesis.
- **J and Z** in fingerspelling are motion-based; handle them with the sequence model.
- **Deaf community validation:** reach out now. Filipino Deaf mainly use FSL, so tell
  them clearly this prototype is ASL.
- Emergency phrases and the wording "Deaf po ako" need Deaf review.
