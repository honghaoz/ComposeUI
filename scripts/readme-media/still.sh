#!/bin/zsh
# Launches one README demo of the AppKit playground and saves a still of its window.
#
# usage: still.sh <app> <demo> <out.png> [theme light|dark] [height]
set -euo pipefail

app=$1; demo=$2; out=$3; theme=${4:-light}; height=${5:-220}
if [[ "$app" == *.app ]]; then
  app=("$app"/Contents/MacOS/*(N[1]))
fi

"$app" -readmeDemo "$demo" -readmeTheme "$theme" -NSQuitAlwaysKeepsWindows NO >/dev/null 2>&1 &
app_pid=$!
trap 'kill $app_pid 2>/dev/null || true' EXIT
sleep 2
screencapture -x -R"120,160,360,$height" "$out"
