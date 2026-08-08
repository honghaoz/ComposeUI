#!/bin/bash

set -euo pipefail

# OVERVIEW:
# Fast CI test runner for ComposeUI workspace platforms.
# Compared to the shared ChouTi test-workspace.sh, this script:
# - uses `swift package resolve` instead of `swift package update`
# - skips the expensive `xcodebuild -showdestinations` dump
# - picks simulators via `simctl` only
# - uses a fixed `-derivedDataPath` so GitHub Actions can cache compiles
# - boots the simulator asynchronously so boot time is hidden behind
#   package resolution and the test build
#
# PHASES:
# Simulator platforms (iOS/tvOS) split the work into phases so CI can run
# them as separate workflow steps, which gives per-phase timing in the
# GitHub UI and API:
#   prepare - pick a simulator, kick off boot (async), resolve packages
#   build   - xcodebuild build-for-testing (runs while the simulator boots)
#   test    - wait for boot, then xcodebuild test-without-building
#   all     - run all phases in order (default; for local use)

safe_tput() { [ -n "${TERM:-}" ] && [ "$TERM" != "dumb" ] && tput "$@" || echo ""; }
BOLD=$(safe_tput bold)
CYAN=$(safe_tput setaf 6)
RESET=$(safe_tput sgr0)

print_help() {
  echo "${BOLD}OVERVIEW:${RESET} Fast CI tests for a workspace scheme."
  echo ""
  echo "${BOLD}Usage:${RESET} $0 --workspace-path <path> --scheme <name> --os <iOS|tvOS|macOS> [--phase <prepare|build|test|all>]"
}

WORKSPACE_PATH=""
SCHEME=""
OS=""
DERIVED_DATA_PATH=""
PHASE="all"

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
  --phase)
    PHASE="${2:?missing --phase value}"
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

case "$PHASE" in
prepare | build | test | all) ;;
*)
  echo "🛑 Invalid --phase: $PHASE (expected prepare|build|test|all)"
  exit 1
  ;;
esac

REPO_ROOT=$(git rev-parse --show-toplevel)
WORKSPACE_PATH=$(realpath "$WORKSPACE_PATH")
WORKSPACE_DIR=$(dirname "$WORKSPACE_PATH")

if [ -z "$DERIVED_DATA_PATH" ]; then
  DERIVED_DATA_PATH="$WORKSPACE_DIR/.ci-derived-data"
fi
mkdir -p "$DERIVED_DATA_PATH"

# The prepare phase records the chosen simulator here so the later build/test
# phases (separate processes when run as CI steps) target the same device.
STATE_FILE="$DERIVED_DATA_PATH/ci-test-state.env"

CONTENTS_FILE="$WORKSPACE_PATH/contents.xcworkspacedata"
if [ ! -f "$CONTENTS_FILE" ]; then
  echo "Error: contents.xcworkspacedata not found"
  exit 1
fi

PACKAGE_DIR=$(sed -n 's/.*location = "group:\([^"]*\)".*/\1/p' "$CONTENTS_FILE" | head -n 1)
PACKAGE_DIR=$(realpath "$WORKSPACE_DIR/$PACKAGE_DIR")

echo "🎯 CI test workspace: ${CYAN}$(basename "$WORKSPACE_PATH")${RESET}, scheme: ${CYAN}$SCHEME${RESET}, os: ${CYAN}$OS${RESET}, phase: ${CYAN}$PHASE${RESET}"
echo "DerivedData: $DERIVED_DATA_PATH"
echo "${BOLD}Xcode:${RESET} $(xcodebuild -version | tr '\n' ' ')"

resolve_packages() {
  cd "$PACKAGE_DIR"
  echo "Package: $PACKAGE_DIR/Package.swift"
  echo "Resolve packages (no update)..."
  # Resolve uses Package.resolved pins. Update would hit the network every CI run.
  swift package resolve

  local workspace_package_resolved="$WORKSPACE_PATH/xcshareddata/swiftpm/Package.resolved"
  if [ -f "$PACKAGE_DIR/Package.resolved" ]; then
    mkdir -p "$(dirname "$workspace_package_resolved")"
    cp "$PACKAGE_DIR/Package.resolved" "$workspace_package_resolved"
  fi
  cd "$REPO_ROOT"
}

run_xcodebuild() {
  if [ -x "$REPO_ROOT/bin/xcbeautify" ]; then
    set -o pipefail
    "$@" | "$REPO_ROOT/bin/xcbeautify"
  else
    "$@"
  fi
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

pick_device() {
  local device_info=""
  case "$OS" in
  iOS)
    device_info=$(pick_simulator '^iPhone [0-9]+')
    if [ -z "$device_info" ]; then
      echo "🛑 No available iPhone simulator found"
      exit 1
    fi
    ;;
  tvOS)
    # Prefer Apple TV 4K when present; fall back to any Apple TV.
    device_info=$(pick_simulator '^Apple TV 4K')
    if [ -z "$device_info" ]; then
      device_info=$(pick_simulator '^Apple TV')
    fi
    if [ -z "$device_info" ]; then
      echo "🛑 No available Apple TV simulator found"
      exit 1
    fi
    ;;
  esac

  local runtime
  runtime=$(echo "$device_info" | cut -f1)
  NAME=$(echo "$device_info" | cut -f2)
  UDID=$(echo "$device_info" | cut -f3)
  # runtime looks like "com.apple.CoreSimulator.SimRuntime.iOS-26-0"
  OS_VERSION=$(echo "$runtime" | sed -E 's/.*OS-//' | tr '-' '.')
  DESTINATION="platform=$OS Simulator,id=$UDID"
}

