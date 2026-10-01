#!/bin/sh
# Runs inside the build container. /src is this repository (read-only);
# /work is a Docker volume, because Buildroot needs a case-sensitive
# filesystem and the Mac's isn't.
set -eu

BUILDROOT_VERSION=2026.02.3
BUILDROOT=/work/buildroot-$BUILDROOT_VERSION
OUTPUT=/work/output

mkdir -p /work/dl
if [ ! -d "$BUILDROOT" ]; then
	tarball=/work/dl/buildroot-$BUILDROOT_VERSION.tar.xz
	[ -f "$tarball" ] || wget -q -O "$tarball" "https://buildroot.org/downloads/buildroot-$BUILDROOT_VERSION.tar.xz"
	tar -C /work -xf "$tarball"
fi

make -C "$BUILDROOT" O="$OUTPUT" BR2_EXTERNAL=/src/buildroot BR2_DL_DIR=/work/dl tortos_px2_defconfig
make -C "$OUTPUT" "$@"
