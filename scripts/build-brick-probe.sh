#!/bin/sh
# The Brick panel probe's card image (board/brick/probe): plastron's Brick
# kernel and boot loader with the probe as the whole initramfs, nothing else.
# Runs in plastron-builder with the volume, after make brick (its toolchain,
# mkimage and genimage) and make brick-kernel (the Image and device tree).
# Output in /work/brick-probe/brick-panel-probe.img.
set -eu
BOARD=/src/buildroot/board/brick
PROBE=$BOARD/probe
HOST=/work/output-brick/host
KERNEL=/work/brick-kernel/images
OUT=/work/brick-probe
export SOURCE_DATE_EPOCH=1791936000
# genimage calls mkdosfs and mcopy, Buildroot's host builds of them
export PATH=$HOST/bin:$HOST/sbin:$PATH

for f in "$HOST/bin/aarch64-linux-gcc" "$HOST/bin/mkimage" "$HOST/bin/genimage" \
	"$KERNEL/Image" "$KERNEL/brick.dtb"; do
	[ -e "$f" ] || { echo "missing $f: make brick and make brick-kernel first" >&2; exit 1; }
done
rm -rf "$OUT"
mkdir -p "$OUT/input" "$OUT/build" "$OUT/initramfs/dev" "$OUT/initramfs/sys"

# The kernel's own 8x16 font (lib/fonts/font_8x16.c), its table alone
sed -n '/^static const unsigned char fontdata_8x16/,/^};/p' \
	/work/brick-kernel/linux/lib/fonts/font_8x16.c |
	sed 's/\[FONTDATAMAX\]/[4096]/' > "$OUT/build/font_8x16.h"
"$HOST/bin/aarch64-linux-gcc" -static -O2 -Wall -Wextra -I"$OUT/build" \
	-o "$OUT/initramfs/rdinit" "$PROBE/probe.c"
"$HOST/bin/aarch64-linux-strip" "$OUT/initramfs/rdinit"

find "$OUT/initramfs" -exec touch -h -d "@$SOURCE_DATE_EPOCH" {} +
(cd "$OUT/initramfs" && find . | LC_ALL=C sort | cpio -o -H newc --reproducible --quiet) |
	gzip -9 -n > "$OUT/input/initramfs.cpio.gz"
"$HOST/bin/mkimage" -A arm64 -T script -C none -n "Brick boot" \
	-d "$BOARD/boot.cmd" "$OUT/input/boot.scr" > /dev/null
cp "$KERNEL/Image" "$KERNEL/brick.dtb" "$PROBE/README.txt" "$OUT/input/"
cp "$BOARD/bootloader/u-boot-sunxi-with-spl.bin" "$OUT/input/"

"$HOST/bin/genimage" --config "$PROBE/genimage.cfg" --rootpath "$OUT/initramfs" \
	--tmppath "$OUT/tmp" --inputpath "$OUT/input" --outputpath "$OUT" > /dev/null
rm -rf "$OUT/tmp"
ls -l "$OUT/brick-panel-probe.img"
