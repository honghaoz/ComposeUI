"""Prints the runs of motion in a recording, to find where one seamless loop starts.

usage: python3 motion.py <recording-dir> [--timescale s]

record-screen writes a frame only when the screen changes, so a gap between frames is a still moment. A loop starts at
the first frame of a run that follows a still gap, and lasts one period of the demo. --timescale multiplies the times,
for a recording made with -readmeFrameHold (see make-apng.py).
"""
import sys

directory = sys.argv[1]
scale = float(sys.argv[sys.argv.index("--timescale") + 1]) if "--timescale" in sys.argv else 1.0
times = [float(line) for line in open(f"{directory}/times.txt") if line.strip()]
times = [(t - times[0]) * scale for t in times]
start = 0
for index in range(1, len(times) + 1):
    if index == len(times) or times[index] - times[index - 1] > 0.25:
        gap = times[index] - times[index - 1] if index < len(times) else 0
        print(f"frames {start}-{index - 1}: {times[start]:.3f}s to {times[index - 1]:.3f}s, then still for {gap:.3f}s")
        start = index
