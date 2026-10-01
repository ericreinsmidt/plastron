# Bringing TortOS to the Pixel 2

The plan for getting TortOS and Diatom running on this system, worked out
from a read-through of both codebases. Nothing here is built yet.

## What has to stay true

TortOS is fast because it never starts a process to run a game: Diatom comes
up once, keeps every core mapped, and a game arrives as one line on a socket
(26 to 44 ms from `RUN` to `RUNNING` on the Brick). Coming back from a game is
a frame, because the launcher never tears down its display. The port keeps
both of those exactly. If a step would cost either one, it's the wrong step.

## What's different here

| | Brick | Pixel 2 |
|---|---|---|
| Screen | 1024x768, landscape | 640x480, but the panel is 480x640 portrait and has to be drawn rotated |
| Display | `/dev/fb0` (Diatom) and SDL's `mali` driver (TortOS) | DRM/KMS only; one program owns the display at a time ("DRM master") |
| GPU | Mali, vendor driver | Mali-G31, Panfrost (Mesa) |
| CPU | 4x Cortex-A53, 2.0 GHz | 4x Cortex-A35, 1.3 GHz |
| Buttons | SDL joystick from TrimUI's input daemon, hat d-pad, F1/F2 | kernel devices by name, d-pad as buttons, a FUNCTION key, no F1/F2 |
| Volume | inverted 0-63 control plus HpSpeaker switch | `Master` 0-255; `jackswitch` picks speaker or headphones |
| Brightness | `/dev/disp` ioctls | `/sys/class/backlight/backlight` |
| Mute switch, LEDs, rumble, Wi-Fi, Bluetooth | yes | none |
| Toolchain | Debian bullseye, libraries pulled off a Brick over adb | Buildroot's toolchain and libraries |

The two codebases are well prepared for this. Diatom has a real port layer
(`port/brick.c` behind `include/diatom_port.h`), designed from the start for a
rotated panel. TortOS keeps most device code in `src/platform.c`, and its
layout is 4:3 like this screen.

## The hard part: sharing the display

On the Brick, both programs stay alive and take turns presenting; neither
owns the screen. With DRM, only the program holding "master" can put a
picture up. The plan is to pass master back and forth at the moments the
protocol already marks: TortOS drops it before `RUN` and `RESUME`, Diatom
takes it to present and drops it when it stops (before `PAUSED` and `EXIT`),
and TortOS takes it back. The protocol itself doesn't change.

This is already half proven here: `brrr` hands the display to `kmscube` this
way with no black frame. The other half, handing it back to an SDL program
that has been drawing all along, is the first thing to test.

Diatom draws with the GPU here, unlike on the Brick: it hands each frame to
the GPU as a small texture, and the GPU scales and rotates it onto the panel.
The CPU route would eat most of what the slower CPU has left (measured
below). TortOS rotates on the GPU too: everything draws into a 640x480
texture, turned onto the panel at present time (measured: full 60 fps).

## Order of work

Riskiest first, so a wrong assumption costs a day and not a month.

### 1. Two measurements before anything else (done, 2026-10-01)

**The A35 keeps up.** Each core timed with nothing drawn, 3,600 frames from a
cold start (title screens and demo play, so not quite the Brick's gameplay
states). Roughly half the Brick's speed, as expected:

| core | game | p50 | p95 | worst | Brick p50 (gameplay) |
|---|---|---|---|---|---|
| snes9x2010 | Donkey Kong Country | 9.4 ms | 10.5 ms | 11.3 ms | 4.2 ms |
| mednafen_ngp | Metal Slug 1st Mission | 7.6 | 8.2 | 8.9 | 3.4 |
| genesis_plus_gx | Gunstar Heroes | 5.3 | 6.1 | 8.0 | 3.1 |
| mgba | Golden Sun | 5.3 | 7.1 | 13.8 | 2.9 |
| fceumm | Contra | 4.2 | 4.4 | 5.3 | 2.2 |
| mednafen_pce_fast | R-Type | 2.9 | 3.0 | 3.6 | 1.5 (Rondo of Blood) |

**But drawing on the CPU doesn't fit beside SNES.** Scaling a 256x224 frame to
640x480 and rotating it, nearest-neighbor:

