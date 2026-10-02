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

# The name keeps the "lineage_sdk_" prefix on purpose: Lineage's lunch only sets LINEAGE_BUILD (which
# loads the Lineage board config) for "lineage_*" products, and goldfish only defines emu_img_zip for
# "lineage_sdk_*"/"sdk_*" products.
PRODUCT_NAME := lineage_sdk_circa_x86_64
PRODUCT_MODEL := Circa emulator (x86_64)
