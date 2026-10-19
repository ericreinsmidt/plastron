#!/bin/sh
# The TrimUI Brick's card, sdcard.img in output-brick/images: its boot files
# (the initramfs, rootswitch as /rdinit; boot.scr from board/brick/boot.cmd;
# the kernel, also LZ4-compressed, and device tree from make brick-kernel, in
# this volume; the boot loader, board/brick/bootloader, from make
# brick-bootloader) and the root, laid out by board/brick/genimage.cfg.
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
# The kernel LZ4-compressed too, which boot.scr boots: U-Boot reads the card at
# about 17 MB/s, and the file half the size saves 194 ms of reading for 33 ms
# of unpacking. Image stays beside it, for U-Boot's own boot command.
"$HOST_DIR/bin/lz4" -9 -f -q --no-frame-crc "$BINARIES_DIR/Image" "$BINARIES_DIR/Image.lz4"
cp "$BOARD/bootloader/u-boot-sunxi-with-spl.bin" "$BINARIES_DIR/"
# The state partition, empty: ext4, 16 MB, for what changes and has to last
# (Bluetooth's pairings, volumes and address; init.d/bluetooth mounts it). The
# same bytes every build: fixed UUID and hash seed, and the build's date
rm -f "$BINARIES_DIR/state.ext4"
dd if=/dev/zero of="$BINARIES_DIR/state.ext4" bs=1M count=0 seek=16 2> /dev/null
E2FSPROGS_FAKE_TIME=$SOURCE_DATE_EPOCH "$HOST_DIR/sbin/mkfs.ext4" -q -F -L plastron-state \
	-O ^64bit,^orphan_file -U 2d8f6a40-6c1e-4f5b-9e3a-706c61737465 \
	-E hash_seed=2d8f6a40-6c1e-4f5b-9e3a-706c61737465 "$BINARIES_DIR/state.ext4"
support/scripts/genimage.sh -c "$BOARD/genimage.cfg"
