################################################################################
#
# diatom: the libretro frontend, from the Diatom repository
#
################################################################################

DIATOM_VERSION = local
DIATOM_SITE = /diatom
DIATOM_SITE_METHOD = local
DIATOM_DEPENDENCIES = sdl2 mesa3d-px2 libdrm host-pkgconf
DIATOM_LICENSE = MIT

# Diatom's Pixel 2 port (port/pixel2.c, its ADR-0035). Its build finds SDL2,
# EGL, GLES, GBM and libdrm with pkg-config, which in Buildroot's PATH answers
# for this system's libraries.
define DIATOM_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) PORT=pixel2 CC="$(TARGET_CC)"
endef

define DIATOM_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/build/pixel2/diatom $(TARGET_DIR)/usr/bin/diatom
endef

$(eval $(generic-package))
