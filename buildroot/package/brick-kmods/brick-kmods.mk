################################################################################
#
# brick-kmods: the TrimUI Brick's kernel modules, built with its kernel
#
################################################################################

BRICK_KMODS_VERSION = local
# make brick-kernel's output, in the build volume
BRICK_KMODS_SITE = /work/brick-kernel/images
BRICK_KMODS_SITE_METHOD = local
BRICK_KMODS_LICENSE = GPL-2.0 (brick-pad, cfg80211, xr829), Dual MIT/GPL-2.0 (pvrsrvkm, dc_sunxi)
# Built files, not source: their source is the Brick's kernel recipe
# (board/brick/linux), which goes out with a release; legal-info packs nothing here
BRICK_KMODS_REDISTRIBUTE = NO

BRICK_KMODS_FILES = brick-pad.ko pvrsrvkm.ko dc_sunxi.ko \
	cfg80211.ko xr829_mac.ko xr829_core.ko xr829_wlan.ko

define BRICK_KMODS_INSTALL_TARGET_CMDS
	$(foreach m,$(BRICK_KMODS_FILES),
		$(INSTALL) -D -m 0644 $(@D)/$(m) $(TARGET_DIR)/usr/lib/brick/$(m))
endef

$(eval $(generic-package))
