# Moto G54 5G (cancunf) Linux Stock Firmware Flasher and Debloater
A Linux-focused, carefully validated workflow for restoring Motorola stock firmware on the **Moto G54 5G (`cancunf`)**, relocking the bootloader, conservatively debloating the restored stock ROM, and reinstalling applications from a package-name list. This is not a theoretical collection of commands. It documents the actual procedure followed on a real Moto G54 5G from **Debian 13 (Trixie)** and the observations made during that restore.


![Device](https://img.shields.io/badge/device-Moto%20G54%205G%20(cancunf)-blue)
![Android](https://img.shields.io/badge/tested%20Android-15-green)
![Linux](https://img.shields.io/badge/tested%20on-Debian%2013-red)
![Shell](https://img.shields.io/badge/shell-Bash-lightgrey)
![ADB](https://img.shields.io/badge/tools-ADB%20%2B%20Fastboot-orange)
![Status](https://img.shields.io/badge/status-tested%20on%20real%20device-brightgreen)


> ## 📢 Keep Android Open
>
> If you care about the freedom to unlock, modify, repair, flash custom ROMs, and continue developing for Android devices, please take a moment to visit **[Keep Android Open](https://keepandroidopen.org/en/)** and support the campaign.
>
> **The ability to unlock and modify our own devices is directly relevant to projects like this one. Please read, share, and act.**


## What this project covers

- Reassembling Motorola split firmware archives (`.001`, `.002`, ...)
- Testing the reconstructed ZIP before extraction
- Reading and inspecting Motorola's `flashfile.xml` rather than guessing a flash sequence
- Verifying model, CID, current slot and sparse-image capability
- Independently verifying firmware files against the MD5 checksums supplied in `flashfile.xml`
- Flashing the exact XML sequence from Linux with `fastboot` — without needing an unlocked bootloader, Developer options, OEM unlocking, or USB debugging (see [Before you start](#before-you-start-developer-options-unlocking-and-relocking))
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
- Optionally, unlocking the bootloader and installing a custom ROM instead of restoring stock (see [Part IV](#part-iv---custom-rom-installation-optional))

## Before you start: Developer options, unlocking, and relocking

**If you're recovering a phone that won't boot at all (bricked), read this first:** flashing the ROM with this repository's scripts needs none of Developer options, OEM unlocking, USB debugging, or an unlocked bootloader. Fastboot/bootloader mode is reachable with the phone powered off via **Volume Down + Power**, entirely independent of whether Android boots or whether any of those settings were ever turned on. This was field-confirmed on the tested device: `flash-service-cancunf.sh` completed a full flash and successful reboot with the bootloader still *locked* (`securestate: flashing_locked`, no Developer options or USB debugging enabled at all), confirmed afterward by `ro.boot.verifiedbootstate: green` — not just fastboot returning `OKAY`. See step 1 below for why, and its limits.

Developer options, OEM unlocking, and USB debugging only matter for what comes **after** a successful flash and reboot: verifying the restored system, debloating (Part II), and reinstalling apps (Part III) are all `adb`-based and need a booted phone with USB debugging enabled. The steps below cover getting there, plus how to unlock the bootloader if you separately want or need to (for custom-ROM work, for instance), and how to relock afterward.

### 1. Do you actually need to unlock the bootloader?

Not necessarily, on this hardware. `flashfile.xml`/`servicefile.xml` are Motorola's own officially signed images for this exact model and CID, and this device's MediaTek bootloader validates that signature independently of the lock state — flashing one of those packages via plain `fastboot flash` was confirmed to complete successfully with `securestate: flashing_locked` (the same mechanism that lets Motorola's own Rescue and Smart Assistant repair a phone without unlocking it). The flasher scripts detect a locked bootloader and print an informational note rather than refusing to run.

This is **not** a general "locked accepts anything" rule — it applies specifically to Motorola's own signed firmware matching your model/CID, not to unsigned or custom images (custom recovery, patched boot images, custom ROMs), which still require a genuine unlock. On the G54, the risk of a hard brick from that path is high — Anti-Rollback (ARB) protection, combined with how MediaTek and Motorola handle the preloader partition, make a mismatched or mistimed flash unusually punishing on this device — so an AOSP recovery is, as always, the safest option once you're outside Motorola's own signed firmware. If a flash command fails with something like `not allowed in locked state`, or you want the bootloader unlocked anyway (for future custom-ROM work, for instance), continue to step 6.

### 2. Enable Developer options

On the phone: **Settings → About phone → tap "Build number" 7 times.** "Developer options" then appears under **Settings → System**. Not needed for flashing itself — see step 1 above.

### 3. Enable OEM unlocking and USB debugging

Inside Developer options, enable both:

- **OEM unlocking** — required before `fastboot` will accept an unlock *command*, if you choose to unlock (step 6). On Motorola devices this can require an active SIM/internet connection and a signed-in Google account the first time, since the toggle itself may need to phone home to confirm the device is eligible. Not required to flash `flashfile.xml`/`servicefile.xml` with this repository's scripts.
- **USB debugging** — required for every `adb`-based step in this repository (all of Part II/III, the verification commands in Part I, and `debloat-cancunf.sh`). It is **not** required for `fastboot`/flashing itself, since fastboot talks to the bootloader directly, before Android boots.

When you plug in and run `adb devices` for the first time, accept the "Allow USB debugging?" prompt on the phone screen; otherwise the host is not authorized and every `adb` command in this repository will fail.

### 4. Get into fastboot/bootloader mode

Either:

```bash
adb reboot bootloader
```

(requires USB debugging and an already-authorized host, so only works on a phone that already boots), or hold **Volume Down + Power** while the phone is off — no ADB, no Developer options, no working Android required. This is the way in for a phone that won't boot.

### 5. Check whether the bootloader is locked

```bash
fastboot devices
fastboot flashing get_unlock_ability
fastboot oem device-info
fastboot getvar unlocked
fastboot getvar securestate
```

- `fastboot flashing get_unlock_ability` reports whether an unlock is currently *permitted* (i.e. OEM unlocking was enabled and no carrier/policy restriction blocks it) — not whether the phone is already unlocked.
- `fastboot oem device-info` is a Motorola-specific command that, on some bootloader versions, reports the actual state as `Device unlocked: false`.
- `fastboot getvar unlocked` is the generic AOSP equivalent; many Motorola bootloader versions don't implement it and print `unlocked: not supported` or fail outright, which is expected and not an error.
- `fastboot getvar securestate` is the value confirmed present on the tested device's MediaTek bootloader (and shown directly on the fastboot-mode screen): `flashing_locked` or `flashing_unlocked`.

Not every device exposes all four; the flasher scripts here already try them in this order and fall back gracefully. See step 1 above if you're still deciding whether you actually need to unlock before going further.

### 6. Unlock the bootloader (if you need or want to)

**This factory-resets the phone.** Unlocking the bootloader is a security measure that wipes `userdata` by design, on every Android device, not something specific to this repository's scripts. Back up anything you need first.

```bash
fastboot flashing unlock
```

(older Motorola bootloaders instead use `fastboot oem unlock`). Confirm on the phone's screen using the volume/power keys as prompted. Re-run step 5's checks afterward to confirm.

### 7. Relocking, once you're done

Relocking is covered in full, with the tested device's actual output, in [Part I, step 11](docs/stock-restore.md#11-relock-the-bootloader) and [`docs/relock-bootloader.md`](docs/relock-bootloader.md). In short, after stock Android has booted successfully and been verified:

```bash
adb reboot bootloader
fastboot oem lock
```

Do this only after the restored stock system has booted and been checked — not immediately after flashing.

## Important warning

**Flashing firmware can permanently brick a device if the firmware, model, CID or partition sequence is wrong.**

The included flashers perform destructive operations including erasing `nvdata`, `userdata`, `metadata` and `debug_token` (`flash-stock-cancunf.sh`) or `nvdata`/`debug_token` only (`flash-service-cancunf.sh`), because those operations are present in Motorola's own `flashfile.xml`/`servicefile.xml`.

These scripts are specific to the Moto G54 5G (`cancunf`) and its CID `0x0032`, and they no longer pin one specific firmware build — they trust that your `flashfile.xml`/`servicefile.xml` has the same step sequence already confirmed on two real Motorola packages (see [Firmware builds documented here](#firmware-builds-documented-here)). Every hardcoded command is still cross-checked against your actual XML at runtime and will print a `WARNING` rather than silently mismatching (see `print_xml_step` in [Run the guarded flasher](docs/stock-restore.md#7-run-the-guarded-flasher)) — read those warnings before trusting a run against firmware this hasn't been exercised against. Do not treat these as a generic Motorola flasher for a different device, region, or CID. Read the script and your own XML before running anything.

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
- correct firmware for that device/region/CID (see [Firmware builds documented here](#firmware-builds-documented-here) for how to get it)
- for flashing (Part I): none of a bootloader unlock, Developer options, OEM unlocking or USB debugging — see [Before you start](#before-you-start-developer-options-unlocking-and-relocking)
- for everything after a successful flash (Part I verification, Part II, Part III): USB debugging enabled, since those steps are `adb`-based
- sufficient battery charge
- reliable USB cable/port

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

**Getting your own firmware:** Motorola Software Fix (Windows) is the straightforward way to obtain a firmware package for this device. Point it at the phone (connected via USB, or by entering its model/serial) and it identifies and downloads the exact CID/region-matched package Motorola currently associates with that handset — including both `flashfile.xml` and `servicefile.xml`, ready to use directly with the scripts in this repository. This is particularly relevant if you're recovering a phone that won't boot: Software Fix can look the device up and fetch the right package without needing the phone to be in a working state beyond fastboot/bootloader mode.

The Motorola Software Fix XML uses the **same partition/erase sequence and the same 22 `super` sparse chunks** as the original build documented here, only with different firmware file MD5 hashes. Because that sequence has now been confirmed identical across two real Motorola packages, the flashers in this repository are **not** pinned to one specific build string:

- [`flash-stock-cancunf.sh`](flash-stock-cancunf.sh) — full factory restore from `flashfile.xml`. Used (in its earlier, build-pinned form) in the original successful restore documented here, and confirmed again against the `V1TDS35H.83-20-5-8-4` package.
- [`flash-service-cancunf.sh`](flash-service-cancunf.sh) — repair/service reflash from `servicefile.xml`, preserving user data. See the next section.

Both scripts still verify phone model, CID and sparse size against your `flashfile.xml`/`servicefile.xml`, and cross-check every hardcoded `fastboot` command against a real `<step>` in that file at runtime, warning rather than silently mismatching if your firmware's actual sequence ever differs (see [Important warning](#important-warning)).

### `servicefile.xml`: a repair flash that preserves user data

Motorola's Software Fix package for `V1TDS35H.83-20-5-8-4` also ships a **`servicefile.xml`**, alongside `flashfile.xml`. It is the exact same build's flash sequence with three steps removed: it does not erase `userdata`, does not erase `metadata`, and does not flash `efuseBackup`. Everywhere else — GPT, preloader, core firmware, all 22 `super` sparse chunks, the `debug_token` erase, and the `fb_mode`/`config` cleanup — is identical.

That makes it a repair/service reflash intended to fix firmware or system corruption, a bad boot, or a failed OTA **without** wiping the user's data — as opposed to `flashfile.xml`, which is a full factory restore.

- [`flash-service-cancunf.sh`](flash-service-cancunf.sh) — the guarded counterpart for `servicefile.xml`. Run it from a directory containing `servicefile.xml` (not `flashfile.xml`).

**Compatibility caveat:** preserving `userdata`/`metadata` while reflashing system images is only safe when the firmware you reflash is compatible with the encryption state already on the phone — `metadata` holds the file-based-encryption policy/keys tied to `userdata`, which is why the two are only ever skipped together. Don't use the service flasher across an Android version, CID or region change. If in doubt, use the full stock flasher and expect a factory reset.

**Field-confirmed on real hardware:** run on the tested device with the bootloader locked (`securestate: flashing_locked`; see [Before you start](#before-you-start-developer-options-unlocking-and-relocking)). Every fastboot step completed with `OKAY`, the phone rebooted successfully, and post-boot verification showed:

```text
adb shell getprop ro.build.fingerprint
motorola/cancunf_g_sysenq/cancunf:15/V1TDS35H.83-20-5-8-4/d3b29e-8d7d82:user/release-keys
adb shell getprop ro.build.version.security_patch
2026-07-01
adb shell getprop ro.boot.verifiedbootstate
green
```

`verifiedbootstate: green` means Android's verified boot chain validated the flashed images against Motorola's own signing keys — independent, boot-time confirmation (not just a fastboot `OKAY`) that the service flash succeeded correctly while the bootloader stayed locked throughout.

## Test environment

The procedure documented here was performed from:

```text
Host OS: Debian GNU/Linux 13 (Trixie)
Device: Motorola Moto G54 5G
Codename: cancunf
Android: 15
```

ADB and Fastboot were run directly from the Debian host.

---

# Part I - Stock firmware restoration

Restoring Motorola's own signed stock firmware from `flashfile.xml`/`servicefile.xml` — without needing an unlocked bootloader (see [Before you start, step 1](#1-do-you-actually-need-to-unlock-the-bootloader)).

See [`docs/stock-restore.md`](docs/stock-restore.md) for the full walkthrough: reassembling split firmware, inspecting `flashfile.xml`, verifying the device and firmware files, running the guarded flasher ([`flash-stock-cancunf.sh`](flash-stock-cancunf.sh) / [`flash-service-cancunf.sh`](flash-service-cancunf.sh)), first boot, verifying the restored system, and relocking the bootloader.

---

# Part II - Conservative debloating

**Reminder:** this entire section is `adb`-based, so USB debugging must be enabled in Developer options (see [Before you start, step 3](#3-enable-oem-unlocking-and-usb-debugging)) before any of it will work — unlike Part I's flashing, which needs none of that. The debloat was deliberately performed **after** restoring and validating stock Android, removing packages only for Android user 0 rather than deleting anything from `/system`, `/product` or `/system_ext` — reversible on system packages, and decided package by package rather than from a generic internet "remove everything" list.

See [`docs/stock-applications.md`](docs/stock-applications.md) for the stock/preloaded application snapshot and the KEEP / REMOVE / DISABLED decisions, and [`docs/debloat.md`](docs/debloat.md) for the removal method, the actual batches and commands, verification after each batch, and [`debloat-cancunf.sh`](debloat-cancunf.sh), the guarded script that automates it with before/after logging (see [docs/debloat.md, section 15](docs/debloat.md#15-automated-script)).

---

# Part III - Reinstalling applications

For a large list of applications, entering each Play Store page manually is unnecessary if the Android package names are already known.

The tested workflow opens the correct Play Store page through ADB and allows Play Store to queue installs in the background. Banking, payment, government and authenticator applications can be installed through the same official Play Store workflow; what should not be blindly restored is their old private application data.

See [`docs/reinstalling.md`](docs/reinstalling.md).

A separate note on Seedvault/Seednaut-assisted recovery is available in [`docs/app-restore.md`](docs/app-restore.md).

---

# Part IV - Custom ROM installation (optional)

Everything above restores and cleans up Motorola's own stock firmware, which is why none of it needs an unlocked bootloader. Installing a custom ROM instead is a separate, optional path with different requirements — a genuine bootloader unlock, a full data wipe, and trusting a third-party ROM build rather than Motorola's own signed firmware.

See [`docs/custom-rom-guide.md`](docs/custom-rom-guide.md) for the full unlock-and-flash walkthrough (codename `cancunf`, covering both the Moto G54 5G and Moto G64 5G).

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

### `flashfile.xml not found` / `servicefile.xml not found`

The script must be copied into and run from the directory that contains the matching XML (`flashfile.xml` for `flash-stock-cancunf.sh`, `servicefile.xml` for `flash-service-cancunf.sh`) and the firmware images, not from wherever it was downloaded to.

### `ERROR: XML model mismatch` / `ERROR: XML CID mismatch` / `ERROR: XML max-sparse-size mismatch`

These come from reading `flashfile.xml`/`servicefile.xml` itself, before the phone is even touched. They mean the firmware package you extracted is not for this device (`cancunf`) or not for CID `0x0032` — get the correct firmware package instead of editing the script's `EXPECTED_*` values to force a match. This does not check the exact build string (see [Why the scripts don't pin a specific build](#why-the-scripts-dont-pin-a-specific-build)); if your firmware's actual flash sequence differs from what's hardcoded, `print_xml_step` will print a `WARNING` for the affected command instead.

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

A firmware file referenced by `flashfile.xml` is either missing from the extracted directory or its MD5 does not match. This usually means the split archive (`.001`, `.002`, ...) was reassembled incorrectly or the ZIP was only partially extracted. Redo [steps 1–3](docs/stock-restore.md#1-reassemble-motorola-split-firmware) and re-verify before flashing.

### `Flashing not authorized.`

This is not an error — it means something other than exactly `YES` was typed at a confirmation prompt, so the script stopped safely without flashing anything. Re-run the script when ready.

### Stopped mid-flash with `Motorola fb_mode is still SET`

A `fastboot` command failed partway through flashing. Do not reboot the phone. Read the terminal output (or the `tee` log) to see which stage and command failed, and resolve that specific problem before deciding whether it is safe to continue, retry, or seek help referencing the exact failing command.

---

# Firmware redistribution

This repository does **not** distribute Motorola firmware images, proprietary APKs, Seedvault backups, personal app data or authentication material.

Users must obtain firmware appropriate for their own device and verify it independently. Motorola Software Fix can be useful for identifying/downloading the firmware Motorola currently associates with a specific handset.

# Scope

The flashers in this repository are deliberately conservative and specific to this exact device and CID (`cancunf`, `0x0032`) — they are generic across *builds* of that device/CID (confirmed identical flash sequence across two real Motorola packages so far), not across devices, CIDs, or firmware families in general. Do not assume they are safe for another Moto G54 variant, CID, or Motorola model without reviewing that firmware's own `flashfile.xml`/`servicefile.xml` and adapting the validation rules and flash sequence if necessary.

Likewise, the debloat list reflects choices made on the tested device. A package being removable does not mean every user should remove it.

# Acknowledgements / community contributors

This project was developed with practical information and community knowledge shared through the Moto G54 / `cancunf` Telegram community. Special thanks to the people contributing to and maintaining:

- [Motorola G54 Official](https://t.me/motorolag54official)
- [Motorola G54 Updates](https://t.me/motorolag54updates)
- [cancunf Backup](https://mirrors.lolinet.com/firmware/lenomola/2023/cancunf/official/)

These communities are acknowledged as sources of device-specific help and shared experience. They are not responsible for this repository's scripts or documentation.

**[`docs/custom-rom-guide.md`](docs/custom-rom-guide.md)** is a rewrite, adapted for this repository, of **[cyberknight777's Motorola G54/G64 5G Custom ROM Guide](https://cyberknight777.dev/instructions/cancunf/)**. All credit for the original unlock/flash process goes to cyberknight777; any error introduced in the rewritten version here is this repository's own.

# License

MIT License — see [`LICENSE`](LICENSE).
