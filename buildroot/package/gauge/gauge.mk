################################################################################
#
# gauge: the four lights on the side show the battery
#
################################################################################

GAUGE_VERSION = 1.0
GAUGE_SITE = $(BR2_EXTERNAL_PX2_PATH)/package/gauge/src
GAUGE_SITE_METHOD = local
GAUGE_LICENSE = MIT
GAUGE_LICENSE_FILES = LICENSE

define GAUGE_BUILD_CMDS
	$(TARGET_CC) $(TARGET_CFLAGS) $(TARGET_LDFLAGS) -Wall -Wextra \
		-o $(@D)/gauge $(@D)/gauge.c
endef

define GAUGE_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/gauge $(TARGET_DIR)/usr/sbin/gauge
endef

$(eval $(generic-package))
