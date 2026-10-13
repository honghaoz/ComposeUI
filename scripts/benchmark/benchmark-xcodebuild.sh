#!/bin/bash

# Builds and runs the benchmarks on a simulator with xcodebuild, for benchmark-run.sh and benchmark-compare.sh, which
# source it.
#
# `swift test` runs tests only on the Mac, so the benchmarks run on a simulator through xcodebuild, with the settings of
# the macOS runs: a release build with testability and DEBUG, since the tests use debug-only hooks, and the benchmark and
# deterministic hashing variables, which xcodebuild passes to the tests without their TEST_RUNNER_ prefix.
#
# Needs REPO_ROOT, and SCHEME, the package's scheme.

# jq reads the simulators and the tests, the repository's own binary before one on the path
if [ -x "$REPO_ROOT/bin/jq" ]; then
  JQ_BIN="$REPO_ROOT/bin/jq"
elif command -v jq > /dev/null; then
  JQ_BIN="jq"
else
  echo "🛑 jq not found. Run make bootstrap or install jq." >&2
  exit 1
fi

# Picks the newest available simulator of iOS or tvOS, as the package's tests do, and sets DESTINATION, DEVICE_UDID and
# DEVICE_DESCRIPTION.
benchmark_pick_simulator() { # <platform>
  # the plain base model, such as "iPhone 17", or the Apple TV 4K, before any other device of the platform
  local names=()
  case "$1" in
  iOS)
    names=("^iPhone [0-9]+$" "^iPhone")
    ;;
  tvOS)
    names=("^Apple TV 4K" "^Apple TV")
    ;;
  *)
    echo "🛑 No simulator for $1" >&2
    exit 1
    ;;
  esac

  local name device=""
  for name in "${names[@]}"; do
    # the newest runtime first, comparing its version numerically, then the last name alphabetically
    device=$(xcrun simctl list devices available -j | "$JQ_BIN" -r --arg re "$name" '
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
    if [ -n "$device" ]; then
      break
    fi
  done
  if [ -z "$device" ]; then
    echo "🛑 No available $1 simulator found" >&2
    exit 1
  fi

  DEVICE_UDID=$(echo "$device" | cut -f2)
  DEVICE_DESCRIPTION="$(echo "$device" | cut -f1) ($(echo "$device" | cut -f3))"
  DESTINATION="platform=$1 Simulator,id=$DEVICE_UDID"
}

# Builds a package's tests for the simulator in release, into a derived data directory.
benchmark_build_for_simulator() { # <package dir> <derived data dir>
  (cd "$1" && xcodebuild build-for-testing -scheme "$SCHEME" -destination "$DESTINATION" -derivedDataPath "$2" \
    -configuration Release ENABLE_TESTABILITY=YES SWIFT_ACTIVE_COMPILATION_CONDITIONS=DEBUG COMPILER_INDEX_STORE_ENABLE=NO)
}

# Boots the simulator, or waits for its boot to finish.
benchmark_boot_simulator() {
  xcrun simctl bootstatus "$DEVICE_UDID" -b > /dev/null
}

# Writes the -only-testing arguments of the tests in a built package that a swift test filter selects, one per line,
# without the tests named test_profile_, which only run for a profiler, as benchmark-compare.sh skips them on macOS.
#
# The filter is matched against each test's name in swift test's form, `<module>.<class>/<method>`, as an extended
# regular expression with grep. swift test's filter also takes syntax that extended expressions lack, such as `\d`, so
# a filter that uses it selects other tests here.
benchmark_select_tests() { # <package dir> <derived data dir> <filter> <output file>
  local log="$4.log"
  local list="$4.json"
  if ! (cd "$1" && xcodebuild test-without-building -scheme "$SCHEME" -destination "$DESTINATION" -derivedDataPath "$2" \
    -configuration Release -enumerate-tests -test-enumeration-style flat -test-enumeration-format json \
    -test-enumeration-output-path "$list") > "$log" 2>&1; then
    tail -20 "$log" >&2
    return 1
  fi
  # xcodebuild lists a test bundle that it can't load as an error, and exits successfully
  if [ "$("$JQ_BIN" '.errors | length' "$list")" != "0" ]; then
    "$JQ_BIN" -r '.errors[]' "$list" >&2
    return 1
  fi

  # a test's identifier is `<module>/<class>/<method>()`, which -only-testing takes without the parentheses
  "$JQ_BIN" -r '.values[].enabledTests[].identifier' "$list" |
    sed -E 's|\(\)$||; s|/|.|' |
    { grep -E -e "$3" || true; } |
    { grep -v -e "/test_profile_" || true; } |
    sed -E 's|^([^.]*)\.|-only-testing:\1/|' > "$4"
}

# Runs the selected tests of a built package on the simulator.
benchmark_run_on_simulator() { # <package dir> <derived data dir> <selected tests file>
  local only_testing=()
  local test
  while IFS= read -r test; do
    only_testing+=("$test")
  done < "$3"
  (cd "$1" && TEST_RUNNER_BENCHMARK=1 TEST_RUNNER_SWIFT_DETERMINISTIC_HASHING=1 xcodebuild test-without-building \
    -scheme "$SCHEME" -destination "$DESTINATION" -derivedDataPath "$2" -configuration Release \
    -parallel-testing-enabled NO ${only_testing[@]+"${only_testing[@]}"})
}
