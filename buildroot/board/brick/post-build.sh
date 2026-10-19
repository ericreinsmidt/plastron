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

# Bluetooth's lasting state, on the plastron-state partition that
# init.d/bluetooth mounts at /var/lib/state, as the root is read-only: the
# pairings, the headsets' volumes, and the adapter's address (xr_bt.conf,
# which hciattach makes at the first attach). Everything else that changes at
# run time is already in the RAM filesystems (/var/run, /var/log, /var/lib/dbus)
mkdir -p "${TARGET_DIR:?}/var/lib/state"
rm -rf "${TARGET_DIR:?}/var/lib/bluetooth" "${TARGET_DIR:?}/var/lib/bluealsa"
ln -s state/bluetooth "$TARGET_DIR/var/lib/bluetooth"
ln -s state/bluealsa "$TARGET_DIR/var/lib/bluealsa"
ln -sfn ../../var/lib/state/xr_bt.conf "$TARGET_DIR/etc/bluetooth/xr_bt.conf"
