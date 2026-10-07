# Backlog

Ideas for later. Not planned yet, just written down so they don't get lost,
except the first section, which is the gate for the next release.

## Before TortOS v1.4.0 (a release gate)

Decided with Eric 2026-10-06. **v1.4.0 does not ship until every box below is
ticked.** It spans TortOS, plastron and a new installer, and lives here
because this is the one backlog.

- [x] **A new installer.** Written from scratch under Eric's own license, not
  the fork of spruceOS's installer: a Tauri app (an HTML and CSS front end on
  a Rust core), in TortOS's own look, built on the Mac for all three systems
  and pushed to GitHub by hand, with no workflows. It installs and updates the
  Brick, installs the Pixel fresh and updates its system without touching the
  games partition, and reads what is on a card to offer Update or Fresh
  install and to refuse a card from the other device. No box art: a fresh card
  has no games yet, and anyone updating already gets art on the Brick or
  through Down To The Wire. On Linux a .deb and an .rpm, no AppImage. The
  fork's `pixel-system-update` branch proved the update on macOS, Windows and
  Linux and is the reference. Built 2026-10-07: TortOS Installer 2.0.0, in
  `~/Developer/TortOS-Installer`, tested on real cards for both devices; it
  goes on GitHub with v1.4.0 (the last box).
- [x] **Down To The Wire on Windows.** The cable speaks NCM now, with
  Microsoft's descriptor naming Windows' own driver; tested from a Mac,
  Windows 11 and Linux, 2026-10-06 and 07 (the first done entry below).
- [x] **Commit what is done and tested.** TortOS: the payload writes
  `TortOS/VERSION` (the README's paragraph on updating waits for the new
  installer, in the README item below). plastron:
  `TortOS/` copied over when the image's TortOS is newer, the version passed
  to the payload and written into the startup script, and boot-time.md step
  21.
- [ ] **The README for the new picture.** The Pixel's section points to the
  new installer, "the TortOS Installer can fetch box art" goes, Wire's
  "Windows not yet" changes, and the v1.3.0 file names move on.
- [ ] **TortOS's version to 1.4.0.**
- [ ] **A release build, tested.** The update from v1.3.0 on a v1.3.0 card
  with games on it, from a Mac and from Windows; a fresh install on a blank
  card; and the Brick, which shares Muse's tidying of the Music folder and
  the covers in Over The Hare's lists.
- [ ] **The old installer.** On v1.4.0's release day, all at once, so the
  README's links never land on an empty repository: rename TortOS-Installer
  to TortOS-Installer-spruce, create tortos-installer and publish 2.0.0, then
  archive the old one. Its v1.1.0 never asks for updates, so it needs no last
  release. Eric deletes its two pre-releases, `beta-pixel-system-update` and
  `beta-main`.

Not part of the gate, still open from v1.3.0: tortos.games says Brick only,
and the legal-info lacks license files for plastron's own jackswitch,
powerkey and splash.

## A color matrix for the Pixel's panel (games from v1.4.0, the rest later)

Out of the v1.4.0 gate, Eric 2026-10-07: he is ordering a colorimeter, and
the full fix goes into a later release. What v1.4.0 has: games through the
matrix tuned by eye below, Diatom reading /etc/panel-color (blue gains a
tenth of green); the shelf without it. Beside the Brick the Pixel shows greens yellow
and loses purples and magentas (the glow behind the Master System card).
Tested 2026-10-06, live against the Brick Hammer, two scenes and two filmed
sweeps: the splash's curve per channel can't fix both, because the cause is
the panel's own primaries. Its green is yellower (no blue in it where the
Brick's has some), and red has to stay strong in purple but out of green. A
curve only sees one channel at a time, so less red brought the purple back
and turned grass yellow, and more blue tinted whites without reaching the
greens. The splash's curve stays (red and green 1.5, blue 1.0), the best a
curve does.

- **With the colorimeter:** solid patches on each screen (red, green, blue,
  white, greys; on the Pixel the gamma table itself can fill the screen with
  one color), read with ArgyllCMS on the Mac, and the matrix calculated from
  the readings rather than guessed, then checked by eye. It could match the
  Brick, or sRGB.
