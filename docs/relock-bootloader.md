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
