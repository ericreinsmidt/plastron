################################################################################
#
# diatom: the libretro frontend, from the Diatom repository
#
################################################################################

DIATOM_VERSION = local
DIATOM_SITE = /diatom
DIATOM_SITE_METHOD = local
DIATOM_DEPENDENCIES = sdl2 host-pkgconf
DIATOM_LICENSE = MIT

# Its build finds SDL2 with pkg-config, which in Buildroot's PATH answers for
# this system's libraries. LDFLAGS=-lm from the environment, which its
# Makefile appends to: the desktop port doesn't link libm, which macOS
# includes anyway and Linux doesn't.
define DIATOM_BUILD_CMDS
	$(TARGET_MAKE_ENV) LDFLAGS=-lm $(MAKE) -C $(@D) PORT=desktop CC="$(TARGET_CC)"
endef

define DIATOM_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/build/desktop/diatom $(TARGET_DIR)/usr/bin/diatom
endef

$(eval $(generic-package))
