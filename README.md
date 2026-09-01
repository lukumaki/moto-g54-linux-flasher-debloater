# Moto G54 5G (cancunf) Linux Stock Firmware Flasher and Debloater

![Device](https://img.shields.io/badge/device-Moto%20G54%205G%20(cancunf)-blue)
![Android](https://img.shields.io/badge/tested%20Android-15-green)
![Linux](https://img.shields.io/badge/tested%20on-Debian%2013-red)
![Shell](https://img.shields.io/badge/shell-Bash-lightgrey)
![ADB](https://img.shields.io/badge/tools-ADB%20%2B%20Fastboot-orange)
![Status](https://img.shields.io/badge/status-tested%20on%20real%20device-brightgreen)

A Linux-focused, carefully validated workflow for restoring Motorola stock firmware on the **Moto G54 5G (`cancunf`)**, relocking the bootloader, conservatively debloating the restored stock ROM, and reinstalling applications from a package-name list.

This is not a theoretical collection of commands. It documents the actual procedure followed on a real Moto G54 5G from **Debian 13 (Trixie)** and the observations made during that restore.

The tested Motorola firmware build was:

```text
V1TDS35H.83-20-5-12
Android 15
Security patch: 2026-07-01
```

## What this project covers

- Reassembling Motorola split firmware archives (`.001`, `.002`, ...)
- Testing the reconstructed ZIP before extraction
- Reading Motorola's `flashfile.xml` rather than guessing a flash sequence
- Verifying model, CID, current slot and sparse-image capability
- Verifying the firmware files against the MD5 checksums provided by Motorola
- Flashing the exact `flashfile.xml` sequence from Linux with `fastboot`
- Stopping safely on errors and preserving Motorola `fb_mode` for inspection
- Reviewing non-fatal messages seen during a successful real flash
- Booting and verifying stock Android before attempting a bootloader relock
- Relocking the Motorola bootloader
- Capturing the stock package set before debloating
- Removing only selected packages for Android user 0
- Keeping framework, telephony, OTA, security and Motorola integration components intact
- Keeping the screen awake during long ADB/app-install sessions
- Reinstalling large application lists through Google Play using package names

## Test environment

The procedure documented here was performed from:

```text
Host OS: Debian GNU/Linux 13 (Trixie)
Device: Motorola Moto G54 5G
Codename: cancunf
Firmware: V1TDS35H.83-20-5-12
Android: 15
```

ADB and Fastboot were run directly from the Debian host.

## Important warning

**Flashing firmware can permanently brick a device if the firmware, model, CID or partition sequence is wrong.**

The included flasher is intentionally tied to the tested firmware build above and performs destructive operations including erasing `nvdata`, `userdata`, `metadata` and `debug_token`, because those operations are present in Motorola's own `flashfile.xml`.

Do not treat a script written for one firmware as a generic Motorola flasher. Read the script and your own `flashfile.xml` before running anything.

This repository intentionally does **not** include Motorola firmware images.

## Requirements

On Debian 13 or another Linux distribution, the workflow expects:

- `adb`
- `fastboot`
- `python3`
- `unzip`
- standard GNU shell utilities (`cat`, `grep`, `sed`, `sort`, `md5sum`, etc.)

Example package installation on Debian:

```bash
sudo apt update
sudo apt install adb fastboot python3 unzip
```

On the phone:

- Moto G54 5G (`cancunf`)
- correct firmware for that device/region/CID
- bootloader unlocked for the flashing stage
- sufficient battery charge
- reliable USB cable/port

---

# Part I - Stock firmware restoration

## 1. Reassemble Motorola split firmware

The firmware used during testing arrived split into two pieces:

```text
CANCUNF_G_SYS_V1TDS35H_83_20_5_12_subsidy_DEFAULT_regulatory_DEFAULT.001
CANCUNF_G_SYS_V1TDS35H_83_20_5_12_subsidy_DEFAULT_regulatory_DEFAULT.002
```

They were reassembled in numerical order:

```bash
cat CANCUNF_G_SYS_V1TDS35H_83_20_5_12_subsidy_DEFAULT_regulatory_DEFAULT.001 \
    CANCUNF_G_SYS_V1TDS35H_83_20_5_12_subsidy_DEFAULT_regulatory_DEFAULT.002 \
    > CANCUNF_G_SYS_V1TDS35H_83_20_5_12.zip
```

Do **not** extract the pieces individually.

## 2. Test the reconstructed ZIP

Before flashing anything, verify that the reconstructed archive is readable:

```bash
file CANCUNF_G_SYS_V1TDS35H_83_20_5_12.zip
unzip -t CANCUNF_G_SYS_V1TDS35H_83_20_5_12.zip
```

Continue only if `unzip -t` completes successfully.

## 3. Extract the firmware

```bash
mkdir stock-firmware
unzip CANCUNF_G_SYS_V1TDS35H_83_20_5_12.zip -d stock-firmware
cd stock-firmware
```

The directory should contain Motorola's `flashfile.xml` together with `PGPT`, bootloader images, partition images and the `super` sparse chunks referenced by the XML.

## 4. Inspect `flashfile.xml`

The tested XML identified:

```text
model: cancunf_g_sys
CID:   0x0032
max sparse size: 268435456
```

The XML is important because it defines the expected flash order and destructive erase operations. The script in this repository mirrors that sequence instead of inventing one.

## 5. Verify the device before flashing

Boot the phone into Fastboot mode and check that the host can see it:

```bash
fastboot devices
```

The real device was also checked for product, active slot, CID, security state and sparse-size capability before flashing. The guarded script performs these preflight checks and refuses to proceed when the expected values do not match.

## 6. Verify the firmware files

Before the real flash, every firmware file referenced by `flashfile.xml` was checked against the MD5 values contained in the XML.

This matters because a damaged `super` chunk or bootloader image can turn an otherwise correct command sequence into a failed flash.

The supplied script repeats these checks automatically.

## 7. Run the guarded flasher

Copy the script into the extracted firmware directory, then:

```bash
chmod +x flash-stock-cancunf-V1TDS35H-83-20-5-12.sh
./flash-stock-cancunf-V1TDS35H-83-20-5-12.sh 2>&1 | tee flash-stock.log
```

Using `tee` is recommended. It leaves a complete host-side log that can be reviewed before rebooting.

The script deliberately:

- validates the environment first;
- pauses before destructive stages;
- follows Motorola's XML order;
- stops if a `fastboot` operation fails;
- does **not** automatically reboot at the end;
- does **not** automatically relock the bootloader.

That last point is intentional: a relock should happen only after the restored stock system has booted successfully.

## 8. What does `OKAY` / `Success` mean?

Fastboot output needs to be read operation by operation. During the successful test run, writes completed with `OKAY`, even though a few commands also printed warnings.

A warning should therefore be evaluated together with the command's final status. The script treats an actual failed fastboot command as fatal; it does not blindly continue.

### Non-fatal messages seen during the successful flash

The real restore produced a few messages worth documenting:

- GPT/preloader-related AVB-footer warnings, while the actual send/write operation completed with `OKAY`.
- An erase command displayed Fastboot's generic ext4-format suggestion; the requested erase itself completed.
- `efuseBackup` reported that blowing the partition was not permitted on the secure phone and that the operation was skipped; Fastboot still returned `OKAY`.

These exact observations are included to help distinguish the tested behaviour from an arbitrary failure. They are **not** a rule that all warnings are safe to ignore.

## 9. First boot

Only after the flash sequence and log have been reviewed:

```bash
fastboot reboot
```

Allow the first Android boot to complete. It can take noticeably longer than a normal reboot.

## 10. Verify the restored stock system

After Android starts and USB debugging is available:

```bash
adb devices
adb shell getprop ro.product.device
adb shell getprop ro.build.version.release
adb shell getprop ro.build.version.security_patch
adb shell getprop ro.build.fingerprint
adb shell getprop ro.boot.verifiedbootstate
adb shell getprop ro.boot.flash.locked
```

On the tested restore the device reported Android 15 and the expected Motorola `V1TDS35H.83-20-5-12` fingerprint.

## 11. Relock the bootloader

Only do this after stock Android has booted successfully and the installed build has been verified.

```bash
adb reboot bootloader
fastboot flashing get_unlock_ability
```

The command that successfully relocked the tested Moto G54 was:

```bash
fastboot oem lock
```

After the on-device confirmation, the bootloader reported that it was locked and `get_unlock_ability` changed from permitted to not permitted.

See [`docs/relock-bootloader.md`](docs/relock-bootloader.md) for the dedicated notes.

---

# Part II - Conservative debloating

The debloat was deliberately performed **after** restoring and validating stock Android.

The approach here does not delete APK files from `/system`, `/product` or `/system_ext`. Packages are removed only for Android user 0:

```bash
adb shell pm uninstall --user 0 PACKAGE.NAME
```

For system packages this is normally reversible with:

```bash
adb shell cmd package install-existing PACKAGE.NAME
```

Before removing anything, the stock package set and APK paths were captured for inspection. The decisions were then made package by package rather than by applying an internet "remove everything" list.

See [`docs/stock-applications.md`](docs/stock-applications.md) for the stock/preloaded application snapshot and the KEEP / REMOVE / DISABLED decisions.

See [`docs/debloat.md`](docs/debloat.md) for:

- the actual removal batches and commands;
- packages left disabled;
- packages deliberately kept;
- verification after each batch;
- the meaning of `Success` from Android Package Manager.

---

# Part III - Reinstalling applications

For a large list of ordinary applications, entering each Play Store page manually is unnecessary if the Android package names are already known.

The tested workflow opens the correct Play Store page through ADB and allows Play Store to queue installs in the background.

See [`docs/reinstalling.md`](docs/reinstalling.md).

A separate note on Seedvault/Seednaut-assisted recovery is available in [`docs/app-restore.md`](docs/app-restore.md).

---

# Useful ADB convenience: keep the screen awake

During long debloat or application-reinstall sessions, the phone can be kept awake while connected through USB:

```bash
adb shell svc power stayon true
```

Restore normal sleep behaviour afterwards:

```bash
adb shell svc power stayon false
```

This does not disable Android's screen timeout permanently; it controls the "stay awake while powered" behaviour and is convenient during an ADB session.

---

# Firmware redistribution

This repository does **not** distribute Motorola firmware images, proprietary APKs, Seedvault backups, personal app data or authentication material.

Users must obtain firmware appropriate for their own device and verify it independently.

# Scope

The current flasher is deliberately conservative and build-specific. Do not assume it is safe for another Moto G54 variant, CID, firmware revision or Motorola model without reviewing and adapting the XML sequence and validation rules.

Likewise, the debloat list reflects choices made on the tested device. A package being removable does not mean every user should remove it.

# Acknowledgements / community contributors

This project was developed with practical information and community knowledge shared through the Moto G54 / `cancunf` Telegram community. Special thanks to the people contributing to and maintaining:

- [Motorola G54 Official](https://t.me/motorolag54official)
- [Motorola G54 Updates](https://t.me/motorolag54updates)
- [cancunf Backup](https://t.me/cancunfbackup)

These communities are acknowledged as sources of device-specific help and shared experience. They are not responsible for this repository's scripts or documentation.
