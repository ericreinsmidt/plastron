#!/bin/sh
# Assemble out/sdcard.img from the kernel, device tree, boot script, root
# filesystem and ROCKNIX's prebuilt bootloader.
set -eu
BOARD_DIR=$(dirname "$0")

cp "$BOARD_DIR/bootloader/u-boot-rocknix-20260901.bin" "$BINARIES_DIR/"
support/scripts/genimage.sh -c "$BOARD_DIR/genimage.cfg"
