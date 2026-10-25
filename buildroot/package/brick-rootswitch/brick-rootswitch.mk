################################################################################
#
# brick-rootswitch: the TrimUI Brick's initramfs program
#
################################################################################

BRICK_ROOTSWITCH_VERSION = local
BRICK_ROOTSWITCH_SITE = $(BR2_EXTERNAL_PX2_PATH)/package/brick-rootswitch/src
BRICK_ROOTSWITCH_SITE_METHOD = local
BRICK_ROOTSWITCH_LICENSE = GPL-3.0+
# Not in the root: it goes in the initramfs, with the boot files
BRICK_ROOTSWITCH_INSTALL_TARGET = NO
BRICK_ROOTSWITCH_INSTALL_IMAGES = YES
# For board/brick/post-image.sh, which packs this with the other boot files and
# compresses the kernel with host-lz4: Buildroot has no option for host-lz4
# alone, and the build host's own lz4 would put a tool from outside the build
# into what goes on the card
BRICK_ROOTSWITCH_DEPENDENCIES = host-lz4

define BRICK_ROOTSWITCH_BUILD_CMDS
	$(TARGET_CC) -static -O2 -Wall -Wextra -o $(@D)/rdinit $(@D)/rootswitch.c
	$(TARGET_STRIP) $(@D)/rdinit
endef

define BRICK_ROOTSWITCH_INSTALL_IMAGES_CMDS
	$(INSTALL) -D -m 0755 $(@D)/rdinit $(BINARIES_DIR)/rdinit
endef

$(eval $(generic-package))
