#!/bin/bash

set -euo pipefail

# OVERVIEW:
# Runs the hosted tests, which run in an app with a window scene, on an iOS or visionOS simulator.
#
# The package's tests run in a test runner without a window scene, where UIKit doesn't set up views as in an app, such
# as visionOS wrapping the layers of some views, so ComposeUI/HostedTests has an app to host the tests that need one.
#
# The build and the tests are separate phases, so CI can run them as separate steps, as the package's tests do: the
# simulator boots in the test phase, after the build, since both are CPU-heavy.

REPO_ROOT=$(git rev-parse --show-toplevel)
PROJECT="$REPO_ROOT/ComposeUI/HostedTests/ComposeUIHostedTests.xcodeproj"
SCHEME="ComposeUIHostedTests"

print_help() {
  echo "Usage: $0 --os <iOS|visionOS> [--phase <build|test|all>] [--derived-data-path <path>]"
  echo ""
  echo "  --os <iOS|visionOS>          The platform to test on. Required."
  echo "  --phase <build|test|all>     build: build the tests. test: boot the simulator and run the built tests."
  echo "                               all: both, the default."
  echo "  --derived-data-path <path>   Use a fixed DerivedData path. Optional. Default is Xcode's DerivedData."
}

OS=""
PHASE="all"
DERIVED_DATA_PATH=""

while [[ "$#" -gt 0 ]]; do
  case $1 in
  --os)
    OS="${2:-}"
    shift 2
    ;;
  --phase)
    PHASE="${2:-}"
    shift 2
    ;;
  --derived-data-path)
    DERIVED_DATA_PATH="${2:-}"
    shift 2
    ;;
  --help | -h)
    print_help
    exit 0
    ;;
  *)
    echo "🛑 Unknown argument: $1" >&2
    print_help
    exit 1
    ;;
  esac
done

case "$PHASE" in
build | test | all) ;;
*)
  echo "🛑 Invalid --phase: $PHASE (expected build|test|all)" >&2
  exit 1
  ;;
esac

# the plain base model, such as "iPhone 17", before any other device of the platform, as the package's tests pick, so
# that on CI the tests run on the simulator that the package's tests booted
case "$OS" in
iOS)
  DEVICE_NAMES=("^iPhone [0-9]+$" "^iPhone")
  ;;
visionOS)
  DEVICE_NAMES=("^Apple Vision")
  ;;
*)
  echo "🛑 Invalid --os: '$OS' (expected iOS or visionOS)" >&2
  exit 1
  ;;
esac

if [ -x "$REPO_ROOT/bin/jq" ]; then
  JQ_BIN="$REPO_ROOT/bin/jq"
elif command -v jq > /dev/null; then
  JQ_BIN="jq"
else
  echo "🛑 jq not found. Run make bootstrap or install jq." >&2
  exit 1
fi

DEVICE=""
for name in "${DEVICE_NAMES[@]}"; do
  # the newest runtime first, comparing its version numerically, then the last name alphabetically
  DEVICE=$(xcrun simctl list devices available -j | "$JQ_BIN" -r --arg re "$name" '
    [
      .devices
      | to_entries[]
      | .key as $runtime
      | .value[]
      | select(.isAvailable == true and (.name | test($re)))
      | {name: .name, udid: .udid, version: ($runtime | sub(".*OS-"; "") | split("-") | map(tonumber? // 0))}
    ]
    | sort_by([.version, .name])
    | last // empty
    | [.name, .udid, (.version | map(tostring) | join("."))]
    | @tsv
  ')
  if [ -n "$DEVICE" ]; then
    break
  fi
done
if [ -z "$DEVICE" ]; then
  echo "🛑 No available $OS simulator found" >&2
  exit 1
fi
DEVICE_UDID=$(echo "$DEVICE" | cut -f2)
DESTINATION="platform=$OS Simulator,id=$DEVICE_UDID"
echo "📱 Destination: $(echo "$DEVICE" | cut -f1) ($(echo "$DEVICE" | cut -f3)), UDID: $DEVICE_UDID"

# expand with ${DD_ARGS[@]+"${DD_ARGS[@]}"}, so that an empty array is safe under set -u in macOS's bash 3.2
DD_ARGS=()
if [ -n "$DERIVED_DATA_PATH" ]; then
  DD_ARGS=(-derivedDataPath "$DERIVED_DATA_PATH")
fi

run_xcodebuild() {
  if [ -x "$REPO_ROOT/bin/xcbeautify" ]; then
    "$@" | "$REPO_ROOT/bin/xcbeautify"
  else
    "$@"
  fi
}

if [ "$PHASE" = build ] || [ "$PHASE" = all ]; then
  echo "🔨 Building the hosted tests for $OS..."
  run_xcodebuild xcodebuild build-for-testing -project "$PROJECT" -scheme "$SCHEME" -destination "$DESTINATION" \
    ${DD_ARGS[@]+"${DD_ARGS[@]}"} COMPILER_INDEX_STORE_ENABLE=NO
fi

if [ "$PHASE" = test ] || [ "$PHASE" = all ]; then
  echo "⏳ Booting the simulator, or waiting for its boot..."
  xcrun simctl bootstatus "$DEVICE_UDID" -b > /dev/null
  echo "➡️  Running the hosted tests on $OS..."
  run_xcodebuild xcodebuild test-without-building -project "$PROJECT" -scheme "$SCHEME" -destination "$DESTINATION" \
    ${DD_ARGS[@]+"${DD_ARGS[@]}"}
fi
