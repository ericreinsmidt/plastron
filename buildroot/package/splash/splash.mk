################################################################################
#
# splash: TortOS's boot animation, from the moment the panel lights
#
################################################################################

SPLASH_VERSION = 1.0
SPLASH_SITE = $(BR2_EXTERNAL_PX2_PATH)/package/splash/src
SPLASH_SITE_METHOD = local
SPLASH_LICENSE = MIT
SPLASH_LICENSE_FILES = LICENSE
SPLASH_DEPENDENCIES = libdrm host-pkgconf

define SPLASH_BUILD_CMDS
	$(TARGET_CC) $(TARGET_CFLAGS) $(TARGET_LDFLAGS) -Wall -Wextra \
		-o $(@D)/splash $(@D)/splash.c \
		$$($(PKG_CONFIG_HOST_BINARY) --cflags --libs libdrm) -lm
endef

# frames.bin is TortOS's boot animation, turned for the panel and encoded on
# the Mac by scripts/make-splash-frames.py; kept here so the build never
# decodes video.
define SPLASH_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/splash $(TARGET_DIR)/usr/bin/splash
	$(INSTALL) -D -m 0644 $(SPLASH_PKGDIR)/frames.bin $(TARGET_DIR)/usr/share/splash/frames.bin
endef

define SPLASH_INSTALL_INIT_SYSV
	$(INSTALL) -D -m 0755 $(SPLASH_PKGDIR)/splash.init $(TARGET_DIR)/etc/init.d/splash
endef

$(eval $(generic-package))
