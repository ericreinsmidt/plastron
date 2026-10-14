################################################################################
#
# brick-tools: backlight and sincereset, for the TrimUI Brick's startup
#
################################################################################

BRICK_TOOLS_VERSION = 1.0
BRICK_TOOLS_SITE = $(BR2_EXTERNAL_PX2_PATH)/package/brick-tools/src
BRICK_TOOLS_SITE_METHOD = local
BRICK_TOOLS_LICENSE = MIT

BRICK_TOOLS_PROGRAMS = backlight sincereset

define BRICK_TOOLS_BUILD_CMDS
	$(foreach p,$(BRICK_TOOLS_PROGRAMS),
		$(TARGET_CC) $(TARGET_CFLAGS) $(TARGET_LDFLAGS) -Wall -Wextra \
			-o $(@D)/$(p) $(@D)/$(p).c)
endef

define BRICK_TOOLS_INSTALL_TARGET_CMDS
	$(foreach p,$(BRICK_TOOLS_PROGRAMS),
		$(INSTALL) -D -m 0755 $(@D)/$(p) $(TARGET_DIR)/usr/lib/brick/$(p))
endef

$(eval $(generic-package))
