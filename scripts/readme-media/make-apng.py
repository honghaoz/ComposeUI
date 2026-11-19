"""Cuts one loop from a record-screen recording and encodes it as an animated PNG that loops forever.

usage: python3 make-apng.py <recording-dir> <width-px> <height-px> <start> <frames> <out.png>
                            [--fps 50] [--timescale s] [--palette] [extra ffmpeg args, such as -pred mixed]

<start> is in seconds from the first recorded frame, on the timescale. Frame k shows what was on screen at
start + k / fps, so the loop is seamless when the frame after the last one matches the first one, which the script
checks. --timescale multiplies the recorded times: a recording made with -readmeFrameHold n -readmeFrameRate r shows
each frame for n display frames at 60 Hz, so its timescale is 60 / (n * r). --palette maps the frames to one 256-color
palette for the whole animation, which an APNG keeps in a single PLTE chunk. The output gets an sRGB chunk.
"""
import bisect
import struct
import subprocess
import sys
import zlib

directory, width, height = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
start, count, out = float(sys.argv[4]), int(sys.argv[5]), sys.argv[6]
extra = sys.argv[7:]


def take_option(name, default=None, has_value=True):
    if name not in extra:
        return default
    index = extra.index(name)
    value = extra[index + 1] if has_value else True
    del extra[index:index + (2 if has_value else 1)]
    return value


fps = int(take_option("--fps", 50))
scale = float(take_option("--timescale", 1.0))
palette = take_option("--palette", False, has_value=False)

times = [float(line) for line in open(f"{directory}/times.txt") if line.strip()]
times = [(t - times[0]) * scale for t in times]
frame_size = width * height * 4
frames = open(f"{directory}/frames.raw", "rb")


def frame(index):
    frames.seek(index * frame_size)
    return frames.read(frame_size)


def frame_at(time):
    return bisect.bisect_right(times, time + 0.5 / fps) - 1


pixel_format = (["-filter_complex", "[0]split[a][b];[a]palettegen=max_colors=256:stats_mode=full:reserve_transparent=0[p];"
                 "[b][p]paletteuse=dither=none", "-pix_fmt", "pal8"] if palette else ["-pix_fmt", "rgb24"])
ffmpeg = subprocess.Popen(["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "bgra", "-s", f"{width}x{height}",
                           "-framerate", str(fps), "-i", "-"] + pixel_format + ["-f", "apng", "-plays", "0"] + extra + [out],
                          stdin=subprocess.PIPE)
indexes = [frame_at(start + k / fps) for k in range(count)]
for index in indexes:
    ffmpeg.stdin.write(frame(index))
ffmpeg.stdin.close()
if ffmpeg.wait() != 0:
    sys.exit("ffmpeg failed")

# the sRGB chunk goes right after IHDR, so that browsers treat the colors as sRGB, which record-screen captures in
with open(out, "rb") as file:
    data = file.read()
if b"sRGB" not in data[:200]:
    after_header = 8 + 12 + 13
    chunk = struct.pack(">I", 1) + b"sRGB" + b"\x00" + struct.pack(">I", zlib.crc32(b"sRGB\x00") & 0xffffffff)
    with open(out, "wb") as file:
        file.write(data[:after_header] + chunk + data[after_header:])

wrap = frame_at(start + count / fps)
first, after = frame(indexes[0]), frame(wrap)
largest = max((abs(a - b) for a, b in zip(first, after)), default=0)
print(f"{out}: {count} frames at {fps} fps ({count / fps:.3f}s), source frames {indexes[0]}..{indexes[-1]}, "
      f"largest difference between the first frame and the frame after the last: {largest} levels")
