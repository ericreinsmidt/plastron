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

# The kernel LZ4-compressed (Image.lz4, 4.1 MB for 8.8), unpacked straight to
# where it runs: U-Boot reads the card at about 17 MB/s, and the smaller file
# saves 194 ms of reading for 33 ms of unpacking (with U-Boot's patch 0010; it
# took 213 before). Image stays on the card for U-Boot's own boot command,
# which boots it if this fails
if load mmc 0:1 ${kernel_comp_addr_r} Image.lz4 &&
   unlz4 ${kernel_comp_addr_r} ${kernel_addr_r} 0x2000000 &&
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
