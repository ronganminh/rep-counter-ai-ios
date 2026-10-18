#!/usr/bin/env bash
# Runs inside the booted Android emulator (called by the android-replay workflow).
# Installs the debug CI-video APK, discovers the app temp dir from its
# missing_file log, pushes the fixture into the app sandbox, replays, and reads
# the CI_VIDEO_RESULT. Informational: never hard-fails on the rep count.
set -uo pipefail

ART="$GITHUB_WORKSPACE/ci-artifacts"
mkdir -p "$ART"
APK="build/app/outputs/flutter-apk/app-store-debug.apk"
ACTIVITY="$PKG/.MainActivity"
RESULT="ci-video-result.txt"

adb wait-for-device
adb install -r -g "$APK" || adb install -r "$APK"
adb shell pm grant "$PKG" android.permission.CAMERA 2>/dev/null || true

# First launch WITHOUT the video so the app logs the temp path it looks in.
adb logcat -c || true
adb shell am start -n "$ACTIVITY" >/dev/null 2>&1 \
  || adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1

tmp_path=""
for _ in $(seq 1 40); do
  line="$(adb logcat -d 2>/dev/null | grep -F '[CI_VIDEO_ERROR] missing_file path=' | tail -n1 || true)"
  if [ -n "$line" ]; then
    tmp_path="${line##*path=}"
    tmp_path="$(printf '%s' "$tmp_path" | tr -d '\r')"
    break
  fi
  sleep 3
done

if [ -z "$tmp_path" ]; then
  echo "Could not discover the app temp path from logcat." >&2
  adb logcat -d 2>/dev/null | tail -n 200 | tee "$ART/android-logcat.txt"
  exit 1
fi
tmp_dir="$(dirname "$tmp_path")"
echo "App temp dir: $tmp_dir"

# Push fixture into the app's private dir via run-as (debuggable build).
adb push "$FIXTURE_PATH" "/data/local/tmp/$TEST_VIDEO_ASSET"
adb shell "run-as $PKG mkdir -p '$tmp_dir'" 2>/dev/null || true
adb shell "run-as $PKG sh -c 'cp /data/local/tmp/$TEST_VIDEO_ASSET \"$tmp_path\"'"
adb shell "run-as $PKG sh -c 'rm -f \"$tmp_dir/$RESULT\"'" 2>/dev/null || true

# Relaunch to run the replay.
adb shell am force-stop "$PKG" || true
adb logcat -c || true
adb shell am start -n "$ACTIVITY" >/dev/null 2>&1 \
  || adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1

found=0
for _ in $(seq 1 1100); do
  cur="$(adb shell "run-as $PKG sh -c 'cat \"$tmp_dir/$RESULT\" 2>/dev/null'" 2>/dev/null || true)"
  if printf '%s' "$cur" | grep -q '\[CI_VIDEO_RESULT\]'; then
    found=1
    break
  fi
  if printf '%s' "$cur" | grep -q '\[CI_VIDEO_ERROR\]'; then
    printf '%s\n' "$cur"
    break
  fi
  sleep 6
done

adb exec-out screencap -p > "$ART/android-video-result.png" 2>/dev/null || true
adb logcat -d > "$ART/android-logcat.txt" 2>/dev/null || true
adb shell "run-as $PKG sh -c 'cat \"$tmp_dir/$RESULT\"'" > "$ART/ci-video-result.txt" 2>/dev/null || true
grep -F 'CI_VIDEO_STATUS' "$ART/android-logcat.txt" > "$ART/ci-video-timeline.txt" 2>/dev/null || true

echo "=================== ANDROID REPLAY RESULT ==================="
cat "$ART/ci-video-result.txt" 2>/dev/null || echo "(no result file)"
echo "============================================================"

if [ "$found" != "1" ]; then
  echo "::warning::Android replay did not produce a CI_VIDEO_RESULT in time (informational job)."
fi
