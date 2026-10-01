#!/bin/sh
# Runs in an x86 container: Rockchip's loaderimage only exists as an x86
# binary. Wraps u-boot-dtb.bin as uboot.img and drops it into ROCKNIX's
# bootloader in place of theirs. Their idbloader (DDR init and miniloader)
# and trust.img (BL31) stay byte for byte what passed phase 0.
set -eu

WORK=/work/bootloader
BASE=/src/buildroot/board/px2/bootloader/u-boot-rocknix-20260901.bin
OUT=/src/buildroot/board/px2/bootloader/u-boot-px2.bin

cd "$WORK"
./loaderimage --pack --uboot u-boot-dtb.bin uboot.img 0x00200000

# Offsets are in 512-byte sectors from the start of this file, which lands at
# sector 64 of the card: uboot.img at 16320 (card 16384), trust.img at 24512.
cp "$BASE" "$OUT.new"
dd if=/dev/zero of="$OUT.new" bs=512 seek=16320 count=$((24512 - 16320)) conv=notrunc status=none
dd if=uboot.img of="$OUT.new" bs=512 seek=16320 conv=notrunc status=none
[ "$(stat -c %s "$OUT.new")" = "$(stat -c %s "$BASE")" ] || { echo "uboot.img overran its space" >&2; exit 1; }
mv "$OUT.new" "$OUT"
ls -l uboot.img "$OUT"
