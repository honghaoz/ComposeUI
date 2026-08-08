#!/bin/bash

set -euo pipefail

# OVERVIEW:
# Fast CI test runner for ComposeUI workspace platforms.
# Compared to the shared ChouTi test-workspace.sh, this script:
# - uses `swift package resolve` instead of `swift package update`
# - skips the expensive `xcodebuild -showdestinations` dump
# - picks simulators via `simctl` only
# - uses a fixed `-derivedDataPath` so GitHub Actions can cache compiles
# - uses `simctl bootstatus -b` for clearer boot waiting

safe_tput() { [ -n "${TERM:-}" ] && [ "$TERM" != "dumb" ] && tput "$@" || echo ""; }
BOLD=$(safe_tput bold)
CYAN=$(safe_tput setaf 6)
RESET=$(safe_tput sgr0)

print_help() {
  echo "${BOLD}OVERVIEW:${RESET} Fast CI tests for a workspace scheme."
  echo ""
  echo "${BOLD}Usage:${RESET} $0 --workspace-path <path> --scheme <name> --os <iOS|tvOS|macOS>"
}

WORKSPACE_PATH=""
SCHEME=""
OS=""
DERIVED_DATA_PATH=""

while [[ "$#" -gt 0 ]]; do
  case $1 in
  --workspace-path)
    WORKSPACE_PATH="${2:?missing --workspace-path value}"
    shift 2
    ;;
  --scheme)
    SCHEME="${2:?missing --scheme value}"
    shift 2
    ;;
  --os)
    OS="${2:?missing --os value}"
    shift 2
    ;;
  --derived-data-path)
    DERIVED_DATA_PATH="${2:?missing --derived-data-path value}"
    shift 2
    ;;
  --help | -h)
    print_help
    exit 0
    ;;
  *)
    echo "🛑 Unknown option: $1" >&2
    print_help
    exit 1
    ;;
  esac
done

if [ -z "$WORKSPACE_PATH" ] || [ -z "$SCHEME" ] || [ -z "$OS" ]; then
  print_help
  exit 1
fi

REPO_ROOT=$(git rev-parse --show-toplevel)
WORKSPACE_PATH=$(realpath "$WORKSPACE_PATH")
WORKSPACE_DIR=$(dirname "$WORKSPACE_PATH")
WORKSPACE=$(basename "$WORKSPACE_PATH")

if [ -z "$DERIVED_DATA_PATH" ]; then
  DERIVED_DATA_PATH="$WORKSPACE_DIR/.ci-derived-data"
fi
mkdir -p "$DERIVED_DATA_PATH"

CONTENTS_FILE="$WORKSPACE_PATH/contents.xcworkspacedata"
if [ ! -f "$CONTENTS_FILE" ]; then
  echo "Error: contents.xcworkspacedata not found"
  exit 1
fi

PACKAGE_DIR=$(sed -n 's/.*location = "group:\([^"]*\)".*/\1/p' "$CONTENTS_FILE" | head -n 1)
PACKAGE_DIR=$(realpath "$WORKSPACE_DIR/$PACKAGE_DIR")

cd "$PACKAGE_DIR"
echo "Package: $PACKAGE_DIR/Package.swift"
echo "Resolve packages (no update)..."
# Resolve uses Package.resolved pins. Update would hit the network every CI run.
swift package resolve

cd "$WORKSPACE_DIR"
WORKSPACE_PACKAGE_RESOLVED="$WORKSPACE_PATH/xcshareddata/swiftpm/Package.resolved"
if [ -f "$PACKAGE_DIR/Package.resolved" ]; then
  mkdir -p "$(dirname "$WORKSPACE_PACKAGE_RESOLVED")"
  cp "$PACKAGE_DIR/Package.resolved" "$WORKSPACE_PACKAGE_RESOLVED"
fi

echo "🎯 CI test workspace: ${CYAN}$WORKSPACE${RESET}, scheme: ${CYAN}$SCHEME${RESET}, os: ${CYAN}$OS${RESET}"
echo "DerivedData: $DERIVED_DATA_PATH"
echo "${BOLD}Xcode:${RESET} $(xcodebuild -version | tr '\n' ' ')"

run_xcodebuild_test() {
  local destination="$1"
  local -a cmd=(
    xcodebuild test
    -workspace "$WORKSPACE"
    -scheme "$SCHEME"
    -destination "$destination"
    -derivedDataPath "$DERIVED_DATA_PATH"
    -retry-tests-on-failure
    -test-iterations 3
  )

  if [ -x "$REPO_ROOT/bin/xcbeautify" ]; then
    set -o pipefail
    "${cmd[@]}" | "$REPO_ROOT/bin/xcbeautify"
  else
    "${cmd[@]}"
  fi
}

