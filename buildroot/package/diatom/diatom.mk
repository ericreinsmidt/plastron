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
DIATOM_LICENSE_FILES = LICENSE
# Its source is public (github.com/ericreinsmidt/diatom), so legal-info names
# it rather than packing up the copy below, which is a working tree's
DIATOM_REDISTRIBUTE = NO

# What git ignores stays behind: build products, cores, sysroots, notes
DIATOM_OVERRIDE_SRCDIR_RSYNC_EXCLUSIONS = --filter=:-_.gitignore --exclude=/.claude

# Diatom's Pixel 2 port (port/pixel2.c, its ADR-0035). Its build finds SDL2,
# EGL, GLES, GBM and libdrm with pkg-config, which in Buildroot's PATH answers
# for this system's libraries.
define DIATOM_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) PORT=pixel2 CC="$(TARGET_CC)"
endef

# Nothing to install here: diatom runs from the card, beside TortOS, and the
# tortos package puts it in TortOS's payload

$(eval $(generic-package))
