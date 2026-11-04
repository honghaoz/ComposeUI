#!/bin/bash

# Groups the imports at the top of the Swift files that `configs/.import-groups` applies to, in the order of its groups,
# with a blank line between groups. The grouping's logic is in `ComposeUI/Tests/ComposeUITests/Tooling/ImportGroups.swift`,
# where the tests cover it, and SwiftFormat's `sortImports` sorts the imports in each group.
#
# Usage: group-imports.sh --fix|--check
#   --fix:   Group the imports of the files whose imports aren't grouped.
#   --check: List the files whose imports aren't grouped, and exit with 1 when there are any.

set -euo pipefail

if [[ $# -ne 1 || ("$1" != "--fix" && "$1" != "--check") ]]; then
  echo "usage: $0 --fix|--check"
  exit 2
fi

# git hooks in a linked worktree export GIT_DIR, which makes `--show-toplevel` return the current directory
REPO_ROOT=$(unset GIT_DIR; git rev-parse --show-toplevel)
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
LOGIC="$REPO_ROOT/ComposeUI/Tests/ComposeUITests/Tooling/ImportGroups.swift"
ENTRY="$SCRIPT_DIR/group-imports.swift"
CONFIG="$REPO_ROOT/configs/.import-groups"

# compiling the tool takes a couple of seconds, so it's built once for each version of its sources and of this script,
# which has the compiler's arguments. each run builds into a file of its own, so that a run that stops halfway, or
# another run building at the same time, can't leave a broken tool behind
BUILD_DIR="$REPO_ROOT/.temp/group-imports"
TOOL="$BUILD_DIR/group-imports-$(cat "$LOGIC" "$ENTRY" "${BASH_SOURCE[0]}" | shasum | cut -c1-12)"
if [[ ! -x "$TOOL" ]]; then
  mkdir -p "$BUILD_DIR"
  swiftc -parse-as-library -o "$TOOL.$$" "$LOGIC" "$ENTRY"
  mv "$TOOL.$$" "$TOOL"
  find "$BUILD_DIR" -type f ! -name "$(basename "$TOOL")*" -delete
fi

echo ""
echo "➡️  Grouping imports..."
"$TOOL" "$1" "$CONFIG" "$REPO_ROOT"