| | per frame |
|---|---|
| CPU, writing in the panel's order | 7.7 ms |
| CPU, writing in the game's order | 12.5 ms |
| GPU (through SDL), CPU time spent | 2.6 ms |

SNES at 10.5 ms plus 7.7 ms of drawing is past the 16.7 ms a frame has, so
Diatom draws with the GPU on the Pixel. That also makes sharp-bilinear a free
shader instead of extra CPU work, and leaves room for fast forward.

**The display goes back and forth cleanly.** A stand-in for TortOS (SDL, GPU)
and one for Diatom (buffers straight to the display) swapped the screen 100
times by passing DRM master: no black frames, no glitches (watched on the
device). Handing over took 2 refreshes (33 ms) one way and 1 (17 ms) back.
Things the real code has to do, learned the hard way:

- Use the same pixel format as SDL (ARGB8888): a flip can't change it.
- The previous owner's last frame may still be queued, so the first flip can
  come back busy: wait a refresh and retry. Diatom's game load (26 to 44 ms)
  covers that wait.
- Opening the display device while nobody owns it makes you the owner, and a
  memory mapping of its buffers keeps that alive after closing it. Drop
  ownership on purpose.
- SDL shows a mouse pointer on DRM unless told not to.

### 2. The base system grows what TortOS needs

- A FAT or exFAT partition filling the rest of the card, mounted at
  `/mnt/SDCARD`, so ROMs and saves can be copied on from a Mac (there's no
  Wi-Fi to do it over).
- Libraries TortOS and Diatom load: SDL2_image, SDL2_ttf, sqlite, zlib,
  libstdc++ (for C++ cores), FFmpeg 6.1 for Muse (Buildroot has 6.1.5, the
  same series as the headers TortOS pins).
- ALSA mixing (dmix), so Diatom and Muse can both have sound open.
- TortOS and Diatom built as packages here, from their own repos, with this
  system's toolchain.

### 3. Diatom on the Pixel 2

A new `port/pixel2.c` next to `port/brick.c`: GBM and OpenGL ES, with the
frame uploaded as a texture and scaled and rotated in one draw, swaps on
their own thread so presenting never blocks the frame loop, buttons read
straight from the kernel by device name,
`Master` for volume, sysfs for brightness. Diatom's portable code doesn't
change. Then measure what it costs to present a frame, as was done on the
Brick.

### 4. TortOS on the Pixel 2

- The device code in `platform.c` gets a Pixel 2 version: buttons by device
  name, `Master`, sysfs brightness and battery, no mute switch, no LEDs.
- Drawing goes through one 640x480 target that's rotated at present. Layout
  stays in 1024x768 terms and is scaled, at first; text drawn at full size
  and scaled down will look soft, so fonts get sized for this screen after.
- Wi-Fi, Bluetooth, Over The Hare and the online features are hidden when
  there's no radio.
- New button combinations for what F1/F2 did (brightness, the Muse pocket
  lock), probably FUNCTION plus volume.
- The display handover from step 1, around `RUN`, `PAUSED` and `EXIT`.

### 5. Boot

`init` starts the splash, then Diatom and TortOS instead of the cube. TortOS
takes the display from the splash the way `kmscube` does now. The Brick's
2.4 s boot video hides a startup that takes about a second; here the whole
boot takes about 2 s, so the first build uses a still picture and the timing
decides whether a video earns its place. Then measure power press to shelf.

### 6. Then 4b

With TortOS running, every driver it touches is known, so the kernel can be
carved down to what's actually used, with the buttons moved to the kernel's
own `gpio-keys` driver on the way (the code from step 3 and 4 finds them by
name, so that move costs nothing).

## Where the work lives

- TortOS: branch `gkd-pixel-2` (this port's worktree).
- Diatom: a `gkd-pixel-2` branch in `~/Developer/diatom`, kept off main the
  same way.
- This repo: the system, plus the packages that build TortOS and Diatom into
  it.

## Kept reusable

This repo is the Pixel 2 system first and TortOS's home second. Everything
TortOS-specific stays in its own packages and defconfig, so the base system
(bootloader, kernel, device tree, display, sound, buttons, power) builds and
boots without it, and someone else could put their own frontend on top.
