"""Prints what matters for the README of each animated PNG: frames, frame delays, plays, frame areas and size.

usage: python3 inspect-apng.py <file.png>...
"""
import struct
import sys
from collections import Counter

for path in sys.argv[1:]:
    data = open(path, "rb").read()
    index, frames, plays, srgb = 8, [], None, False
    while index < len(data):
        length, = struct.unpack(">I", data[index:index + 4])
        kind, body = data[index + 4:index + 8], data[index + 8:index + 8 + length]
        if kind == b"acTL":
            plays = struct.unpack(">II", body)[1]
        elif kind == b"fcTL":
            frames.append(struct.unpack(">IIIIIHHBB", body))
        elif kind == b"sRGB":
            srgb = True
        index += 12 + length
    width, height = frames[0][1], frames[0][2]
    delays = Counter(f"{f[5]}/{f[6]}" for f in frames)
    area = sum(f[1] * f[2] for f in frames) / (len(frames) * width * height)
    print(f"{path.split('/')[-1]}: {width}x{height}, {len(frames)} frames, delays {dict(delays)}, "
          f"plays {'forever' if plays == 0 else plays}, sRGB {srgb}, average frame area {area:.0%}, {len(data) / 1e6:.2f} MB")
