################################################################################
#
# usbrole: the USB port's role follows the ID pin
#
################################################################################

USBROLE_VERSION = 1.0
USBROLE_SITE = $(BR2_EXTERNAL_PX2_PATH)/package/usbrole/src
USBROLE_SITE_METHOD = local
USBROLE_LICENSE = MIT
USBROLE_LICENSE_FILES = LICENSE

define USBROLE_BUILD_CMDS
	$(TARGET_CC) $(TARGET_CFLAGS) $(TARGET_LDFLAGS) -Wall -Wextra \
		-o $(@D)/usbrole $(@D)/usbrole.c
endef

define USBROLE_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/usbrole $(TARGET_DIR)/usr/sbin/usbrole
endef

$(eval $(generic-package))
