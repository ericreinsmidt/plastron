#!/bin/sh
# The TrimUI Brick's boot files, beside the root's image in output-brick/images:
# the initramfs (rootswitch, as /rdinit), boot.scr from board/brick/boot.cmd,
# the kernel and device tree from make brick-kernel (in this volume), and the
# boot loader (board/brick/bootloader, from make brick-bootloader).
set -eu
BOARD=$BR2_EXTERNAL_PX2_PATH/board/brick
KERNEL=/work/brick-kernel/images
# Fixed dates, so the same files pack to the same bytes
export SOURCE_DATE_EPOCH=1791936000

D=$(mktemp -d)
mkdir -p "$D/dev" "$D/sys" "$D/root"
cp "$BINARIES_DIR/rdinit" "$D/rdinit"
find "$D" -exec touch -h -d "@$SOURCE_DATE_EPOCH" {} +
(cd "$D" && find . | LC_ALL=C sort | cpio -o -H newc --reproducible --quiet) |
	gzip -9 -n > "$BINARIES_DIR/initramfs.cpio.gz"
rm -r "$D"

"$HOST_DIR/bin/mkimage" -A arm64 -T script -C none -n "Brick boot" \
	-d "$BOARD/boot.cmd" "$BINARIES_DIR/boot.scr" > /dev/null

for f in Image brick.dtb; do
	[ -f "$KERNEL/$f" ] || { echo "no $f from make brick-kernel" >&2; exit 1; }
	cp "$KERNEL/$f" "$BINARIES_DIR/"
done
cp "$BOARD/bootloader/u-boot-sunxi-with-spl.bin" "$BINARIES_DIR/"
