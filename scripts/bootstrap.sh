#!/bin/bash

set -e

# change to the directory in which this script is located
pushd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 || exit 1

# ===------ BEGIN ------===

# OVERVIEW:
# This script is used to bootstrap the development environment.
#
# BOOTSTRAP_PROFILE controls which binaries are installed:
#   full  - swiftformat, swiftlint, xcbeautify (default, local development)
#   test  - xcbeautify only (CI test/build jobs)
#   lint  - swiftformat + swiftlint (CI lint jobs)
#   build - xcbeautify only (CI build jobs)

REPO_ROOT=$(git rev-parse --show-toplevel)
BOOTSTRAP_PROFILE="${BOOTSTRAP_PROFILE:-full}"

cd "$REPO_ROOT" || exit 1

echo "🚀 Bootstrap development environment (profile: $BOOTSTRAP_PROFILE)..."
git submodule update --init --recursive --remote

OS=$(uname -s)
case "$OS" in
'Darwin') # macOS
  CPU=$(uname -m)
  case "$CPU" in
  'arm64') # on Apple Silicon Mac
    # download jq when missing, so cache hits can skip the network fetch
    echo ""
    if [ -x "$REPO_ROOT/bin/jq" ]; then
      echo "📦 jq already present, skipping download"
    else
      echo "📦 Download jq..."
      curl -sL https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-macos-arm64 -o "$REPO_ROOT/bin/jq"
      chmod +x "$REPO_ROOT/bin/jq"
    fi

    # download scripts
    echo ""
    echo "📥 Download scripts..."
    "$REPO_ROOT/scripts/download-scripts.sh"

    # Select which binaries to install for this profile.
    # CI test/build jobs do not need SwiftFormat/SwiftLint, so skip those downloads.
    VERSIONS_FILE="$REPO_ROOT/bin/.versions"
    case "$BOOTSTRAP_PROFILE" in
    test | build)
      VERSIONS_FILE="$REPO_ROOT/bin/.versions-ci-test"
      ;;
    lint)
      VERSIONS_FILE="$REPO_ROOT/bin/.versions-ci-lint"
      ;;
    full)
      VERSIONS_FILE="$REPO_ROOT/bin/.versions"
      ;;
    *)
      echo "Unknown BOOTSTRAP_PROFILE: $BOOTSTRAP_PROFILE (expected full|test|lint|build)"
      exit 1
      ;;
    esac

    # download bins using a temporary .versions file when using a CI profile,
    # because download-bins.sh always reads bin/.versions
    echo ""
    echo "📦 Download bins from $(basename "$VERSIONS_FILE")..."
    ACTIVE_VERSIONS="$REPO_ROOT/bin/.versions"
    RESTORE_VERSIONS=""
    restore_versions_file() {
      if [ -n "${RESTORE_VERSIONS:-}" ] && [ -f "$RESTORE_VERSIONS" ]; then
        mv "$RESTORE_VERSIONS" "$ACTIVE_VERSIONS"
        RESTORE_VERSIONS=""
      fi
    }
    trap restore_versions_file EXIT
    if [ "$VERSIONS_FILE" != "$ACTIVE_VERSIONS" ]; then
      if [ -f "$ACTIVE_VERSIONS" ]; then
        RESTORE_VERSIONS="$(mktemp)"
        cp "$ACTIVE_VERSIONS" "$RESTORE_VERSIONS"
      fi
      cp "$VERSIONS_FILE" "$ACTIVE_VERSIONS"
    fi
    "$REPO_ROOT/scripts/download-bin/download-bins.sh"
    restore_versions_file
    trap - EXIT

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
      "$REPO_ROOT/scripts/swift-package/update-packages.sh" ./playgrounds/ComposeUIPlayground-macOS/ComposeUIPlayground-macOS.xcodeproj
      "$REPO_ROOT/scripts/swift-package/update-packages.sh" ./playgrounds/ComposeUIPlayground-iOS/ComposeUIPlayground-iOS.xcodeproj
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
