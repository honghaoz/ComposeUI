#!/bin/bash

set -e

# change to the directory in which this script is located
pushd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 || exit 1

# ===------ BEGIN ------===

# OVERVIEW:
# Download external scripts from https://github.com/honghaoz/ChouTi

# branch of ChouTi
BRANCH="master"

# an array of scripts to download
declare -a scripts=(
  "scripts/download-bin/"
  "scripts/format.sh"
  "scripts/lint.sh"
  "scripts/swiftformat-beautify"
  "scripts/swiftlint-beautify"
)

function get_files() {
  if [ -z "$1" ]; then
    echo "Error: No path provided to get_files" >&2
    return 1
  fi
  local path="$1"

  # remove trailing slash if it exists
  path="${path%/}"

  # curl -s "https://api.github.com/repos/honghaoz/ChouTi/contents/scripts/download-bin?ref=master" | grep '"path"' | cut -d '"' -f 4
  curl -s "https://api.github.com/repos/honghaoz/ChouTi/contents/$path?ref=$BRANCH" | grep '"path"' | cut -d '"' -f 4
}

function download_file() {
  if [ -z "$1" ]; then
    echo "Error: No path provided to download_file" >&2
    return 1
  fi
  local path="$1"
  local filename=$(basename "$path")
  echo "Downloading $filename..."
  curl -fsSL https://raw.githubusercontent.com/honghaoz/ChouTi/$BRANCH/$path -o $filename
  chmod +x $filename
}

function download_files() {
  if [ -z "$1" ]; then
    echo "Error: No files provided to download_files" >&2
    return 1
  fi
  local files="$1"
  for file in $files; do
    download_file "$file"
  done
}

# download each script
for path in "${scripts[@]}"; do
  if [[ "$path" == */ ]]; then
    # path is a directory
    files=$(get_files "$path")

    # create local directory if it doesn't exist
    folder=$(basename "$path")
    mkdir -p "$folder"

    cd "$folder"
    download_files "$files"
    cd ..
  else
    # path is a file
    download_file "$path"
  fi
done

# ===------ END ------===

# return to whatever directory we were in when this script was run
popd >/dev/null 2>&1 || exit 0
