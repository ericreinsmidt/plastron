# Backlog

Ideas for later. Not planned yet, just written down so they don't get lost.

## Over The Hare, over the USB cable (done, 2026-10-05, as Down to the Wire)

Eric's idea: Over The Hare, which moves files to the Brick over Wi-Fi, over
the Pixel's USB cable instead. Done, and tested from a Mac: files both ways,
and Download logs.

- **The name is Down to the Wire**, on the Pixel only; the Brick keeps Over
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

Still to do: **Windows.** The cable speaks ECM, which macOS and Linux
understand and Windows doesn't without a driver. NCM works on all three: a
kernel option and a line in S40usbgadget. Needs a Windows PC to test.

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
