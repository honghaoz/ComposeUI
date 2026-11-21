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
git submodule update --init --recursive --remote

OS=$(uname -s)
case "$OS" in
'Darwin') # macOS
  CPU=$(uname -m)
  case "$CPU" in
  'arm64') # on Apple Silicon Mac
    echo ""
    if [ -x "$REPO_ROOT/bin/jq" ]; then
      echo "📦 jq already present, skipping download"
    else
      echo "📦 Download jq..."
      mkdir -p "$REPO_ROOT/bin"
      # Download to a temp file so a failed or truncated response can't leave a
      # broken jq that the "already present" check would then skip. The EXIT trap
      # removes the temp file if the run is interrupted before the move.
      # --retry covers timeouts and HTTP 408/429/5xx. --retry-all-errors is
      # required for a dropped connection (curl 56), which is how the 503 showed
      # up in CI; with -f it also retries 4xx. --connect-timeout and --max-time
      # turn a stall into a retryable failure; --retry-max-time only limits when
      # a new retry may start.
      CURL_RETRY=(
        -fsSL
        --retry 5
        --retry-all-errors
        --retry-delay 2
        --retry-max-time 90
        --connect-timeout 10
        --max-time 30
      )
      tmp=$(mktemp "$REPO_ROOT/bin/jq.XXXXXX")
      trap 'rm -f "$tmp"' EXIT
      curl "${CURL_RETRY[@]}" \
        "https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-macos-arm64" \
        -o "$tmp"
      chmod +x "$tmp"
      mv "$tmp" "$REPO_ROOT/bin/jq"
      trap - EXIT
    fi

    # download scripts
    echo ""
    echo "📥 Download scripts..."
    "$REPO_ROOT/scripts/download-scripts.sh"

    # download bins
    echo ""
    echo "📦 Download bins..."
    "$REPO_ROOT/scripts/download-bin/download-bins.sh"

    # git hooks are only useful for local development, so skip them in CI
    if [ "${CI:-}" = "true" ]; then
      echo ""
      echo "🪝 Skipping git hooks install in CI"
    else
      echo ""
      echo "🪝 Install git hooks..."
      "$REPO_ROOT/scripts/git/install-git-hooks.sh"
    fi

    # update packages if needed
    echo ""
    if [ "${CI:-}" = "true" ]; then
      echo "Skipping package update in CI"
    else
      echo "🔄 Update packages..."
      "$REPO_ROOT/scripts/swift-package/update-packages.sh" ComposeUI
      "$REPO_ROOT/scripts/swift-package/update-packages.sh" ./ComposeUI/HostedTests/ComposeUIHostedTests.xcodeproj
      "$REPO_ROOT/scripts/swift-package/update-packages.sh" ./playgrounds/ComposeUIPlayground.xcodeproj
    fi

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
