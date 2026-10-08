#!/bin/sh
# Runs inside the build container (make release). Builds the TortOS image
# without the developer's SSH key and puts what a release carries in
# /work/release, for the Makefile to copy out:
#
#   TortOS-v<version>-pixel2.img.xz          the card image, compressed
#   TortOS-v<version>-pixel2-sources.tar     the licenses and sources of
#                                            everything in it
#   SHA256SUMS
set -eu

VERSION=$1
NAME=TortOS-v$VERSION-pixel2
OUTPUT=/work/output
RELEASE=/work/release

# The packages built from working trees (TortOS, Diatom, and our own small
# ones here) are copied in when first built and never again unless cleaned:
# without this a release ships whatever was last built, under the new
# version's name. v1.4.0's first build carried TortOS 1.3.0 that way.
LOCAL=$(grep -l '_SITE_METHOD = local' /src/buildroot/package/*/*.mk | sed 's|.*/\([^/]*\)\.mk$|\1-dirclean|')
# The kernel too, built again from its tree as it stands, so the device tree
# (board/px2/dts, copied in before each build) is the one in the repository
PLASTRON_RELEASE=1 sh /src/scripts/build.sh $LOCAL linux-rebuild all legal-info

# Checked, not trusted: the build has no key of its own to leave behind, but a
# leftover in the output from a development build would ship to everyone
if [ -e "$OUTPUT/target/root/.ssh" ]; then
	echo "release: $OUTPUT/target/root/.ssh is in the image" >&2
	exit 1
fi

# U-Boot is built outside Buildroot (make bootloader) and committed, so
# legal-info has no source for it. Its source is the tarball it is built
# from plus our patches and config, which go in beside the rest.
UBOOT_VERSION=$(sed -n 's/^UBOOT_VERSION=//p' /src/scripts/build-bootloader.sh)
UBOOT=$OUTPUT/legal-info/sources/u-boot-$UBOOT_VERSION
mkdir -p "$UBOOT"
cp "/work/dl/u-boot-$UBOOT_VERSION.tar.gz" "$UBOOT/"
cp -R /src/buildroot/board/px2/u-boot/. "$UBOOT/plastron/"
# Copied from a working tree on a Mac, so Finder's files come too
find "$UBOOT/plastron" -name .DS_Store -delete

# Buildroot itself is GPL-2.0+, and its makefiles and patches built every
# package in the image, but legal-info never saves it (it says so on every
# run). The release tarball the build started from goes in.
BUILDROOT_VERSION=$(sed -n 's/^BUILDROOT_VERSION=//p' /src/scripts/build.sh)
mkdir -p "$OUTPUT/legal-info/buildroot-source"
cp "/work/dl/buildroot-$BUILDROOT_VERSION.tar.xz" "$OUTPUT/legal-info/buildroot-source/"

rm -rf "$RELEASE"
mkdir -p "$RELEASE"
xz -T0 -9 -c "$OUTPUT/images/sdcard.img" > "$RELEASE/$NAME.img.xz"
tar -C "$OUTPUT" -cf "$RELEASE/$NAME-sources.tar" legal-info
(cd "$RELEASE" && sha256sum "$NAME.img.xz" "$NAME-sources.tar" > SHA256SUMS)
ls -l "$RELEASE"
