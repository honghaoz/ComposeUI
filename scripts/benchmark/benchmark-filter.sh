#!/bin/bash

# Prints the swift test filter of the benchmark suites: the subclasses of BenchmarkTestCase in the benchmark directory.
#
# The filter names the suites, since a pattern such as their names' "PerformanceTests" suffix also matches other tests,
# which report no benchmark results, and whose timing assertions can fail a run. The benchmark directory is also the
# only test directory that benchmark-compare.sh copies into the base.

set -euo pipefail

# zsh has no BASH_SOURCE, so resolve this file the zsh way when run or sourced there
if [ -n "${BASH_SOURCE[0]:-}" ]; then
  _script_file=${BASH_SOURCE[0]}
elif [ -n "${ZSH_VERSION:-}" ]; then
  eval '_script_file=${(%):-%x}'
else
  echo "🛑 Run this script with bash." >&2
  exit 1
fi
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$_script_file")" >/dev/null && pwd)
unset _script_file
BENCHMARKS_DIR="$SCRIPT_DIR/../../ComposeUI/Tests/ComposeUITests/Performance"

SUITES=$(sed -nE 's/^(final )?class ([A-Za-z0-9_]+): BenchmarkTestCase.*/\2/p' "$BENCHMARKS_DIR"/*.swift | paste -sd '|' -)
if [ -z "$SUITES" ]; then
  echo "🛑 No benchmark suites in $BENCHMARKS_DIR" >&2
  exit 1
fi

echo "ComposeUITests\\.($SUITES)/"
