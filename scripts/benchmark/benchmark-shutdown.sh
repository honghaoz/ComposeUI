#!/bin/bash

# Shuts down the simulator that the benchmarks of a platform run on, and no other, such as at the end of a CI job on a
# machine where other simulators may be in use. It picks the simulator as benchmark-run.sh and benchmark-compare.sh do.
# macOS has no simulator.

set -euo pipefail

BOLD=$( [ -n "${TERM:-}" ] && [ "$TERM" != "dumb" ] && tput bold || echo "")
RESET=$( [ -n "${TERM:-}" ] && [ "$TERM" != "dumb" ] && tput sgr0 || echo "")

print_help() {
  echo "${BOLD}OVERVIEW:${RESET} Shut down the simulator that the benchmarks of a platform run on, and no other."
  echo ""
  echo "${BOLD}USAGE:${RESET} $0 [--platform <macOS|iOS|tvOS>]"
  echo ""
  echo "${BOLD}OPTIONS:${RESET}"
  echo "  --platform <macOS|iOS|tvOS> The platform the benchmarks ran on. Default is macOS, which has no simulator."
  echo "  --help, -h                  Show this help message."
}

PLATFORM="macOS"

while [[ $# -gt 0 ]]; do
  case "$1" in
  --platform)
    PLATFORM="$2"
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

case "$PLATFORM" in
macOS)
  echo "ℹ️  No simulator to shut down for macOS"
  exit 0
  ;;
iOS | tvOS) ;;
*)
  echo "🛑 --platform must be macOS, iOS or tvOS: $PLATFORM" >&2
  exit 1
  ;;
esac

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)
# shellcheck source-path=SCRIPTDIR source=benchmark-xcodebuild.sh
source "$SCRIPT_DIR/benchmark-xcodebuild.sh"
benchmark_pick_simulator "$PLATFORM"

echo "⏹️  Shutting down simulator: $DEVICE_DESCRIPTION"
# an error means the simulator was already shut down
xcrun simctl shutdown "$DEVICE_UDID" 2> /dev/null || true
echo "✅ Simulator shut down"
