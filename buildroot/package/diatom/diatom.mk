################################################################################
#
# diatom: the libretro frontend, from the Diatom repository
#
################################################################################

DIATOM_VERSION = local
DIATOM_SITE = /diatom
DIATOM_SITE_METHOD = local
# The Brick's system is the one with the Brick's GPU libraries
DIATOM_PORT = $(if $(BR2_PACKAGE_PVR_GE8300),brick,pixel2)
ifeq ($(DIATOM_PORT),brick)
DIATOM_DEPENDENCIES = sdl2 zlib host-pkgconf
else
DIATOM_DEPENDENCIES = sdl2 zlib mesa3d-px2 libdrm host-pkgconf
endif
DIATOM_LICENSE = MIT
DIATOM_LICENSE_FILES = LICENSE
# Its source is public (github.com/ericreinsmidt/diatom), so legal-info names
# it rather than packing up the copy below, which is a working tree's
DIATOM_REDISTRIBUTE = NO

# What git ignores stays behind: build products, cores, sysroots, notes
DIATOM_OVERRIDE_SRCDIR_RSYNC_EXCLUSIONS = --filter=:-_.gitignore --exclude=/.claude

# Diatom's port for the device (port/brick.c or port/pixel2.c). Its build
# finds the libraries with pkg-config, which in Buildroot's PATH answers for
# this system's: SDL2 on the Brick; SDL2, EGL, GLES, GBM and libdrm on the
# Pixel 2.
define DIATOM_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) PORT=$(DIATOM_PORT) CC="$(TARGET_CC)"
endef

# Nothing to install here: diatom runs from the card, beside TortOS, and the
# tortos package puts it in TortOS's payload

$(eval $(generic-package))
