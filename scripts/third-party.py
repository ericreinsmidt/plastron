#!/usr/bin/env python3
"""Every package in a plastron image, with its version, license and where it
comes from, as Markdown: from Buildroot's own manifest of the image
(legal-info/manifest.csv), so the list is the build's, not a hand-kept one.

usage: third-party.py MANIFEST DEVICE   (DEVICE: pixel2 or brick)

make third-party writes it to buildroot/board/<board>/third-party-packages.md
from the last release build; make release stops when the committed list no
longer matches its build."""
import csv
import sys

NAMES = {"pixel2": "GKD Pixel 2", "brick": "TrimUI Brick"}

# Where the packages built from local folders come from, by their site
LOCAL = {
    "/tortos": "TortOS, https://github.com/ericreinsmidt/TortOS",
    "/diatom": "Diatom, https://github.com/ericreinsmidt/diatom",
    "/brick-gpu": "Imagination Technologies: closed, not distributed on its own (see THIRD-PARTY.md)",
    "/brick-xr829": "XRadio: closed, not distributed on its own (see THIRD-PARTY.md)",
    "/work/brick-kernel/images": "plastron's build of the Brick's kernel (see THIRD-PARTY.md)",
}


def origin(site):
    for prefix, name in LOCAL.items():
        if site.startswith(prefix):
            return name
    if site.startswith("/src/"):
        return "plastron, https://github.com/ericreinsmidt/plastron"
    return site


def main():
    manifest, device = sys.argv[1], sys.argv[2]
    with open(manifest, newline="") as f:
        rows = list(csv.DictReader(f))
    print(f"# Packages in plastron's {NAMES[device]} image")
    print()
    print("Made from Buildroot's manifest of a release build by")
    print("`scripts/third-party.py`. A release's sources tar carries each one's")
    print("license text and source; `THIRD-PARTY.md` says more about the kernel,")
    print("the boot loader and the closed parts.")
    print()
    print("| Package | Version | License | From |")
    print("|---|---|---|---|")
    for r in sorted(rows, key=lambda r: r["PACKAGE"]):
        version = "from its repository" if r["VERSION"] == "local" else r["VERSION"]
        cells = [r["PACKAGE"], version, r["LICENSE"], origin(r["SOURCE SITE"])]
        print("| " + " | ".join(c.replace("|", "/") for c in cells) + " |")


main()
