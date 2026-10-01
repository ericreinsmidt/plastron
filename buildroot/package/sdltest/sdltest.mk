################################################################################
#
# sdltest: SDL2 start-up time and rotated presentation, as TortOS uses them
#
################################################################################

SDLTEST_VERSION = 1.0
SDLTEST_SITE = $(BR2_EXTERNAL_PX2_PATH)/package/sdltest/src
SDLTEST_SITE_METHOD = local
SDLTEST_DEPENDENCIES = sdl2 host-pkgconf

define SDLTEST_BUILD_CMDS
	$(TARGET_CC) $(TARGET_CFLAGS) $(TARGET_LDFLAGS) -Wall -Wextra \
		-o $(@D)/sdltest $(@D)/sdltest.c \
		$$($(PKG_CONFIG_HOST_BINARY) --cflags --libs sdl2)
endef

define SDLTEST_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/sdltest $(TARGET_DIR)/usr/bin/sdltest
endef

$(eval $(generic-package))
