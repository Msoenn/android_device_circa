#
# Circa products.
#
#   circa_a64_bvN4         the watch image (a64 GSI system.img, vanilla, ext4) = lineage_a64_bvN4 + Circa
#   circa_sdk_phone_x86_64 the emulator image = lineage_sdk_phone_x86_64 + Circa
#
# lunch circa_a64_bvN4-bp4a-userdebug
# lunch circa_sdk_phone_x86_64-bp4a-userdebug
#

PRODUCT_MAKEFILES := \
    $(LOCAL_DIR)/aurora/circa_a64_bvN4.mk \
    $(LOCAL_DIR)/emulator/circa_sdk_phone_x86_64.mk
