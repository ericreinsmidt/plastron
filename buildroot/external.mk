# The Pixel 2 device tree comes from ROCKNIX (board/px2/dts), including its
# own rk3326.dtsi, which replaces mainline's the same way ROCKNIX's build does.
define PX2_LINUX_ADD_DTS
	cp $(BR2_EXTERNAL_PX2_PATH)/board/px2/dts/* $(@D)/arch/arm64/boot/dts/rockchip/
	grep -q rk3326s-gkd-pixel2 $(@D)/arch/arm64/boot/dts/rockchip/Makefile || \
		echo 'dtb-$$(CONFIG_ARCH_ROCKCHIP) += rk3326s-gkd-pixel2.dtb' >> $(@D)/arch/arm64/boot/dts/rockchip/Makefile
endef
LINUX_POST_PATCH_HOOKS += PX2_LINUX_ADD_DTS
