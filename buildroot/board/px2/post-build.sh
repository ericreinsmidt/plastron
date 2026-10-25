#!/bin/sh
# Install the developer's SSH public key, if local/authorized_keys exists.
# local/ is gitignored, so the key never lands in the repository. A release
# build (PLASTRON_RELEASE=1, set by scripts/release.sh) takes it out instead:
# the key would let its owner into every card written from the image, and
# without one nobody can log in, as root has no password and dropbear turns
# down an empty one.
set -eu
KEYS=$BR2_EXTERNAL_PX2_PATH/../local/authorized_keys

if [ "${PLASTRON_RELEASE:-0}" = 1 ]; then
	rm -rf "$TARGET_DIR/root/.ssh"
elif [ -f "$KEYS" ]; then
	install -d -m 700 "$TARGET_DIR/root/.ssh"
	install -m 600 "$KEYS" "$TARGET_DIR/root/.ssh/authorized_keys"
fi

# TortOS's version, as a number, into its init script, so a boot compares the
# card's against it without reading the image's VERSION file. Worked out by
# the init script's own version_of, so the two can't disagree.
INIT=$TARGET_DIR/etc/init.d/tortos
SEED_VERSION=$TARGET_DIR/usr/share/tortos/card/TortOS/VERSION
if [ -f "$INIT" ] && [ -f "$SEED_VERSION" ]; then
	eval "$(sed -n '/^version_of()/,/^}/p' "$INIT")"
	version_of "$SEED_VERSION" && sed -i "s/^SEED_V=.*/SEED_V=$v/" "$INIT"
	grep "^SEED_V=" "$INIT"
fi

# Finder leaves .DS_Store files in the overlay folders on a Mac
find "$TARGET_DIR" -name .DS_Store -delete

# The games partition's mount point, made here rather than at boot, as on the
# Brick: on a squashfs root nothing can be made at boot, and datapart's mkdir
# would fail, leaving the card unmounted and TortOS with nowhere to start from
mkdir -p "$TARGET_DIR/mnt/SDCARD"

# The licenses, on the card where a player can find them: a Licenses folder
# beside TortOS's, which the first boot and every TortOS update copy onto the
# card with it. plastron's notice and this image's package list, Diatom's
# notice, and TortOS's
SEED_CARD=$TARGET_DIR/usr/share/tortos/card
if [ -d "$SEED_CARD" ]; then
	L=$SEED_CARD/Licenses
	mkdir -p "$L"
	cp "$BR2_EXTERNAL_PX2_PATH/../THIRD-PARTY.md" "$L/plastron.md"
	cp "$BR2_EXTERNAL_PX2_PATH/board/px2/third-party-packages.md" "$L/plastron-packages.md"
	[ -f /diatom/THIRD-PARTY.md ] && cp /diatom/THIRD-PARTY.md "$L/Diatom.md"
	[ -f "$SEED_CARD/TortOS/THIRD-PARTY-LICENSES.md" ] && cp "$SEED_CARD/TortOS/THIRD-PARTY-LICENSES.md" "$L/TortOS.md"
	ls "$L"
fi
