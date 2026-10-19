include $(sort $(wildcard $(BR2_EXTERNAL_PX2_PATH)/package/*/*.mk))

# The Pixel 2 device tree comes from ROCKNIX (board/px2/dts), including its
# own rk3326.dtsi, which replaces mainline's the same way ROCKNIX's build does.
# Copied in before every kernel build, not once after the source is patched:
# as a post-patch hook an edit here never reached a rebuilt kernel (the LED
# polarity fix, 2026-10-08), only one built from a fresh source tree.
define PX2_LINUX_ADD_DTS
	cp $(BR2_EXTERNAL_PX2_PATH)/board/px2/dts/* $(@D)/arch/arm64/boot/dts/rockchip/
	grep -q rk3326s-gkd-pixel2 $(@D)/arch/arm64/boot/dts/rockchip/Makefile || \
		echo 'dtb-$$(CONFIG_ARCH_ROCKCHIP) += rk3326s-gkd-pixel2.dtb' >> $(@D)/arch/arm64/boot/dts/rockchip/Makefile
endef
LINUX_PRE_BUILD_HOOKS += PX2_LINUX_ADD_DTS

# The Brick's SDL2 draws through Imagination's EGL on the framebuffer, with
# the video driver board/brick/patches/sdl2 adds (it is off unless asked for)
ifeq ($(BR2_PACKAGE_PVR_GE8300),y)
SDL2_CONF_OPTS += --enable-video-pvrfb
endif

# The Brick's squashfs root with the boot's files first, in the order it reads
# them (board/brick/squashfs-sort.txt), packed together at the image's front
# so they come off the card in a few large reads. Here, as Buildroot's squashfs
# options have no sort list (its compression options follow the compressor
# and can't be set), and this file is read after fs/*.mk
ifeq ($(BR2_PACKAGE_BRICK_ROOTSWITCH),y)
ROOTFS_SQUASHFS_ARGS += -sort $(BR2_EXTERNAL_PX2_PATH)/board/brick/squashfs-sort.txt
endif
