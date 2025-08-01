#!/bin/bash

set -e

# change to the directory in which this script is located
pushd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 || exit 1

# ===------ BEGIN ------===

# OVERVIEW:
# This script is used to bootstrap the development environment.

REPO_ROOT=$(git rev-parse --show-toplevel)

cd "$REPO_ROOT" || exit 1

echo "🚀 Bootstrap development environment..."
git submodule update --init --recursive

OS=$(uname -s)
case "$OS" in
'Darwin') # macOS
  CPU=$(uname -m)
  case "$CPU" in
  'arm64') # on Apple Silicon Mac
    # download jq
    echo ""
    echo "📦 Download jq..."
    curl -sL https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-macos-arm64 -o "$REPO_ROOT/bin/jq"
    chmod +x "$REPO_ROOT/bin/jq"

    # download scripts
    echo ""
    echo "📥 Download scripts..."
    "$REPO_ROOT/scripts/download-scripts.sh"

    # download bins
    echo ""
    echo "📦 Download bins..."
    "$REPO_ROOT/scripts/download-bin/download-bins.sh"

    # git hooks
    echo ""
    echo "🪝 Install git hooks..."
    "$REPO_ROOT/scripts/git/install-git-hooks.sh"

    # update packages
    echo ""
    echo "🔄 Update packages..."
    "$REPO_ROOT/scripts/swift-package/update-packages.sh" ComposeUI

    echo ""
    echo "🎉 Done."
    ;;
  'x86_64') # on Intel Mac
    echo "Does not support Intel Mac."
    ;;
  *)
    echo "Unknown CPU: $CPU"
    ;;
  esac
  ;;
'Linux') # on Ubuntu
  echo "Does not support Linux."
  ;;
*)
  echo "Unknown OS: $OS"
  ;;
esac

# ===------ END ------===

# return to whatever directory we were in when this script was run
popd >/dev/null 2>&1 || exit 0
