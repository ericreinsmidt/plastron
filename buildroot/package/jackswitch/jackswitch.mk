################################################################################
#
# jackswitch: sound follows the headphone jack
#
################################################################################

JACKSWITCH_VERSION = 1.0
JACKSWITCH_SITE = $(BR2_EXTERNAL_PX2_PATH)/package/jackswitch/src
JACKSWITCH_SITE_METHOD = local
JACKSWITCH_LICENSE = MIT
JACKSWITCH_LICENSE_FILES = LICENSE
JACKSWITCH_DEPENDENCIES = alsa-lib

define JACKSWITCH_BUILD_CMDS
	$(TARGET_CC) $(TARGET_CFLAGS) $(TARGET_LDFLAGS) -Wall -Wextra \
		-o $(@D)/jackswitch $(@D)/jackswitch.c -lasound
endef

define JACKSWITCH_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/jackswitch $(TARGET_DIR)/usr/sbin/jackswitch
endef

$(eval $(generic-package))
