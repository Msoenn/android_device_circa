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
# persist.sys.usb.config=adb: USB debugging (and so adbd, which also serves TCP) on for a fresh /data;
# AdbService derives adb_enabled from it. AOSP only adds it when ro.adb.secure=0.
PRODUCT_PRODUCT_PROPERTIES += \
    persist.sys.usb.config=adb \
    service.adb.tcp.port=5555
# adb root allowed by default (Lineage's adb_root service state), see init/init.circa.rc.
PRODUCT_PACKAGES += \
    init.circa.rc

# --- SELinux ------------------------------------------------------------------------------------------
# su permissive on userdebug again (adb root), see sepolicy/private/su.te.
SYSTEM_EXT_PRIVATE_SEPOLICY_DIRS += device/circa/common/sepolicy/private

# --- The Circa apps -----------------------------------------------------------------------------------
# vendor/circa-apps (github.com/Msoenn/circa-apps, in the Circa manifest). Its ./build-all.sh builds the APKs
# into vendor/circa-apps/prebuilt/; until then circa-apps.mk adds nothing and the image keeps Launcher3,
# LatinIME and DeskClock. The configuration the apps require is in apps/ here.
$(call inherit-product-if-exists, vendor/circa-apps/circa-apps.mk)

# --- Private parts (adb key, stock SELinux) -------------------------------------------------------------
# A plain local directory, not a repo project; absent in public checkouts. See README.md.
$(call inherit-product-if-exists, vendor/circa-private/circa-private.mk)
