#!/bin/sh
# TortOS's version, as a number, into the Brick's startup script, so a boot
# compares the card's against it without reading the image's VERSION file, as
# the Pixel 2's post-build.sh does. Worked out by the script's own version_of,
# so the two can't disagree.
set -eu
INIT=$TARGET_DIR/etc/init.d/brick
SEED_VERSION=$TARGET_DIR/usr/share/tortos/card/TortOS/VERSION
if [ -f "$SEED_VERSION" ]; then
	eval "$(sed -n '/^version_of()/,/^}/p' "$INIT")"
	version_of "$SEED_VERSION" && sed -i "s/^SEED_V=.*/SEED_V=$v/" "$INIT"
	grep "^SEED_V=" "$INIT"
fi

# Finder leaves .DS_Store files in the overlay folders on a Mac
find "$TARGET_DIR" -name .DS_Store -delete

# The games partition's mount point, made here rather than at boot: on a
# squashfs root nothing can be made at boot, and init.d/brick's mkdir would
# fail, leaving the card unmounted and TortOS with nowhere to start from
mkdir -p "$TARGET_DIR/mnt/SDCARD"
