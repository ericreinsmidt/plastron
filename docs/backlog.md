# Backlog

Ideas for later. Not planned yet, just written down so they don't get lost.

## Over The Hare, over the USB cable

On the Brick, Over The Hare moves files to the device over Wi-Fi. The Pixel 2
has no Wi-Fi or Bluetooth, but it can already look like a network adapter
over its USB cable (that's how it's worked on in development). Something like
Over The Hare could run over that link: plug the Pixel into a computer and
open a page in the browser to add games, saves and audiobooks.

The USB networking is already in every image, release included (S40usbgadget,
the same link SSH runs over in development). What it would still take:

- **An address a browser can open.** The Pixel only has an IPv6 link-local
  address on the cable (fe80::...%en10), which browsers won't take as a URL.
  A plain IPv4 address on usb0, and BusyBox's udhcpd handing the computer one,
  would let the PIN screen say something like http://10.42.0.1.
- **Windows.** The gadget speaks ECM, which macOS and Linux understand and
  Windows doesn't without a driver. NCM works on all three: a kernel option
  and a line in S40usbgadget.
- **TortOS showing the row.** Over The Hare is hidden where there's no Wi-Fi;
  on the Pixel it would show, waiting for the cable.

It sits beside a USB-C DAC (below) without a fight: the ID pin picks the role,
device for a computer's cable, host for a DAC.

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
