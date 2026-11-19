#!/bin/zsh
# Launches one README demo of the AppKit playground and records its window with record-screen.
#
# usage: capture.sh <app> <demo> <out-dir> <seconds> <height> <cursor 0|1> [mouse steps...]
#
# <app> is the built playground app (the .app bundle or its binary). The demo window sits at (120, 160) points from the
# top-left corner of the main screen and is 360 points wide, 220 tall, or 360 for the scrolling demo. Mouse steps, if
# any, run with drive-mouse one second after the recording starts. APP_ARGS adds launch arguments, for example
# APP_ARGS="-readmeFrameHold 4 -readmeFrameRate 50".
set -euo pipefail

here=${0:A:h}
tools=${TMPDIR:-/tmp}/composeui-readme-media
mkdir -p "$tools"
for tool in record-screen drive-mouse; do
  if [[ ! -x "$tools/$tool" || "$here/$tool.swift" -nt "$tools/$tool" ]]; then
    swiftc -O "$here/$tool.swift" -o "$tools/$tool"
  fi
done

app=$1; demo=$2; out=$3; seconds=$4; height=$5; cursor=$6
shift 6
if [[ "$app" == *.app ]]; then
  app=("$app"/Contents/MacOS/*(N[1]))
fi

"$app" -readmeDemo "$demo" -readmeTheme light -NSQuitAlwaysKeepsWindows NO ${=APP_ARGS:-} >/dev/null 2>&1 &
app_pid=$!
trap 'kill $app_pid 2>/dev/null || true' EXIT
sleep 2

"$tools/record-screen" 120 160 360 "$height" "$seconds" "$out" "$cursor" &
record_pid=$!
if (( $# > 0 )); then
  sleep 1
  "$tools/drive-mouse" "$@"
fi
wait $record_pid
