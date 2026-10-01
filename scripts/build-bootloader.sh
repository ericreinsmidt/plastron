#!/bin/sh
# Builds U-Boot the way ROCKNIX does for RK3326 (v2025.10, their patch, their
# config) plus board/px2/u-boot/px2.config. Runs in the build container, whose
# native gcc is aarch64, so no cross-compiler is needed. Output:
# /work/bootloader/u-boot-dtb.bin, packed afterwards by pack-bootloader.sh.
set -eu

UBOOT_VERSION=v2025.10
UBOOT_SHA256=5414ee86562abc5ed524c6dc5e092511ad281441020a88e7027de6e83fd16116
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
for p in "$BOARD"/patches/*.patch; do patch -p1 -F0 -s < "$p"; done
cp -R "$BOARD"/sources/. .

make rk3326-handheld_defconfig
scripts/kconfig/merge_config.sh -m .config "$BOARD/px2.config"
make olddefconfig
make -j"$(nproc)" u-boot-dtb.bin
cp u-boot-dtb.bin "$WORK/"

# Rockchip's packer for the next step, from the rkbin commit ROCKNIX pins
RKBIN=74213af1e952c4683d2e35952507133b61394862
[ -x "$WORK/loaderimage" ] || {
	wget -q -O "$WORK/loaderimage" "https://raw.githubusercontent.com/rockchip-linux/rkbin/$RKBIN/tools/loaderimage"
	chmod +x "$WORK/loaderimage"
}
grep -E "^CONFIG_BOOTDELAY=" .config
