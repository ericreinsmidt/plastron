#!/bin/sh
# Runs in an x86 container: Rockchip's loaderimage and trust_merger only exist
# as x86 binaries. Puts the card's bootloader together from what
# build-bootloader.sh left in /work/bootloader: the first stage (Rockchip's DDR
# init and miniloader), then U-Boot as uboot.img and TF-A's BL31 as trust.img,
# where the miniloader reads them, the same layout ROCKNIX's bootloader has.
set -eu

WORK=/work/bootloader
R=$WORK/rkbin
OUT=/src/buildroot/board/px2/bootloader/u-boot-px2.bin

cd "$WORK"
"$R/loaderimage" --pack --uboot u-boot-dtb.bin uboot.img 0x00200000 >/dev/null
cat > trust.ini <<EOF
[BL30_OPTION]
SEC=0
[BL31_OPTION]
SEC=1
PATH=$WORK/bl31.elf
ADDR=0x00010000
[BL32_OPTION]
SEC=0
[BL33_OPTION]
SEC=0
[OUTPUT]
PATH=$WORK/trust.img
EOF
"$R/trust_merger" trust.ini >/dev/null

# Offsets are in 512-byte sectors from the start of this file, which lands at
# sector 64 of the card: uboot.img at 16320 (card 16384), trust.img at 24512
# (card 24576), and the file ends where the boot partition starts, at 16 MiB.
rm -f "$OUT.new"
dd if=idbloader.img of="$OUT.new" conv=notrunc status=none
dd if=uboot.img of="$OUT.new" bs=512 seek=16320 conv=notrunc status=none
dd if=trust.img of="$OUT.new" bs=512 seek=24512 conv=notrunc status=none
[ "$(stat -c %s "$OUT.new")" -le 16744448 ] || { echo "the bootloader overran 16 MiB" >&2; exit 1; }
truncate -s 16744448 "$OUT.new"
mv "$OUT.new" "$OUT"
ls -l "$OUT"
