#!/bin/sh
# Builds U-Boot the way ROCKNIX does for RK3326 (v2025.10, their patch, their
# config) plus board/px2/u-boot/px2.config, and TF-A's BL31 for the PX30 at
# the commit the Brick's uses, fetches Rockchip's prebuilt DDR init and
# miniloader from rkbin and makes the card's first stage. Runs in the build
# container, whose native gcc is aarch64, so no cross-compiler is needed.
# Output in /work/bootloader: u-boot-dtb.bin, bl31.elf, idbloader.img and
# rkbin/, put together afterwards by pack-bootloader.sh.
set -eu

UBOOT_VERSION=v2025.10
UBOOT_SHA256=5414ee86562abc5ed524c6dc5e092511ad281441020a88e7027de6e83fd16116
TFA_COMMIT=510355478850fb9bb4b064554d3dc2416b8b4b96
TFA_SHA256=917f5f345c781239e128456b151cbcb662944dcc7572c115f17cfc40efb30050

# What each says about itself, fixed, so the same sources always build the
# same bytes
UBOOT_EPOCH=1792107000
TFA_BUILD_STRING=5103554
TFA_TIMESTAMP='"23:30:00, Oct 15 2026"'
BOARD=/src/buildroot/board/px2/u-boot
WORK=/work/bootloader
SRC=$WORK/u-boot-$UBOOT_VERSION

mkdir -p /work/dl "$WORK"
tarball=/work/dl/u-boot-$UBOOT_VERSION.tar.gz
[ -f "$tarball" ] || wget -q -O "$tarball" "https://github.com/u-boot/u-boot/archive/refs/tags/$UBOOT_VERSION.tar.gz"
echo "$UBOOT_SHA256  $tarball" | sha256sum -c -

rm -rf "$SRC"
mkdir -p "$SRC"
tar -C "$SRC" --strip-components=1 -xzf "$tarball"
cd "$SRC"
for p in "$BOARD"/patches/*.patch; do patch -p1 -F0 -s --batch < "$p"; done
cp -R "$BOARD"/sources/. .

make rk3326-handheld_defconfig
scripts/kconfig/merge_config.sh -m .config "$BOARD/px2.config"
make olddefconfig
SOURCE_DATE_EPOCH=$UBOOT_EPOCH make -j"$(nproc)" u-boot-dtb.bin
cp u-boot-dtb.bin "$WORK/"

# BL31: TF-A, the same commit as the Brick's, for the PX30
tfa=/work/dl/tf-a-$TFA_COMMIT.tar.gz
[ -f "$tfa" ] || wget -q -O "$tfa" "https://github.com/ARM-software/arm-trusted-firmware/archive/$TFA_COMMIT.tar.gz"
echo "$TFA_SHA256  $tfa" | sha256sum -c -
rm -rf "$WORK/tf-a"
mkdir -p "$WORK/tf-a"
tar -C "$WORK/tf-a" --strip-components=1 -xzf "$tfa"
make -s -C "$WORK/tf-a" -j"$(nproc)" PLAT=px30 DEBUG=0 \
	BUILD_STRING="$TFA_BUILD_STRING" BUILD_MESSAGE_TIMESTAMP="$TFA_TIMESTAMP" bl31
cp "$WORK/tf-a/build/px30/release/bl31/bl31.elf" "$WORK/"

# Rockchip's prebuilt pieces, from the rkbin commit ROCKNIX pins: the DDR init
# and miniloader (the first stage), and the x86 tools that pack U-Boot and
# BL31 into the images the miniloader reads
RKBIN=74213af1e952c4683d2e35952507133b61394862
mkdir -p "$WORK/rkbin"
rkbin() {
	f="$WORK/rkbin/$(basename "$1")"
	[ -f "$f" ] || wget -q -O "$f" "https://raw.githubusercontent.com/rockchip-linux/rkbin/$RKBIN/$1"
	echo "$2  $f" | sha256sum -c - >/dev/null
}
rkbin bin/rk33/rk3326_ddr_333MHz_v2.11.bin 2df577824953bea3584282e7f5118c96620e1348dbc378d50604fe07c70eb3e4
rkbin bin/rk33/rk3326_miniloader_v1.40.bin 473aacd5378f356757a71efeb54f4339925db154fbce288df7e3c1177f45bc28
rkbin tools/loaderimage e26a311d449c6254d0d89ecaf8cd1870438205e07a66b27265d68830b8977439
rkbin tools/trust_merger 059b622fc7597da572d8fcf726da3897e498985b3e922015f1413fb45f89963a
chmod +x "$WORK/rkbin/loaderimage" "$WORK/rkbin/trust_merger"

# The first stage the way ROCKNIX makes it: the DDR init through mkimage, then
# the miniloader appended after it
./tools/mkimage -n px30 -T rksd -d "$WORK/rkbin/rk3326_ddr_333MHz_v2.11.bin" "$WORK/idbloader.img" >/dev/null
cat "$WORK/rkbin/rk3326_miniloader_v1.40.bin" >> "$WORK/idbloader.img"
grep -E "^CONFIG_BOOTDELAY=" .config
