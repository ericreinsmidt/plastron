#!/bin/sh
# Assemble out/sdcard.img from the kernel, device tree, boot script, root
# filesystem and the bootloader (ROCKNIX's, with our U-Boot; make bootloader).
set -eu
BOARD_DIR=$(dirname "$0")

cp "$BOARD_DIR/bootloader/u-boot-px2.bin" "$BINARIES_DIR/"
support/scripts/genimage.sh -c "$BOARD_DIR/genimage.cfg"
