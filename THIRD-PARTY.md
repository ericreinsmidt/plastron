# Third-party notices

plastron's own code (its build scripts, board files, init scripts, packages
and patches written for it) is licensed under the GNU General Public License,
version 3 or later; see `LICENSE`. It was MIT until 2026-10-25. Patches to the
kernel and U-Boot are under their GPL, as the code they change is.

The images plastron builds carry a great deal that isn't plastron's: the
Linux kernel, boot loaders, Buildroot's system and the libraries TortOS runs
on, and on the TrimUI Brick two closed parts. They keep their own licenses.
This file says what they are and where they come from, credits the projects
plastron builds on even where no license asks for it, and points to the full
package lists. A release's `TortOS-v<version>-<device>-sources.tar` carries
the license texts and sources of everything in its image.

On a card, these notices are in the `Licenses` folder, beside TortOS's and
Diatom's.

## Both devices

- **Buildroot** 2026.02.3 (GPL-2.0-or-later), https://buildroot.org: builds
  each system, its compiler and every package in it.
- **The packages in each image**, with their versions, licenses and where
  they come from: `buildroot/board/px2/third-party-packages.md` for the GKD
  Pixel 2 and `buildroot/board/brick/third-party-packages.md` for the TrimUI
  Brick, made from Buildroot's own manifest of a release build
  (`scripts/third-party.py`). Among them: glibc, BusyBox, SDL2 with
  SDL2_image and SDL2_ttf, FFmpeg, ALSA, curl, OpenSSL, SQLite, zlib, libpng,
  exfatprogs, wpa_supplicant, and on the Brick BlueZ and bluez-alsa.
- **Josefin Sans** (SIL Open Font License 1.1), by Santiago Orozco: the boot
  splash's lettering is drawn from it (`scripts/make-logo.py`).

## GKD Pixel 2

- **Linux** 7.1.2 (GPL-2.0), https://kernel.org, with patches from
  **ROCKNIX** (https://rocknix.org) for the RK3326 and its handhelds: the
  panel, the joypad, the battery, USB and the PX30S changes
  (`buildroot/board/px2/patches/linux`, the ones whose names start
  `1-` to `5-`). The rest are plastron's.
- **The device tree**, `rk3326s-gkd-pixel2.dts` (GPL-2.0-or-later or MIT),
  reconstructed from GameKiddy's own device tree for the Pixel 2 in the
  layout ROCKNIX's RK3326 boards use, on Rockchip's `rk3326.dtsi`.
- **U-Boot** v2025.10 (GPL-2.0-or-later), https://u-boot.org, built the way
  ROCKNIX builds it for the RK3326, with ROCKNIX's patch and plastron's
  (`buildroot/board/px2/u-boot`).
- **Trusted Firmware-A** at 5103554 (BSD-3-Clause),
  https://www.trustedfirmware.org: its BL31.
- **Rockchip's rkbin** at 74213af (Rockchip's binary license),
  https://github.com/rockchip-linux/rkbin: the DDR init
  (`rk3326_ddr_333MHz_v2.11.bin`) and miniloader
  (`rk3326_miniloader_v1.40.bin`), which start the Pixel 2 before U-Boot.
  Closed, and redistributed as rkbin allows. Its packing tools run only at
  build time.
- **Mesa** (MIT and others), https://mesa3d.org: OpenGL ES for the Mali GPU,
  through Panfrost.

## TrimUI Brick

- **Linux** 4.9.191 (GPL-2.0) as Allwinner made it for the A133, from
  **Creality's** Sonic Pad SDK (https://github.com/CrealityTech/sonic_pad_os
  at 7f37a7f, `lichee/linux-4.9`), less 11 closed binaries the Brick never
  builds. It carries Allwinner's drivers, **X-Powers'** drivers for the
  AXP2202 power chip, **XRadio's** XR829 Wi-Fi and Bluetooth drivers, and
  **Imagination Technologies'** GPU kernel driver (dual MIT and GPL-2.0).
- **plastron's patches** to it (`buildroot/board/brick/linux/patches`),
  which bring in mainline Linux's exFAT driver (Samsung, GPL-2.0) and the
  SDK's AXP2202 charger driver, among the Brick's own changes.
- **The device tree**, `buildroot/board/brick/dts`: **Allwinner's** A133
  device tree as it came on the Brick, decompiled and cut down to what
  plastron uses, with Allwinner's names for its parts.
- **U-Boot** at 5e3b01c (GPL-2.0-or-later), https://u-boot.org, with
  plastron's patches for the A133 and the Brick
  (`buildroot/board/brick/u-boot/patches`).
- **Trusted Firmware-A** at 5103554 (BSD-3-Clause),
  https://www.trustedfirmware.org: its BL31.
- **Two closed parts**, in the image and nowhere else, not distributed on
  their own, and not covered by plastron's license:
  - **Imagination Technologies'** PowerVR DDK 1.11@5516664 userspace
    libraries and firmware for the GE8300 GPU (OpenGL ES, EGL), under
    Imagination's terms, as Allwinner ships them for the A133.
  - **XRadio's** firmware for the XR829 Wi-Fi and Bluetooth chip, with no
    license stated.

  Both as Creality's Sonic Pad SDK has them.

## Files in this repository that aren't plastron's

```
  buildroot/board/px2/patches/linux/
                   Patches to the Linux kernel, from ROCKNIX and from
                   kernel.org, and our own. GPL-2.0, as the kernel is.

  buildroot/board/px2/dts/
                   The Pixel 2 device tree, from ROCKNIX, (c) GameKiddy and
                   Rockchip. GPL-2.0+ OR MIT, as each file states.

  buildroot/board/px2/linux.config.rocknix
                   ROCKNIX's kernel config for the RK3326, which
                   scripts/kernel-config.sh starts from.

  buildroot/board/px2/u-boot/
                   Patches and sources for U-Boot, from ROCKNIX and
                   Hardkernel, and our own. GPL-2.0+, as U-Boot is.

  buildroot/board/px2/bootloader/
                   The Pixel 2's bootloader, made by make bootloader: our
                   U-Boot (GPL-2.0+) and TF-A's BL31 (BSD-3-Clause), both
                   built from source, with Rockchip's prebuilt DDR init and
                   miniloader, redistributed unmodified under Rockchip's
                   terms (github.com/rockchip-linux/rkbin, the commit
                   scripts/build-bootloader.sh pins).

  buildroot/board/brick/linux/patches/
                   Patches to Allwinner's Linux 4.9, our own, bringing in
                   mainline Linux's exFAT driver and the SDK's AXP2202
                   charger driver. GPL-2.0, as the kernel is.

  buildroot/board/brick/dts/
                   The Brick's device tree: Allwinner's A133 device tree as
                   it came on the Brick, decompiled and cut down. GPL-2.0,
                   as the kernel is.

  buildroot/board/brick/u-boot/patches/
                   Patches to U-Boot for the A133 and the Brick, our own.
                   GPL-2.0+, as U-Boot is.

  buildroot/board/brick/bootloader/
                   The Brick's boot loader, made by make brick-bootloader:
                   our U-Boot (GPL-2.0+) and TF-A's BL31 (BSD-3-Clause),
                   both built from source.

  buildroot/package/splash/frames.bin
                   TortOS's boot animation, from TortOS. GPL-3.0-or-later.
```
