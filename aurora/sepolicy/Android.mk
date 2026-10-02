#
# Circa: merge the stock system_ext SELinux policy into the GSI's system_ext policy at build time.
#
# The files under /system/system_ext/etc/selinux are installed by system/sepolicy (Soong). Two rules
# can't install the same path, so this rewrites the installed copies in place after they are
# installed and before the system image is packed:
#   1. copy the files that selinux_policy_system_ext installs (from their built copies, so a rerun
#      never merges twice) into a work dir,
#   2. merge the stock files into them (circa_sepolicy_merge, see merge_system_ext_sepolicy.py),
#   3. copy the result over the installed files, then touch a stamp.
# The system image, its staging dir and installed-files.txt depend on that stamp.
#
# Only active when the product lists circa_system_ext_sepolicy (sepolicy.mk adds it when the
# stock files are staged), so other products and public checkouts are unaffected.
#

LOCAL_PATH := $(call my-dir)

circa_se_stock := vendor/circa-private/sepolicy-stock

ifneq ($(filter circa_system_ext_sepolicy,$(PRODUCT_PACKAGES)),)
ifneq ($(wildcard $(circa_se_stock)/selinux/system_ext_sepolicy.cil),)

circa_se_dir := $(TARGET_OUT_SYSTEM_EXT)/etc/selinux
circa_se_work := $(call intermediates-dir-for,FAKE,circa_system_ext_sepolicy)/merge
circa_se_stamp := $(circa_se_work).stamp
circa_se_tool := $(HOST_OUT_EXECUTABLES)/circa_sepolicy_merge

# built:installed pairs of everything selinux_policy_system_ext puts into etc/selinux.
circa_se_pairs := $(sort \
    $(foreach m,$(ALL_MODULES.selinux_policy_system_ext.REQUIRED_FROM_TARGET), \
        $(foreach p,$(ALL_MODULES.$(m).BUILT_INSTALLED), \
            $(if $(filter $(circa_se_dir)/%,$(call word-colon,2,$(p))),$(p)))))
ifeq ($(filter %:$(circa_se_dir)/system_ext_sepolicy.cil,$(circa_se_pairs)),)
$(error circa_system_ext_sepolicy: found no installed system_ext_sepolicy.cil in selinux_policy_system_ext)
endif

circa_se_stock_files := \
    $(filter-out %/mapping,$(wildcard $(circa_se_stock)/selinux/* $(circa_se_stock)/selinux/mapping/*)) \
    $(circa_se_stock)/vendor_plat_sepolicy_vers.txt \
    $(circa_se_stock)/build_id.txt

$(circa_se_stamp): PRIVATE_PAIRS := $(circa_se_pairs)
$(circa_se_stamp): PRIVATE_DIR := $(circa_se_dir)
$(circa_se_stamp): PRIVATE_WORK := $(circa_se_work)
$(circa_se_stamp): PRIVATE_STOCK := $(circa_se_stock)
$(circa_se_stamp): PRIVATE_TOOL := $(circa_se_tool)
$(circa_se_stamp): $(circa_se_tool) $(circa_se_stock_files) \
    $(foreach p,$(circa_se_pairs),$(call word-colon,1,$(p)) $(call word-colon,2,$(p)))
	@echo "Circa: merging stock system_ext sepolicy into $(PRIVATE_DIR)"
	$(hide) rm -rf $(PRIVATE_WORK) && mkdir -p $(PRIVATE_WORK)/gsi
	$(hide) $(foreach p,$(PRIVATE_PAIRS), \
	    f=$(patsubst $(PRIVATE_DIR)/%,%,$(call word-colon,2,$(p))) && \
	    mkdir -p $(PRIVATE_WORK)/gsi/$$(dirname $$f) && \
	    cp $(call word-colon,1,$(p)) $(PRIVATE_WORK)/gsi/$$f && ) true
	$(hide) $(PRIVATE_TOOL) $(PRIVATE_WORK)/gsi $(PRIVATE_STOCK)/selinux $(PRIVATE_WORK)/merged \
	    --ver "$$(cat $(PRIVATE_STOCK)/vendor_plat_sepolicy_vers.txt)" \
	    --stock-name "stock aurora system_ext ($$(cat $(PRIVATE_STOCK)/build_id.txt))"
	$(hide) $(foreach p,$(PRIVATE_PAIRS), \
	    f=$(patsubst $(PRIVATE_DIR)/%,%,$(call word-colon,2,$(p))) && \
	    src=$(PRIVATE_WORK)/gsi/$$f && \
	    { [ ! -f $(PRIVATE_WORK)/merged/$$f ] || src=$(PRIVATE_WORK)/merged/$$f; } && \
	    { cmp -s $$src $(call word-colon,2,$(p)) || cp -f $$src $(call word-colon,2,$(p)); } && ) true
	$(hide) touch $@

include $(CLEAR_VARS)
LOCAL_MODULE := circa_system_ext_sepolicy
LOCAL_LICENSE_KINDS := SPDX-license-identifier-Apache-2.0
LOCAL_LICENSE_CONDITIONS := notice
LOCAL_ADDITIONAL_DEPENDENCIES := $(circa_se_stamp)
include $(BUILD_PHONY_PACKAGE)

# Pack the image only after the rewrite. These targets are defined later, in build/make/core/Makefile.
$(call intermediates-dir-for,PACKAGING,system)/system.img: $(circa_se_stamp)
$(call intermediates-dir-for,PACKAGING,system)/staging_dir.stamp: $(circa_se_stamp)
$(PRODUCT_OUT)/installed-files.txt: $(circa_se_stamp)

endif
endif
