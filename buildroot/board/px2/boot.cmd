# U-Boot boot script. Our U-Boot (ROCKNIX's config) only looks for boot.scr
# ("bootmeth order script"), so this is the whole boot menu.
#
# The kernel goes at 0x02200000, not U-Boot's default kernel_addr_r of
# 0x02080000: the kernel runs from any 2 MiB-aligned address, and given an
# unaligned one U-Boot first moves all of it up to the next one, which
# measured 245 ms. The device tree stays at U-Boot's fdt_addr_r, below it.
setenv kernel_addr_r 0x02200000
load ${devtype} ${devnum}:${distro_bootpart} ${kernel_addr_r} /Image
load ${devtype} ${devnum}:${distro_bootpart} ${fdt_addr_r} /rk3326s-gkd-pixel2.dtb
#
# No console=ttyS2: the serial port has no one on the other end, and every
# kernel message was being written to it. The kernel has no framebuffer
# console either (linux-px2.config): the panel powers up in the background
# from early in boot (kernel patch 6), and nothing draws on it until
# userspace does. For kernel messages on screen while debugging, turn
# CONFIG_FRAMEBUFFER_CONSOLE back on; panic=30 then keeps a panic visible
# instead of rebooting after 1 s.
setenv bootargs "root=/dev/mmcblk0p2 rootwait rw console=tty1 panic=30"
booti ${kernel_addr_r} - ${fdt_addr_r}
