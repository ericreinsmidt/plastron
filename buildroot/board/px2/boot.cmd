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
# panic=30: keep a panic message on screen instead of rebooting after 1 s
setenv bootargs "root=/dev/mmcblk0p2 rootwait rw console=tty1 console=ttyS2,1500000 panic=30"
booti ${kernel_addr_r} - ${fdt_addr_r}
