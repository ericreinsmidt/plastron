################################################################################
#
# xr829-firmware: the XR829's Wi-Fi and Bluetooth firmware (see Config.in)
#
################################################################################

XR829_FIRMWARE_VERSION = sonic-pad-7f37a7f
XR829_FIRMWARE_SITE = /brick-xr829
XR829_FIRMWARE_SITE_METHOD = local
XR829_FIRMWARE_LICENSE = PROPRIETARY
XR829_FIRMWARE_REDISTRIBUTE = NO

XR829_FIRMWARE_FILES = boot_xr829.bin fw_xr829.bin sdd_xr829.bin fw_xr829_bt.bin

# Checked before anything is installed (see Config.in for what they are)
define XR829_FIRMWARE_CHECK_FILES
	cd $(@D) && sha256sum -c --quiet $(XR829_FIRMWARE_PKGDIR)/files.sha256 || { \
		echo "xr829-firmware: the files in /brick-xr829 aren't the ones" \
			"expected (package/xr829-firmware/files.sha256)" >&2; exit 1; }
endef
XR829_FIRMWARE_PRE_CONFIGURE_HOOKS += XR829_FIRMWARE_CHECK_FILES

define XR829_FIRMWARE_INSTALL_TARGET_CMDS
	$(foreach f,$(XR829_FIRMWARE_FILES),
		$(INSTALL) -D -m 0644 $(@D)/$(f) $(TARGET_DIR)/lib/firmware/$(f))
endef

$(eval $(generic-package))
