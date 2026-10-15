# The Brick's boot, as its U-Boot runs it from boot.scr (made from
# this by board/brick/post-image.sh). If anything here fails, U-Boot's own boot
# command carries on and boots the uncompressed Image as before.

# The PLLs boot0 starts, at TrimUI's running values (Allwinner's 4.9 kernel
# can't start them itself)
mw.l 0x03001128 0xd1303333; mw.l 0x03001160 0xc0014396; mw.l 0x03001178 0xc001eb85
mw.l 0x03001028 0xa9003100; mw.l 0x03001030 0xa8007403; mw.l 0x03001040 0xa8001803
mw.l 0x03001048 0xa8006203; mw.l 0x03001050 0xa8003701; mw.l 0x03001058 0xa8002301
mw.l 0x03001060 0xa9002401; mw.l 0x03001068 0xa8003101; mw.l 0x03001078 0xa9042701

# The CPU's PLL as the boot loader left it, for Linux to read in
# /proc/device-tree/chosen/brick,pll-cpux
setexpr.l pllcpux *0x03001000

# The kernel uncompressed: LZ4 read in 200 ms less, but U-Boot took 265 ms
# to unpack it (tried 2026-10-12)
if load mmc 0:1 ${kernel_addr_r} Image &&
   load mmc 0:1 ${ramdisk_addr_r} initramfs.cpio.gz && setenv rdsize ${filesize} &&
   load mmc 0:1 ${fdt_addr_r} brick.dtb; then
	fdt addr ${fdt_addr_r}
	fdt resize 4096
	fdt rsvmem add 0x40000000 0x40000
	fdt set /soc@03000000/sdmmc@04022000 status disabled
	fdt set /chosen brick,pll-cpux "${pllcpux}"
	setenv bootargs console=ttyS0,115200 loglevel=1 rdinit=/rdinit cma=64M bootscr=1
	booti ${kernel_addr_r} ${ramdisk_addr_r}:${rdsize} ${fdt_addr_r}
fi
