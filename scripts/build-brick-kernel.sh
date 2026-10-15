#!/bin/sh
# The TrimUI Brick's kernel: Allwinner's Linux 4.9.191 for the A133, as
# Creality published it, plus board/brick/linux/patches (carapace's commits),
# and the modules the Brick loads: brick-pad, and Imagination's GPU driver
# (pvrsrvkm, dc_sunxi) from the DDK 1.11 kernel source in the tree. Runs in
# plastron-brick-kernel (docker/brick-kernel), for its GCC 10. Output in
# /work/brick-kernel/images: Image, the device tree (brick.dtb, from
# board/brick/dts) and the modules stripped of debug info.
set -eu

# The base: the kernel tree as Creality published it (CrealityTech/
# sonic_pad_os 7f37a7f, lichee/linux-4.9), less 11 closed binaries the Brick
# never builds (Allwinner's camera and HDMI libraries, prebuilt test tools)
LINUX_BASE=linux-4.9.191-a133
LINUX_SHA256=93710f3a1f1a54678641fe15b7898fd64bc151b63377ac698c5eced8806fa743
LINUX_URL=https://github.com/ericreinsmidt/plastron/releases/download/brick-linux-4.9.191-base/$LINUX_BASE.tar.xz

# Where it builds, and what it says about itself, fixed so the same sources
# always build the same bytes. All can be set, to compare with an older build.
SRC=${KERNEL_SRC:-/work/brick-kernel/linux}
OUT=${KERNEL_OUT:-/work/brick-kernel/out}
GPU=${KERNEL_GPU:-/work/brick-kernel/gpu}
export KBUILD_BUILD_VERSION=${KBUILD_BUILD_VERSION:-1}
export KBUILD_BUILD_TIMESTAMP=${KBUILD_BUILD_TIMESTAMP:-Wed Oct 14 00:00:00 UTC 2026}
export KBUILD_BUILD_USER=${KBUILD_BUILD_USER:-plastron}
export KBUILD_BUILD_HOST=${KBUILD_BUILD_HOST:-plastron}
# 4.9.191+, as carapace's git checkout made it: the modules carry it
LOCALVERSION=+

BOARD=/src/buildroot/board/brick/linux
IMAGES=/work/brick-kernel/images
mkdir -p /work/dl "$IMAGES"

f=/work/dl/$LINUX_BASE.tar.xz
[ -f "$f" ] || wget -q -O "$f" "$LINUX_URL"
echo "$LINUX_SHA256  $f" | sha256sum -c - >/dev/null

rm -rf "$SRC" "$OUT" "$GPU"
mkdir -p "$SRC" "$OUT" "$GPU/img-rgx"
tar -C "$SRC" --strip-components=1 -xJf "$f"
cd "$SRC"
for p in "$BOARD"/patches/*.patch; do patch -p1 -F0 -s --batch < "$p"; done

k() { make -s -C "$SRC" O="$OUT" ARCH=arm64 LOCALVERSION="$LOCALVERSION" -j"$(nproc)" "$@"; }
k brick_defconfig
k Image drivers/input/joystick/brick-pad.ko

# The GPU driver builds with Imagination's own build system, which writes
# into its source, so from a copy
cp -a "$SRC/modules/gpu/img-rgx/." "$GPU/img-rgx/"
make -s -C "$GPU/img-rgx/linux/rogue_km/build/linux/sunxi_linux" \
	BUILD=release KERNELDIR="$OUT" ARCH=arm64 > "$GPU/build.log" 2>&1 ||
	{ tail -20 "$GPU/build.log"; exit 1; }

G=$GPU/img-rgx/linux/rogue_km/binary_sunxi_linux_nullws_release/target_aarch64
cp "$OUT/arch/arm64/boot/Image" "$IMAGES/"
for m in "$OUT/drivers/input/joystick/brick-pad.ko" "$G/pvrsrvkm.ko" "$G/dc_sunxi.ko"; do
	strip --strip-debug -o "$IMAGES/$(basename "$m")" "$m"
done
dtc -q -I dts -O dtb -o "$IMAGES/brick.dtb" /src/buildroot/board/brick/dts/sun50iw10p1-trimui-brick.dts
strings "$IMAGES/Image" | grep -m1 "^Linux version"
