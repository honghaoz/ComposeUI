#!/bin/bash

# Compares the benchmarks of the working tree against a base revision, measured on this machine.
#
# Builds the base in a temporary worktree and the working tree, both in release, runs the benchmarks of both in turns
# for a few rounds, and compares each benchmark's time, instructions and allocations. Both sides run the working tree's
# benchmark files, so a change to a benchmark doesn't show as a change in the code it measures, and the comparison stops
# when those files don't build against the base.

set -euo pipefail

BOLD=$( [ -n "${TERM:-}" ] && [ "$TERM" != "dumb" ] && tput bold || echo "")
RESET=$( [ -n "${TERM:-}" ] && [ "$TERM" != "dumb" ] && tput sgr0 || echo "")

print_help() {
  echo "${BOLD}OVERVIEW:${RESET} Compare the benchmarks of the working tree against a base revision, on this machine."
  echo ""
  echo "${BOLD}USAGE:${RESET} $0 [--base <revision>] [--filter <regex>] [--rounds <count>]"
  echo ""
  echo "${BOLD}OPTIONS:${RESET}"
  echo "  --base <revision>  The revision to compare against. Default is origin/master."
  echo "  --filter <regex>   The benchmarks to run, as a swift test filter. Default is the benchmark suites, all of them."
  echo "  --rounds <count>   The number of rounds to run each side. Default is 5."
  echo "  --help, -h         Show this help message."
  echo ""
  echo "Exits with 1 when a benchmark makes more allocations than the base made in any round, or retires more than 1%"
  echo "more instructions, when a side doesn't report a benchmark exactly once in every round, and as inconclusive"
  echo "when no benchmark has allocations or instructions on both sides. A time more than 20% slower is a warning, since"
  echo "time depends on the machine's load. Both sides run the working tree's benchmark files, so the comparison stops"
  echo "when they don't build against the base."
}

BASE="origin/master"
FILTER=""
ROUNDS=5
TIME_THRESHOLD=20
INSTRUCTIONS_THRESHOLD=1

while [[ $# -gt 0 ]]; do
  case "$1" in
  --base)
    BASE="$2"
    shift 2
    ;;
  --filter)
    FILTER="$2"
    shift 2
    ;;
  --rounds)
    ROUNDS="$2"
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

# check before anything builds, since a round count `seq` doesn't take fails only after the builds, and `seq 0` counts
# down from 1 on macOS
if ! [[ "$ROUNDS" =~ ^[1-9][0-9]*$ ]]; then
  echo "🛑 --rounds must be a positive integer: $ROUNDS" >&2
  exit 1
fi

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)
PACKAGE_PATH_IN_REPO="ComposeUI"
PACKAGE_DIR="$REPO_ROOT/$PACKAGE_PATH_IN_REPO"
BENCHMARKS_PATH_IN_PACKAGE="Tests/ComposeUITests/Performance"

if [ -z "$FILTER" ]; then
  FILTER=$("$SCRIPT_DIR/benchmark-filter.sh")
fi

if ! BASE_COMMIT=$(git -C "$REPO_ROOT" rev-parse --verify --quiet "$BASE^{commit}"); then
  echo "🛑 Unknown base revision: $BASE" >&2
  exit 1
fi

WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/benchmark-compare.XXXXXX")
BASE_DIR="$WORK_DIR/base"
RESULTS_DIR="$WORK_DIR/results"
mkdir -p "$RESULTS_DIR"

cleanup() {
  git -C "$REPO_ROOT" worktree remove --force "$BASE_DIR" > /dev/null 2>&1 || true
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

# compile the comparison first, so that a broken comparison fails before the builds. its logic is in the test target,
# where the tests cover it
COMPARE="$WORK_DIR/benchmark-compare"
if ! swiftc -parse-as-library -o "$COMPARE" "$PACKAGE_DIR/$BENCHMARKS_PATH_IN_PACKAGE/BenchmarkComparison.swift" "$SCRIPT_DIR/benchmark-compare.swift"; then
  echo "🛑 The comparison doesn't compile." >&2
  exit 1
fi

# the tests use debug-only hooks, so the release build defines DEBUG
BUILD_FLAGS=(-c release -Xswiftc -enable-testing -Xswiftc -DDEBUG)

HEAD_DESCRIPTION=$(git -C "$REPO_ROOT" log --oneline -1 HEAD)
if [ -n "$(git -C "$REPO_ROOT" status --porcelain)" ]; then
  HEAD_DESCRIPTION="$HEAD_DESCRIPTION, with uncommitted changes"
fi
echo "${BOLD}Base:${RESET} $BASE, $(git -C "$REPO_ROOT" log --oneline -1 "$BASE_COMMIT")"
echo "${BOLD}Head:${RESET} the working tree, $HEAD_DESCRIPTION"
echo "${BOLD}Benchmarks:${RESET} $FILTER, $ROUNDS rounds"
echo ""

# the temporary checkout has none of the downloaded scripts, so the repository's hooks would fail in it
git -C "$REPO_ROOT" -c core.hooksPath=/dev/null worktree add --quiet --detach "$BASE_DIR" "$BASE_COMMIT"
BASE_PACKAGE_DIR="$BASE_DIR/$PACKAGE_PATH_IN_REPO"
rsync -a --delete "$PACKAGE_DIR/$BENCHMARKS_PATH_IN_PACKAGE/" "$BASE_PACKAGE_DIR/$BENCHMARKS_PATH_IN_PACKAGE/"

# Builds the tests of a package, or prints the end of the build log and fails.
build() { # <name> <package dir>
  local log="$WORK_DIR/$1-build.log"
  if ! swift build "${BUILD_FLAGS[@]}" --build-tests --package-path "$2" > "$log" 2>&1; then
    echo "🛑 The $1 build failed:" >&2
    tail -20 "$log" >&2
    return 1
  fi
}

echo "Building the head..."
build head "$PACKAGE_DIR"
echo "Building the base..."
if ! build base "$BASE_PACKAGE_DIR"; then
  # the base's own benchmark files can measure different work under the same names, or not report every cost, so the
  # comparison stops instead of falling back to them
  echo "🛑 The base doesn't build with the working tree's benchmark files, see the errors above. Compare against a revision they build against." >&2
  exit 1
fi

# Runs the benchmarks of a side once, and keeps their result lines.
run() { # <side> <package dir> <round>
  local log="$WORK_DIR/$1-$3.log"
  if ! BENCHMARK=1 SWIFT_DETERMINISTIC_HASHING=1 swift test --skip-build -c release --package-path "$2" --filter "$FILTER" > "$log" 2>&1; then
    echo "🛑 The $1 benchmarks failed in round $3:" >&2
    tail -30 "$log" >&2
    exit 1
  fi
  grep '^\[BENCHMARK\]' "$log" > "$RESULTS_DIR/$1-$3.txt" || true
}

for round in $(seq "$ROUNDS"); do
  echo "Running round $round of $ROUNDS..."
  # alternate which side runs first, so a drift in the machine's speed affects both sides alike
  if ((round % 2 == 1)); then
    run base "$BASE_PACKAGE_DIR" "$round"
    run head "$PACKAGE_DIR" "$round"
  else
    run head "$PACKAGE_DIR" "$round"
    run base "$BASE_PACKAGE_DIR" "$round"
  fi
done

echo ""
"$COMPARE" "$RESULTS_DIR" "$TIME_THRESHOLD" "$INSTRUCTIONS_THRESHOLD"
