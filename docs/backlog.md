# Backlog

Ideas for later. Not planned yet, just written down so they don't get lost.

## Over The Hare, over the USB cable

On the Brick, Over The Hare moves files to the device over Wi-Fi. The Pixel 2
has no Wi-Fi or Bluetooth, but it can already look like a network adapter
over its USB cable (that's how it's worked on in development). Something like
Over The Hare could run over that link: plug the Pixel into a computer and
open a page in the browser to add games, saves and audiobooks.

Much further down the line, once TortOS runs on the Pixel.

## Offer our kernel fixes upstream

Two things found while speeding up the boot would help everyone running a
Pixel 2, not just us:

- **The screen's waits.** ROCKNIX's Pixel 2 device tree writes the panel's
  power-up waits as ordinary numbers, but the driver reads them as
  hexadecimal, so the screen takes 640 ms to power up where 280 were meant
  (boot-time.md, step 7). A one-file fix to their device tree.
- **The display starting in the background.** Our kernel patch 6 lets the
  display driver power the screen up while the rest of the boot carries on,
  instead of everything waiting for it (boot-time.md, step 9). This one is a
  bigger ask: it would go to ROCKNIX first, and maybe to mainline after.

ROCKNIX takes changes as pull requests on GitHub.
