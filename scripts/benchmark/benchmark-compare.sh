#!/bin/bash

# Compares the benchmarks of the working tree against a base revision, measured on this machine.
#
# Builds the base in a temporary worktree and the working tree, both in release, runs the benchmarks of both in turns
# for a few rounds, and compares each benchmark's time, instructions and allocations, which change only when every round
# of one side is past every round of the other. Both sides run the working tree's benchmark files, so a change to a
# benchmark doesn't show as a change in the code it measures, and the comparison stops when those files don't build
# against the base.
#
# On an iOS or tvOS simulator, the benchmarks build and run with xcodebuild, see benchmark-xcodebuild.sh, and the
# working tree's build is kept in the package's build directory, so that the next comparison builds only what changed,
# as `swift build` does on macOS.

set -euo pipefail

BOLD=$( [ -n "${TERM:-}" ] && [ "$TERM" != "dumb" ] && tput bold || echo "")
RESET=$( [ -n "${TERM:-}" ] && [ "$TERM" != "dumb" ] && tput sgr0 || echo "")

print_help() {
  echo "${BOLD}OVERVIEW:${RESET} Compare the benchmarks of the working tree against a base revision, on this machine."
  echo ""
  echo "${BOLD}USAGE:${RESET} $0 [--base <revision>] [--platform <macOS|iOS|tvOS>] [--filter <regex>] [--rounds <count>] [--time-threshold <percent>] [--instructions-threshold <percent>] [--summary <file>]"
  echo ""
  echo "${BOLD}OPTIONS:${RESET}"
  echo "  --base <revision>                  The revision to compare against. Default is origin/master."
  echo "  --platform <macOS|iOS|tvOS>        The platform to run on, macOS or the newest available simulator of iOS or tvOS. Default is macOS."
  echo "  --filter <regex>                   The benchmarks to run, as a swift test filter. Default is the benchmark suites, all of them."
  echo "  --rounds <count>                   The number of rounds to run each side. Default is 5."
  echo "  --time-threshold <percent>         The slowdown past which a time warns. Default is 20."
  echo "  --instructions-threshold <percent> The increase past which instructions regress. Default is 1."
  echo "  --summary <file>                   A markdown file to append the report to, such as GitHub's step summary. Optional."
  echo "  --help, -h                         Show this help message."
  echo ""
  echo "Exits with 1 when a benchmark makes more allocations in every round than the base made in any, or retires more"
  echo "instructions in every round than the base did in any and more than the instructions threshold allows, when a"
  echo "side doesn't report a benchmark exactly once in every round, when a round skips a test, and as inconclusive when"
  echo "no benchmark has allocations or instructions on both sides. A time slower in every round, and slower than the"
  echo "time threshold allows, is a warning, since time depends on the machine's load. Both sides run the working"
  echo "tree's benchmark files, so the comparison stops when they don't build against the base. Tests named"
  echo "test_profile_ are left out, since they only run for a profiler."
}

