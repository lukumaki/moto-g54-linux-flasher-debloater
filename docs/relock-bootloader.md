# Relocking the Moto G54 bootloader after stock restore

Relock only after the flashed stock ROM has booted successfully and basic verification has passed.

## Preconditions

- Stock Motorola firmware has been flashed successfully.
- Android has completed first boot.
- The firmware matches the device model/CID.
- No custom boot, recovery, vbmeta or system image remains installed.

## Check current state

From Android:

```bash
adb reboot bootloader
```

Then:

```bash
fastboot getvar product
fastboot getvar current-slot
fastboot getvar cid
fastboot getvar secure
fastboot flashing get_unlock_ability
```

On the tested device before relocking, `fastboot flashing get_unlock_ability` reported that flashing Android images was permitted.

## Motorola relock command

The command that successfully relocked the tested Moto G54 was:

```bash
fastboot oem lock
```

The bootloader responded that it was now locked and rebooted back to fastboot mode.

## Verify relock

Run:

```bash
fastboot flashing get_unlock_ability
fastboot getvar secure
fastboot getvar current-slot
```

On the tested device, `get_unlock_ability` then reported that flashing Android images was **not permitted**.

Reboot manually:

```bash
fastboot reboot
```

After Android boots, optional ADB checks include:

```bash
adb shell getprop ro.boot.verifiedbootstate
adb shell getprop ro.boot.flash.locked
adb shell getprop ro.boot.vbmeta.device_state
```

## Warning

Do not relock while custom or mismatched partitions are installed. A locked bootloader expects verified stock images and can refuse to boot if the device state is inconsistent.

## A second, separate risk: the AVB rollback index, not just the per-component anti-rollback table

Motorola's `signing-info.txt` (shipped alongside `flashfile.xml`) lists a per-component anti-rollback version table — `preloader`, `lk`, `efuse`, `gz`, and similar security-critical partitions each get a small integer version. Before relocking on anything other than the newest firmware you've ever run on the device, diff that table between the build you're about to lock on and the newest build the phone has ever booted:

```bash
diff <(sed -n '/anti_rollback_version_begin/,/anti_rollback_version_end/p' older-build/signing-info.txt) \
     <(sed -n '/anti_rollback_version_begin/,/anti_rollback_version_end/p' newer-build/signing-info.txt)
```

An identical table across two builds is a good sign, but **it is not the whole story.** On the tested device, an older stock build (same per-component ARB table as a newer one already run on the device) booted fine while the bootloader was *unlocked*, then failed to boot with **"No valid operating system could be found"** immediately after relocking with `fastboot oem lock`.

The actual cause was Android's own **AVB rollback index**, embedded in `vbmeta.img` — a separate mechanism from Motorola's per-component table above. Booting a newer build can silently advance that rollback-index fuse as a normal side effect of a successful boot. An unlocked bootloader does not strictly enforce the AVB rollback check; a locked one does. The result: firmware that boots fine unlocked can be rejected the moment the bootloader is locked, if a *newer* build was ever booted on the device in between — even if the per-component ARB table above matches exactly.

**This was recoverable, not a hard brick.** The fix is the same technique this repository's own header comments already document for recovering a phone that won't boot to Android at all: flashing officially signed Motorola firmware over fastboot works even while the bootloader is locked. Concretely:

1. Confirm the bootloader still responds (a `securestate: flashing_locked`, `product: cancunf`, `current-slot` etc. all still readable) — this is not a bricked bootloader, only a rejected boot.
2. Run `flash-stock-cancunf.sh` (or `flash-service-cancunf.sh`) against the **newest** stock `flashfile.xml`/`servicefile.xml` you have for this device, while still locked. The script does not require an unlock (see [Before you start, step 1](../README.md#1-do-you-actually-need-to-unlock-the-bootloader)).
3. Reboot. The device should boot normally.

**The practical takeaway:** relock on the newest firmware build you have, not an older one you happen to be testing — even one whose per-component ARB table matches. If you must relock on an older build for some reason, be ready to immediately reflash the newest build while still locked if the first boot fails, rather than assuming a bricked bootloader.
