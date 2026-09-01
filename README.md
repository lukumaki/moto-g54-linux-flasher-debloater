# Moto G54 5G (cancunf) Linux Stock Firmware Flasher and Debloater

A Linux-focused, carefully validated workflow for restoring Motorola stock firmware on the **Moto G54 5G (`cancunf`)**, relocking the bootloader, and performing a conservative ADB-based debloat without modifying signed partitions.

This repository documents a real successful restore of firmware build:

`V1TDS35H.83-20-5-12`

## What this project covers

- Reassembling Motorola split firmware archives (`.001`, `.002`, ...)
- Validating the reconstructed ZIP before flashing
- Checking the target device, CID, slot and sparse size
- Verifying every firmware image against `flashfile.xml` MD5 values
- Flashing the exact Motorola `flashfile.xml` sequence from Linux with `fastboot`
- Stopping safely on errors and preserving Motorola `fb_mode` state for inspection
- Relocking the bootloader after a successful stock boot
- Conservative, reversible debloating with `pm uninstall --user 0`
- Optional app-reinstall helpers using ADB + Google Play

## Important warning

**Flashing firmware can permanently brick a device if the firmware, model, CID or partition sequence is wrong.**

The included flasher is intentionally tied to the exact firmware build above and performs destructive operations including erasing `nvdata`, `userdata`, `metadata` and `debug_token`, because those operations are present in Motorola's own `flashfile.xml`.

Read the script before running it. Keep a complete firmware copy and recovery path available.

## Requirements

On the Linux host:

- `fastboot`
- `adb`
- `python3`
- `unzip`

On the phone:

- Moto G54 5G (`cancunf`)
- bootloader unlocked for the flashing stage
- sufficient battery charge
- reliable USB connection

## 1. Reassemble split Motorola firmware

If Motorola firmware is distributed as split files such as:

```text
CANCUNF_G_SYS_...zip.001
CANCUNF_G_SYS_...zip.002
```

reassemble them in order:

```bash
cat firmware.001 firmware.002 > firmware.zip
```

Then verify the archive:

```bash
file firmware.zip
unzip -t firmware.zip
```

Only continue if the ZIP test completes successfully.

## 2. Extract firmware

```bash
unzip firmware.zip -d stock
cd stock
```

The extracted directory must contain `flashfile.xml`, `PGPT`, `preloader.img`, boot/vendor images, the super sparse chunks and the other images referenced by the XML.

## 3. Flash from Linux

Copy the included script into the extracted firmware directory:

```bash
chmod +x flash-stock-cancunf-V1TDS35H-83-20-5-12.sh
./flash-stock-cancunf-V1TDS35H-83-20-5-12.sh 2>&1 | tee flash-stock.log
```

The script performs preflight checks before writing anything and requires explicit confirmation at destructive stages.

It intentionally **does not reboot** and **does not relock the bootloader** at the end.

## 4. First boot and verification

After a successful flash, review the log, then reboot manually:

```bash
fastboot reboot
```

Allow Android to complete its first boot before making further bootloader changes.

Useful verification commands:

```bash
adb shell getprop ro.product.device
adb shell getprop ro.build.version.release
adb shell getprop ro.build.fingerprint
adb shell getprop ro.boot.verifiedbootstate
adb shell getprop ro.boot.flash.locked
```

## 5. Relock the Motorola bootloader

Only relock **after stock Android has booted successfully** and you have verified the installed firmware.

Check flashing state first:

```bash
adb reboot bootloader
fastboot flashing get_unlock_ability
```

On the tested Moto G54, the Motorola-specific relock command was:

```bash
fastboot oem lock
```

After relocking, verify that Android images are no longer permitted to flash, then reboot.

See [`docs/relock-bootloader.md`](docs/relock-bootloader.md).

## 6. Debloating

The debloat approach used here does **not** modify `/system` or `/product`. Packages are removed only for Android user 0:

```bash
adb shell pm uninstall --user 0 PACKAGE.NAME
```

This is substantially safer than altering signed partitions and is normally reversible for system packages with:

```bash
adb shell cmd package install-existing PACKAGE.NAME
```

See [`docs/debloat.md`](docs/debloat.md) for the tested package list and packages deliberately kept.

## Notes from the real flashing run

A few messages seen during the successful restore were non-fatal:

- GPT/preloader AVB-footer warnings while the actual send/write operations returned `OKAY`
- `fastboot erase` suggesting a format operation for an ext4 partition
- `efuseBackup` reporting that blowing the partition was not allowed and was being skipped on the secure device, while still returning `OKAY`

Do not ignore arbitrary errors. The included script stops immediately on a failed `fastboot` command.

## Firmware redistribution

This repository does **not** distribute Motorola firmware images. Obtain the correct firmware for your own device and region through an appropriate source.

## Scope

The current flasher is deliberately conservative and build-specific. Do not assume it is safe for another Moto G54 variant, CID, firmware revision, or Motorola model without reviewing and adapting the XML sequence and validation rules.
