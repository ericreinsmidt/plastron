################################################################################
#
# brrr: "TortOS go brrr" on screen at boot
#
################################################################################

BRRR_VERSION = 1.0
BRRR_SITE = $(BR2_EXTERNAL_PX2_PATH)/package/brrr/src
BRRR_SITE_METHOD = local
BRRR_DEPENDENCIES = libdrm host-pkgconf

define BRRR_BUILD_CMDS
	$(TARGET_CC) $(TARGET_CFLAGS) $(TARGET_LDFLAGS) -Wall -Wextra \
		-o $(@D)/brrr $(@D)/brrr.c \
		$$($(PKG_CONFIG_HOST_BINARY) --cflags --libs libdrm)
endef

define BRRR_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/brrr $(TARGET_DIR)/usr/bin/brrr
endef

define BRRR_INSTALL_INIT_SYSV
	$(INSTALL) -D -m 0755 $(BRRR_PKGDIR)/brrr.init $(TARGET_DIR)/etc/init.d/brrr
endef

$(eval $(generic-package))
