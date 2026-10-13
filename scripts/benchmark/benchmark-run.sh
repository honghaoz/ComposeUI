#!/bin/bash

# Runs the benchmarks of the working tree once, in release, on macOS or on an iOS or tvOS simulator.
#
# The tests use debug-only hooks, so the release build defines DEBUG, and deterministic hashing keeps the instruction
# counts from varying between runs. On a simulator, the benchmarks build and run with xcodebuild, see
# benchmark-xcodebuild.sh, and the build is kept in the package's build directory, so that the next run builds only what
# changed, as `swift test` does on macOS.

set -euo pipefail

BOLD=$( [ -n "${TERM:-}" ] && [ "$TERM" != "dumb" ] && tput bold || echo "")
RESET=$( [ -n "${TERM:-}" ] && [ "$TERM" != "dumb" ] && tput sgr0 || echo "")

print_help() {
  echo "${BOLD}OVERVIEW:${RESET} Run the benchmarks of the working tree once, in release, on macOS or a simulator."
  echo ""
  echo "${BOLD}USAGE:${RESET} $0 [--platform <macOS|iOS|tvOS>] [--filter <regex>]"
  echo ""
  echo "${BOLD}OPTIONS:${RESET}"
  echo "  --platform <macOS|iOS|tvOS> The platform to run on, macOS or the newest available simulator of iOS or tvOS. Default is macOS."
  echo "  --filter <regex>            The benchmarks to run, as a swift test filter. Default is the benchmark suites, all of them."
  echo "  --help, -h                  Show this help message."
}

PLATFORM="macOS"
FILTER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
  --platform)
    PLATFORM="$2"
    shift 2
    ;;
  --filter)
    FILTER="$2"
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
macOS | iOS | tvOS) ;;
*)
  echo "🛑 --platform must be macOS, iOS or tvOS: $PLATFORM" >&2
  exit 1
  ;;
esac

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)
PACKAGE_DIR="$REPO_ROOT/ComposeUI"

if [ -z "$FILTER" ]; then
  FILTER=$("$SCRIPT_DIR/benchmark-filter.sh")
fi

if [ "$PLATFORM" = "macOS" ]; then
  BENCHMARK=1 SWIFT_DETERMINISTIC_HASHING=1 swift test --package-path "$PACKAGE_DIR" -c release -Xswiftc -enable-testing -Xswiftc -DDEBUG --filter "$FILTER"
  exit 0
fi

SCHEME="ComposeUI"
# shellcheck source-path=SCRIPTDIR source=benchmark-xcodebuild.sh
source "$SCRIPT_DIR/benchmark-xcodebuild.sh"
benchmark_pick_simulator "$PLATFORM"
DERIVED_DATA="$PACKAGE_DIR/.build/benchmark-$PLATFORM"

WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/benchmark-run.XXXXXX")
trap 'rm -rf "$WORK_DIR"' EXIT

echo "${BOLD}Platform:${RESET} $PLATFORM, $DEVICE_DESCRIPTION"
echo "${BOLD}Benchmarks:${RESET} $FILTER"
echo ""

echo "Building..."
if ! benchmark_build_for_simulator "$PACKAGE_DIR" "$DERIVED_DATA" > "$WORK_DIR/build.log" 2>&1; then
  tail -20 "$WORK_DIR/build.log" >&2
  echo "🛑 The benchmarks don't build, see the errors in the log." >&2
  exit 1
fi

echo "Booting the simulator..."
benchmark_boot_simulator

# xcodebuild runs every test when it's given none to run, so an empty selection stops the run
benchmark_select_tests "$PACKAGE_DIR" "$DERIVED_DATA" "$FILTER" "$WORK_DIR/tests.txt" || exit 1
if [ ! -s "$WORK_DIR/tests.txt" ]; then
  echo "🛑 No tests match the filter: $FILTER" >&2
  exit 1
fi

echo "Running..."
status=0
benchmark_run_on_simulator "$PACKAGE_DIR" "$DERIVED_DATA" "$WORK_DIR/tests.txt" 2>&1 | tee "$WORK_DIR/run.log" | { grep --line-buffered -a "^\[BENCHMARK\]" || true; } || status=$?
if [ "$status" -ne 0 ]; then
  tail -30 "$WORK_DIR/run.log" >&2
  echo "🛑 The benchmarks failed, see the end of their log." >&2
  exit 1
fi
