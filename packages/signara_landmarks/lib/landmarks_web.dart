// Web implementation: camera via getUserMedia, hand landmarks via MediaPipe
// Tasks Vision (JavaScript, WebAssembly). Runs in the browser, nothing is
// uploaded.
//
// UNTESTED: written without a browser or Dart SDK.
//
// The MediaPipe script and wasm come from the jsdelivr CDN on first use, so
// the first load needs internet. The hand model is loaded from
// `models/hand_landmarker.task` next to index.html if present (run
// tools/setup_web.ps1), otherwise from Google's storage URL.

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'landmark_types.dart';

const String _moduleSource = r'''
import { HandLandmarker, FilesetResolver } from "https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.14/vision_bundle.mjs";

const WASM = "https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.14/wasm";
const MODELS = [
  "models/hand_landmarker.task",
  "https://storage.googleapis.com/mediapipe-models/hand_landmarker/hand_landmarker/float16/1/hand_landmarker.task",
];

let landmarker = null;
let stream = null;
let video = null;
let rafId = 0;
let running = false;
let lastTime = -1;

async function createLandmarker() {
  const fileset = await FilesetResolver.forVisionTasks(WASM);
  let lastError = null;
  for (const path of MODELS) {
    for (const delegate of ["GPU", "CPU"]) {
      try {
        return await HandLandmarker.createFromOptions(fileset, {
          baseOptions: { modelAssetPath: path, delegate: delegate },
          runningMode: "VIDEO",
          numHands: 2,
        });
      } catch (e) {
        lastError = e;
      }
    }
  }
  throw lastError || new Error("Could not load the hand model.");
}

function stopAll() {
  running = false;
  if (rafId) cancelAnimationFrame(rafId);
  rafId = 0;
  if (stream) {
    stream.getTracks().forEach((t) => t.stop());
    stream = null;
  }
  if (video) {
    video.srcObject = null;
    video = null;
  }
}

window.signaraLandmarks = {
  async start(front, onFrame) {
    stopAll();
    stream = await navigator.mediaDevices.getUserMedia({
      video: {
        facingMode: front ? "user" : "environment",
        width: { ideal: 640 },
        height: { ideal: 480 },
      },
      audio: false,
    });
    const v = document.createElement("video");
    v.setAttribute("playsinline", "");
    v.muted = true;
    v.srcObject = stream;
    video = v;
    await v.play();

    if (!landmarker) landmarker = await createLandmarker();

    running = true;
    lastTime = -1;
    const loop = () => {
      if (!running || video !== v) return;
      if (v.readyState >= 2 && v.currentTime !== lastTime) {
        lastTime = v.currentTime;
        const t0 = performance.now();
        let res = null;
        try {
          res = landmarker.detectForVideo(v, t0);
        } catch (e) {
          res = null;
        }
        const inferMs = Math.round(performance.now() - t0);
        const hd = (res && (res.handedness || res.handednesses)) || [];
        const hands = ((res && res.landmarks) || []).map((pts, i) => ({
          handedness: (hd[i] && hd[i][0] && hd[i][0].categoryName) || "?",
          xyz: pts.flatMap((p) => [p.x, p.y, p.z]),
        }));
        const aspect = v.videoHeight ? v.videoWidth / v.videoHeight : 0.75;
        onFrame(JSON.stringify({ ts: Math.round(t0), inferMs: inferMs, aspect: aspect, hands: hands }));
      }
      rafId = requestAnimationFrame(loop);
    };
    rafId = requestAnimationFrame(loop);
    return v;
  },
  stop() {
    stopAll();
  },
};
''';

@JS()
extension type _SignaraJs._(JSObject _) implements JSObject {
  external JSPromise<web.HTMLVideoElement> start(bool front, JSFunction onFrame);
  external void stop();
}

@JS('signaraLandmarks')
external _SignaraJs? get _api;

final StreamController<LandmarkFrame> _frames =
    StreamController<LandmarkFrame>.broadcast();
int _nextViewId = 0;

Future<void> _ensureLoaded() async {
  if (_api != null) return;
  final script = web.document.createElement('script') as web.HTMLScriptElement;
  script.type = 'module';
  script.text = _moduleSource;
  web.document.head!.append(script);

  for (var i = 0; i < 200 && _api == null; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  if (_api == null) {
    throw StateError(
      'Could not load MediaPipe in the browser. Check your internet '
      'connection (first load needs it).',
    );
  }
}

Future<int?> start({bool front = false, int width = 640, int height = 480}) async {
  await _ensureLoaded();

  void onFrame(JSString json) {
    final m = jsonDecode(json.toDart) as Map<String, dynamic>;
    _frames.add(LandmarkFrame.fromMap(m));
  }

  final video = await _api!.start(front, onFrame.toJS).toDart;

  video.style.setProperty('object-fit', 'cover');
  video.style.setProperty('width', '100%');
  video.style.setProperty('height', '100%');
  // Mirror the selfie camera so it behaves like a mirror. The landmarks stay
  // in the unmirrored image; the spike painter flips x for the front camera.
  video.style.setProperty('transform', front ? 'scaleX(-1)' : 'none');

  final id = _nextViewId++;
  ui_web.platformViewRegistry.registerViewFactory(
    'signara-video-$id',
    (int viewId) => video,
  );
  return id;
}

Future<void> stop() async {
  _api?.stop();
}

Stream<LandmarkFrame> get frames => _frames.stream;

Widget buildPreview(int id) => HtmlElementView(viewType: 'signara-video-$id');
