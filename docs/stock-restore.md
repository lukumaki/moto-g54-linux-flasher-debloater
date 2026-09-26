# Stock firmware restoration (cancunf)

This is the full walkthrough behind [Part I](../README.md#part-i---stock-firmware-restoration) of the main README: reassembling split firmware, inspecting Motorola's `flashfile.xml`, verifying the device and firmware, running the guarded flasher, first boot, verifying the restored system, and relocking.

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

- [`flash-stock-cancunf.sh`](https://github.com/lukumaki/moto-g54-linux-flasher-debloater/blob/main/flash-stock-cancunf.sh) — full factory restore from `flashfile.xml`.
- [`flash-service-cancunf.sh`](https://github.com/lukumaki/moto-g54-linux-flasher-debloater/blob/main/flash-service-cancunf.sh) — repair/service reflash from `servicefile.xml`, preserving user data. See [`servicefile.xml`: a repair flash that preserves user data](../README.md#servicefilexml-a-repair-flash-that-preserves-user-data).

Both are generic across builds of this exact device/CID rather than pinned to one firmware version (see [Firmware builds documented here](../README.md#firmware-builds-documented-here)) — copy whichever matches your firmware type (`flashfile.xml` for a full restore, `servicefile.xml` to preserve data) into the extracted firmware directory.

For a full factory restore:

```bash
chmod +x flash-stock-cancunf.sh
./flash-stock-cancunf.sh 2>&1 | tee flash-stock.log
```

For a repair/service reflash that preserves `userdata`/`metadata` (requires `servicefile.xml` in the same directory):

```bash
chmod +x flash-service-cancunf.sh
./flash-service-cancunf.sh 2>&1 | tee flash-service.log
```

Using `tee` is recommended. It leaves a complete host-side log that can be reviewed before rebooting.

The script deliberately:

- validates the firmware XML identity (model, CID, sparse size) first;
- checks the connected device, including reporting bootloader lock state (informational, not a hard block — see [Before you start](../README.md#before-you-start-developer-options-unlocking-and-relocking) for why a locked bootloader can still succeed here);
- verifies every XML-referenced firmware file against its MD5;
- prints the literal source-XML `<step>` (`flashfile.xml` or `servicefile.xml`) that each `fastboot` command corresponds to, warning instead of guessing if a command has no matching step — this is the main safety net now that the script isn't pinned to one build string;
- pauses before destructive stages;
- follows Motorola's XML order;
- stops if a `fastboot` operation fails;
- does **not** automatically reboot at the end;
- does **not** automatically relock the bootloader.

That last point is intentional: a relock should happen only after the restored stock system has booted successfully.

### Why the scripts don't pin a specific build

The Motorola Software Fix XML for `V1TDS35H.83-20-5-8-4` was confirmed to have the same model (`cancunf_g_sys`), CID (`0x0032`), sparse size, partition sequence, erase operations and 22-super-chunk layout as the original `V1TDS35H.83-20-5-12` restore documented here — only the firmware files' MD5 hashes and the exact build string differ. Since the fastboot sequence itself has now held steady across two independently confirmed real Motorola packages, both scripts here check `phone_model`/CID/sparse-size rather than an exact build string, trusting `print_xml_step`'s per-command cross-check (above) to flag it if a future firmware's actual XML ever diverges from the hardcoded sequence.

The MD5 values themselves are **not hard-coded in either script**. They are read dynamically from the `flashfile.xml`/`servicefile.xml` located beside the firmware images, which means each script verifies the hashes supplied with whatever Motorola package you point it at.

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

See [`relock-bootloader.md`](relock-bootloader.md) for the dedicated notes.
