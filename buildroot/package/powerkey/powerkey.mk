################################################################################
#
# powerkey: a press of the power button shuts down cleanly
#
################################################################################

POWERKEY_VERSION = 1.0
POWERKEY_SITE = $(BR2_EXTERNAL_PX2_PATH)/package/powerkey/src
POWERKEY_SITE_METHOD = local

define POWERKEY_BUILD_CMDS
	$(TARGET_CC) $(TARGET_CFLAGS) $(TARGET_LDFLAGS) -Wall -Wextra \
		-o $(@D)/powerkey $(@D)/powerkey.c
endef

define POWERKEY_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/powerkey $(TARGET_DIR)/usr/sbin/powerkey
endef

$(eval $(generic-package))
