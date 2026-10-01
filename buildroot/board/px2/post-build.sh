#!/bin/sh
# Install the developer's SSH public key, if local/authorized_keys exists.
# local/ is gitignored, so the key never lands in the repository.
set -eu
KEYS=$BR2_EXTERNAL_PX2_PATH/../local/authorized_keys

if [ -f "$KEYS" ]; then
	install -d -m 700 "$TARGET_DIR/root/.ssh"
	install -m 600 "$KEYS" "$TARGET_DIR/root/.ssh/authorized_keys"
fi
