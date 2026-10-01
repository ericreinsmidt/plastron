# TortOS-px2

The operating system under TortOS on the GKD Pixel 2 (Rockchip RK3326S,
which Linux calls PX30S). On the Brick, TortOS runs on top of TrimUI's own
system. The Pixel 2 has no internal system to run on - the card is the whole
OS - so this builds one: as little as it takes to boot fast and run TortOS.

## Status

Phase 1: the smallest image that boots, with a root shell over the USB cable.

The kernel is kernel.org 7.1.2 with ROCKNIX's patches, config and device tree
from their 20260901 release, the one checked on the device in phase 0. The
plan is to carve that down, one patch at a time, to kernel.org plus the few
patches this chip actually needs.

The bootloader is ROCKNIX's, with U-Boot rebuilt from source by
`make bootloader` (`buildroot/board/px2/u-boot/`). Rockchip's DDR init,
miniloader and BL31 are still their prebuilt blobs. U-Boot records its own
timings in the device tree it hands Linux (bootstage), so where the
bootloader spends its time can be read on the running device under
`/proc/device-tree/bootstage`, with no serial console.

## Boot time

What's been done to make it boot fast, step by step and with measurements,
is in [docs/boot-time.md](docs/boot-time.md).

## Building

Needs Docker. Everything else - the cross-compiler included - Buildroot
builds from source inside the container.

```sh
make                # out/sdcard.img
make linux-rebuild  # just the kernel, after changing its config or patches
make bootloader     # U-Boot -> buildroot/board/px2/bootloader/u-boot-px2.bin
make shell          # a shell in the build container
```

The first build takes a while: it builds the whole toolchain. After that,
Buildroot only rebuilds what changed.

To get SSH access, put a public key in `local/authorized_keys` before
building. `local/` is not tracked.

## On the device

Write `out/sdcard.img` to a card from sector 0. With the USB cable plugged
into a Mac, the Pixel appears as a network interface:

```sh
ssh root@fe80::70:78ff:fe32:1%en10
```

(`en10` is whatever interface macOS assigned it; `networksetup
-listallhardwareports` names it "GKD Pixel 2".)

## Layout

```
buildroot/                  a Buildroot external tree (BR2_EXTERNAL)
  configs/                  tortos_px2_defconfig
  board/px2/
    linux.config            kernel config (ROCKNIX's RK3326 config)
    patches/linux/          kernel patches, numbered in the order they apply
    dts/                    the Pixel 2 device tree (ROCKNIX's)
    bootloader/             the bootloader written at sector 64: ROCKNIX's,
                            and ours with U-Boot rebuilt (u-boot-px2.bin)
    u-boot/                 U-Boot's patches, ROCKNIX's sources, our config
    boot.cmd                the U-Boot boot script
    genimage.cfg            the card layout
    rootfs-overlay/         files added to the root filesystem
docker/                     the build container
scripts/build.sh            runs Buildroot inside it
```
