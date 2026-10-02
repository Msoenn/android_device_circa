#
# Circa on the Android emulator (x86_64): the LineageOS SDK phone target plus the same Circa product
# layer as the watch. Used for fast iteration on the framework, SystemUI, overlays and our apps.
#
# The goldfish SDK product does not inherit device/phh/treble, so the TrebleDroid system/sepolicy patches
# trip AOSP neverallows: build with SELINUX_IGNORE_NEVERALLOWS=true (as the stock Lineage SDK target in
# this tree needs too).
#

# See aurora/circa_a64_bvN4.mk.
CIRCA_DEBUGGABLE_USERDEBUG := true

$(call inherit-product, vendor/lineage/build/target/product/lineage_sdk_phone_x86_64.mk)
$(call inherit-product, device/circa/common/circa.mk)

PRODUCT_NAME := circa_sdk_phone_x86_64

# Lineage's lunch derives LINEAGE_BUILD (which turns on its board config) from a "lineage_" product name
# prefix; set it here like the GSI products do.
LINEAGE_BUILD := sdk_phone_x86_64
PRODUCT_MODEL := Circa emulator (x86_64)
