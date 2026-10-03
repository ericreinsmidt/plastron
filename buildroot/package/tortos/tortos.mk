################################################################################
#
# tortos: the launcher and Muse, from the TortOS repository
#
################################################################################

TORTOS_VERSION = local
TORTOS_SITE = /tortos
TORTOS_SITE_METHOD = local
# diatom too: its binary goes on the card with TortOS's (see the install)
TORTOS_DEPENDENCIES = sdl2 sdl2_image sdl2_ttf ffmpeg diatom
TORTOS_LICENSE = MIT
# Its source is public (github.com/ericreinsmidt/TortOS), so legal-info names
# it rather than packing up the copy below, which is a working tree's
TORTOS_REDISTRIBUTE = NO

# The source is copied from a working tree, so what git ignores stays behind:
# build products (a Brick build among them), vendor/, the ScreenScraper pair's
# file, notes. Then the worktrees, and AUDIOBOOKS/, staging material that is
# untracked but not ignored.
TORTOS_OVERRIDE_SRCDIR_RSYNC_EXCLUSIONS = \
	--filter=:-_.gitignore --exclude=/.claude --exclude=/AUDIOBOOKS

# TortOS's own cross build (mk/cross.mk), pointed at this system's compiler
# and libraries instead of the Brick's, with the Pixel 2's device file
# (src/device/pixel2.c). The generated ScreenScraper header first, on its own:
# the elf needs it and has no rule to make it.
#
# Into build-pixel2/, never build/: the source used to be copied in whole,
# ignored files and all, so a Brick build sitting in the worktree's build/
# came along and make took its muse as up to date. The Brick's binary shipped
# as the Pixel's, caught 2026-10-01 by its size. The copy leaves build/ behind
# now (above), and a directory of its own makes sure of it.
TORTOS_BUILD_DIR = build-pixel2
#
# The ScreenScraper pair comes from the file the Makefile mounts, read here
# in the shell so neither value is written into a command line make prints.
TORTOS_SS_ENV = /tortos-ss.env
define TORTOS_BUILD_CMDS
	SS_DEVID="$$(sed -n 's/^SS_DEVID=//p' $(TORTOS_SS_ENV) 2>/dev/null | head -1)" \
	SS_DEVPASS="$$(sed -n 's/^SS_DEVPASS=//p' $(TORTOS_SS_ENV) 2>/dev/null | head -1)" \
		$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) -f mk/cross.mk BUILD=$(TORTOS_BUILD_DIR) creds
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) -f mk/cross.mk \
		CC="$(TARGET_CC)" SYSROOT="$(STAGING_DIR)" DEVICE=pixel2 \
		BUILD=$(TORTOS_BUILD_DIR) \
		$(TORTOS_BUILD_DIR)/tortos.elf $(TORTOS_BUILD_DIR)/muse
endef

# TortOS runs from the card's games partition, as on the Brick, so it can be
# updated by copying files onto the card. What goes there is TortOS's own
# payload (mk/payload.sh, DEVICE=pixel2): the launcher, Muse, diatom, the
# cores, cards and fonts, and the empty Roms, Bios and Saves folders. The
# image keeps a copy in /usr/share/tortos/card, laid out as on the card, and
# /etc/init.d/tortos copies it there when the card has no TortOS.
TORTOS_CARD = $(TARGET_DIR)/usr/share/tortos/card
define TORTOS_INSTALL_TARGET_CMDS
	DEVICE=pixel2 OUT=$(TORTOS_CARD) ZIP= \
		TORTOS_ELF=$(@D)/$(TORTOS_BUILD_DIR)/tortos.elf \
		MUSE_ELF=$(@D)/$(TORTOS_BUILD_DIR)/muse \
		DIATOM_ELF=$(DIATOM_DIR)/build/pixel2/diatom \
		VENDOR_DIR=/tortos-vendor \
		sh $(@D)/mk/payload.sh
endef

$(eval $(generic-package))
