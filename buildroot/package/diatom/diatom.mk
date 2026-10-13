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
DIATOM_DEPENDENCIES = sdl2
else
DIATOM_DEPENDENCIES = sdl2 mesa3d-px2 libdrm host-pkgconf
endif
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
#
# Its Brick port (port/brick.c) builds against TrimUI's system laid out as
# tools/fetch-brick-sysroot.sh lays it out: SDL2's library under
# usr/trimui/lib, its headers under usr/include. This system's own staging
# area stands in for it, through links, so Diatom builds unchanged.
ifeq ($(DIATOM_PORT),brick)
define DIATOM_BUILD_CMDS
	mkdir -p $(@D)/brick-sysroot/usr/trimui
	ln -sfn $(STAGING_DIR)/usr/lib $(@D)/brick-sysroot/usr/trimui/lib
	ln -sfn $(STAGING_DIR)/usr/include $(@D)/brick-sysroot/usr/include
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) PORT=brick CROSS= CC="$(TARGET_CC)" \
		SYSROOT=$(@D)/brick-sysroot
endef
else
define DIATOM_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) PORT=pixel2 CC="$(TARGET_CC)"
endef
endif

# Nothing to install here: diatom runs from the card, beside TortOS, and the
# tortos package puts it in TortOS's payload

$(eval $(generic-package))
