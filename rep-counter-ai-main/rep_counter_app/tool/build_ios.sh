#!/bin/bash
# hooks_runner currently filters DEVELOPER_DIR from native-asset subprocesses.
# Keep Xcode selection local to this build, even when xcode-select points to CLT.
set -euo pipefail
cd "$(dirname "$0")/.."
repcoach_developer_dir="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
if [[ ! -d "$repcoach_developer_dir/Platforms/iPhoneOS.platform" ]]; then
  echo "Set DEVELOPER_DIR to a full Xcode installation." >&2
  exit 1
fi
repcoach_flutter="${FLUTTER_BIN:-flutter}"
repcoach_tools="$(mktemp -d "${TMPDIR:-/tmp}/repcoach-xcode.XXXXXX")"
trap 'rm -rf "$repcoach_tools"' EXIT
{
  printf '#!/bin/bash\nexport DEVELOPER_DIR=%q\n' "$repcoach_developer_dir"
  printf 'exec /usr/bin/xcrun "$@"\n'
} > "$repcoach_tools/xcrun"
chmod +x "$repcoach_tools/xcrun"
export DEVELOPER_DIR="$repcoach_developer_dir"
export PATH="$repcoach_tools:$PATH"
repcoach_build_target="ios"
if [[ "${1:-}" == "--ipa" ]]; then
  repcoach_build_target="ipa"
  shift
fi
"$repcoach_flutter" build "$repcoach_build_target" "$@"
