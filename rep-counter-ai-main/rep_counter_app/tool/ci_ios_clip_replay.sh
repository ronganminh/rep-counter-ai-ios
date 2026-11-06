#!/usr/bin/env bash
# Clip smoke replay on the iOS Simulator (plan 07 PR B, smoke-replay.yml).
# Same steps as the reference replay in ios-ci.yml, with a short budget: the
# looped sample clips last about a minute. Never judges the rep count; it
# fails only when the replay produced no result.
#
# Env: FIXTURE_PATH, TEST_VIDEO_ASSET, ART (artifact dir),
#      REPLAY_WAIT_SECONDS (default 1200).
set -euo pipefail

mkdir -p "$ART"
udid="$(xcrun simctl list devices available -j | jq -r '
  [.devices | to_entries[] | select(.key | contains("iOS-18"))
   | .value[] | select(.isAvailable == true)
   | select(.name | startswith("iPhone"))][0].udid // empty')"
if [[ -z "$udid" ]]; then
  echo "No available iPhone simulator was found." >&2
  exit 1
fi
xcrun simctl boot "$udid" 2>/dev/null || true
xcrun simctl bootstatus "$udid" -b

bundle_id="com.ronganminh.repCounterApp"
xcrun simctl install "$udid" build/ios/iphonesimulator/Runner.app
data_dir="$(xcrun simctl get_app_container "$udid" "$bundle_id" data)"
result_file="$data_dir/tmp/ci-video-result.txt"
rm -f "$result_file"
cp "$FIXTURE_PATH" "$data_dir/tmp/$TEST_VIDEO_ASSET"

xcrun simctl launch --terminate-running-process \
  --stdout="$ART/runner.stdout.log" --stderr="$ART/runner.stderr.log" \
  "$udid" "$bundle_id"

timeline="$ART/ci-video-timeline.txt"
: > "$timeline"
last=""
found=0
deadline=$(( $(date +%s) + ${REPLAY_WAIT_SECONDS:-1200} ))
while [[ "$(date +%s)" -lt "$deadline" ]]; do
  if grep -Eq "F0000|Check failed:|Abort trap|Terminated due to signal" \
      "$ART/runner.stderr.log" 2>/dev/null; then
    echo "[CI_VIDEO_ERROR] native_mlkit_crash" | tee "$ART/ci-video-result.txt"
    break
  fi
  if [[ -s "$result_file" ]]; then
    cur="$(cat "$result_file")"
    if [[ "$cur" != "$last" ]]; then
      printf '%s\n' "$cur" >> "$timeline"
      last="$cur"
    fi
    if grep -q "\[CI_VIDEO_RESULT\]\|\[CI_VIDEO_ERROR\]" "$result_file"; then
      found=1
      break
    fi
  fi
  # The result file holds only the latest status line; poll often so the
  # timeline keeps most 5-second samples of a one-minute clip.
  sleep 1
done

xcrun simctl io "$udid" screenshot "$ART/ios-video-result.png" || true
if [[ -s "$result_file" ]]; then cp "$result_file" "$ART/ci-video-result.txt"; fi
echo "=================== iOS CLIP REPLAY RESULT ==================="
cat "$ART/ci-video-result.txt" 2>/dev/null || echo "(no result file)"
echo "=============================================================="
[[ "$found" == "1" ]]
