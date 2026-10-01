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
# and libraries instead of the Brick's. The generated ScreenScraper header
# first, on its own: build/tortos.elf needs it and has no rule to make it.
define TORTOS_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) -f mk/cross.mk creds
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) -f mk/cross.mk \
		CC="$(TARGET_CC)" SYSROOT="$(STAGING_DIR)" \
		build/tortos.elf build/muse
endef

define TORTOS_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/build/tortos.elf $(TARGET_DIR)/usr/bin/tortos
	$(INSTALL) -D -m 0755 $(@D)/build/muse $(TARGET_DIR)/usr/bin/muse
endef

$(eval $(generic-package))
