> ## 📢 Keep Android Open
>
> If you care about the freedom to unlock, modify, repair, flash custom ROMs, and continue developing for Android devices, please take a moment to visit **[Keep Android Open](https://keepandroidopen.org/en/)** and support the campaign.
>
> **The ability to unlock and modify our own devices is directly relevant to projects like this one. Please read, share, and act.**
>

# Moto G54 5G (cancunf) Linux Stock Firmware Flasher and Debloater

![Device](https://img.shields.io/badge/device-Moto%20G54%205G%20(cancunf)-blue)
![Android](https://img.shields.io/badge/tested%20Android-15-green)
![Linux](https://img.shields.io/badge/tested%20on-Debian%2013-red)
![Shell](https://img.shields.io/badge/shell-Bash-lightgrey)
![ADB](https://img.shields.io/badge/tools-ADB%20%2B%20Fastboot-orange)
![Status](https://img.shields.io/badge/status-tested%20on%20real%20device-brightgreen)

A Linux-focused, carefully validated workflow for restoring Motorola stock firmware on the **Moto G54 5G (`cancunf`)**, relocking the bootloader, conservatively debloating the restored stock ROM, and reinstalling applications from a package-name list.

This is not a theoretical collection of commands. It documents the actual procedure followed on a real Moto G54 5G from **Debian 13 (Trixie)** and the observations made during that restore.

## Firmware builds documented here

The original successful restore documented by this repository used:

```text
V1TDS35H.83-20-5-12
Android 15
Security patch: 2026-07-01
```

Afterwards, Motorola **Software Fix** was used from a Windows 11 VM to obtain the device-matched firmware package for the tested XT2343-6 / CID 50 handset:

```text
CANCUNF_G_SYS_V1TDS35H.83_20_5_8_4_subsidy_DEFAULT_regulatory_XT2343_6_cid50_CFC
```

Its `flashfile.xml` reports:

```text
model:           cancunf_g_sys
build:           V1TDS35H.83-20-5-8-4
CID:             0x0032
max sparse size: 268435456
```

`cid50` in the package name is decimal 50, which is hexadecimal `0x32`, matching the XML CID.

The Motorola Software Fix XML uses the **same partition/erase sequence and the same 22 `super` sparse chunks** as the earlier flasher, but its firmware files have different MD5 hashes and it is a different build. For that reason there is now a separate build-specific flasher:

- [`flash-stock-cancunf-V1TDS35H-83-20-5-12.sh`](flash-stock-cancunf-V1TDS35H-83-20-5-12.sh) — the script used in the successful restore documented here.
- [`flash-stock-cancunf-V1TDS35H-83-20-5-8-4.sh`](flash-stock-cancunf-V1TDS35H-83-20-5-8-4.sh) — generated from the Motorola Software Fix `flashfile.xml` for XT2343-6 / CID 50. It must only be used with that matching firmware package.

Do **not** rename one firmware build and use the other build's script. The scripts deliberately check the build recorded in `flashfile.xml` before allowing flashing to continue.

## What this project covers

- Reassembling Motorola split firmware archives (`.001`, `.002`, ...)
- Testing the reconstructed ZIP before extraction
- Reading and inspecting Motorola's `flashfile.xml` rather than guessing a flash sequence
- Verifying model, CID, current slot and sparse-image capability
- Independently verifying firmware files against the MD5 checksums supplied in `flashfile.xml`
- Flashing the exact XML sequence from Linux with `fastboot`
- Stopping safely on errors and preserving Motorola `fb_mode` for inspection
- Reviewing non-fatal messages seen during a successful real flash
- Booting and verifying stock Android before attempting a bootloader relock
- Relocking the Motorola bootloader
- Capturing the stock package set before debloating
- Removing only selected packages for Android user 0
- Keeping framework, telephony, OTA, security and Motorola integration components intact
- Running the removal batches through a guarded script with its own before/after logging
- Keeping the screen awake during long ADB/app-install sessions
- Reinstalling large application lists through Google Play using package names

## Test environment

The procedure documented here was performed from:

```text
Host OS: Debian GNU/Linux 13 (Trixie)
Device: Motorola Moto G54 5G
Codename: cancunf
Android: 15
```

ADB and Fastboot were run directly from the Debian host.

## Important warning

**Flashing firmware can permanently brick a device if the firmware, model, CID or partition sequence is wrong.**

The included flashers are intentionally build-specific and perform destructive operations including erasing `nvdata`, `userdata`, `metadata` and `debug_token`, because those operations are present in Motorola's own `flashfile.xml`.

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

If the firmware arrives split into numbered pieces such as `.001`, `.002`, etc., join them in numerical order.

Example from the original restore:

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

"Inspect" here means **read the metadata and the actual flash instructions before executing them**. The XML is both an identity check for the firmware and Motorola's ordered recipe for flashing it.

Start by looking at the beginning of the file:

```bash
sed -n '1,80p' flashfile.xml
```

To show the most important header values directly:

```bash
grep -E 'phone_model|software_version|sparsing|cid_value' flashfile.xml
```

For the Motorola Software Fix package used as the newer reference, the important values are:

```text
phone_model:     cancunf_g_sys
software build:  V1TDS35H.83-20-5-8-4
CID:             0x0032
max-sparse-size: 268435456
```

You should also inspect the operations themselves:

```bash
grep '<step ' flashfile.xml
```

That shows, in order, every partition that Motorola expects to be flashed or erased.

A clearer structured view can be produced with Python:

```bash
python3 <<'PY'
import xml.etree.ElementTree as ET

root = ET.parse('flashfile.xml').getroot()
header = root.find('./header')

print('Model: ', header.find('phone_model').get('model'))
print('Build: ', header.find('software_version').get('version'))
print('CID:   ', header.find('cid_value').get('value'))
print('Sparse:', header.find('sparsing').get('max-sparse-size'))
print()
print('Flash sequence:')

for n, step in enumerate(root.findall('./steps/step'), 1):
    op = step.get('operation')
    partition = step.get('partition', '')
    filename = step.get('filename', '')
    var = step.get('var', '')
    print(f'{n:02d}. {op:7} {partition:20} {filename or var}')
PY
```

Before using a flasher, check specifically that:

- the model is your `cancunf` variant;
- the build is the build for which the script was written;
- the CID matches the phone;
- `max-sparse-size` is what the script expects;
- the partition order in the script follows the XML;
- the number of `super.img_sparsechunk.*` files matches the XML;
- all erase operations in the script are actually present in the XML.

For the Motorola Software Fix `V1TDS35H.83-20-5-8-4` XML there are **22 super chunks (`0` through `21`)**, followed by erase operations for `userdata`, `metadata` and `debug_token`, then Motorola's `fb_mode_clear` and cleanup commands.

## 5. Verify the device before flashing

Boot the phone into Fastboot mode and check that the host can see it:

```bash
fastboot devices
```

Useful manual checks are:

```bash
fastboot getvar product
fastboot getvar cid
fastboot getvar current-slot
fastboot getvar max-sparse-size
fastboot getvar secure
fastboot getvar version-bootloader
```

Motorola Fastboot often prints `getvar` output to stderr; that is normal.

The guarded flasher repeats these checks and refuses to proceed when the expected product, CID, slot or sparse size does not match.

## 6. Verify the firmware files

Each `<step>` that flashes a file contains Motorola's expected MD5 checksum. The firmware directory should be checked against those values **before any partition is written**.

The guarded flasher does this automatically, but it is useful to know how to perform the verification independently.

Run this from the extracted firmware directory containing `flashfile.xml`:

```bash
python3 <<'PY'
import hashlib
import xml.etree.ElementTree as ET
from pathlib import Path

root = ET.parse('flashfile.xml').getroot()
checked = 0
errors = 0

for step in root.findall('.//step'):
    filename = step.get('filename')
    expected = step.get('MD5')

    if not filename or not expected:
        continue

    checked += 1
    path = Path(filename)

    if not path.is_file():
        print(f'MISSING  {filename}')
        errors += 1
        continue

    md5 = hashlib.md5()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(8 * 1024 * 1024), b''):
            md5.update(chunk)

    actual = md5.hexdigest()

    if actual.lower() == expected.lower():
        print(f'OK       {filename}')
    else:
        print(f'FAILED   {filename}')
        print(f'         expected {expected}')
        print(f'         actual   {actual}')
        errors += 1

print()
print(f'Checked {checked} firmware files.')

if errors:
    raise SystemExit(f'{errors} integrity problem(s) found. DO NOT FLASH.')

print('ALL FIRMWARE FILES MATCH flashfile.xml')
PY
```

A healthy result consists of `OK` for every referenced firmware file and ends with:

```text
ALL FIRMWARE FILES MATCH flashfile.xml
```

If you see `MISSING` or `FAILED`, stop. Do not flash until the firmware package has been reconstructed/extracted correctly.

This check is especially important because different Motorola builds use different image contents and therefore different MD5 values even when the partition names and flash order are identical.

## 7. Run the guarded flasher

The flashers are available directly in this repository:

- **Successfully used in the original restore:** [`flash-stock-cancunf-V1TDS35H-83-20-5-12.sh`](https://github.com/lukumaki/moto-g54-linux-flasher-debloater/blob/main/flash-stock-cancunf-V1TDS35H-83-20-5-12.sh)
- **Motorola Software Fix XT2343-6 / CID 50 build:** [`flash-stock-cancunf-V1TDS35H-83-20-5-8-4.sh`](https://github.com/lukumaki/moto-g54-linux-flasher-debloater/blob/main/flash-stock-cancunf-V1TDS35H-83-20-5-8-4.sh)

Copy the script matching **your exact firmware build** into the extracted firmware directory.

For the original `V1TDS35H.83-20-5-12` build:

```bash
chmod +x flash-stock-cancunf-V1TDS35H-83-20-5-12.sh
./flash-stock-cancunf-V1TDS35H-83-20-5-12.sh 2>&1 | tee flash-stock.log
```

For the Motorola Software Fix `V1TDS35H.83-20-5-8-4` build:

```bash
chmod +x flash-stock-cancunf-V1TDS35H-83-20-5-8-4.sh
./flash-stock-cancunf-V1TDS35H-83-20-5-8-4.sh 2>&1 | tee flash-stock.log
```

Using `tee` is recommended. It leaves a complete host-side log that can be reviewed before rebooting.

The script deliberately:

- validates the firmware XML identity first;
- checks the connected device;
- verifies every XML-referenced firmware file against its MD5;
- pauses before destructive stages;
- follows Motorola's XML order;
- stops if a `fastboot` operation fails;
- does **not** automatically reboot at the end;
- does **not** automatically relock the bootloader.

That last point is intentional: a relock should happen only after the restored stock system has booted successfully.

### Why the newer firmware needed a separate script

The Motorola Software Fix XML confirms that `V1TDS35H.83-20-5-8-4` has the same model (`cancunf_g_sys`), CID (`0x0032`), sparse size, partition sequence, erase operations and 22-super-chunk layout as the earlier script.

Therefore the core fastboot sequence did **not** need redesigning. However, the old script deliberately contained:

```bash
EXPECTED_BUILD="V1TDS35H.83-20-5-12"
```

and would correctly refuse the newer XML. The new script changes the build guard to:

```bash
EXPECTED_BUILD="V1TDS35H.83-20-5-8-4"
```

The MD5 values themselves are **not hard-coded in either script**. They are read dynamically from the `flashfile.xml` located beside the firmware images, which means each script verifies the hashes supplied with its matching Motorola package.

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

The original tested restore reported Android 15 and the expected `V1TDS35H.83-20-5-12` Motorola fingerprint.

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
- the meaning of `Success` from Android Package Manager;
- [`debloat-cancunf.sh`](debloat-cancunf.sh), a guarded script that automates the removal batches together with before/after logging (see [docs/debloat.md, section 14](docs/debloat.md#14-automated-script)).

---

# Part III - Reinstalling applications

For a large list of applications, entering each Play Store page manually is unnecessary if the Android package names are already known.

The tested workflow opens the correct Play Store page through ADB and allows Play Store to queue installs in the background. Banking, payment, government and authenticator applications can be installed through the same official Play Store workflow; what should not be blindly restored is their old private application data.

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

# Troubleshooting

The guarded flasher is intentionally strict: it stops rather than guesses whenever something does not match what Motorola's `flashfile.xml` or the connected device reports. Below is what each stop message actually means and what to check.

### `fastboot is not installed or not in PATH.` / `python3 is required for XML/MD5 validation.`

Install the missing tool (see [Requirements](#requirements)) and re-run the script.

### `flashfile.xml not found. Run this script from the extracted firmware directory.`

The script must be copied into and run from the directory that contains `flashfile.xml` and the firmware images, not from wherever it was downloaded to.

### `ERROR: XML model mismatch` / `ERROR: XML build mismatch` / `ERROR: XML CID mismatch` / `ERROR: XML max-sparse-size mismatch`

These come from reading `flashfile.xml` itself, before the phone is even touched. They mean the firmware package you extracted does not match the build the script was written for. Re-check which script matches which firmware, as described in [Firmware builds documented here](#firmware-builds-documented-here). Do not edit the script's `EXPECTED_*` values to force a match — get the correct firmware/script pairing instead.

### `Expected exactly one fastboot device; found 0.` (or more than one)

The phone is not in Fastboot mode, the USB cable/port is unreliable, or more than one fastboot-mode device is connected. Run `fastboot devices` on its own to confirm exactly one device is listed before retrying.

### `Product mismatch: expected cancunf, got ...`

The connected phone is not a Moto G54 5G (`cancunf`), or `fastboot getvar product` could not be read. Double-check you have the right device connected.

### `CID mismatch: expected 0x0032, got ...`

The phone's Carrier/Config ID does not match the firmware's CID. Flashing a firmware package built for a different CID/region is a common cause of a bricked device — get the firmware package that matches your phone's own CID instead of bypassing this check.

### `Current slot must be a, got b.`

Both flashers in this repository only contain images for the `_a` slot partitions, matching Motorola's `flashfile.xml`. If a prior OTA update left the phone on slot `b`, switch the active slot back to `a` before flashing:

```bash
fastboot set_active a
```

Then re-run `fastboot getvar current-slot` to confirm it now reports `a`, and start the script again.

### `max-sparse-size mismatch: expected 268435456, got ...`

The device's fastboot implementation reports a different maximum sparse chunk size than the firmware expects. This is unusual on a stock Moto G54 5G bootloader; if it happens, do not force past it without understanding why, since the `super` partition is flashed in sparse chunks sized for `268435456`.

### `MISSING <file>` / `FAILED <file>` during firmware verification

A firmware file referenced by `flashfile.xml` is either missing from the extracted directory or its MD5 does not match. This usually means the split archive (`.001`, `.002`, ...) was reassembled incorrectly or the ZIP was only partially extracted. Redo [steps 1–3](#1-reassemble-motorola-split-firmware) and re-verify before flashing.

### `Flashing not authorized.`

This is not an error — it means something other than exactly `YES` was typed at a confirmation prompt, so the script stopped safely without flashing anything. Re-run the script when ready.

### Stopped mid-flash with `Motorola fb_mode is still SET`

A `fastboot` command failed partway through flashing. Do not reboot the phone. Read the terminal output (or the `tee` log) to see which stage and command failed, and resolve that specific problem before deciding whether it is safe to continue, retry, or seek help referencing the exact failing command.

---

# Firmware redistribution

This repository does **not** distribute Motorola firmware images, proprietary APKs, Seedvault backups, personal app data or authentication material.

Users must obtain firmware appropriate for their own device and verify it independently. Motorola Software Fix can be useful for identifying/downloading the firmware Motorola currently associates with a specific handset.

# Scope

The flashers in this repository are deliberately conservative and build-specific. Do not assume they are safe for another Moto G54 variant, CID, firmware revision or Motorola model without reviewing that firmware's own `flashfile.xml` and adapting the validation rules and flash sequence if necessary.

Likewise, the debloat list reflects choices made on the tested device. A package being removable does not mean every user should remove it.

# Acknowledgements / community contributors

This project was developed with practical information and community knowledge shared through the Moto G54 / `cancunf` Telegram community. Special thanks to the people contributing to and maintaining:

- [Motorola G54 Official](https://t.me/motorolag54official)
- [Motorola G54 Updates](https://t.me/motorolag54updates)
- [cancunf Backup](https://t.me/cancunfbackup)

These communities are acknowledged as sources of device-specific help and shared experience. They are not responsible for this repository's scripts or documentation.
