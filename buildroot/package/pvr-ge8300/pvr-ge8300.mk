################################################################################
#
# pvr-ge8300: Imagination's GLES and EGL for the TrimUI Brick's GPU
#
################################################################################

PVR_GE8300_VERSION = 1.11.5516664
PVR_GE8300_SITE = /brick-gpu
PVR_GE8300_SITE_METHOD = local
PVR_GE8300_LICENSE = PROPRIETARY
# Closed, and no license came with them: legal-info lists them, and packs
# nothing
PVR_GE8300_REDISTRIBUTE = NO
PVR_GE8300_INSTALL_STAGING = YES
PVR_GE8300_PROVIDES = libegl libgles

# What EGL and GLES load, and the window system they're told to use
PVR_GE8300_LIBS = libEGL.so libGLESv2.so libGLES_CM.so libIMGegl.so \
	libsrv_um.so libglslcompiler.so libusc.so libpvrNULL_WSEGL.so

# The libraries under their own names, with the versioned names programs
# link against as links to them: libIMGegl opens libGLESv2.so by that name,
# and a second copy under the other one loads GLES twice (seen on the Brick
# from a FAT card, which can't hold links)
define PVR_GE8300_INSTALL_LIBS
	$(foreach lib,$(PVR_GE8300_LIBS),
		$(INSTALL) -D -m 0755 $(@D)/lib64/$(lib) $(1)/usr/lib/$(lib))
	ln -sf libEGL.so $(1)/usr/lib/libEGL.so.1
	ln -sf libGLESv2.so $(1)/usr/lib/libGLESv2.so.2
	ln -sf libGLES_CM.so $(1)/usr/lib/libGLES_CM.so.1
endef

# The Khronos headers that came with them, and pkg-config files for what
# SDL2 and the rest look for
define PVR_GE8300_INSTALL_STAGING_CMDS
	$(call PVR_GE8300_INSTALL_LIBS,$(STAGING_DIR))
	mkdir -p $(STAGING_DIR)/usr/include
	cp -r $(@D)/include/EGL $(@D)/include/KHR $(@D)/include/GLES \
		$(@D)/include/GLES2 $(@D)/include/GLES3 $(STAGING_DIR)/usr/include/
	$(INSTALL) -D -m 0644 $(PVR_GE8300_PKGDIR)/egl.pc \
		$(STAGING_DIR)/usr/lib/pkgconfig/egl.pc
	$(INSTALL) -D -m 0644 $(PVR_GE8300_PKGDIR)/glesv2.pc \
		$(STAGING_DIR)/usr/lib/pkgconfig/glesv2.pc
	$(INSTALL) -D -m 0644 $(PVR_GE8300_PKGDIR)/glesv1_cm.pc \
		$(STAGING_DIR)/usr/lib/pkgconfig/glesv1_cm.pc
endef

# The firmware, which the kernel driver loads on first use, and the window
# system setting the libraries read
define PVR_GE8300_INSTALL_TARGET_CMDS
	$(call PVR_GE8300_INSTALL_LIBS,$(TARGET_DIR))
	$(INSTALL) -D -m 0644 $(@D)/lib64/firmware/rgx.fw.22.102.54.38 \
		$(TARGET_DIR)/lib/firmware/rgx.fw.22.102.54.38
	$(INSTALL) -D -m 0644 $(PVR_GE8300_PKGDIR)/powervr.ini \
		$(TARGET_DIR)/etc/powervr.ini
endef

$(eval $(generic-package))
