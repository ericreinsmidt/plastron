# Boot time log

Everything done to make the GKD Pixel 2 boot faster, in order, with what it
measured before and after. Kept up to date as we go.

## Where it stands

From the moment the chip comes out of reset:

| | Time |
|---|---|
| Kernel starts | 1.33 s |
| **Picture on screen** (the boot animation starts) | **about 2.2 s** |
| Startup scripts done | about 2.5 s |
| **TortOS's shelf on screen**, ready to use | **about 4.0 s** |

Add the power button on top. The power chip only switches on once the button
has been held for a moment, about 0.7 s into the press (measured from a
video: press, then the picture about 2.9 s later). It starts while the button
is still down, not on release.

| | Time |
|---|---|
| **Power button pressed to picture on screen** | **about 2.9 s** |
| **Power button pressed to TortOS's shelf** | **about 4.7 s** |

For comparison, GKD's own system took about 16 s just from the kernel
starting to its menu program running, and official ROCKNIX took 33 s to its
menu.

Where the 2.2 s goes now:

| Step | Time | Whose |
|---|---|---|
| Rockchip's memory setup and first loader | 0.65 s | Rockchip's closed blobs |
| U-Boot, the bootloader | 0.11 s | ours |
| U-Boot reading the 12.5 MB kernel off the card | 0.55 s | ours |
| Kernel, until the picture | 0.87 s | ours |

## How it's measured

Nothing here uses a serial console (that would mean soldering), so:

