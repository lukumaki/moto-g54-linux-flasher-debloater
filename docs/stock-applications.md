# Stock application snapshot and decisions

This list was captured from the tested Moto G54 5G (`cancunf`) after restoring Motorola stock firmware `V1TDS35H.83-20-5-12`, updating the stock applications/services, and **before the debloat was applied**.

The complete package-manager snapshot contained 403 package entries. That raw set also contained framework services, APEX modules, resource overlays, carrier overlays and other components that are not ordinary applications. The table below therefore focuses on the recognizable stock, Motorola, Google and partner applications/components that were actually useful when making the debloat decisions.

`REMOVE` means removed only for Android user 0 with `pm uninstall --user 0`. It does **not** mean the APK was deleted from a signed partition.

`DISABLED` means the package was already observed disabled for user 0 and was left in that state.

| Package | What it represents | Decision |
|---|---|---|
| `com.amazon.appmanager` | Amazon App Manager preload | **DISABLED** |
| `com.aura.oobe.motorola` | AppCloud Motorola OOBE / recommendation component | **REMOVE** |
| `com.dti.motorola` | Motorola Ignite / dynamic preload component | **REMOVE** |
| `com.taboola.mip` | Taboola recommendation/content component | **REMOVE** |
| `com.glance.lockscreenM` | Glance Motorola lock-screen content | **REMOVE** |
| `com.orange.aura.oobe` | Orange manual-selector/OOBE component | **DISABLED** |
| `com.orange.update` | Orange update component | KEEP |
| `com.payjoy.access` | PayJoy access component present in product image | KEEP |
| `de.telekom.tsc` | App Assistant Enabler present in product image | KEEP |
| `com.facebook.appmanager` | Meta/Facebook preload helper | **REMOVE** |
| `com.facebook.system` | Meta/Facebook installer helper | **REMOVE** |
| `com.facebook.services` | Meta/Facebook services helper | **REMOVE** |
| `com.facebook.katana` | Facebook application | KEEP |
| `com.motorola.brapps` | Motorola/partner BRApps preload | **REMOVE** |
| `com.motorola.demo` | Motorola demo-mode package | **REMOVE** |
| `com.motorola.ccc.notification` | Motorola CCC notification component | **REMOVE** |
| `com.motorola.gamemode` | Motorola Game Mode | **REMOVE** |
| `com.motorola.timeweatherwidget` | Motorola time/weather widget | **REMOVE** |
| `com.motorola.livewallpaper3` | Motorola live wallpapers | **REMOVE** |
| `com.motorola.spaces` | Motorola Spaces | **REMOVE** |
| `com.motorola.audiorecorder` | Motorola audio recorder | KEEP |
| `com.motorola.help` | Motorola Help | KEEP |
| `com.motorola.help.extlog` | Motorola Feedback/extended logging used by Help | KEEP |
| `com.motorola.moto` | Moto application | KEEP |
| `com.motorola.actions` | Moto Actions | KEEP |
| `com.motorola.aiservices` | Motorola AI services | KEEP |
| `com.motorola.appforecast` | Motorola App Forecast | KEEP |
| `com.motorola.camera3` | Motorola Camera | KEEP |
| `com.motorola.camera3.content.ai` | Motorola camera AI component | KEEP |
| `com.motorola.screenshoteditor` | Motorola screenshot editor | KEEP |
| `com.motorola.fmplayer` | Motorola FM player | KEEP |
| `com.motorola.android.fmradio` | Motorola FM radio service | KEEP |
| `com.motorola.dolby.dolbyui` | Motorola Dolby UI | KEEP |
| `com.dolby.daxservice` | Dolby audio service | KEEP |
| `com.motorola.faceunlock` | Motorola face unlock | KEEP |
| `com.motorola.batterycare` | Motorola Battery Care | KEEP |
| `com.motorola.securityhub` | Motorola Security Hub | KEEP |
| `com.motorola.securityhubext` | Motorola Security Hub extension | KEEP |
| `com.motorola.securevault` | Motorola Secure Vault | KEEP |
| `com.motorola.smart5g` | Motorola Smart 5G | KEEP |
| `com.motorola.thermalservice` | Motorola thermal service | KEEP |
| `com.motorola.android.fota` | Motorola FOTA | KEEP |
| `com.motorola.ccc.ota` | Motorola OTA component | KEEP |
| `com.motorola.carrierconfig` | Motorola carrier configuration | KEEP |
| `com.motorola.carriersettingsext` | Motorola carrier-settings extension | KEEP |
| `com.motorola.rcsConfigService` | Motorola RCS configuration service | KEEP |
| `com.motorola.entitlement` | Motorola entitlement service | KEEP |
| `com.motorola.systemserver` | Motorola system-server integration | KEEP |
| `com.motorola.coresettingsext` | Motorola Settings integration | KEEP |
| `com.motorola.android.providers.settings` | Motorola Settings provider | KEEP |
| `com.motorola.launcher3` | Motorola launcher | KEEP |
| `com.motorola.personalize` | Motorola personalization | KEEP |
| `com.motorola.gesture` | Motorola gesture-navigation tutorial/integration | KEEP |
| `com.google.android.apps.docs.editors.sheets` | Google Sheets | **REMOVE** |
| `com.google.android.apps.docs.editors.docs` | Google Docs editor | **REMOVE** |
| `com.google.android.apps.docs.editors.slides` | Google Slides | **REMOVE** |
| `com.google.android.apps.magazines` | Google News | **REMOVE** |
| `com.google.android.apps.fitness` | Google Fit | **REMOVE** |
| `com.google.android.apps.podcasts` | Google Podcasts | **REMOVE** |
| `com.google.android.apps.nbu.files` | Files by Google | **REMOVE** |
| `com.google.android.apps.youtube.music` | YouTube Music | **REMOVE** |
| `com.google.android.apps.tachyon` | Google Meet | **REMOVE** |
| `com.google.android.apps.subscriptions.red` | Google One | **REMOVE** |
| `com.google.android.apps.googleassistant` | Google Assistant application | **REMOVE** |
| `com.google.android.apps.photos` | Google Photos | **REMOVE** |
| `com.google.android.apps.docs` | Google Drive | KEEP |
| `com.google.android.videos` | Google TV | KEEP |
| `com.google.android.apps.wallpaper` | Google Wallpapers | KEEP |
| `com.google.android.youtube` | YouTube | KEEP |
| `com.google.android.apps.maps` | Google Maps | KEEP |
| `com.google.android.apps.wellbeing` | Digital Wellbeing | KEEP |
| `com.google.android.apps.safetyhub` | Personal Safety / Safety Hub | KEEP |
| `com.google.android.gm` | Gmail | KEEP |
| `com.google.android.calendar` | Google Calendar | KEEP |
| `com.google.android.contacts` | Google Contacts | KEEP |
| `com.google.android.apps.messaging` | Google Messages | KEEP |
| `com.google.android.dialer` | Google Phone | KEEP |
| `com.google.android.deskclock` | Google Clock | KEEP |
| `com.google.android.calculator` | Google Calculator | KEEP |
| `com.google.android.inputmethod.latin` | Gboard | KEEP |
| `com.android.chrome` | Chrome | KEEP |
| `com.android.vending` | Google Play Store | KEEP |
| `com.google.android.gms` | Google Play services | KEEP |
| `com.google.android.gsf` | Google Services Framework | KEEP |
| `com.google.android.webview` | Android System WebView | KEEP |
| `com.google.ar.core` | Google Play Services for AR / ARCore | KEEP |

