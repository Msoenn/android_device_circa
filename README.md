# device/circa

The Circa product layer: a LineageOS 23.2 (Android 16) build for a round smartwatch, made from the
TrebleDroid a64 GSI. Everything that used to be patched into a prebuilt GSI after the build (image edits,
a root module, overlays installed from /data, adb setup) is declared here.

## Products

| Lunch target | What |
|---|---|
| `circa_a64_bvN4-bp4a-userdebug` | the watch: `lineage_a64_bvN4` (a64 GSI, vanilla, ext4) + `common/` + `aurora/`. `m systemimage` |
| `lineage_sdk_circa_x86_64-bp4a-userdebug` | the emulator: `lineage_sdk_phone_x86_64` + `common/`. `m emu_img_zip` (not `droid`: its boot-jars check rejects the TrebleDroid radio classes); build with `SELINUX_IGNORE_NEVERALLOWS=true` |

Own product names (not `lineage_a64_bvN4` + an inherit) so the stock Lineage targets stay buildable from
the same tree for comparison, and so the build identity (`ro.product.*.name`, fingerprint) says which image
is on the device. The emulator keeps a `lineage_sdk_` prefix because tooling keys off it: Lineage's lunch
sets `LINEAGE_BUILD` (which loads the Lineage board config) only for `lineage_*` names, and goldfish defines
`emu_img_zip` only for `lineage_sdk_*`/`sdk_*`. The watch product inherits `LINEAGE_BUILD := GSI` from
`lineage_a64_bvN4.mk`, so it can drop the prefix. `PRODUCT_DEVICE` is unchanged, so the `out/target/product/<device>` directories are
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
| buttons | the crown's press is the POWER key, the side button is STEM_PRIMARY. Crown short press `config_shortPressOnPowerBehavior=101` (app list / face), side button short press `config_shortPressOnStemPrimaryBehavior=100` (notifications screen), side button long press `config_longPressOnStemPrimaryBehavior=100` (exercise app via `org.circa.action.EXERCISE_LONG_PRESS` if a system app has it, else the power menu); all in the apps overlay (CircaLauncherOverlay) |
| deep idle | `config_autoPowerModeUseMotionSensor=false` (no significant-motion sensor on the watch), `config_autoPowerModePrefetchLocation=false` |

Settings defaults only apply to a fresh `/data`; an existing `/data` keeps its values.

## Removed packages

`CircaRemovePackages` overrides (does not install) these:

| Package | Why it goes | Depends on it |
|---|---|---|
| Dialer, messaging | telephony UI; no calls or SMS on the watch | Telecom/TeleService stay (the framework expects the phone process); no default dialer/SMS role holder is fine |
| Contacts | address book UI; ContactsProvider stays | nothing in the image |
| Aperture (+ its lens launcher and overlay) | camera app; no camera | nothing |
| AudioFX | phone audio-effects UI; no audio output on the watch | nothing |
| DocumentsUI (Files) | **kept** (it is also the system file picker for OPEN_DOCUMENT/GET_CONTENT); only its launcher icon is hidden via sysconfig component-override | apps that pick files |
| ExactCalculator | phone calculator: 33 targets under 72 px and the RAD/menu row outside the circle; a round Circa calculator replaces it later | nothing |
| Glimpse, Gallery2 | galleries; no camera, no photos | nothing |
| Jelly | phone browser; the WebView stays | nothing |
| Etar | calendar UI; CalendarProvider stays | nothing |
| Camelot | PDF viewer | nothing |
| PhotoTable | photo screensaver; the AOD dream is the launcher's | nothing |
| Recorder | phone voice recorder; no mic capture on the watch | nothing |
| Stk | SIM Toolkit; the watch has no SIM | nothing (SimAppDialog/CellBroadcast stay) |
| Twelve | phone music player; no audio output on the watch | nothing |
| Backgrounds, ThemePicker | wallpaper and style pickers; the watch face draws its own background | Settings' "Wallpaper & style" entry has no target |
| LineageSetupWizard | first-boot setup; replaced by the defaults above | nothing (it overrides AOSP Provision itself) |
| Launcher3QuickStep, Launcher3Overlay | overridden by the Circa launcher module (not here), so a build without our apps keeps a launcher | Quickstep is the recents provider (`config_recentsComponentName`) and handles the swipe-up-home gesture; back (edge swipe) is SystemUI's and keeps working. Home is the crown's press |
| LatinIME | the phone keyboard; overridden by the Circa keyboard module (not here), so a build without our apps keeps a keyboard | nothing. It comes from `handheld_product.mk` and Lineage's `common_mobile.mk` (both products). No other IME is in either product (no OpenWnn, PinyinIME or Google keyboard: `device/phh/treble/gapps.mk` is not inherited) |

Kept on purpose: SystemUI, Settings, SettingsProvider, PermissionController, PackageInstaller,
Bluetooth, Shell, TeleService/Telecom, DeskClock (alarms, timers), WebView.
Candidates for later (not phone-only, so not removed yet): EmergencyInfo, LiveWallpapersPicker,
SimAppDialog/CellBroadcast (telephony stack; check first whether anything binds them).

## The Circa apps

The watch apps (launcher, WatchLink, Settings, Clock, Companion, Keyboard, Exercise) are in
[circa-apps](https://github.com/Msoenn/circa-apps), checked out by the Circa manifest at `vendor/circa-apps`.
They are Gradle projects; `vendor/circa-apps/build-all.sh` builds and signs them and writes the APKs plus
generated `android_app_import` modules into `vendor/circa-apps/prebuilt/`. `common/circa.mk` inherits
`vendor/circa-apps/circa-apps.mk`, which adds those modules to `PRODUCT_PACKAGES` once they exist. Each
module `require`s the matching configuration from `apps/` here (permission files are product-partition
files and only apply to product priv-apps). The launcher module `overrides` `Launcher3QuickStep` and
`Launcher3Overlay`, the keyboard module `LatinIME`, the clock module `DeskClock`.

Without `build-all.sh` (or without the project) the products still build, with no Circa apps.

## Private parts

The adb key is not in this repository. If a plain local `vendor/circa-private/` directory exists,
`common/circa.mk` inherits its `circa-private.mk`, which is expected to:

* set `PRODUCT_ADB_KEYS` to an `adb_keys` file in that directory.
* provide the stock system_ext SELinux inputs for `aurora/sepolicy` (see there).

Without it the products still build: no baked-in adb key, no SELinux merge.

The default keyboard needs no setting here. AOSP's SettingsProvider has no default for
`default_input_method`/`enabled_input_methods`; on a fresh `/data` InputMethodManagerService enables the
system IMEs that declare a keyboard subtype for the system (or English fallback) locale and selects the
first. With LatinIME overridden, the Circa keyboard is the only system IME, so it is enabled and selected
on first boot, provided its `method.xml` declares an `en`/`en_US` subtype with
`imeSubtypeMode="keyboard"`. `def_show_ime_with_hard_keyboard` stays false: neither the watch nor the
emulator AVD (`hw.keyboard=no`) has a hardware keyboard.

## Not here (yet)

* `build/make`: `BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true` for the `generic` board (a local
  commit; it is a board variable, which a product makefile cannot set).
* Quick doze at screen-off (Wear's deep-idle path that ignores motion) needs a framework change.
* Wi-Fi off by default (battery) is one value: `def_wifi_on=false` in the SettingsProvider overlay.
