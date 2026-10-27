# Run from the repo root, AFTER `flutter create --platforms=web .`
#
#   .\tools\setup_web.ps1
#
# Puts the MediaPipe hand model in web/models/ so the browser loads it from
# your own site instead of Google's storage. Optional: if the file is missing,
# the web app falls back to Google's URL.
#
# The MediaPipe JavaScript and wasm still load from the jsdelivr CDN on first
# use, so the first load needs internet. True offline web (PWA + bundled wasm)
# is future work.
#
# UNTESTED.

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

$webDir = Join-Path $root 'web'
if (-not (Test-Path $webDir)) {
  throw 'web\ folder not found. Run: flutter create --platforms=web .'
}

$models = Join-Path $webDir 'models'
New-Item -ItemType Directory -Force -Path $models | Out-Null
$target = Join-Path $models 'hand_landmarker.task'

if (Test-Path $target) {
  Write-Host 'web\models\hand_landmarker.task already exists.'
  exit 0
}

# Reuse the Android copy if setup_android.ps1 already downloaded it.
$android = Join-Path $root 'android\app\src\main\assets\hand_landmarker.task'
if (Test-Path $android) {
  Copy-Item $android $target
  Write-Host "Copied the model from $android"
} else {
  $url = 'https://storage.googleapis.com/mediapipe-models/hand_landmarker/hand_landmarker/float16/1/hand_landmarker.task'
  Write-Host "Downloading $url"
  Invoke-WebRequest -Uri $url -OutFile $target
  Write-Host "Saved $target"
}
