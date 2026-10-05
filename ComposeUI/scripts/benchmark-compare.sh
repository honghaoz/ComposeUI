#!/bin/bash

# Compares the benchmarks of the working tree against a base revision, measured on this machine.
#
# Builds the base in a temporary worktree and the working tree, both in release, runs the benchmarks of both in turns
# for a few rounds, and compares each benchmark's time, instructions and allocations. Both sides run the working tree's
# benchmark files, so a change to a benchmark doesn't show as a change in the code it measures.

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
  echo "  --filter <regex>   The benchmarks to run, as a swift test filter. Default is PerformanceTests, all of them."
  echo "  --rounds <count>   The number of rounds to run each side. Default is 5."
  echo "  --help, -h         Show this help message."
  echo ""
  echo "Exits with 1 when a benchmark makes more allocations than the base made in any round, or retires more than 1%"
  echo "more instructions. A time more than 20% slower is a warning, since time depends on the machine's load."
}

BASE="origin/master"
FILTER="PerformanceTests"
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

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PACKAGE_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(git -C "$PACKAGE_DIR" rev-parse --show-toplevel)
PACKAGE_PATH_IN_REPO=${PACKAGE_DIR#"$REPO_ROOT"/}
BENCHMARKS_PATH_IN_PACKAGE="Tests/ComposeUITests/Performance"

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
if ! build base "$BASE_PACKAGE_DIR" 2> /dev/null; then
  # the working tree's benchmarks can use code the base doesn't have, so fall back to the base's own benchmarks
  echo "⚠️  The working tree's benchmarks don't build against the base, comparing with the base's own benchmarks."
  git -C "$BASE_DIR" checkout --quiet -- "$PACKAGE_PATH_IN_REPO/$BENCHMARKS_PATH_IN_PACKAGE"
  git -C "$BASE_DIR" clean --quiet -fd -- "$PACKAGE_PATH_IN_REPO/$BENCHMARKS_PATH_IN_PACKAGE"
  build base "$BASE_PACKAGE_DIR"
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
swift "$SCRIPT_DIR/benchmark-compare.swift" "$RESULTS_DIR" "$TIME_THRESHOLD" "$INSTRUCTIONS_THRESHOLD"