boot_simulator() {
  local udid="$1"
  echo "📱 Device UDID: $udid"
  echo "🚀 Booting simulator..."
  xcrun simctl boot "$udid" 2>/dev/null || true
  # bootstatus -b waits until the simulator is ready for use
  xcrun simctl bootstatus "$udid" -b
  echo "✅ Simulator ready"

  if [ "${CI:-false}" != "false" ] || [ "${GITHUB_ACTIONS:-false}" != "false" ]; then
    echo "🔧 Setting CI environment variables on simulator..."
    xcrun simctl spawn "$udid" launchctl setenv CI "${CI:-true}"
    xcrun simctl spawn "$udid" launchctl setenv CONTINUOUS_INTEGRATION "${CONTINUOUS_INTEGRATION:-true}"
    xcrun simctl spawn "$udid" launchctl setenv GITHUB_ACTIONS "${GITHUB_ACTIONS:-true}"
  fi
}

cleanup_simulator() {
  local udid="$1"
  echo "🧹 Cleaning up CI environment variables..."
  xcrun simctl spawn "$udid" launchctl unsetenv CI 2>/dev/null || true
  xcrun simctl spawn "$udid" launchctl unsetenv CONTINUOUS_INTEGRATION 2>/dev/null || true
  xcrun simctl spawn "$udid" launchctl unsetenv GITHUB_ACTIONS 2>/dev/null || true
}

# Prefer the newest available matching simulator without dumping every destination.
pick_simulator() {
  local name_regex="$1"
  # JSON is more reliable than grepping the human-readable device list.
  xcrun simctl list devices available -j | "$REPO_ROOT/bin/jq" -r --arg re "$name_regex" '
    .devices
    | to_entries[]
    | .key as $runtime
    | .value[]
    | select(.isAvailable == true and (.name | test($re)))
    | [$runtime, .name, .udid]
    | @tsv
  ' | sort -r | head -n 1
}

case "$OS" in
macOS)
  echo "➡️  Running macOS package tests via swift test..."
  cd "$PACKAGE_DIR"
  set -o pipefail
  if [ -x "$REPO_ROOT/bin/xcbeautify" ]; then
    swift test -Xswiftc -DTEST | "$REPO_ROOT/bin/xcbeautify"
  else
    swift test -Xswiftc -DTEST
  fi
  ;;
iOS)
  DEVICE_INFO=$(pick_simulator '^iPhone [0-9]+')
  if [ -z "$DEVICE_INFO" ]; then
    echo "🛑 No available iPhone simulator found"
    exit 1
  fi
  RUNTIME=$(echo "$DEVICE_INFO" | cut -f1)
  NAME=$(echo "$DEVICE_INFO" | cut -f2)
  UDID=$(echo "$DEVICE_INFO" | cut -f3)
  OS_VERSION=$(echo "$RUNTIME" | sed -E 's/.*iOS-([0-9-]+)/\1/' | tr '-' '.')
  DESTINATION="platform=iOS Simulator,id=$UDID"
  echo "➡️  Running iOS tests on ${CYAN}$NAME ($OS_VERSION)${RESET}..."
  boot_simulator "$UDID"
  run_xcodebuild_test "$DESTINATION"
  cleanup_simulator "$UDID"
  ;;
tvOS)
  # Prefer Apple TV 4K when present; fall back to any Apple TV.
  DEVICE_INFO=$(pick_simulator '^Apple TV 4K')
  if [ -z "$DEVICE_INFO" ]; then
    DEVICE_INFO=$(pick_simulator '^Apple TV')
  fi
  if [ -z "$DEVICE_INFO" ]; then
    echo "🛑 No available Apple TV simulator found"
    exit 1
  fi
  RUNTIME=$(echo "$DEVICE_INFO" | cut -f1)
  NAME=$(echo "$DEVICE_INFO" | cut -f2)
  UDID=$(echo "$DEVICE_INFO" | cut -f3)
  OS_VERSION=$(echo "$RUNTIME" | sed -E 's/.*tvOS-([0-9-]+)/\1/' | tr '-' '.')
  DESTINATION="platform=tvOS Simulator,id=$UDID"
  echo "➡️  Running tvOS tests on ${CYAN}$NAME ($OS_VERSION)${RESET}..."
  boot_simulator "$UDID"
  run_xcodebuild_test "$DESTINATION"
  cleanup_simulator "$UDID"
  ;;
*)
  echo "🛑 Unsupported OS for CI fast path: $OS"
  exit 1
  ;;
esac

echo "✅ Tests passed."
