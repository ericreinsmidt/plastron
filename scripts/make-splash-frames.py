#!/usr/bin/env python3
"""
Turns TortOS's boot animation into the frames the splash plays on the Pixel 2.

Runs on the Mac, not in the build: it needs FFmpeg, and the result is small
enough to keep in the repository (buildroot/package/splash/frames.bin), so
the image build never has to decode video. Rerun it when the animation
changes:

    scripts/make-splash-frames.py [path/to/tortos-boot.mp4]
    scripts/make-splash-frames.py --brick [path/to/tortos-boot.mp4]

--brick makes the TrimUI Brick's (frames-brick.bin, for splash-fb.c): its
panel is the video's own 1024x768 landscape, so the frames are only encoded.

--fly takes TortOS's flyby instead (res/boot/tortos-fly.mp4, from its
tools/genboot.py --fly), at its 60 fps: the wordmark from the first frame and
the turtle shooting across above it with his speed bars, for fast boots.

The input may also be the folder of PNG frames genboot.py leaves in TortOS's
build/boot-frames: lossless, so the flat ground stays one run where the
video's compression noise broke it up (a turtle on the Brick: 7.6 MB from the
video, 5.1 from the frames).

The video is 1024x768 landscape. Each frame is scaled to 640x480 and turned
90 degrees counter-clockwise onto the panel's 480x640, the way TortOS draws,
so the splash only copies. The animation ends on the TortOS logo held still;
frames from the first one that already matches the last are left out, and the
splash keeps showing the last one it has.

Format, little-endian:
    "TSPL", u16 width, u16 height, u16 frames, u16 fps
    u32 offset of each frame, from the start of the file
    per frame: runs of (u32 count, u32 XRGB pixel), covering width*height

The Brick's (--brick) is "TSPZ" instead, for splash-fb.c: the same header and
offsets, then per frame only the band of rows that changed from the frame
before (frame 0 whole), as u16 first row, u16 rows, u32 length, and that
many bytes of zlib: the band's XRGB pixels, each byte less the same byte of
the pixel to its left (as PNG's Sub filter does), so the wordmark costs one
frame and the bars' smooth fade compresses. Runs alone made the flyby 7.8 MB:
the fade has no two pixels alike.
"""
import os
import struct
import subprocess
import sys
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_VIDEO = os.path.expanduser("~/Developer/TortOS/res/boot/tortos-boot.mp4")
FLY_VIDEO = os.path.expanduser("~/Developer/TortOS/res/boot/tortos-fly.mp4")
PACKAGE = os.path.join(HERE, "..", "buildroot", "package", "splash")
FPS, FLY_FPS = 30, 60


def main():
    args = sys.argv[1:]
    brick = "--brick" in args
    fly = "--fly" in args
    args = [a for a in args if a not in ("--brick", "--fly")]
    video = args[0] if args else (FLY_VIDEO if fly else DEFAULT_VIDEO)
    fps = FLY_FPS if fly else FPS
    if brick:
        W, H, OUT = 1024, 768, os.path.join(PACKAGE, "frames-brick.bin")
        vf = "fps=%d" % fps
    else:
        W, H, OUT = 480, 640, os.path.join(PACKAGE, "frames.bin")
        vf = "scale=640:480:flags=area,transpose=2,fps=%d" % fps
    source = ["-i", video]
    if os.path.isdir(video):
        source = ["-framerate", str(fps), "-start_number", "0",
                  "-i", os.path.join(video, "f%04d.png")]
    raw = subprocess.run(
        ["ffmpeg", "-v", "error"] + source + [
         "-vf", vf,
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

    if brick:
        write_bands(OUT, frames, W, H, fps)
        return

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

    header = struct.pack("<4sHHHH", b"TSPL", W, H, len(encoded), fps)
    offset = len(header) + 4 * len(encoded)
    table = bytearray()
    for e in encoded:
        table += struct.pack("<I", offset)
        offset += len(e)
    with open(OUT, "wb") as out:
        out.write(header + table + b"".join(encoded))
    print("%s: %d frames of %d, %.1f MB" % (os.path.relpath(OUT), len(encoded),
                                           len(raw) // size, offset / 1e6))


def sub_filter(band, stride):
    """Each byte less the same byte one pixel to the left (row starts kept)."""
    out = bytearray(band)
    for start in range(0, len(band), stride):
        row = band[start:start + stride]
        for i in range(4, stride):
            out[start + i] = (row[i] - row[i - 4]) & 0xff
    return bytes(out)


def write_bands(out_path, frames, w, h, fps):
    stride = w * 4
    frames = [bytearray(f) for f in frames]
    for f in frames:
        f[3::4] = b"\xff" * (len(f) // 4)      # opaque: the display blends by alpha
    encoded = []
    for n, f in enumerate(frames):
        if n == 0:
            first, rows = 0, h
        else:
            prev = frames[n - 1]
            changed = [y for y in range(h)
                       if f[y * stride:(y + 1) * stride] != prev[y * stride:(y + 1) * stride]]
            first, rows = (changed[0], changed[-1] - changed[0] + 1) if changed else (0, 0)
        band = bytes(f[first * stride:(first + rows) * stride])
        data = zlib.compress(sub_filter(band, stride), 9) if rows else b""
        encoded.append(struct.pack("<HHI", first, rows, len(data)) + data)
    header = struct.pack("<4sHHHH", b"TSPZ", w, h, len(encoded), fps)
    offset = len(header) + 4 * len(encoded)
    table = bytearray()
    for e in encoded:
        table += struct.pack("<I", offset)
        offset += len(e)
    with open(out_path, "wb") as out:
        out.write(header + table + b"".join(encoded))
    print("%s: %d frames, changed bands only, %.2f MB" % (
        os.path.relpath(out_path), len(encoded), offset / 1e6))


if __name__ == "__main__":
    main()
