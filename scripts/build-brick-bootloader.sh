#!/bin/sh
# The TrimUI Brick's boot loader: TF-A's BL31, then U-Boot with it, as one
# file (u-boot-sunxi-with-spl.bin) that goes 128 KiB into the card. Pinned
# sources plus board/brick/u-boot/patches, which were scute's commits. Runs in
# plastron-brick-boot (docker/brick-boot), the compiler it was tested with;
# output: /work/brick-boot/u-boot-sunxi-with-spl.bin.
set -eu

UBOOT_COMMIT=5e3b01c8466dbe45cd6a06299f8f4c7e8c1c2363
UBOOT_SHA256=1a7f1b493f48e1fcc2ef99e56620be8ff7772f3a7f30c8c40c32d9cbac6c260a
TFA_COMMIT=510355478850fb9bb4b064554d3dc2416b8b4b96
TFA_SHA256=917f5f345c781239e128456b151cbcb662944dcc7572c115f17cfc40efb30050

# What each says about itself, fixed, so the same sources always build the
# same bytes: TF-A as it was built and tested (2026-10-11), U-Boot's date as
# the build tested on the Brick (2026-10-13). The version suffix can be set
# for comparing with an older build.
TFA_BUILD_STRING=5103554
TFA_TIMESTAMP='"17:54:29, Oct 11 2026"'
UBOOT_EPOCH=1791867416
UBOOT_LOCALVERSION=${UBOOT_LOCALVERSION--plastron}

BOARD=/src/buildroot/board/brick/u-boot
W=/work/brick-boot
mkdir -p /work/dl "$W"

fetch() {
	[ -f "/work/dl/$1" ] || wget -q -O "/work/dl/$1" "$2"
	echo "$3  /work/dl/$1" | sha256sum -c - >/dev/null
}
fetch "u-boot-$UBOOT_COMMIT.tar.gz" \
	"https://github.com/u-boot/u-boot/archive/$UBOOT_COMMIT.tar.gz" "$UBOOT_SHA256"
fetch "tf-a-$TFA_COMMIT.tar.gz" \
	"https://github.com/ARM-software/arm-trusted-firmware/archive/$TFA_COMMIT.tar.gz" "$TFA_SHA256"

rm -rf "$W/tf-a" "$W/u-boot"
mkdir -p "$W/tf-a" "$W/u-boot"
tar -C "$W/tf-a" --strip-components=1 -xzf "/work/dl/tf-a-$TFA_COMMIT.tar.gz"
tar -C "$W/u-boot" --strip-components=1 -xzf "/work/dl/u-boot-$UBOOT_COMMIT.tar.gz"

make -s -C "$W/tf-a" -j"$(nproc)" PLAT=sun50i_a133 DEBUG=0 \
	BUILD_STRING="$TFA_BUILD_STRING" BUILD_MESSAGE_TIMESTAMP="$TFA_TIMESTAMP" bl31

cd "$W/u-boot"
for p in "$BOARD"/patches/*.patch; do patch -p1 -F0 -s --batch < "$p"; done
make -s trimui-brick_defconfig
SOURCE_DATE_EPOCH=$UBOOT_EPOCH make -s -j"$(nproc)" LOCALVERSION="$UBOOT_LOCALVERSION" \
	BL31="$W/tf-a/build/sun50i_a133/release/bl31.bin" SCP=/dev/null
cp u-boot-sunxi-with-spl.bin "$W/"
strings u-boot-sunxi-with-spl.bin | grep -m1 "^U-Boot SPL 20"
