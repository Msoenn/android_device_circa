#
# Merge the stock system_ext SELinux policy into the GSI's system_ext policy (see README.md).
# Only when the stock files are staged; without them the GSI's own policy is installed unchanged.
#

ifneq ($(wildcard vendor/circa-private/sepolicy-stock/selinux/system_ext_sepolicy.cil),)
ifneq ($(wildcard vendor/circa-private/sepolicy-stock/vendor_plat_sepolicy_vers.txt),)
PRODUCT_PACKAGES += \
    circa_system_ext_sepolicy
endif
endif
