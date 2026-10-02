# device/circa

The Circa product layer: a LineageOS 23.2 (Android 16) build for a round smartwatch, made from the
TrebleDroid a64 GSI. Everything that used to be patched into a prebuilt GSI after the build (image edits,
a root module, overlays installed from /data, adb setup) is declared here.

## Products

| Lunch target | What |
|---|---|
| `circa_a64_bvN4-bp4a-userdebug` | the watch: `lineage_a64_bvN4` (a64 GSI, vanilla, ext4) + `common/` + `aurora/`. `m systemimage` |
| `circa_sdk_phone_x86_64-bp4a-userdebug` | the emulator: `lineage_sdk_phone_x86_64` + `common/`. `m && m emu_img_zip`; build with `SELINUX_IGNORE_NEVERALLOWS=true` |

Own product names (not `lineage_a64_bvN4` + an inherit) so the stock Lineage targets stay buildable from
the same tree for comparison, and so the build identity (`ro.product.*.name`, fingerprint) says which image
is on the device. `PRODUCT_DEVICE` is unchanged, so the `out/target/product/<device>` directories are
shared with the stock targets.

Needs these Circa forks: `vendor/lineage` (`CIRCA_DEBUGGABLE_USERDEBUG`, keeps `ro.debuggable=1` on
userdebug) and `device/phh/treble` (`ro.phh.securize.default`, the `/metadata` fix).

## Layout

| Path | What |
|---|---|
| `common/circa.mk` | shared layer: overlays, features, package removals, props, private parts |
| `common/overlay/` | static RROs: `CircaFrameworkOverlay` (round display, AOD available, gestural nav, deep-idle policy), `CircaSystemUIOverlay` (status bar padding, round PIN bouncer), `CircaSettingsProviderOverlay` (first-boot defaults) |
| `common/permissions/` | `circa-features.xml` (`android.software.app_widgets`) |
| `common/removals/` | `CircaRemovePackages`: overrides phone-only packages |
| `apps/` | config for the Circa apps (launcher overlay, privapp/default permissions, sysconfig); installed only with the apps |
| `aurora/` | watch-only: securize off, system_ext SELinux merge (`aurora/sepolicy/`) |
| `emulator/` | the emulator product |

## Properties and defaults

| Setting | Mechanism |
|---|---|
| `ro.debuggable=1` on userdebug | `CIRCA_DEBUGGABLE_USERDEBUG := true` (vendor/lineage fork) |
| securize off | `ro.phh.securize.default=0` (device/phh/treble fork) |
| adb key auth | `ro.adb.secure=1` (Lineage default) + `PRODUCT_ADB_KEYS` from the private directory |
| wireless adb | `service.adb.tcp.port=5555` (adbd listens on TCP from its start) |
| density 160 | `ro.sf.lcd_density=160` in product properties (loaded after vendor/odm, so it wins). The emulator's `qemu.sf.lcd_density` (AVD `hw.lcd.density`) still takes precedence there |
| no setup wizard | LineageSetupWizard removed, `ro.setupwizard.mode=DISABLED`, `def_device_provisioned` / `def_user_setup_complete` = true |
| orientation locked | `def_accelerometer_rotation=false` |
| Bluetooth on, Wi-Fi on, 30 s timeout | `def_bluetooth_on`, `def_wifi_on`, `def_screen_off_timeout` |
| AOD on | `config_dozeAlwaysOnDisplayAvailable/Enabled=true` (+ the launcher's dream as `config_dozeComponent` when the apps are present) |
| crown short press | `config_shortPressOnStemPrimaryBehavior=2` + target activity (apps overlay). This is also the default of `stem_primary_button_short_press` |
| deep idle | `config_autoPowerModeUseMotionSensor=false` (no significant-motion sensor on the watch), `config_autoPowerModePrefetchLocation=false` |

Settings defaults only apply to a fresh `/data`; an existing `/data` keeps its values.

## Removed packages

`CircaRemovePackages` overrides (does not install) these:

| Package | Why it goes | Depends on it |
|---|---|---|
| Dialer, messaging | telephony UI; no calls or SMS on the watch | Telecom/TeleService stay (the framework expects the phone process); no default dialer/SMS role holder is fine |
| Contacts | address book UI; ContactsProvider stays | nothing in the image |
| Aperture (+ its lens launcher and overlay) | camera app; no camera | nothing |
| Glimpse, Gallery2 | galleries; no camera, no photos | nothing |
| Jelly | phone browser; the WebView stays | nothing |
| Etar | calendar UI; CalendarProvider stays | nothing |
| Camelot | PDF viewer | nothing |
| PhotoTable | photo screensaver; the AOD dream is the launcher's | nothing |
| Backgrounds, ThemePicker | wallpaper and style pickers; the watch face draws its own background | Settings' "Wallpaper & style" entry has no target |
| LineageSetupWizard | first-boot setup; replaced by the defaults above | nothing (it overrides AOSP Provision itself) |
| Launcher3QuickStep, Launcher3Overlay | overridden by the Circa launcher module (not here), so a build without our apps keeps a launcher | Quickstep is the recents provider (`config_recentsComponentName`) and handles the swipe-up-home gesture; back (edge swipe) is SystemUI's and keeps working. Home is the crown |

Kept on purpose: SystemUI, Settings, SettingsProvider, PermissionController, PackageInstaller, DocumentsUI,
Bluetooth, Shell, TeleService/Telecom, LatinIME (text input), DeskClock (alarms, timers), WebView.
Candidates for later (not phone-only, so not removed yet): ExactCalculator, Recorder, Twelve (music),
AudioFX, EmergencyInfo, LiveWallpapersPicker, Stk/SimAppDialog/CellBroadcast (telephony stack; check
first whether anything binds them).

## Private parts

Our apps and the adb key are not in this repository. They live in `vendor/circa-private/`, a plain local
directory that no manifest includes. If present, `common/circa.mk` inherits
`vendor/circa-private/circa-private.mk`, which is expected to:

* add the app modules to `PRODUCT_PACKAGES`: `android_app_import` modules, `privileged: true`,
  `product_specific: true` (the permission files here are product-partition files and only apply to
  product priv-apps), with `required:` the matching modules from `apps/Android.bp`. The launcher module
  `overrides` `Launcher3QuickStep` and `Launcher3Overlay`.
* set `PRODUCT_ADB_KEYS` to an `adb_keys` file in that directory.
* provide the stock system_ext SELinux inputs for `aurora/sepolicy` (see there).

Without it the products still build: no Circa apps (Launcher3 stays), no baked-in adb key, no SELinux merge.

## Not here (yet)

* `build/make`: `BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true` for the `generic` board (a local
  commit; it is a board variable, which a product makefile cannot set).
* Quick doze at screen-off (Wear's deep-idle path that ignores motion) needs a framework change.
* Wi-Fi off by default (battery) is one value: `def_wifi_on=false` in the SettingsProvider overlay.
