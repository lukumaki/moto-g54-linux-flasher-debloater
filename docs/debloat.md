# Conservative debloat on Moto G54 5G (`cancunf`)

This project uses **ADB package-manager removal for Android user 0** rather than modifying signed system partitions.

That means commands such as:

```bash
adb shell pm uninstall --user 0 PACKAGE.NAME
```

remove the package for the current user without deleting the APK from `/system`, `/product` or `/system_ext`.

For preinstalled system packages, restoration is normally possible with:

```bash
adb shell cmd package install-existing PACKAGE.NAME
```

## Packages removed in the tested setup

### Google apps intentionally not used

```text
com.google.android.apps.docs.editors.sheets
com.google.android.apps.docs.editors.docs
com.google.android.apps.docs.editors.slides
com.google.android.apps.magazines
com.google.android.apps.fitness
com.google.android.apps.podcasts
com.google.android.apps.nbu.files
com.google.android.apps.youtube.music
com.google.android.apps.tachyon
com.google.android.apps.subscriptions.red
com.google.android.apps.googleassistant
com.google.android.apps.photos
```

### Motorola / partner preload and recommendation components

```text
com.aura.oobe.motorola
com.dti.motorola
com.taboola.mip
com.glance.lockscreenM
com.motorola.brapps
com.motorola.demo
com.motorola.ccc.notification
```

### Optional Motorola features not wanted on the tested device

```text
com.motorola.gamemode
com.motorola.timeweatherwidget
com.motorola.livewallpaper3
com.motorola.spaces
```

### Meta/Facebook helper components

The Facebook application itself was kept, but the Motorola-preloaded helper packages were removed:

```text
com.facebook.appmanager
com.facebook.system
com.facebook.services
```

## Packages deliberately kept

The following packages were kept because they are either useful, integrated into Settings, or potentially tied to stock-ROM functionality:

```text
com.google.android.apps.safetyhub
com.google.android.apps.wellbeing
com.motorola.audiorecorder
com.motorola.help
com.motorola.help.extlog
com.motorola.systemserver
com.motorola.actions
com.motorola.aiservices
com.motorola.appforecast
com.motorola.coresettingsext
com.motorola.android.providers.settings
com.motorola.securityhub
com.motorola.securityhubext
com.motorola.carrierconfig
com.motorola.carriersettingsext
com.motorola.rcsConfigService
com.motorola.entitlement
com.motorola.smart5g
com.motorola.thermalservice
com.motorola.android.fota
com.motorola.ccc.ota
```

The list above is intentionally conservative. A package being removable on another Motorola model does **not** mean it should be removed on this Android version or firmware build.

## Protected packages observed

Two partner packages were already disabled for Android user 0 and were left in that state:

```text
com.amazon.appmanager
com.orange.aura.oobe
```

Their APKs remain part of the signed `/product` image. Trying to force-delete those files would defeat the goal of preserving a clean stock installation.

## Inspect before removing

Useful read-only commands:

```bash
adb shell pm path PACKAGE.NAME
adb shell dumpsys package PACKAGE.NAME
adb shell pm list packages -d
adb shell pm list packages -e
```

A package path under `/product/priv-app`, `/system/priv-app`, or `/system_ext/priv-app` means it is a privileged system package. That alone does not make it unsafe to disable or remove for user 0, but it is a reason to inspect dependencies first.

## Verify after a debloat batch

After removing a group of packages:

```bash
adb reboot
```

Then verify that the intended packages remain absent:

```bash
adb shell pm list packages | grep -Ei 'PACKAGE1|PACKAGE2|PACKAGE3'
```

Also check the phone manually for:

- Settings pages still opening normally
- mobile data / calls / SMS
- Wi-Fi and Bluetooth
- camera
- Motorola gestures and battery settings
- Play Store and Google services
- OTA update functionality

## General rule

Do not debloat just to make the package count smaller. Once promotional software and genuinely unwanted user-facing features are gone, further removal gives diminishing returns and increases the chance of breaking stock-ROM integration.