## Why framework packages are not presented as "bloat"

The original package snapshot also contained hundreds of entries such as Android providers, telephony services, MediaProvider, Bluetooth, Wi-Fi resources, APEX modules, Motorola resource overlays, carrier overlays and Settings/SystemUI components.

They were intentionally not turned into an aggressive removal list. The goal of this project is a stable stock device, not the smallest possible output from `pm list packages`.

## Watch out for Google Play auto-restore on a fresh flash

After later flashing the Motorola Software Fix build `V1TDS35H.83-20-5-8-4` (see the [README](../README.md#firmware-builds-documented-here)) and signing back into a Google account, a raw `pm list packages` snapshot on that device showed **489** packages instead of the 403 seen on the original `V1TDS35H.83-20-5-12` restore.

The extra packages were not part of the firmware. Cross-checking the third-party subset (`pm list packages -3`, 96 entries) against this file's original 403-package reference (`reference/all-packages.txt`) split cleanly in two:

- **10 third-party packages matched** entries already present in the original stock snapshot — genuine Motorola/carrier-bundled apps such as `com.facebook.katana`, `com.brave.browser`, `com.google.android.apps.docs.editors.{docs,sheets,slides}`, `com.google.android.apps.{fitness,podcasts,adm,walletnfcrel}`.
- **86 third-party packages did not exist** in the original firmware snapshot at all — recognizable personal apps (`com.whatsapp`, `com.instagram.android`, `com.spotify.music`, `com.anthropic.claude`, `com.openai.chatgpt`, `com.bitwarden.authenticator`, several Greek banking/government/utility apps, and similar).

Removing exactly those 86 packages from the 489-package snapshot reproduced the original 403-package list **exactly**, name for name. This confirms two things: `V1TDS35H.83-20-5-8-4` ships the identical stock application set as `V1TDS35H.83-20-5-12`, and the 86 extra packages came entirely from Google Play's "restore apps" feature reinstalling the signed-in account's previously-used apps — not from the firmware.

**Practical guidance:** if you sign into Google before capturing a `packages-before` snapshot on a fresh flash, expect it to be polluted with your own previously-installed apps. Either capture the snapshot before adding a Google account, or diff the third-party subset (`pm list packages -3`) against [`reference/all-packages.txt`](../reference/all-packages.txt) to separate genuine stock/carrier bundles from auto-restored personal apps before making any debloat decisions from it.

## Capture your own before-state

Before changing a different firmware build, create your own snapshots:

```bash
adb shell pm list packages | sort > packages-before.txt
adb shell pm list packages -f | sort > packages-with-paths-before.txt
adb shell pm list packages -d | sort > packages-disabled-before.txt
adb shell pm list packages -3 | sort > packages-third-party-before.txt
```

Those files are more useful than blindly assuming another region or later firmware has exactly the same preload set.
