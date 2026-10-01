# U-Boot boot script. ROCKNIX's U-Boot (board/px2/bootloader) only looks for
# boot.scr ("bootmeth order script"), so this is the whole boot menu.
# Addresses are U-Boot's own defaults for this board.
load ${devtype} ${devnum}:${distro_bootpart} ${kernel_addr_r} /Image
load ${devtype} ${devnum}:${distro_bootpart} ${fdt_addr_r} /rk3326s-gkd-pixel2.dtb
# panic=30: keep a panic message on screen instead of rebooting after 1 s
setenv bootargs "root=/dev/mmcblk0p2 rootwait rw console=tty1 console=ttyS2,1500000 panic=30"
booti ${kernel_addr_r} - ${fdt_addr_r}
