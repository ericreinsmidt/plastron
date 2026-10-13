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
# The TrimUI Brick's display is a framebuffer, not DRM: splash-fb.c there,
# with the frames at its panel's 1024x768
ifeq ($(BR2_PACKAGE_PVR_GE8300),y)
SPLASH_DEPENDENCIES = zlib
SPLASH_SOURCE_C = splash-fb.c
SPLASH_FRAMES = frames-brick.bin
SPLASH_LIBS = -lz
else
SPLASH_DEPENDENCIES = libdrm host-pkgconf
SPLASH_SOURCE_C = splash.c
SPLASH_FRAMES = frames.bin
SPLASH_LIBS = $$($(PKG_CONFIG_HOST_BINARY) --cflags --libs libdrm) -lm
endif

define SPLASH_BUILD_CMDS
	$(TARGET_CC) $(TARGET_CFLAGS) $(TARGET_LDFLAGS) -Wall -Wextra \
		-o $(@D)/splash $(@D)/$(SPLASH_SOURCE_C) $(SPLASH_LIBS)
endef

# frames.bin (the Pixel's) and frames-brick.bin are TortOS's boot animation,
# encoded for each panel on the Mac by scripts/make-splash-frames.py; kept
# here so the build never decodes video.
define SPLASH_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/splash $(TARGET_DIR)/usr/bin/splash
	$(INSTALL) -D -m 0644 $(SPLASH_PKGDIR)/$(SPLASH_FRAMES) $(TARGET_DIR)/usr/share/splash/frames.bin
endef

# The Pixel's inittab starts it through this; the Brick's /etc/init.d/brick
# starts it itself
ifneq ($(BR2_PACKAGE_PVR_GE8300),y)
define SPLASH_INSTALL_INIT_SYSV
	$(INSTALL) -D -m 0755 $(SPLASH_PKGDIR)/splash.init $(TARGET_DIR)/etc/init.d/splash
endef
endif

$(eval $(generic-package))
