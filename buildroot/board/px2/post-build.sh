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

# Finder leaves .DS_Store files in the overlay folders on a Mac
find "$TARGET_DIR" -name .DS_Store -delete