- **By eye first, 2026-10-07,** in a Diatom test build that read the matrix
  from a file while a game ran (Super Mario World, the forest, against the
  Brick Hammer, both at full brightness): adding blue in proportion to green,
  in linear light, took the yellow out of the greens, and 0.10 beat 0.15
  (0.15 went a little past the Brick). Pulling red out of greens changed
  nothing, as SNES greens carry no red. Easing green's curve to 1.3 made them
  brighter but no closer. The greens stay darker and less vibrant than the
  Brick's: that is the panel's own limit, which no matrix can lift. The
  present step took 1.9 to 2.0 ms a frame with the matrix; without it was
  not measured.
- **The shelf, 2026-10-07:** a prototype draws TortOS's turned copy through
  the same matrix (TortOS branch panel-matrix-shelf; SDL keeps red and blue
  swapped in that texture, so the shader reads .bgr). By eye the shelf was
  no clearer with it. Its trouble is red: purples (the GBA's body, the
  glow behind the Master System card) lose theirs to the curve's red cut.
  Easing red to 1.2 brought the glow back but tinted the dark parts red;
  an eased curve (1.5 in the darks, near none at the top) lost to 1.5; and
  the shelf with no correction at all looked better to Eric, if not right,
  while games without it showed greens yellow again. So the curve stays at
  1.5 for now, and red is the first thing to measure.
- **Where it goes:** a 3x3 matrix in the final drawing step of Diatom (its
  own GPU shaders in port/pixel2.c, a line each) and TortOS (its turned copy
  to the panel in src/device/pixel2.c, today an SDL_RenderCopyEx, to become
  a direct GPU draw), read from one file on the system partition so the two
  can't disagree; the splash's frames get it when they are built.

## Over The Hare, over the USB cable (done, 2026-10-05, as Down To The Wire)

Eric's idea: Over The Hare, which moves files to the Brick over Wi-Fi, over
the Pixel's USB cable instead. Done, and tested from a Mac: files both ways,
and Download logs.

