# TortOS-px2

The operating system under TortOS on the GKD Pixel 2 (Rockchip RK3326S,
which Linux calls PX30S). On the Brick, TortOS runs on top of TrimUI's own
system. The Pixel 2 has no internal system to run on - the card is the whole
OS - so this builds one: as little as it takes to boot fast and run TortOS.

## Status

Phase 2: the hardware works on our own system (display with Panfrost, sound
with headphone switching, all buttons, power, brightness, battery), and a
picture is on screen about 2.2 s after reset. Next is TortOS itself; the plan
is in [docs/tortos-plan.md](docs/tortos-plan.md).

The kernel is kernel.org 7.1.2 with ROCKNIX's patches, config and device tree
from their 20260901 release, the one checked on the device in phase 0, with
the config cut down to what the Pixel 2 uses. The plan is to carve the
patches down too, one at a time, to kernel.org plus the few this chip
actually needs.

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
make                # out/sdcard.img: TortOS on the base system
make base           # out/sdcard-base.img: the base system alone
make linux-rebuild  # just the kernel, after changing its config or patches
make bootloader     # U-Boot -> buildroot/board/px2/bootloader/u-boot-px2.bin
make shell          # a shell in the build container
```

The first build takes a while: it builds the whole toolchain. After that,
Buildroot only rebuilds what changed.

To get SSH access, put a public key in `local/authorized_keys` before
building. `local/` is not tracked.

## On the device

Write `out/sdcard.img` to a card from sector 0. The first boot adds an exFAT
partition over the rest of the card, for games and saves, which a Mac or PC
can read and write (labeled TORTOS, or PIXEL2 on the base image). On the
device it's mounted at `/mnt/SDCARD`.

With the USB cable plugged into a Mac, the Pixel appears as a network
interface:

```sh
ssh root@fe80::70:78ff:fe32:1%en10
```

(`en10` is whatever interface macOS assigned it; `networksetup
-listallhardwareports` names it "GKD Pixel 2".)

## Layout

```
buildroot/                  a Buildroot external tree (BR2_EXTERNAL)
  configs/px2_defconfig     the base Pixel 2 system: boots, display, sound,
                            buttons, power, nothing TortOS-specific
  board/tortos/             TortOS on top: tortos.config (merged into the
                            base config) and its rootfs overlay
  package/                  our packages (splash, Panfrost, jackswitch, ...)
  board/px2/
    linux.config            kernel config, derived from ROCKNIX's RK3326
                            one by scripts/kernel-config.sh
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
