# Run from the repo root, AFTER `flutter create --platforms=android --org com.signara .`
#
#   .\tools\setup_android.ps1
#
# 1. Sets minSdk to 24 (needed by CameraX / MediaPipe in the signara_landmarks plugin).
# 2. Downloads MediaPipe's hand_landmarker.task into android/app/src/main/assets/.
#
# The camera permission is declared by the plugin's own manifest and gets merged
# into the app automatically, so it is not edited here.
#
# UNTESTED. Review the result with `git diff` before committing.

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

# --- 1. minSdk -------------------------------------------------------------
$candidates = @(
  (Join-Path $root 'android\app\build.gradle.kts'),
  (Join-Path $root 'android\app\build.gradle')
) | Where-Object { Test-Path $_ }

if (-not $candidates) {
  throw 'android\app\build.gradle(.kts) not found. Run flutter create first.'
}

foreach ($f in $candidates) {
  $text = [System.IO.File]::ReadAllText($f)
  $new = $text `
    -replace 'minSdk\s*=\s*flutter\.minSdkVersion', 'minSdk = 24' `
    -replace 'minSdkVersion\s+flutter\.minSdkVersion', 'minSdkVersion 24'
  if ($new -ne $text) {
    # WriteAllText writes UTF-8 without a BOM, which Gradle is happy with.
    [System.IO.File]::WriteAllText($f, $new)
    Write-Host "minSdk set to 24 in $f"
  } else {
    Write-Host "minSdk: nothing changed in $f. Already set, or a different format. Check it by hand."
  }
}

# --- 1b. microphone permission (speech input in Voice -> Sign) -----------------
$manifest = Join-Path $root 'android\app\src\main\AndroidManifest.xml'
if (Test-Path $manifest) {
  $m = [System.IO.File]::ReadAllText($manifest)
  $changed = $false

  if ($m -notmatch 'android\.permission\.RECORD_AUDIO') {
    $m = $m -replace '(<manifest[^>]*>)', ('$1' + "`n    <uses-permission android:name=`"android.permission.RECORD_AUDIO`"/>")
    $changed = $true
  }

  if ($m -notmatch 'android\.speech\.RecognitionService') {
    $intent = "`n        <intent><action android:name=`"android.speech.RecognitionService`"/></intent>"
    if ($m -match '<queries>') {
      $m = $m -replace '<queries>', ('<queries>' + $intent)
    } else {
      $m = $m -replace '</manifest>', ("    <queries>" + $intent + "`n    </queries>`n</manifest>")
    }
    $changed = $true
  }

  if ($changed) {
    [System.IO.File]::WriteAllText($manifest, $m)
    Write-Host 'Added microphone permission and speech service query to AndroidManifest.xml'
  } else {
    Write-Host 'AndroidManifest.xml already has the microphone entries.'
  }
} else {
  Write-Host "AndroidManifest.xml not found at $manifest. Add RECORD_AUDIO by hand."
}

# --- 2. hand landmarker model ----------------------------------------------
$assets = Join-Path $root 'android\app\src\main\assets'
New-Item -ItemType Directory -Force -Path $assets | Out-Null
$model = Join-Path $assets 'hand_landmarker.task'

if (Test-Path $model) {
  Write-Host 'hand_landmarker.task already exists, skipping download.'
} else {
  # URL is from memory. If it 404s, get the model from the MediaPipe
  # "Hand landmarker" docs page and save it to the path above.
  $url = 'https://storage.googleapis.com/mediapipe-models/hand_landmarker/hand_landmarker/float16/1/hand_landmarker.task'
  Write-Host "Downloading $url"
  Invoke-WebRequest -Uri $url -OutFile $model
  Write-Host "Saved $model"
}

Write-Host ''
Write-Host 'Done. Next: git diff, then flutter run on a real Android phone.'
