#!/bin/sh
# Runs inside the build container (make release), once per device. Builds the
# device's TortOS image without the developer's SSH key and puts what a
# release carries in /work/release, for the Makefile to copy out:
#
#   TortOS-v<version>-<device>.img.xz        the card image, compressed
#   TortOS-v<version>-<device>-sources.tar   the licenses and sources of
#                                            everything in it
#
# <device> is pixel2 or brick. The Makefile writes SHA256SUMS over both
# devices' files once both are built.
#
# Each build starts from an empty output folder of its own, never the
# everyday build's: Buildroot never takes out a file a package stopped
# installing, so an image built on top of older builds can carry dead files
# (the Brick's carried an old /usr/share/tortos/brick, 2026-10-24).
set -eu

VERSION=$1
DEVICE=$2
case $DEVICE in
pixel2) FLAVOR=tortos ;;
brick) FLAVOR=brick ;;
*) echo "release: unknown device $DEVICE (pixel2 or brick)" >&2; exit 1 ;;
esac
NAME=TortOS-v$VERSION-$DEVICE
OUTPUT=/work/release-output-$DEVICE
RELEASE=/work/release
SOURCES=$OUTPUT/legal-info/sources

rm -rf "$OUTPUT"
PLASTRON_RELEASE=1 FLAVOR=$FLAVOR PLASTRON_OUTPUT=$OUTPUT sh /src/scripts/build.sh all legal-info

# The package list on the card and in the repository is this build's: one
# that no longer matches would credit what the image doesn't carry, or miss
# what it does
BOARD=$( [ "$DEVICE" = pixel2 ] && echo px2 || echo brick )
python3 /src/scripts/third-party.py "$OUTPUT/legal-info/manifest.csv" "$DEVICE" > /tmp/third-party-$DEVICE.md
if ! cmp -s /tmp/third-party-$DEVICE.md "/src/buildroot/board/$BOARD/third-party-packages.md"; then
	echo "release: buildroot/board/$BOARD/third-party-packages.md doesn't match this build's packages:" >&2
	diff "/src/buildroot/board/$BOARD/third-party-packages.md" /tmp/third-party-$DEVICE.md >&2 || true
	echo "release: run make third-party, check and commit the list, and build again" >&2
	exit 1
fi

# Checked, not trusted: the build has no key of its own to leave behind, but a
# leftover in the output from a development build would ship to everyone
if [ -e "$OUTPUT/target/root/.ssh" ]; then
	echo "release: $OUTPUT/target/root/.ssh is in the image" >&2
	exit 1
fi
if [ -e "$OUTPUT/target/etc/init.d/S50dropbear" ]; then
	echo "release: dropbear's start script is in the image" >&2
	exit 1
fi

if [ "$DEVICE" = pixel2 ]; then
	# U-Boot is built outside Buildroot (make bootloader) and committed, so
	# legal-info has no source for it. Its source is the tarball it is built
	# from plus our patches and config, which go in beside the rest.
	UBOOT_VERSION=$(sed -n 's/^UBOOT_VERSION=//p' /src/scripts/build-bootloader.sh)
	UBOOT=$SOURCES/u-boot-$UBOOT_VERSION
	mkdir -p "$UBOOT"
	cp "/work/dl/u-boot-$UBOOT_VERSION.tar.gz" "$UBOOT/"
	cp -R /src/buildroot/board/px2/u-boot/. "$UBOOT/plastron/"
	# TF-A's BL31 is built alongside it, unpatched, from this tarball
	TFA_COMMIT=$(sed -n 's/^TFA_COMMIT=//p' /src/scripts/build-bootloader.sh)
	mkdir -p "$SOURCES/tf-a-$TFA_COMMIT"
	cp "/work/dl/tf-a-$TFA_COMMIT.tar.gz" "$SOURCES/tf-a-$TFA_COMMIT/"
else
	# The Brick's kernel and the modules it loads are built outside Buildroot
	# (make brick-kernel), so legal-info has no source for them: the tree as
	# Creality published it (with the GPU's kernel driver, dual MIT/GPL), our
	# patches (the defconfig is in them), the device tree, and how it's built
	KERNEL=$SOURCES/linux-brick
	mkdir -p "$KERNEL/plastron"
	cp /work/dl/linux-4.9.191-a133.tar.xz "$KERNEL/"
	cp -R /src/buildroot/board/brick/linux /src/buildroot/board/brick/dts "$KERNEL/plastron/"
	cp /src/scripts/build-brick-kernel.sh /src/docker/brick-kernel/Dockerfile "$KERNEL/plastron/"
	# Its boot loader too (make brick-bootloader, committed): U-Boot and TF-A
	# at their commits, with our patches
	UBOOT_COMMIT=$(sed -n 's/^UBOOT_COMMIT=//p' /src/scripts/build-brick-bootloader.sh)
	TFA_COMMIT=$(sed -n 's/^TFA_COMMIT=//p' /src/scripts/build-brick-bootloader.sh)
	BOOT=$SOURCES/u-boot-brick
	mkdir -p "$BOOT/plastron"
	cp "/work/dl/u-boot-$UBOOT_COMMIT.tar.gz" "/work/dl/tf-a-$TFA_COMMIT.tar.gz" "$BOOT/"
	cp -R /src/buildroot/board/brick/u-boot/. "$BOOT/plastron/"
	cp /src/scripts/build-brick-bootloader.sh /src/docker/brick-boot/Dockerfile "$BOOT/plastron/"
	# The closed parts are in the image and nowhere else: their packages are
	# marked not to be redistributed, so legal-info leaves their files out
	cat > "$OUTPUT/legal-info/PROPRIETARY.txt" <<-EOF
	The TrimUI Brick's image carries two closed parts that are not ours, are
	not in these sources, and are not distributed on their own:

	- Imagination Technologies' PowerVR DDK 1.11@5516664 userspace libraries
	  and firmware for the GE8300 GPU (OpenGL ES, EGL, the null window
	  system, rgx.fw.22.102.54.38), as Allwinner ships them for the A133,
	  under Imagination's own terms. Package pvr-ge8300.
	- XRadio's firmware for the XR829 Wi-Fi and Bluetooth chip
	  (boot_xr829.bin, fw_xr829.bin, sdd_xr829.bin, fw_xr829_bt.bin), with no
	  license stated. Package xr829-firmware.

	Both as Creality's Sonic Pad SDK has them (github.com/CrealityTech/
	sonic_pad_os at 7f37a7f).
	EOF
fi
# Copied from a working tree on a Mac, so Finder's files come too
find "$SOURCES" -name .DS_Store -delete

# Buildroot itself is GPL-2.0+, and its makefiles and patches built every
# package in the image, but legal-info never saves it (it says so on every
# run). The release tarball the build started from goes in.
BUILDROOT_VERSION=$(sed -n 's/^BUILDROOT_VERSION=//p' /src/scripts/build.sh)
mkdir -p "$OUTPUT/legal-info/buildroot-source"
cp "/work/dl/buildroot-$BUILDROOT_VERSION.tar.xz" "$OUTPUT/legal-info/buildroot-source/"

mkdir -p "$RELEASE"
rm -f "$RELEASE/$NAME.img.xz" "$RELEASE/$NAME-sources.tar"
xz -T0 -9 -c "$OUTPUT/images/sdcard.img" > "$RELEASE/$NAME.img.xz"
tar -C "$OUTPUT" -cf "$RELEASE/$NAME-sources.tar" legal-info
ls -l "$RELEASE/$NAME.img.xz" "$RELEASE/$NAME-sources.tar"