- **The bootloader** writes its own timeline into the device tree it hands
  Linux (U-Boot's "bootstage"), readable afterwards on the running device
  under `/proc/device-tree/bootstage`. Its clock starts at reset.
- **The kernel** stamps every log line with the time since it started
  (`dmesg`). For a full breakdown, booting once with `initcall_debug` times
  every driver.
- **The picture:** the splash (`brrr` until 2026-10-01) logs `splash: panel
  lit at ... s` to the kernel log the moment its picture is on screen.
- **Startup scripts:** the last one writes the time to `/tmp/boot-done`.
- **Whole reboots** are timed from the Mac: from sending `reboot` until the
  Pixel shows up on USB again.
- **The power button,** once, from a phone video.

## What we did

### 0. The starting point

Our first own system booted, but slowly: about **7.5 s** from pressing power
to the login prompt, measured from a video. About 4 s of that passed before
the kernel even started, all in the bootloader.

### 1. The bootloader stopped waiting a second

U-Boot (ROCKNIX's build) waited 1 second at every boot for someone to press a
key on the serial console, which nobody can reach on this device. We build
our own U-Boot now, from the same source, with no wait.

**Saved about 1.2 s** per boot (reboots went from 9.8 to 8.6 s).

### 2. The kernel loads where it can run

U-Boot loaded the kernel at an address the kernel can't run from, then copied
all 21 MB of it somewhere else before starting it. Now it loads it in the
right place to begin with.

**Saved 229 ms** (the copy took 245 ms, now 16).

### 3. The bootloader turned its caches on

U-Boot ran its first steps with the CPU's caches switched off, so every bit of
memory it touched went the slow way. Found by having U-Boot record the CPU's
settings in its timeline: the caches were off, and the CPU speed was fine.
Now it turns the caches on first thing.

**Saved about 625 ms** (those first steps took 706 ms, now 80). The kernel
starts 1.73 s after reset instead of 2.35.

### 4. The kernel was cut down to this device

ROCKNIX's kernel is built for dozens of handhelds: other chips' clock
drivers, other screens, Wi-Fi, Bluetooth, USB gadgets of all kinds, network
filesystems, and 306 separately loadable modules. We kept what the Pixel 2
actually uses and dropped the rest, and nothing is a module anymore.

The kernel went from **21.4 MB to 15.0 MB**, so U-Boot reads it faster
(918 ms to 696), and it starts up faster too (2.26 s to reach the first
program instead of 3.12).

**Reset to startup done: 5.28 s to 4.36 s.** And the buttons started working
on our system for the first time: their driver was one of ROCKNIX's modules,
which our system never loaded, so it's now built in.

### 5. The rumble motor is held off without a delay

With its driver gone, the rumble motor ran from power-on. ROCKNIX's driver
stopped it by fading it out over 250 ms during boot. Instead, the pin is held
low from the first moment the kernel sets up its pins.

**No buzz, and no 250 ms.**

### 6. The kernel stopped waiting for the screen

The kernel lit the panel itself during boot, to show its own text console,
and everything else in the boot waited for the screen to finish powering up:
1.19 s. We turned that off, along with two smaller things:

- Every kernel message was also being sent out the serial port, to nobody.
- A random number generator ran a 145 ms self-test, for features this device
  doesn't use.

**The kernel reaches its first program in 0.7 to 0.8 s instead of 2.26.
Reset to startup done: about 2.7 s.**

The screen now stays dark until a program lights it, so we added `brrr`,
which shows "TortOS go brrr" until TortOS has its own boot animation. The
picture appeared 2.1 s after the kernel started, since the screen's power-up
now happened after the kernel was done.

### 7. The screen's waits were 2.5 times too long

The screen powers up by following a list of steps, some with a wait after
them. The driver reads those waits as hexadecimal, but the Pixel 2's settings
(ROCKNIX's) were written as ordinary numbers, so "wait 100" waited 256 ms,
"wait 120" waited 288, and so on: 640 ms of waiting where 280 were meant.
Found by logging the time of every step; the gaps matched the hexadecimal
values exactly. We wrote the waits the way the driver reads them.

`brrr` was also slow to draw its picture (a quarter of a second), because it
drew pixel by pixel straight into the screen's memory, which is slow to write
to. It now draws in ordinary memory and copies the result over in one go.

**Lighting the screen: 1,070 ms to 688. Reset to picture: about 3.7 s to
3.0.**

### 8. The picture comes first

The first program, `init`, did a few chores before starting anything,
including remounting the system drive, which was already mounted the right
way: 90 ms. `brrr` now starts before all of that, and the remount is gone.

**Picture 1.54 s after the kernel starts, down to 1.49.**

### 9. The screen powers up in the background

The screen's power-up takes about 0.7 s however it's done. Rather than wait
for it at the end, the kernel now starts it early, around 0.2 s in, and lets
the rest of the boot carry on at the same time. By the time `brrr` runs, the
screen is already on, and showing the picture takes 3 ms.

The first try did this through the kernel's text console, which held a lock
the whole time that the first program also needs, so the boot got 0.3 s
slower overall. The version that stuck drops the text console and has the
display driver power the screen up directly.

**Picture 1.49 s after the kernel starts, down to 0.92. Reset to picture:
about 2.4 s.** The first program starts a little later than before (0.76 to
0.80 s instead of 0.70), which is still being looked into.

### 10. The kernel was cut down again

A second pass over what was still big in the kernel, and what it was for:

- A kernel message buffer sized for a server: its index alone was 352 KB.
- USB's host side and every kind of USB gadget, when all the Pixel 2 does
  over USB (in development) is look like a network adapter.
- Unpacking code for a startup ramdisk we don't have, and compression code
  for memory tricks we don't use.
- Virtual terminals and the serial port driver, now that nothing shows a
  console.
- Group controls for services, desktop scheduling tweaks, suspend and
  hibernate, hardware tracing, and a few unused features.

The kernel went from **15.0 MB to 12.5 MB**, so U-Boot reads it in 0.56 s
instead of 0.70.

**The kernel starts 1.38 s after reset instead of 1.47, and the picture is on
screen about 2.26 s after reset.**

Bonus: with USB device-only, plugging the cable in after the Pixel has booted
now works. Before, it only connected if plugged in at boot.

### 11. A smaller bootloader

U-Boot still carried networking, USB, display support and SPI flash, none of
which it uses here, and it read its saved settings off the card at every boot
only to find none. Rockchip's first loader has to read U-Boot off the card
before it can run, so a smaller one should load sooner. It went from 752 KB
to 540 KB.

**Saved about 40 ms**: 21 ms in loading it, the rest in its own startup. Less
than hoped, but it showed something useful: Rockchip's loader reads fast
(about 10 MB/s), so most of the 0.65 s before U-Boot is Rockchip's own memory
setup, which replacing their loader wouldn't change.

### 12. Shutting down cleanly

A boot suddenly took 0.4 s longer, all of it in mounting the system drive:
it was repairing itself first, because it hadn't been closed properly at the
last shutdown. The shutdown steps ran before the remaining programs were
stopped, and a program still writing to the drive (the spinning cube demo,
through the graphics driver's cache) kept it from closing. Now everything
else is stopped first.

**Every boot after a reboot or shutdown skips that 0.4 s repair.** (A power
cut or a dead battery would still cause one, which a read-only system drive
would rule out.)

### 13. A partition for games (a cost, not a saving)

The card now gets a third partition, exFAT, so games and saves can be copied
on from a Mac or PC. The first boot creates it over the rest of the card and
formats it (half a second, once). Every boot after that mounts it.

**Mounting it costs 30 to 44 ms**, measured inside the boot with a timestamp
either side. It runs after the picture is up, so the picture doesn't move,
but TortOS will need it before it can list any games.

### 14. TortOS itself, and its boot animation (the new finish line)

Until now the boot ended on a picture. Now it ends on TortOS's shelf, which
is what the boot is for, so the number that matters moved: TortOS starts from
the card once the startup scripts have mounted it, loads its library and its
cards, and puts the shelf up.

The splash became TortOS's own boot animation (the turtle walks across,
dashes off, and leaves the logo), played from frames prepared ahead of time,
so it lights the panel just as fast as the old picture did. TortOS never
waits for it: it starts alongside, and takes the screen the moment its shelf
is ready. On the boots measured so far TortOS was ready a little after the
animation finished, so the whole turtle shows and the logo holds for a beat.

Measured from the kernel's log on 2026-10-01, after the kernel starts:

| | Time |
|---|---|
| Panel lit, animation starts | 0.88 s |
| Animation reaches the logo | 2.43 s |
| TortOS's shelf on screen | 2.69 s |

**Reset to shelf: about 4.0 s. Power button to shelf: about 4.7 s.** Most of
the 1.8 s between the panel lighting and the shelf is TortOS, started only
once the startup scripts finish (about 1.3 s after the kernel): 1.05 s of its
own startup (the library scan, the display, the font, the cards), then a
350 ms pause it takes to swallow stray button presses from the boot before
drawing anything. That is where to look next.

Two things found on the way, both filmed: SDL's first frame after taking the
screen over never reached it, so the shelf only appeared at the launcher's
once-a-second backstop redraw - a second of black. TortOS now shows its first
frame twice. And the splash, left running, came back on screen as TortOS
exited at power-off; it now ends once TortOS has the screen.

## Graphics start-up

Not boot time exactly, but the same question for TortOS: how long until it
can draw. Measured with `sdltest` (SDL2 drawing straight to the display with
OpenGL ES on Panfrost, as TortOS will), with the screen already on:

| | First launch | After that (shader cache warm) |
|---|---|---|
| SDL video start | 26 ms | 29 ms |
| Window | 44 ms | 44 ms |
| GL renderer | 128 ms | 76 ms |
| First frame on screen | 76 ms | 46 ms |
| **Start to picture** | **273 ms** | **193 ms** |

Presenting a 640x480 landscape frame rotated onto the portrait panel runs at
the panel's full 60 fps. On the Brick, SDL and GL alone took about 620 ms.

## Tried, and didn't help

- **A compressed kernel.** Half the size, so U-Boot read it in 364 ms instead
  of 696. But unpacking it took 727 ms, because U-Boot runs the CPU at only
  400 MHz. Worth trying again if U-Boot ever runs the CPU faster.
- **Disabling the CPU's idle states, and the kernel's tickless mode.** Tried
  while hunting the screen's slow waits, on the theory that sleeping CPUs
  woke up late. Neither changed anything; the real cause was the
  hexadecimal mix-up in step 7.

## Ideas not tried yet

- **Run the CPU faster in U-Boot.** It runs at 400 MHz until the kernel takes
  over. Faster would help everything before the kernel, and could make a
  compressed kernel pay off. Needs the CPU's voltage raised first, carefully.
- **A smaller kernel still.** U-Boot reads it at about 45 ms per MB. Starting
  over from an empty kernel config and adding only what the Pixel 2 uses
  should shrink it a lot. Networking (about 1.9 MB) is only there for working
  on it over USB, so a release build could leave it out.
- **Replace Rockchip's closed first-stage loader** with U-Boot's own, which
  could also load the kernel directly. Less promising than it looked: step 11
  showed most of that 0.65 s is Rockchip's memory setup, which would stay.
- **A read-only system drive.** It would mount in a few milliseconds, and it
  can't be left needing repair (step 12) by pulling the power or a dead
  battery.
- **A shorter press to power on.** The power chip (RK817) waits about 0.7 s
  of holding before it switches on, which comes straight off the time from
  pressing power. It may be a setting in the chip.
- **The screen's own waits, against the datasheet.** Several are far longer
  than this kind of panel controller needs. Only worth it if the screen turns
  out to be what TortOS waits for: right now the screen and the software
  finish at about the same time, and TortOS will add its own startup to the
  software side.
- **Mount the games partition alongside the rest of startup** instead of in
  line with it. Nothing but TortOS's game list needs it, so the 30 to 44 ms
  could overlap with other work instead of adding to it.
- **Fewer startup scripts.** TortOS will start directly instead of after a
  list of general-purpose services.
