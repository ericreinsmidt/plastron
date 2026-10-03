#!/usr/bin/env python3
"""
Draws plastron's mark (docs/plastron.svg) and README card
(docs/plastron-card.png).

Runs on the Mac, not in the build: it needs Pillow, and both files are kept
in the repository. Rerun it when the logo changes:

    scripts/make-logo.py [path/to/josefin_sans.ttf]

The font is Josefin Sans, the face TortOS and diatom use; by default it is
read from TortOS's checkout, as the splash frames read TortOS's animation.

The mark is a plastron, the underside of a turtle's shell: a flat-topped
hexagon split down the middle and twice across into three pairs of plates.
Seen from below, the turtle's left is on the right, so the heart's plate, the
cyan one, is the middle plate on the right. The card follows diatom's
(docs/diatom-card.png in diatom): 1280x640, the mark above the wordmark and
tagline, with the sizes, baselines and colors measured off it.
"""
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
DOCS = os.path.join(HERE, "..", "docs")
DEFAULT_FONT = os.path.expanduser("~/Developer/TortOS/res/fonts/menu.ttf")

BACKGROUND = (14, 20, 17)
WORDMARK = (233, 236, 227)
TAGLINE = (156, 171, 160)
CYAN = (61, 214, 255)
GREEN_LIGHT = (128, 176, 118)
GREEN_MID = (104, 138, 96)

SQRT3 = math.sqrt(3)


def plates(r):
    """The six plates of a flat-topped hexagon of radius r centered on 0,0,
    with their colors. The gaps are real, so the mark works on any
    background."""
    gap = 0.08 * r
    cut = 0.288 * r            # the two cuts across, either side of the middle
    half = r * SQRT3 / 2
    g = gap / 2

    def edge(y):
        return r - abs(y) / SQRT3  # x of the right edge at height y

    top = [(g, -half), (r / 2, -half), (edge(cut + g), -(cut + g)), (g, -(cut + g))]
    middle = [(g, -(cut - g)), (edge(cut - g), -(cut - g)), (r, 0),
              (edge(cut - g), cut - g), (g, cut - g)]
    bottom = [(x, -y) for x, y in reversed(top)]

    def mirror(points):
        return [(-x, y) for x, y in reversed(points)]

    return [
        (mirror(top), GREEN_LIGHT), (mirror(middle), GREEN_LIGHT), (mirror(bottom), GREEN_LIGHT),
        (top, GREEN_MID), (middle, CYAN), (bottom, GREEN_MID),
    ]


def hex_color(color):
    return "#%02X%02X%02X" % color


def mark_svg(r=50):
    half = r * SQRT3 / 2
    polygons = "".join(
        '<polygon points="%s" fill="%s"/>'
        % (" ".join("%.2f,%.2f" % p for p in points), hex_color(color))
        for points, color in plates(r))
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="%.2f %.2f %.2f %.2f" '
            'role="img" aria-label="plastron">%s</svg>\n'
            % (-r, -half, 2 * r, 2 * half, polygons))


def card(font_path, scale=4):
    """Drawn at four times the size and scaled down, which is Pillow's way to
    smooth edges."""
    width, height = 1280 * scale, 640 * scale
    image = Image.new("RGB", (width, height), BACKGROUND)
    draw = ImageDraw.Draw(image)
    cx, cy, r = 640, 214.5, 100
    for points, color in plates(r):
        draw.polygon([((cx + x) * scale, (cy + y) * scale) for x, y in points], fill=color)
    wordmark = ImageFont.truetype(font_path, 128 * scale)
    tagline = ImageFont.truetype(font_path, 43 * scale)
    draw.text((width / 2, 429 * scale), "plastron", font=wordmark, fill=WORDMARK, anchor="ms")
    draw.text((width / 2, 501 * scale), "a minimal Linux for handhelds",
              font=tagline, fill=TAGLINE, anchor="ms")
    return image.resize((1280, 640), Image.LANCZOS)


def main():
    font_path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_FONT
    with open(os.path.join(DOCS, "plastron.svg"), "w") as f:
        f.write(mark_svg())
    card(font_path).save(os.path.join(DOCS, "plastron-card.png"), optimize=True)
    print("docs/plastron.svg, docs/plastron-card.png")


if __name__ == "__main__":
    main()
