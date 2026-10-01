################################################################################
#
# tortos: the launcher and Muse, from the TortOS repository
#
################################################################################

TORTOS_VERSION = local
TORTOS_SITE = /tortos
TORTOS_SITE_METHOD = local
TORTOS_DEPENDENCIES = sdl2 sdl2_image sdl2_ttf ffmpeg
TORTOS_LICENSE = MIT

# TortOS's own cross build (mk/cross.mk), pointed at this system's compiler
# and libraries instead of the Brick's, with the Pixel 2's device file
# (src/device/pixel2.c). The generated ScreenScraper header first, on its own:
# the elf needs it and has no rule to make it.
#
# Into build-pixel2/, never build/: the source is copied in whole, ignored
# files and all, so a Brick build sitting in the worktree's build/ came along
# and make took its muse as up to date. The Brick's binary shipped as the
# Pixel's, caught 2026-10-01 by its size.
TORTOS_BUILD_DIR = build-pixel2
define TORTOS_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) -f mk/cross.mk BUILD=$(TORTOS_BUILD_DIR) creds
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) -f mk/cross.mk \
		CC="$(TARGET_CC)" SYSROOT="$(STAGING_DIR)" DEVICE=pixel2 \
		BUILD=$(TORTOS_BUILD_DIR) \
		$(TORTOS_BUILD_DIR)/tortos.elf $(TORTOS_BUILD_DIR)/muse
endef

define TORTOS_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/$(TORTOS_BUILD_DIR)/tortos.elf $(TARGET_DIR)/usr/bin/tortos
	$(INSTALL) -D -m 0755 $(@D)/$(TORTOS_BUILD_DIR)/muse $(TARGET_DIR)/usr/bin/muse
endef

$(eval $(generic-package))
