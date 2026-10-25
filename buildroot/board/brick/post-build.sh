#!/bin/sh
# TortOS's version, as a number, into its init script (package/tortos's
# tortos.init), so a boot compares the card's against it without reading the
# image's VERSION file, as the Pixel 2's post-build.sh does. Worked out by the
# script's own version_of, so the two can't disagree.
set -eu
INIT=$TARGET_DIR/etc/init.d/tortos
SEED_VERSION=$TARGET_DIR/usr/share/tortos/card/TortOS/VERSION
if [ -f "$INIT" ] && [ -f "$SEED_VERSION" ]; then
	eval "$(sed -n '/^version_of()/,/^}/p' "$INIT")"
	version_of "$SEED_VERSION" && sed -i "s/^SEED_V=.*/SEED_V=$v/" "$INIT"
	grep "^SEED_V=" "$INIT"
fi

# When this system was built, into datapart, which sets a clock that reads
# after 2070 (TrimUI's firmware's RTC year) to it on a fresh card's first boot
DATAPART=$TARGET_DIR/etc/init.d/datapart
sed -i "s/^BUILT=.*/BUILT=$(date +%s)/" "$DATAPART"
grep "^BUILT=" "$DATAPART"

# Finder leaves .DS_Store files in the overlay folders on a Mac
find "$TARGET_DIR" -name .DS_Store -delete

# The games partition's mount point, made here rather than at boot: on a
# squashfs root nothing can be made at boot, and datapart's mkdir would
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

# The licenses, on the card where a player can find them: a Licenses folder
# beside TortOS's, which the first boot and every TortOS update copy onto the
# card with it. plastron's notice and this image's package list, Diatom's
# notice, and TortOS's
SEED_CARD=$TARGET_DIR/usr/share/tortos/card
if [ -d "$SEED_CARD" ]; then
	L=$SEED_CARD/Licenses
	mkdir -p "$L"
	cp "$BR2_EXTERNAL_PX2_PATH/../THIRD-PARTY.md" "$L/plastron.md"
	cp "$BR2_EXTERNAL_PX2_PATH/board/brick/third-party-packages.md" "$L/plastron-packages.md"
	[ -f /diatom/THIRD-PARTY.md ] && cp /diatom/THIRD-PARTY.md "$L/Diatom.md"
	[ -f "$SEED_CARD/TortOS/THIRD-PARTY-LICENSES.md" ] && cp "$SEED_CARD/TortOS/THIRD-PARTY-LICENSES.md" "$L/TortOS.md"
	ls "$L"
fi
