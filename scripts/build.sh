#!/bin/sh
# Runs inside the build container. /src is this repository (read-only);
# /work is a Docker volume, because Buildroot needs a case-sensitive
# filesystem and the Mac's isn't.
set -eu

BUILDROOT_VERSION=2026.02.3
BUILDROOT=/work/buildroot-$BUILDROOT_VERSION
# FLAVOR=tortos (the default) is the base system with TortOS on top;
# FLAVOR=base is the base system alone. Separate outputs, so switching
# never leaves one's files in the other.
FLAVOR=${FLAVOR:-tortos}
case $FLAVOR in
tortos) OUTPUT=/work/output ;;
base) OUTPUT=/work/output-base ;;
*) echo "unknown FLAVOR $FLAVOR" >&2; exit 1 ;;
esac

mkdir -p /work/dl
if [ ! -d "$BUILDROOT" ]; then
	tarball=/work/dl/buildroot-$BUILDROOT_VERSION.tar.xz
	[ -f "$tarball" ] || wget -q -O "$tarball" "https://buildroot.org/downloads/buildroot-$BUILDROOT_VERSION.tar.xz"
	tar -C /work -xf "$tarball"
fi

make -C "$BUILDROOT" O="$OUTPUT" BR2_EXTERNAL=/src/buildroot BR2_DL_DIR=/work/dl px2_defconfig
if [ "$FLAVOR" = tortos ]; then
	"$BUILDROOT/support/kconfig/merge_config.sh" -m -O "$OUTPUT" \
		"$OUTPUT/.config" /src/buildroot/board/tortos/tortos.config >/dev/null
	make -C "$OUTPUT" olddefconfig >/dev/null
fi
make -C "$OUTPUT" "$@"
