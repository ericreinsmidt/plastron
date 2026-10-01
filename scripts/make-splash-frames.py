#!/usr/bin/env python3
"""
Turns TortOS's boot animation into the frames the splash plays on the Pixel 2.

Runs on the Mac, not in the build: it needs FFmpeg, and the result is small
enough to keep in the repository (buildroot/package/splash/frames.bin), so
the image build never has to decode video. Rerun it when the animation
changes:

    scripts/make-splash-frames.py [path/to/tortos-boot.mp4]

The video is 1024x768 landscape. Each frame is scaled to 640x480 and turned
90 degrees counter-clockwise onto the panel's 480x640, the way TortOS draws,
so the splash only copies. The animation ends on the TortOS logo held still;
frames from the first one that already matches the last are left out, and the
splash keeps showing the last one it has.

Format, little-endian:
    "TSPL", u16 width, u16 height, u16 frames, u16 fps
    u32 offset of each frame, from the start of the file
    per frame: runs of (u32 count, u32 XRGB pixel), covering width*height
"""
import os
import struct
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_VIDEO = os.path.expanduser("~/Developer/TortOS/res/boot/tortos-boot.mp4")
OUT = os.path.join(HERE, "..", "buildroot", "package", "splash", "frames.bin")
W, H, FPS = 480, 640, 30


def main():
    video = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_VIDEO
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", video,
         "-vf", "scale=640:480:flags=area,transpose=2,fps=%d" % FPS,
         "-f", "rawvideo", "-pix_fmt", "bgr0", "-"],
        check=True, stdout=subprocess.PIPE).stdout
    size = W * H * 4
    frames = [raw[i:i + size] for i in range(0, len(raw) - size + 1, size)]

    # Up to the first frame that is already the finished logo, then the last
    # frame itself. "Already" within a tolerance: the held frames differ by
    # the video's compression noise, at most 10 of 255 from frame 46 of
    # tortos-boot.mp4 on (measured 2026-10-01), where the logo still settling
    # is off by up to 120.
    last = frames[-1]
    keep = len(frames) - 1
    while keep > 1 and max(abs(a - b) for a, b in zip(frames[keep - 1], last)) <= 12:
        keep -= 1
    frames = frames[:keep] + [last]

    encoded = []
    for f in frames:
        px = struct.unpack("<%dI" % (W * H), f)
        runs = bytearray()
        start = 0
        for i in range(1, len(px) + 1):
            if i == len(px) or px[i] != px[start]:
                runs += struct.pack("<II", i - start, px[start] | 0xff000000)
                start = i
        encoded.append(bytes(runs))

    header = struct.pack("<4sHHHH", b"TSPL", W, H, len(encoded), FPS)
    offset = len(header) + 4 * len(encoded)
    table = bytearray()
    for e in encoded:
        table += struct.pack("<I", offset)
        offset += len(e)
    with open(OUT, "wb") as out:
        out.write(header + table + b"".join(encoded))
    print("%s: %d frames of %d, %.1f MB" % (os.path.relpath(OUT), len(encoded),
                                           len(raw) // size, offset / 1e6))


if __name__ == "__main__":
    main()
