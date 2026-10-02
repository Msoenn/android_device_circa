#
# Watch-only parts of the Circa layer (things the emulator must not get).
#

# Securize (device/phh/treble rw-system.sh/phh-on-boot.sh) makes a userdebug GSI look like a locked user
# build at boot: ro.debuggable=0, release-keys, vendor fingerprints. Off on Circa (needs the Circa
# device/phh/treble fork, which reads this property).
PRODUCT_SYSTEM_PROPERTIES += \
    ro.phh.securize.default=0

# The stock system_ext SELinux policy (vendor.google_clockwork.* HAL services), merged into the GSI's
# system_ext policy at build time. Inputs are staged privately; see sepolicy/README.md.
-include device/circa/aurora/sepolicy/sepolicy.mk
