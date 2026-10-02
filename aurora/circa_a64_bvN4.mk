#
# Circa for the Pixel Watch 2 ("aurora"): the TrebleDroid/LineageOS a64 GSI (vanilla, ext4) plus the Circa
# product layer. Only system.img is built and flashed; vendor, odm, kernel and system_ext stay stock.
#

# Read by vendor/lineage/config/common.mk (Circa fork): keep ro.debuggable=1 on userdebug, so adb root,
# adb remount and adb sync work natively (LineageOS sets PRODUCT_NOT_DEBUGGABLE_IN_USERDEBUG otherwise).
# Must be set before the inherit below.
CIRCA_DEBUGGABLE_USERDEBUG := true

$(call inherit-product, device/phh/treble/lineage_a64_bvN4.mk)
$(call inherit-product, device/circa/common/circa.mk)
$(call inherit-product, device/circa/aurora/aurora.mk)

PRODUCT_NAME := circa_a64_bvN4
