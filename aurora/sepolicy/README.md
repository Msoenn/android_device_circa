# Stock system_ext SELinux policy on the GSI

The watch keeps its stock vendor, odm and system_ext partitions, but the GSI never mounts the stock
system_ext: `/system_ext` is `/system/system_ext` inside system.img. The stock system_ext policy
(service labels and rules for the vendor `vendor.google_clockwork.*` HALs) is then never loaded, the
HALs can't register with servicemanager and boot hangs.

So the stock system_ext policy is merged into the GSI's own `/system/system_ext/etc/selinux` at build
time:

- `merge_system_ext_sepolicy.py` (host tool `circa_sepolicy_merge`) does the merge. Stock
  `base_typeattr_N` attributes are renamed to `base_typeattr_N_aurora` (their numbers collide with the
  GSI's, and init compiles with `secilc -m`), neverallows on stock-plat attributes are dropped,
  context files get the stock entries the GSI lacks, and `system_ext_sepolicy_and_mapping.sha256` is
  regenerated for the merged cil + mapping (so init compiles the policy on the device instead of using
  the stock precompiled one).
- `Android.mk` (module `circa_system_ext_sepolicy`) rewrites the installed files in place after
  system/sepolicy installs them; the system image depends on it. See the comment there for why.
- `sepolicy.mk` adds the module to the watch product.

The stock files are Google's and are not part of this repository. They are staged locally into
`vendor/circa-private/sepolicy-stock/`:

    sepolicy-stock/selinux/                       stock system_ext /etc/selinux
    sepolicy-stock/vendor_plat_sepolicy_vers.txt  /etc/selinux/plat_sepolicy_vers.txt from stock vendor
    sepolicy-stock/build_id.txt                   ro.system_ext.build.id of the stock system_ext

Without that directory nothing is merged and the GSI's own system_ext policy is installed unchanged.
