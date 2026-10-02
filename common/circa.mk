#
# The Circa product layer, shared by the watch (aurora/) and the emulator (emulator/) products.
#
# Everything the watch used to get from post-build image edits, a Magisk module, runtime resource
# overlays installed from /data and adb setup commands is declared here instead.
#

# --- Overlays (static RROs in /product/overlay) -----------------------------------------------------
# Round display, AOD availability, doze/idle policy, gestural navigation (framework-res), round status
# bar + PIN bouncer (SystemUI), first-boot setting defaults (SettingsProvider).
PRODUCT_PACKAGES += \
    CircaFrameworkOverlay \
    CircaSystemUIOverlay \
    CircaSettingsProviderOverlay

# --- Features ------------------------------------------------------------------------------------------
# Stock Wear OS declares these from its /product partition, which the GSI flow deletes.
PRODUCT_PACKAGES += \
    circa-features.xml

# --- Phone-only packages removed (see removals/Android.mk) --------------------------------------------
PRODUCT_PACKAGES += \
    CircaRemovePackages

# No setup wizard (LineageSetupWizard is removed above); the SettingsProvider overlay marks the device
# provisioned and the user setup complete.
PRODUCT_SYSTEM_EXT_PROPERTIES += \
    ro.setupwizard.mode=DISABLED

# --- Display -------------------------------------------------------------------------------------------
# 160 dpi on the 384x384 panel (the vendor says 320). Product properties load after vendor/odm, so this
# value wins over the vendor's ro.sf.lcd_density. On the emulator the AVD's qemu.sf.lcd_density takes
# precedence over ro.sf.lcd_density (DisplayMetrics), so set hw.lcd.density=160 in the AVD instead.
PRODUCT_PRODUCT_PROPERTIES += \
    ro.sf.lcd_density=160

# --- adb -----------------------------------------------------------------------------------------------
# Key authentication stays on (ro.adb.secure=1 from vendor/lineage for userdebug). The authorized key is
# baked in privately: vendor/circa-private sets PRODUCT_ADB_KEYS (-> /product/etc/security/adb_keys, which
# /adb_keys links to). Wireless adb on TCP 5555 from boot (adbd reads service.adb.tcp.port at start).
# Product properties: the generic system partition does not take device properties.
PRODUCT_PRODUCT_PROPERTIES += \
    service.adb.tcp.port=5555
# adb root allowed by default (Lineage's adb_root service state), see init/init.circa.rc.
PRODUCT_PACKAGES += \
    init.circa.rc

# --- Private parts (our apps, adb key) ----------------------------------------------------------------
# A plain local directory, not a repo project; absent in public checkouts, which then build without our
# apps. See README.md.
$(call inherit-product-if-exists, vendor/circa-private/circa-private.mk)
