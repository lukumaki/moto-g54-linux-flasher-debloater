# Conservative debloat on Moto G54 5G (`cancunf`)

This section documents the **actual debloat process performed on the restored stock ROM**, not a generic Motorola debloat list.

Test environment:

```text
Host OS: Debian 13 (Trixie)
Device: Moto G54 5G (cancunf)
Firmware: V1TDS35H.83-20-5-12
Android: 15
```

The guiding rule was simple: remove promotional or genuinely unwanted applications while keeping stock stability, telephony, OTA, Settings integration, Google services and security-related Motorola components intact.

**Before you start:** if you have already signed into a Google account on this flash, your `packages-before` snapshot can include dozens of your own previously-installed apps that Google Play silently reinstalled, not anything from the firmware. See [`stock-applications.md`, "Watch out for Google Play auto-restore on a fresh flash"](stock-applications.md#watch-out-for-google-play-auto-restore-on-a-fresh-flash) before treating every package in that snapshot as stock. It does not change which packages get removed below — the removal list here is fixed and does not touch third-party/personal apps — but it matters if you are deciding whether to remove anything *beyond* this list on your own device.

An automated script that performs the exact removal batches below, with its own logging, is described in [section 15](#15-automated-script). The manual steps that follow remain the documented reasoning for each decision.

## 1. Capture the stock state first

Before removing anything, capture package lists so you can compare the before/after state later:

```bash
adb shell pm list packages | sort > packages-before.txt
adb shell pm list packages -f | sort > packages-with-paths-before.txt
adb shell pm list packages -d | sort > packages-disabled-before.txt
adb shell pm list packages -3 | sort > packages-third-party-before.txt
```

On the tested device the full package-manager snapshot contained hundreds of Android, Google, Motorola, carrier, overlay and APEX entries. A readable application-focused version with the decisions made for this device is in:

[`stock-applications.md`](stock-applications.md)

## 2. Keep the phone awake during the session

For a long ADB session it is convenient to prevent the display from sleeping while the phone remains powered over USB:

```bash
adb shell svc power stayon true
```

When finished:

```bash
adb shell svc power stayon false
```

This avoids repeatedly unlocking the phone while checking Settings, Play Store or application behaviour between debloat batches.

## 3. Removal method

This project uses Android Package Manager removal for **user 0**:

```bash
adb shell pm uninstall --user 0 PACKAGE.NAME
```

This is intentionally different from deleting an APK from `/system`, `/product` or `/system_ext`.

For a preinstalled system package, the APK normally remains present in the signed system image and can usually be made available to user 0 again with:

```bash
adb shell cmd package install-existing PACKAGE.NAME
```

A factory reset also normally recreates the Android user state from the signed system image.

## 4. What does `Success` mean?

For a command such as:

```bash
adb shell pm uninstall --user 0 com.google.android.apps.photos
```

Android Package Manager may return:

```text
Success
```

In this context `Success` means the package-manager operation for user 0 succeeded. It does **not** mean the system APK was physically erased from the phone's signed partitions.

That distinction is one of the reasons this method was chosen.

A failure should be inspected rather than worked around blindly. For example, during the tested session `com.amazon.appmanager` returned a package-manager failure when an uninstall was attempted. Inspection showed that the package lived under `/product/priv-app` and was already disabled for user 0, so it was simply left disabled.

One specific non-`Success` result is benign and worth calling out on its own: `Failure [not installed for 0]` means the package was already removed for user 0 before this command ran — typically because a previous debloat pass (or a previous run of `debloat-cancunf.sh`) already removed it. There is nothing left to do; the end state is identical to a fresh successful removal. `debloat-cancunf.sh` recognizes this exact message and reports it as `ALREADY REMOVED` rather than `FAILED`, so re-running the script on an already-debloated phone doesn't produce a wall of misleading failures.

## 5. First removal batch

The first conservative batch removed unwanted Google applications and obvious partner/recommendation components:

```bash
adb shell pm uninstall --user 0 com.google.android.apps.docs.editors.sheets
adb shell pm uninstall --user 0 com.google.android.apps.docs.editors.docs
adb shell pm uninstall --user 0 com.google.android.apps.docs.editors.slides
adb shell pm uninstall --user 0 com.google.android.apps.magazines
adb shell pm uninstall --user 0 com.google.android.apps.fitness
adb shell pm uninstall --user 0 com.google.android.apps.podcasts
adb shell pm uninstall --user 0 com.google.android.apps.nbu.files
adb shell pm uninstall --user 0 com.google.android.apps.youtube.music
adb shell pm uninstall --user 0 com.aura.oobe.motorola
adb shell pm uninstall --user 0 com.dti.motorola
adb shell pm uninstall --user 0 com.taboola.mip
adb shell pm uninstall --user 0 com.glance.lockscreenM
```

All of these returned `Success` on the tested device.

### Amazon App Manager

An attempt was also made against:

```text
com.amazon.appmanager
```

Inspection showed:

```text
/product/priv-app/AmazonAppManager/AmazonAppManager.apk
```

and the package was already disabled for Android user 0. It was therefore left in the signed product image and left disabled.

Useful inspection commands were:

```bash
adb shell pm path com.amazon.appmanager
adb shell dumpsys package com.amazon.appmanager
adb shell pm list packages -d | grep amazon
adb shell pm list packages -e | grep amazon
```

## 6. Check incidental grep matches instead of deleting them

After rebooting, broad searches can find packages whose names merely contain similar words. They should not automatically be removed.

For example, the post-debloat inspection encountered:

```text
com.google.android.overlay.modules.healthfitness.forframework
```

This was recognized as a framework overlay and kept.

Likewise:

```text
com.orange.aura.oobe
```

was inspected and found at:

```text
/product/priv-app/OrangeManualSelector/OrangeManualSelector.apk
```

It was already disabled for user 0 and was left that way.

## 7. Google One and Google Meet

After confirming the first batch behaved normally, two additional Google applications were removed:

```bash
adb shell pm uninstall --user 0 com.google.android.apps.subscriptions.red
adb shell pm uninstall --user 0 com.google.android.apps.tachyon
```

Both returned:

```text
Success
```

## 8. Second removal batch

A second pass targeted additional promotional/optional Motorola packages and Meta helper packages:

```bash
adb shell pm uninstall --user 0 com.motorola.brapps
adb shell pm uninstall --user 0 com.motorola.demo
adb shell pm uninstall --user 0 com.motorola.ccc.notification
adb shell pm uninstall --user 0 com.facebook.appmanager
adb shell pm uninstall --user 0 com.facebook.system
adb shell pm uninstall --user 0 com.facebook.services
adb shell pm uninstall --user 0 com.motorola.gamemode
adb shell pm uninstall --user 0 com.motorola.timeweatherwidget
adb shell pm uninstall --user 0 com.motorola.livewallpaper3
adb shell pm uninstall --user 0 com.motorola.spaces
adb shell pm uninstall --user 0 com.google.android.apps.googleassistant
adb shell pm uninstall --user 0 com.google.android.apps.photos
```

All of these returned:

```text
Success
```

The Facebook application itself was **not** removed; only the preloaded helper packages were removed.

## 9. Packages deliberately kept

Some packages may look removable at first glance but were deliberately retained.

Examples:

```text
com.google.android.apps.safetyhub
com.google.android.apps.wellbeing
com.motorola.audiorecorder
com.google.android.apps.docs
com.google.android.videos
com.google.android.apps.wallpaper
com.google.android.youtube
com.google.android.apps.maps
com.motorola.help
```

Motorola Help was inspected more deeply because it is a privileged updated system application. It integrates with Settings/help/feedback flows and has relationships with Motorola logging/support components, so it was kept rather than removed merely to reduce package count.

Core Motorola packages tied to OTA, telephony, carrier configuration, security, Settings and system integration were also kept, including examples such as:

```text
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

## 10. Inspect before removing an unfamiliar package

Useful read-only commands:

```bash
adb shell pm path PACKAGE.NAME
adb shell dumpsys package PACKAGE.NAME
adb shell pm list packages -d
adb shell pm list packages -e
```

A package path such as:

```text
/product/priv-app/...
/system/priv-app/...
/system_ext/priv-app/...
```

shows that it is a privileged/system component. That does not automatically mean it cannot be disabled for user 0, but it is a strong reason to inspect its purpose and dependencies first.

## 11. Verify after each batch

Reboot after a meaningful group of removals:

```bash
adb reboot
```

Then verify the intended package state. For a single package:

```bash
adb shell pm list packages com.google.android.apps.photos
```

For several packages:

```bash
adb shell pm list packages | grep -Ei 'photos|tachyon|youtube.music|taboola|glance'
```

Do not assume every grep result is the application you meant to remove; overlays and framework components can share similar terms.

Also test the phone manually:

- Settings pages open normally
- calls and SMS work
- mobile data works
- Wi-Fi works
- Bluetooth works
- camera works
- Motorola gestures/settings still work
- Play Store and Google Play services work
- notifications work
- OTA update functionality remains present

## 12. Compare before and after

Capture the state again:

```bash
adb shell pm list packages | sort > packages-after.txt
adb shell pm list packages -d | sort > packages-disabled-after.txt
adb shell pm list packages -3 | sort > packages-third-party-after.txt
```

Then compare:

```bash
diff -u packages-before.txt packages-after.txt
```

This gives you an auditable record of exactly what changed.

## 13. Restore a removed system package

For a system package removed only for user 0:

```bash
adb shell cmd package install-existing PACKAGE.NAME
```

For example:

```bash
adb shell cmd package install-existing com.google.android.apps.photos
```

Check the result:

```bash
adb shell pm list packages com.google.android.apps.photos
```

## 14. Optional: post-Google-sign-in bundled/junk apps (verify before running)

Sections 5, 7 and 8 remove packages that are part of every install of this stock firmware. This section is different: comparing successive post-flash, post-Google-sign-in `packages-before` snapshots on the tested device against the documented 403-package stock baseline (see the auto-restore note above) turned up a small set of packages that are neither stock firmware nor apps the device's owner intentionally installed — the same seven casual games appeared consistently across separate restore sessions on the same account:

```text
ball.sort.puzzle.color.sorting.bubble.games
com.block.juggle
com.king.candycrushsaga
com.nebula.mahjongtile
com.vitastudio.mahjong
com.oakever.tiletrip
com.oakever.arrows
```

Two more packages were judged the same way and added on the device owner's decision:

```text
ringtonesforandroidphonefree.ringtones.ringtonessongs.ringtonesapp
com.motorola.lmsaappclient
```

`ringtonesforandroidphonefree...` is a generic free-ringtones app matching the same spam-adjacent partner-junk pattern as `com.taboola.mip` (section 5). `com.motorola.lmsaappclient` is a Motorola-branded "Smart Assistant" client — not a game, and its exact purpose was not independently investigated, but it was absent from the stock 403-package snapshot the same way the games were.

Two more were added later, for the same reason — absent from the stock baseline, so account-dependent rather than guaranteed present:

```text
com.google.android.apps.bard
com.google.android.apps.photosgo
```

`com.google.android.apps.bard` is Google Gemini; `com.google.android.apps.photosgo` is the lightweight "Google Photos Go" variant. See [section 16](#16-additional-stockdiagnosticfeature-components-community-list) for how these were identified.

**Unlike sections 5, 7 and 8, this batch is not guaranteed present on every device.** Whether these specific packages appear depends on the signed-in Google account's own app/restore history and/or Motorola's region-specific bundled-app promotions, not the firmware itself. Check what's actually present before removing anything:

```bash
adb shell pm list packages | grep -E 'ball\.sort\.puzzle|block\.juggle|candycrushsaga|nebula\.mahjongtile|vitastudio\.mahjong|oakever\.tiletrip|oakever\.arrows|ringtonesforandroidphonefree|motorola\.lmsaappclient|apps\.bard|apps\.photosgo'
```

Remove only what's confirmed present:

```bash
adb shell pm uninstall --user 0 ball.sort.puzzle.color.sorting.bubble.games
adb shell pm uninstall --user 0 com.block.juggle
adb shell pm uninstall --user 0 com.king.candycrushsaga
adb shell pm uninstall --user 0 com.nebula.mahjongtile
adb shell pm uninstall --user 0 com.vitastudio.mahjong
adb shell pm uninstall --user 0 com.oakever.tiletrip
adb shell pm uninstall --user 0 com.oakever.arrows
adb shell pm uninstall --user 0 ringtonesforandroidphonefree.ringtones.ringtonessongs.ringtonesapp
adb shell pm uninstall --user 0 com.motorola.lmsaappclient
adb shell pm uninstall --user 0 com.google.android.apps.bard
adb shell pm uninstall --user 0 com.google.android.apps.photosgo
```

`debloat-cancunf.sh` runs this as its own separate, clearly-labeled Stage 4 (see [section 15](#15-automated-script)) — kept apart from the core 26-package removal precisely because it is account/region-specific rather than guaranteed stock, and the script checks each package's presence before attempting to remove it.

## 15. Automated script

[`debloat-cancunf.sh`](../debloat-cancunf.sh) automates the three core removal batches documented above (sections 5, 7 and 8 — 26 packages in total, in the same order), the optional post-Google-sign-in batch from section 14, the additional stock/diagnostic/feature batch from section 16, plus the before/after snapshotting and comparison from sections 1 and 12.

It is guarded the same way as the firmware flashers in this repository:

- refuses to run unless exactly one authorized `adb` device is connected and reports `ro.product.device` as `cancunf`;
- prints the full list of packages it is about to remove and requires typing `YES` before doing anything;
- pauses after each batch so you can reboot and manually test the phone before continuing, exactly as this document recommends;
- captures `pm list packages`, `-f`, `-d` and `-3` snapshots before and after into a timestamped `debloat-logs/<timestamp>/` directory, along with a `diff -u` between the before/after package lists and a per-package OK/FAILED result log;
- warns (without stopping) if the before-snapshot package count is higher than this project's documented 403-package stock baseline, pointing at the Google Play auto-restore note above, since that is a sign the device's third-party package list may include your own apps rather than firmware;
- treats a single failed `pm uninstall` as non-fatal — it is logged and reported at the end rather than aborting the run, since a genuinely bad removal is reversible with `adb shell cmd package install-existing` and the point of this project is inspection, not blind automation;
- distinguishes a package already removed before the run (`Failure [not installed for 0]`, logged as `ALREADY REMOVED`) from a genuine failure, so re-running the script on an already-debloated phone doesn't report false failures (see section 4);
- for the section 14 batch specifically, checks each package is actually installed before attempting to remove it, since that batch is not guaranteed present the way the core 26 are.

It does not remove `com.amazon.appmanager` or `com.orange.aura.oobe` (both were already disabled on the tested device, per section 9) and it does not touch any other third-party/personal app.

Recommended invocation:

```bash
chmod +x debloat-cancunf.sh
./debloat-cancunf.sh 2>&1 | tee debloat-run.log
```

## 16. Additional stock/diagnostic/feature components (community list)

This batch (Stage 5 in `debloat-cancunf.sh`) came from a community-shared debloat script for this exact device, not from decisions made independently on the tested device the way sections 5–9 were. Every package below was cross-checked against this project's own 403-package stock baseline (all confirmed genuine stock components, not third-party/personal apps) and against the existing REMOVE/KEEP/DISABLED decisions already on file before being added here.

**Five packages from that community list were deliberately excluded** because they directly conflict with decisions already made and reasoned about on the tested device:

| Package | This project's existing decision |
|---|---|
| `com.google.android.videos` | KEEP (Google TV) |
| `com.motorola.help` | KEEP (see section 9 for the reasoning) |
| `com.motorola.help.extlog` | KEEP (used by Motorola Help) |
| `com.orange.update` | KEEP |
| `de.telekom.tsc` | KEEP |

Two more (`com.amazon.appmanager`, `com.orange.aura.oobe`) were left out because they are already handled as `DISABLED` (section 9) — a prior uninstall attempt against `com.amazon.appmanager` specifically failed on the tested device (section 4), so it was not re-attempted here.

The community script's own mechanism uses `pm disable-user --user 0` rather than this project's `pm uninstall --user 0`; this project kept its existing mechanism for consistency (disabling is more instantly reversible and preserves app data, but introducing a second removal mechanism into one script was judged not worth the inconsistency).

The remaining 29 packages split into three groups:

**No real feature lost** — promotional/sponsor/diagnostic components with no user-facing function removed:

```text
com.android.bookmarkprovider
com.android.providers.partnerbookmarks
com.android.egg
com.google.android.printservice.recommendation
com.motorola.att.phone.extensions
com.motorola.attvowifi
com.motorola.omadm.vzw
com.motorola.vzw.pco.extensions.pcoreceiver
com.motorola.spectrum.setup.extensions
com.motorola.enterprise.service
com.motorola.enterprise.adapter.service
com.motorola.bug2go
com.google.android.feedback
com.motorola.contacts.preloadcontacts
com.lenovo.lsf.user
com.motorola.dimo
com.google.android.gms.supervision
com.motorola.android.providers.chromehomepage
com.motorola.android.nativedropboxagent
```

`com.motorola.att.phone.extensions` through `com.motorola.spectrum.setup.extensions` are US-carrier-specific overlays (AT&T/Verizon) that are inert on the tested device's carrier configuration (`ro.carrier: reteu`). `com.motorola.android.nativedropboxagent` is Android's system crash/ANR diagnostic log collector, not the Dropbox cloud-storage app — removing it has no user-facing effect but does reduce automatic diagnostic log collection. `com.google.android.gms.supervision` was already observed disabled by default on the tested device.

**Removes a real, working feature** — a conscious trade, not pure bloat:

```text
com.motorola.mobiledesktop.core
com.motorola.motcameradesktop
com.motorola.freeform
com.motorola.systemui.desk
com.android.dreams.basic
com.android.dynsystem
com.android.traceur
com.motorola.motocare
```

The first four remove Motorola's Smart Connect / desktop-mode feature (connecting the phone to a monitor for a desktop-like UI) entirely. `com.android.dreams.basic` removes the screensaver (Daydream) system. `com.android.dynsystem` removes Dynamic System Updates (the ability to boot a temporary/dynamic system image for testing). `com.android.traceur` removes the system tracing tool used for performance debugging. `com.motorola.motocare` removes Motorola's own support/care app.

**Purpose not independently confirmed** — included on the device owner's decision despite the package's exact function not being verified on the tested device:

```text
com.motorola.genie
com.motorola.ccc.mainplm
com.google.android.apps.bard
```

`com.google.android.apps.bard` (Google Gemini) is not part of the stock 403-package baseline — like the games in section 14, it depends on the signed-in Google account, so `debloat-cancunf.sh` groups it with `com.google.android.apps.photosgo` into the presence-checked Stage 4 batch rather than the guaranteed-present Stage 5. `com.motorola.genie` and `com.motorola.ccc.mainplm` are confirmed stock components but their exact purpose wasn't independently investigated before removal.

## General rule

Do not debloat simply to make `pm list packages` shorter. Once promotional software and genuinely unwanted user-facing features are gone, further package removal produces diminishing returns while increasing the chance of breaking stock-ROM integration.
