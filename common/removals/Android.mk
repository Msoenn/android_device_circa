#
# Circa: phone-only packages that the inherited LineageOS/AOSP product makefiles add, removed from the
# image. PRODUCT_PACKAGES -= cannot reach entries that inherited makefiles own, so this installs nothing
# and only overrides them (overridden modules and the modules only they require are not installed).
#
# Rationale per package: README.md "Removed packages". The launcher replacement (Launcher3QuickStep) is
# not here: it is overridden by our launcher's own module, so a build without our apps keeps a launcher.
#

LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)
LOCAL_MODULE := CircaRemovePackages
LOCAL_MODULE_CLASS := APPS
LOCAL_MODULE_TAGS := optional
LOCAL_LICENSE_KINDS := SPDX-license-identifier-Apache-2.0
LOCAL_LICENSE_CONDITIONS := notice
LOCAL_OVERRIDES_PACKAGES := \
    Aperture \
    Backgrounds \
    Camelot \
    Contacts \
    Dialer \
    Etar \
    Gallery2 \
    Glimpse \
    Jelly \
    LineageSetupWizard \
    messaging \
    PhotoTable \
    ThemePicker
LOCAL_UNINSTALLABLE_MODULE := true
LOCAL_CERTIFICATE := PRESIGNED
LOCAL_SRC_FILES := /dev/null
include $(BUILD_PREBUILT)
