# Custom ROM installation for the Moto G54/G64 5G (`cancunf`)

This is a from-scratch rewrite of the unlock/flash process, adapted for this repository from a third-party guide. Full credit and the original link are in the README's [Acknowledgements](../README.md#acknowledgements--community-contributors) section — read this doc for the steps, that section for the source.

## Who this is for

- Codename **`cancunf`** covers both the **Moto G54 5G** and the **Moto G64 5G** — this guide applies to either.
- It is written for **Android 16-based custom ROMs (or newer) that themselves bundle Android 15 firmware**. Older ROM builds, or ROMs based on older firmware, are out of scope here.
- A PC is required; this is not an on-device-only process.
- If a stock OTA update is already in progress on the phone, let it finish and reboot into system normally *before* starting any of this. Interrupting an in-flight OTA to unlock or flash is asking for trouble.

## Before you start: what this does to the phone

Unlocking the bootloader and flashing a custom ROM is fundamentally different from the rest of this repository's stock-restore workflow:

- It **wipes `userdata`** — back up anything you care about first (see [`docs/app-restore.md`](app-restore.md) if you use Seedvault).
- It **voids Motorola's warranty coverage** the moment the bootloader is unlocked, independent of whether you ever flash anything afterward.
- It replaces the stock recovery/system with a third-party ROM you have not built yourself — you're trusting that ROM's maintainer, not just Motorola's signing.
- Unlike the stock-firmware path documented elsewhere in this repo (see [step 1 of "Before you start"](../README.md#1-do-you-actually-need-to-unlock-the-bootloader) in the main README), a **genuine bootloader unlock is required** here — there's no signed-firmware shortcut for custom ROMs.

If any of that isn't what you want, stop here and use this repository's stock-restore workflow instead.

## Part A — Unlocking the bootloader

### 1. Set up the tools

Install Google's platform-tools (`adb`/`fastboot`) for your OS:

- [Windows](https://dl.google.com/android/repository/platform-tools-latest-windows.zip)
- [macOS](https://dl.google.com/android/repository/platform-tools-latest-darwin.zip)
- [Linux](https://dl.google.com/android/repository/platform-tools-latest-linux.zip)

On Windows only, also install [Google's USB driver package](https://dl.google.com/android/repository/usb_driver_r13-windows.zip): extract it, then right-click `android_winusb.inf` and choose **Install**. Linux and macOS don't need this.

### 2. Enable OEM unlocking

On the phone: **Settings → About phone**, then tap **Build number** seven times to unlock Developer options. Open **Developer options** and enable **OEM unlocking**.

If the phone is brand new, this toggle can stay greyed out for up to **7 days** after first setup — that's a Motorola-side anti-theft delay, not a bug on your end. Wait it out; there's no way around it.

### 3. Read the device's unlock data

Power the phone off, then hold **Volume Down + Power** to boot into Bootloader/Fastboot mode. From a terminal in the platform-tools folder:

```bash
fastboot devices
```

Confirm the phone shows up, then request its unlock data:

```bash
fastboot oem get_unlock_data
```

This prints several lines of bootloader output, e.g.:

```
(bootloader) Unlock data:
(bootloader) 0A40040192024205#4C4D3556313230
(bootloader) 30373731363031303332323239#BD00
(bootloader) 8A672BA4746C2CE02328A2AC0C39F95
(bootloader) 1A3E5#1F53280002000000000000000
(bootloader) 0000000
```

### 4. Turn that into an unlock token

Concatenate the data lines above into a single string, with no spaces and nothing but the `(bootloader) ...` payload itself — for the example above that's:

```
0A40040192024205#4C4D355631323030373731363031303332323239#BD008A672BA4746C2CE02328A2AC0C39F951A3E5#1F532800020000000000000000000000
```

Go to [Motorola's bootloader-unlock page](https://en-us.support.motorola.com/app/standalone/bootloader/unlock-your-device-b), sign in, and paste that string in to check eligibility. Accept the legal agreement and request the unlock key. Motorola emails a 20-character alphanumeric unlock token — check spam if it doesn't show up quickly.

### 5. Unlock

Still in bootloader mode:

```bash
fastboot oem unlock <token>
```

e.g.:

```bash
fastboot oem unlock MZMC6D342TBNNWI6TRP9
```

The phone's screen will confirm the unlock. From here on, every boot shows an **unlocked bootloader warning screen** — that's expected and can't be turned off from software (it's a hardware-enforced trust indicator, same as on any other Android device once unlocked).

## Part B — Flashing the ROM

### 1. Get the files

From the ROM's release post, download two files:

- the **ROM zip** itself (e.g. `YAAP-16-Banshee-cancunf-20250929.zip`)
- the matching **initial install zip** (e.g. `yaap_banshee_cancunf_initial_install.zip`), which bundles `boot`/`vendor_boot`

The initial install zip only sets up the environment for a first install — it is not maintained release-to-release and **must never be used as a rooting vector**.

You generally do **not** need to separately flash Android 15 stock firmware or "fill both slots" first — the ROM's initial install zip already carries Android 15 firmware. The one exception: if the phone is currently on stock **older than the May 2024 Android 15 build (`U1TDS34.94-12-7-5`)**, flash the ROM once without wiping data first, purely to get post-anti-rollback (post-ARB) firmware onto both slots, then proceed normally.

### 2. Flash the initial install zip — from fastbootd, not bootloader

Boot into bootloader mode (**Volume Down + Power** from off), then switch into **fastbootd** (userspace fastboot):

```bash
fastboot reboot fastboot
```

Confirm you're actually in fastbootd, not plain bootloader:

```bash
fastboot getvar is-userspace
```

should report `is-userspace: yes`. If it says `no`, you're still in bootloader mode — repeat the previous command.

This distinction matters here specifically: Motorola's bootloader enforces a timestamp/version check on some partitions, so flashing images while in plain bootloader mode can fail with something like:

```
Writing 'boot_b'                                   (bootloader) Preflash validation failed
FAILED (remote: '')
```

fastbootd bypasses that check, which is why the initial install zip has to go through fastbootd specifically.

With the device confirmed in fastbootd:

```bash
fastboot --skip-reboot update yaap_banshee_cancunf_initial_install.zip
```

(swap in your own initial install zip's filename.)

### 3. Wipe data

```bash
fastboot reboot recovery
```

then, on-device, choose **Wipe data / Factory reset** to format `/data`. This is unavoidable on a first custom-ROM install — expect it, and make sure step-0 backups are actually done beforehand.

### 4. Sideload the ROM

Still from the recovery menu, choose **Apply update → Apply update from ADB** (wording varies slightly by recovery: *Apply update from ADB*, *Install update → ADB Sideload*, etc.), then from the host:

```bash
adb sideload YAAP-16-Banshee-cancunf-20250929.zip
```

(again, your own ROM zip's filename.) Once it completes without errors, reboot into the new ROM.

## Updating to a newer build later

Once you're running a custom ROM, later updates are simpler than the initial install — no unlocking, no initial-install zip, no data wipe required:

**Option 1 — built-in updater, if the ROM has one:**
- Official-status ROMs typically support OTA: open the updater app and flash directly.
- Unofficial builds with a **Local Update** option: download the new ROM zip to the phone, then pick it from **Local Update** in the updater.

**Option 2 — sideload in recovery, same as the initial flash:**

```bash
fastboot reboot recovery
```

then **Apply update from ADB** as before:

```bash
adb sideload <new-rom-zip>
```

Either way, reboot once it finishes.

---

Questions specific to *this* repository's scripts, debloat list, or stock-restore workflow belong in the main [README](../README.md) — this doc only covers the unlock/custom-ROM path, which the rest of the repo deliberately avoids requiring.