- **The name is Down To The Wire**, on the Pixel only; the Brick keeps Over
  The Hare. Only what people see changed (the row, the screen's title, the
  web page's title); the code stays `hare`, one server for both.
- **10.42.0.1 on the cable**, and BusyBox's udhcpd giving the computer an
  address beside it, with no router and no DNS so a computer never sends its
  internet traffic this way (S40usbgadget, /etc/udhcpd.conf). About 6.5 ms of
  boot (boot-time.md, step 20).
- **The screen always shows 10.42.0.1.** It doesn't try to tell whether a
  computer is on the other end: the USB controller went on saying
  "configured" with the cable pulled, and the screen's browser row already
  says whether a browser is there.
- **BusyBox's tar gained -z**, which Download logs needed.
- **SSH stays shut** in a release image: root has no password and dropbear
  refuses an empty one, so without the development key nobody gets in
  (checked over the cable 2026-10-05).

It sits beside a USB-C DAC (below) without a fight: the ID pin picks the role,
device for a computer's cable, host for a DAC.

**Windows, done 2026-10-07.** The cable spoke ECM, which macOS and Linux
understand and Windows has no driver for. It speaks NCM now (the kernel's
CONFIG_USB_CONFIGFS_NCM, and S40usbgadget), which all three have a driver
for, with Microsoft's OS descriptor marking it WINNCM so Windows loads its
own without being asked; the device number moved to 0x0201, so a computer
that met the ECM Pixel looks again. Tested over the cable:

- **macOS:** Apple's own NCM driver; files both ways, logs.
- **Windows 11:** "UsbNcm Host Device", nothing to install; files both
  ways, logs, and the page's box art (11 games without a cover down to 1).
- **Linux** (Ubuntu 24.04 in a VM, the Pixel passed through): cdc_ncm,
  10.42.0.2 from the Pixel, files both ways, logs. A desktop install has
  the driver and brings the link up by itself; Ubuntu's minimal cloud image
  needed linux-modules-extra and a DHCP setting.
- **Unexplained, once:** after a move from the Mac to Windows the Pixel
  stopped presenting itself to either until it restarted (2026-10-06). Six
  moves after that, one straight after loaded transfers, all came back. If
  it happens again, log the role switch, the extcon cables and the UDC's
  state to the card every half second, and the kernel log beside them.

## The LEDs on the side

Five LEDs, battery0 to battery4 in the device tree: GPIO1_B2 and B4 to B7,
plain on/off (max_brightness 1), driven only by the SoC. Nothing in plastron
or TortOS sets them, so they are off all the time, which already costs no
battery. The names suggest a five-step battery gauge, which is presumably what
GKD's system used them for.

What could drive them, all already in our kernel (checked 2026-10-05):

- **Charging.** The kernel's battery-charging, battery-full and
  battery-charging-blink-full-solid triggers, and rk817-charger-online. A
  trigger set once at boot, and the kernel does the rest.
- **A battery gauge.** Five steps of 20%, shown by TortOS or a small daemon.
  Better shown briefly (on a button, or at power on) than all the time.
- **Blinking**, by the timer and heartbeat triggers, for something like a low
  battery warning.

Dimming isn't possible in hardware: the pins are plain GPIO, not PWM. The
kernel could switch them fast enough to look dimmer (a software PWM), but
waking the CPU a hundred times a second would likely cost more battery than
the LEDs. Open: what Eric wants them to say, if anything; how much current
one lit LED draws (measure, as the backlight was).

## Offer our kernel fixes upstream

Three things found on the way would help everyone running a Pixel 2, not
just us:

- **The screen's waits.** ROCKNIX's Pixel 2 device tree writes the panel's
  power-up waits as ordinary numbers, but the driver reads them as
  hexadecimal, so the screen takes 640 ms to power up where 280 were meant
  (boot-time.md, step 7). A one-file fix to their device tree.
- **The display starting in the background.** Our kernel patch 6 lets the
  display driver power the screen up while the rest of the boot carries on,
  instead of everything waiting for it (boot-time.md, step 9). This one is a
  bigger ask: it would go to ROCKNIX first, and maybe to mainline after.
- **The PX30's gamma table.** Our kernel patch 7 lets mainline use the
  display controller's gamma table on the PX30 (three lines, after the
  RK3506's), and the splash loads a correction for the Pixel 2's panel, whose
  red and green come out too strong (others had noticed the colors on the
  stock system too). The patch could go to mainline; the curve, red and green
  at 1.5, could go to ROCKNIX for whatever loads it there.

ROCKNIX takes changes as pull requests on GitHub.

## Wi-Fi or Bluetooth from a USB dongle

The Pixel 2 has no radio of its own, but a USB Wi-Fi or Bluetooth dongle is
known to work on it. TortOS asks the device file whether it has either radio
(plat_has_wifi, plat_has_bluetooth) and hides the rows that need one when it
doesn't. The Pixel's answers could check for an adapter instead of always
saying no, and the kernel would need the dongle's driver. Waiting on a dongle
to test with.

## Sound through a USB-C DAC (done, 2026-10-05)

Eric's idea (2026-10-04): headphones through a USB-C DAC, beside the speaker
and the headphone jack. Done, and tested with Apple's USB-C to headphone jack
adapter, in Muse and in games:

- **The port is a host while a DAC is in.** usbrole follows the ID pin: host
  while something plugged in wants power, a device for a computer or a
  charger otherwise, so the port never powers into one (ROCKNIX's warning).
  The kernel has USB audio and nothing else on the host side; about 22 ms of
  boot (boot-time.md, step 19).
- **The sound goes there.** USB is a fourth place in TortOS's Audio Output,
  ahead of the jack when both are in, for Muse and diatom both, mixed like the
  speaker so both can play at once (asound.conf's pcm.usb).
- **One volume for every DAC.** A software volume on the RK817's card, which
  TortOS and diatom write with every level; usbrole sets the DAC's own to full
  when it appears. The mix is 24-bit, so turning it down loses none of the
  16-bit sound.

Not on the Brick: its port has no ID pin to tell a DAC from a charger, and
switching it to host by hand risks powering into one.

The host side would also take a USB Wi-Fi or Bluetooth dongle now (above),
given the dongle's driver.