save_state() {
  {
    printf 'CI_TEST_UDID=%q\n' "$UDID"
    printf 'CI_TEST_NAME=%q\n' "$NAME"
    printf 'CI_TEST_OS_VERSION=%q\n' "$OS_VERSION"
    printf 'CI_TEST_DESTINATION=%q\n' "$DESTINATION"
  } >"$STATE_FILE"
}

load_state() {
  if [ ! -f "$STATE_FILE" ]; then
    echo "🛑 State file not found: $STATE_FILE. Run the prepare phase first."
    exit 1
  fi
  # shellcheck disable=SC1090
  source "$STATE_FILE"
  UDID="$CI_TEST_UDID"
  NAME="$CI_TEST_NAME"
  OS_VERSION="$CI_TEST_OS_VERSION"
  DESTINATION="$CI_TEST_DESTINATION"
}

phase_prepare() {
  pick_device
  echo "📱 Simulator: ${CYAN}$NAME ($OS_VERSION)${RESET}, UDID: $UDID"

  # Kick off boot without waiting. The boot finishes while packages resolve
  # and the build phase compiles; the test phase waits for readiness.
  echo "🚀 Booting simulator in the background..."
  xcrun simctl boot "$UDID" 2>/dev/null || true

  resolve_packages
  save_state
}

phase_build() {
  load_state
  echo "🔨 Building for testing on ${CYAN}$NAME ($OS_VERSION)${RESET}..."
  # Building for a simulator destination does not require the device to be
  # booted, so this overlaps with the boot started in the prepare phase.
  run_xcodebuild xcodebuild build-for-testing \
    -workspace "$WORKSPACE_PATH" \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    COMPILER_INDEX_STORE_ENABLE=NO
}

phase_test() {
  load_state
  echo "⏳ Waiting for simulator to finish booting..."
  # bootstatus -b also boots the device in case the prepare-phase boot failed.
  xcrun simctl bootstatus "$UDID" -b
  echo "✅ Simulator ready"

  if [ "${CI:-false}" != "false" ] || [ "${GITHUB_ACTIONS:-false}" != "false" ]; then
    echo "🔧 Setting CI environment variables on simulator..."
    xcrun simctl spawn "$UDID" launchctl setenv CI "${CI:-true}"
    xcrun simctl spawn "$UDID" launchctl setenv CONTINUOUS_INTEGRATION "${CONTINUOUS_INTEGRATION:-true}"
    xcrun simctl spawn "$UDID" launchctl setenv GITHUB_ACTIONS "${GITHUB_ACTIONS:-true}"
  fi

  echo "➡️  Running $OS tests on ${CYAN}$NAME ($OS_VERSION)${RESET}..."
  run_xcodebuild xcodebuild test-without-building \
    -workspace "$WORKSPACE_PATH" \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -retry-tests-on-failure \
    -test-iterations 3

  echo "🧹 Cleaning up CI environment variables..."
  xcrun simctl spawn "$UDID" launchctl unsetenv CI 2>/dev/null || true
  xcrun simctl spawn "$UDID" launchctl unsetenv CONTINUOUS_INTEGRATION 2>/dev/null || true
  xcrun simctl spawn "$UDID" launchctl unsetenv GITHUB_ACTIONS 2>/dev/null || true

  echo "✅ Tests passed."
}

case "$OS" in
macOS)
  if [ "$PHASE" != "all" ]; then
    echo "🛑 --phase is only supported for simulator platforms (iOS/tvOS)"
    exit 1
  fi
  resolve_packages
  echo "➡️  Running macOS package tests via swift test..."
  cd "$PACKAGE_DIR"
  set -o pipefail
  if [ -x "$REPO_ROOT/bin/xcbeautify" ]; then
    swift test -Xswiftc -DTEST | "$REPO_ROOT/bin/xcbeautify"
  else
    swift test -Xswiftc -DTEST
  fi
  echo "✅ Tests passed."
  ;;
iOS | tvOS)
  case "$PHASE" in
  prepare)
    phase_prepare
    ;;
  build)
    phase_build
    ;;
  test)
    phase_test
    ;;
  all)
    phase_prepare
    phase_build
    phase_test
    ;;
  esac
  ;;
*)
  echo "🛑 Unsupported OS for CI fast path: $OS"
  exit 1
  ;;
esac