BASE="origin/master"
PLATFORM="macOS"
FILTER=""
ROUNDS=5
TIME_THRESHOLD=20
INSTRUCTIONS_THRESHOLD=1
SUMMARY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
  --base)
    BASE="$2"
    shift 2
    ;;
  --platform)
    PLATFORM="$2"
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
  --time-threshold)
    TIME_THRESHOLD="$2"
    shift 2
    ;;
  --instructions-threshold)
    INSTRUCTIONS_THRESHOLD="$2"
    shift 2
    ;;
  --summary)
    SUMMARY="$2"
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
if ! [[ "$TIME_THRESHOLD" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "🛑 --time-threshold must be a non-negative number: $TIME_THRESHOLD" >&2
  exit 1
fi
if ! [[ "$INSTRUCTIONS_THRESHOLD" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "🛑 --instructions-threshold must be a non-negative number: $INSTRUCTIONS_THRESHOLD" >&2
  exit 1
fi
case "$PLATFORM" in
macOS | iOS | tvOS) ;;
*)
  echo "🛑 --platform must be macOS, iOS or tvOS: $PLATFORM" >&2
  exit 1
  ;;
esac

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

# Prints an error, also to the summary file if there is one, and exits.
fail() { # <message>
  echo "🛑 $1" >&2
  if [ -n "$SUMMARY" ]; then
    printf '## Benchmarks\n\n🛑 %s\n' "$1" >> "$SUMMARY"
  fi
  exit 1
}

# compile the comparison first, so that a broken comparison fails before the builds. its logic is in the test target,
# where the tests cover it
COMPARE="$WORK_DIR/benchmark-compare"
if ! swiftc -parse-as-library -o "$COMPARE" "$PACKAGE_DIR/$BENCHMARKS_PATH_IN_PACKAGE/BenchmarkComparison.swift" "$SCRIPT_DIR/benchmark-compare.swift"; then
  fail "The comparison doesn't compile."
fi

# the tests use debug-only hooks, so the release build defines DEBUG
BUILD_FLAGS=(-c release -Xswiftc -enable-testing -Xswiftc -DDEBUG)

PLATFORM_DESCRIPTION="macOS"
if [ "$PLATFORM" != "macOS" ]; then
  SCHEME="ComposeUI"
  # shellcheck source-path=SCRIPTDIR source=benchmark-xcodebuild.sh
  source "$SCRIPT_DIR/benchmark-xcodebuild.sh"
  benchmark_pick_simulator "$PLATFORM"
  PLATFORM_DESCRIPTION="$PLATFORM, $DEVICE_DESCRIPTION"
fi
# a simulator side's build, the head's in the package's build directory, so that the next comparison builds only what
# changed, as `swift build` does on macOS
HEAD_DERIVED_DATA="$PACKAGE_DIR/.build/benchmark-$PLATFORM"
BASE_DERIVED_DATA="$WORK_DIR/base-derived-data"

HEAD_DESCRIPTION=$(git -C "$REPO_ROOT" log --oneline -1 HEAD)
if [ -n "$(git -C "$REPO_ROOT" status --porcelain)" ]; then
  HEAD_DESCRIPTION="$HEAD_DESCRIPTION, with uncommitted changes"
fi
echo "${BOLD}Base:${RESET} $BASE, $(git -C "$REPO_ROOT" log --oneline -1 "$BASE_COMMIT")"
echo "${BOLD}Head:${RESET} the working tree, $HEAD_DESCRIPTION"
echo "${BOLD}Platform:${RESET} $PLATFORM_DESCRIPTION"
echo "${BOLD}Benchmarks:${RESET} $FILTER, $ROUNDS rounds, instructions regress past $INSTRUCTIONS_THRESHOLD%, times warn past $TIME_THRESHOLD%, and a change counts only when every round shows it"
echo ""

# the temporary checkout has none of the downloaded scripts, so the repository's hooks would fail in it
git -C "$REPO_ROOT" -c core.hooksPath=/dev/null worktree add --quiet --detach "$BASE_DIR" "$BASE_COMMIT"
BASE_PACKAGE_DIR="$BASE_DIR/$PACKAGE_PATH_IN_REPO"
rsync -a --delete "$PACKAGE_DIR/$BENCHMARKS_PATH_IN_PACKAGE/" "$BASE_PACKAGE_DIR/$BENCHMARKS_PATH_IN_PACKAGE/"

# Builds the tests of a package, or prints the end of the build log and fails.
build() { # <name> <package dir> <simulator derived data dir>
  local log="$WORK_DIR/$1-build.log"
  local status=0
  if [ "$PLATFORM" = "macOS" ]; then
    swift build "${BUILD_FLAGS[@]}" --build-tests --package-path "$2" > "$log" 2>&1 || status=$?
  else
    benchmark_build_for_simulator "$2" "$3" > "$log" 2>&1 || status=$?
  fi
  if [ "$status" -ne 0 ]; then
    tail -20 "$log" >&2
    return 1
  fi
}

echo "Building the head..."
build head "$PACKAGE_DIR" "$HEAD_DERIVED_DATA" || fail "The head doesn't build, see the errors in the log."
echo "Building the base..."
# the base's own benchmark files can measure different work under the same names, or not report every cost, so the
# comparison stops instead of falling back to them
build base "$BASE_PACKAGE_DIR" "$BASE_DERIVED_DATA" || fail "The base doesn't build with the working tree's benchmark files, see the errors in the log. Compare against a revision they build against."

if [ "$PLATFORM" != "macOS" ]; then
  # the simulator boots after the builds, since booting and building both take the processor, and overlapping them was
  # slower than running them in turn on CI's few-core runners
  echo "Booting the simulator..."
  benchmark_boot_simulator
  # each side runs the tests of its own build that the filter selects, as swift test applies the filter to each side.
  # xcodebuild runs every test when it's given none to run, so an empty selection stops the comparison
  echo "Selecting the benchmarks..."
  benchmark_select_tests "$PACKAGE_DIR" "$HEAD_DERIVED_DATA" "$FILTER" "$WORK_DIR/head-tests.txt" || fail "The head's tests can't be listed, see the end of the log."
  benchmark_select_tests "$BASE_PACKAGE_DIR" "$BASE_DERIVED_DATA" "$FILTER" "$WORK_DIR/base-tests.txt" || fail "The base's tests can't be listed, see the end of the log."
  if [ ! -s "$WORK_DIR/head-tests.txt" ] || [ ! -s "$WORK_DIR/base-tests.txt" ]; then
    fail "No tests match the filter: $FILTER"
  fi
fi

# Runs the benchmarks of a side once, and keeps the round's test log, from which the comparison reads the results and the
# skipped tests. A benchmark that runs without reporting fails its test, which fails the round.
run() { # <side> <package dir> <round> <simulator derived data dir>
  local log="$RESULTS_DIR/$1-$3.txt"
  local status=0
  if [ "$PLATFORM" = "macOS" ]; then
    BENCHMARK=1 SWIFT_DETERMINISTIC_HASHING=1 swift test --skip-build -c release --package-path "$2" --filter "$FILTER" --skip "/test_profile_" > "$log" 2>&1 || status=$?
  else
    benchmark_run_on_simulator "$2" "$4" "$WORK_DIR/$1-tests.txt" > "$log" 2>&1 || status=$?
  fi
  if [ "$status" -ne 0 ]; then
    tail -30 "$log" >&2
    fail "The $1 benchmarks failed in round $3, see the end of their log."
  fi
}

for round in $(seq "$ROUNDS"); do
  echo "Running round $round of $ROUNDS..."
  # alternate which side runs first, so a drift in the machine's speed affects both sides alike
  if ((round % 2 == 1)); then
    run base "$BASE_PACKAGE_DIR" "$round" "$BASE_DERIVED_DATA"
    run head "$PACKAGE_DIR" "$round" "$HEAD_DERIVED_DATA"
  else
    run head "$PACKAGE_DIR" "$round" "$HEAD_DERIVED_DATA"
    run base "$BASE_PACKAGE_DIR" "$round" "$BASE_DERIVED_DATA"
  fi
done

echo ""
status=0
report=$("$COMPARE" "$RESULTS_DIR" "$TIME_THRESHOLD" "$INSTRUCTIONS_THRESHOLD") || status=$?
echo "$report"
if [ -n "$SUMMARY" ]; then
  {
    echo "## Benchmarks"
    echo ""
    echo "- Base: $BASE, $(git -C "$REPO_ROOT" log --oneline -1 "$BASE_COMMIT")"
    echo "- Head: $HEAD_DESCRIPTION"
    echo "- Platform: $PLATFORM_DESCRIPTION"
    echo "- Benchmarks: \`$FILTER\`, $ROUNDS rounds, instructions regress past $INSTRUCTIONS_THRESHOLD%, times warn past $TIME_THRESHOLD%, and a change counts only when every round shows it"
    echo ""
    echo "$report"
  } >> "$SUMMARY"
fi
exit "$status"
