# Reinstalling applications from a package-name list

This documents the process used after the stock restore and debloat to reinstall a large set of Android applications through Google Play without searching for each app manually.

Test environment:

```text
Host OS: Debian 13 (Trixie)
Device: Moto G54 5G (cancunf)
Android: 15
```

## When this is useful

If you already have Android package names such as:

```text
com.airbnb.android
com.booking
com.facebook.katana
com.openai.chatgpt
com.spotify.music
com.whatsapp
```

ADB can open the corresponding Play Store pages directly.

This is useful after a clean stock installation when you want the applications to be installed normally by Google Play rather than restoring APKs manually.

## 1. Prepare the package list

Create a plain-text file with **one package name per line**:

```text
com.airbnb.android
com.booking
com.facebook.katana
com.openai.chatgpt
com.spotify.music
com.whatsapp
```

For example:

```text
normal-install.txt
```

Blank lines should be avoided.

Banking, payment, government-ID and authenticator applications can be included in the same package-name list. The important distinction is not how the APK is installed, but how its private app data is handled afterwards: install these apps fresh from Google Play and perform their normal login/device-registration process rather than blindly transplanting old private application data.

## 2. Verify ADB

```bash
adb devices
```

The phone should appear as:

```text
DEVICE_SERIAL    device
```

If it shows `unauthorized`, unlock the phone and approve the debugging prompt.

## 3. Keep the phone awake

Long installation sessions are easier if the phone stays awake while USB power is connected:

```bash
adb shell svc power stayon true
```

When the session is finished:

```bash
adb shell svc power stayon false
```

## 4. Open one Play Store page manually

The basic mechanism is:

```bash
adb shell am start \
  -a android.intent.action.VIEW \
  -d 'market://details?id=com.openai.chatgpt'
```

If Play Store is installed and handles the `market://` scheme, the application page should open directly.

This does **not** silently install the app. Google Play remains responsible for installation, permissions, signature verification and updates.

## 5. Remove packages that are already installed

You can save time by comparing your wanted list with applications already installed by the current Android user.

Capture third-party packages:

```bash
adb shell pm list packages -3 | sed 's/^package://' | sort > currently-installed-user-apps.txt
```

Sort the wanted list:

```bash
sort -u wanted-apps.txt > wanted-sorted.txt
```

Generate only the missing entries:

```bash
comm -23 wanted-sorted.txt currently-installed-user-apps.txt > still-to-install.txt
```

Inspect before continuing:

```bash
cat still-to-install.txt
wc -l still-to-install.txt
```

## 6. Interactive Play Store installer

The following Bash helper opens each missing package in Play Store and waits for you before continuing to the next one.

Create `playstore-install-list.sh`:

```bash
#!/usr/bin/env bash
set -u

LIST="${1:-normal-install.txt}"

if ! command -v adb >/dev/null 2>&1; then
    echo "ERROR: adb was not found in PATH."
    exit 1
fi

if [[ ! -f "$LIST" ]]; then
    echo "ERROR: package list not found: $LIST"
    exit 1
fi

mapfile -t DEVICES < <(adb devices | awk 'NR>1 && $2=="device" {print $1}')

if (( ${#DEVICES[@]} != 1 )); then
    echo "ERROR: expected exactly one authorized ADB device."
    adb devices
    exit 1
fi

cleanup() {
    adb shell svc power stayon false >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

adb shell svc power stayon true

mapfile -t PACKAGES < <(grep -Ev '^[[:space:]]*(#|$)' "$LIST" | sed 's/[[:space:]]*$//')

TOTAL=${#PACKAGES[@]}

for i in "${!PACKAGES[@]}"; do
    pkg="${PACKAGES[$i]}"
    n=$((i + 1))

    echo
    echo "[$n/$TOTAL] $pkg"

    if adb shell pm list packages "$pkg" | tr -d '\r' | grep -qx "package:$pkg"; then
        echo "Already installed - skipping."
        continue
    fi

    while true; do
        adb shell am start \
            -a android.intent.action.VIEW \
            -d "market://details?id=$pkg"

        echo
        read -r -p "Enter=next, r=reopen, s=skip, q=quit: " answer

        case "$answer" in
            "") break ;;
            r|R) continue ;;
            s|S) break ;;
            q|Q) exit 0 ;;
            *) echo "Unknown choice." ;;
        esac
    done
done

echo
echo "Finished package list."
```

Make it executable:

```bash
chmod +x playstore-install-list.sh
```

Run it:

```bash
./playstore-install-list.sh normal-install.txt
```

or:

```bash
./playstore-install-list.sh still-to-install.txt
```

## 7. How to use it efficiently

The process used during testing was:

1. The script opened an application page.
2. `Install` was pressed in Play Store.
3. The script moved to the next package after Enter was pressed.
4. Google Play continued downloading/installing previously selected apps in the background.

This means several installations can be queued without waiting for each application to finish completely.

However, avoid feeding the queue indefinitely. During the tested restore Play Store visibly showed a decreasing queue such as dozens of applications being installed. Let the queue settle periodically before adding many more.

## 8. What successful progress looks like

ADB's role here is only to open the correct Play Store page. A successful `am start` normally shows output similar to:

```text
Starting: Intent { act=android.intent.action.VIEW dat=market://details?... }
```

That means Android accepted the intent. It does **not** prove the app itself has finished installing.

Verify package installation separately:

```bash
adb shell pm list packages com.openai.chatgpt
```

Expected after installation:

```text
package:com.openai.chatgpt
```

## 9. Verify the whole list afterwards

One simple way is:

```bash
while read -r pkg; do
    [[ -z "$pkg" ]] && continue
    if adb shell pm list packages "$pkg" | tr -d '\r' | grep -qx "package:$pkg"; then
        printf 'OK       %s\n' "$pkg"
    else
        printf 'MISSING  %s\n' "$pkg"
    fi
done < normal-install.txt
```

To produce only the missing applications:

```bash
while read -r pkg; do
    [[ -z "$pkg" ]] && continue
    adb shell pm list packages "$pkg" | tr -d '\r' | grep -qx "package:$pkg" || echo "$pkg"
done < normal-install.txt > missing-after-install.txt
```

Then:

```bash
cat missing-after-install.txt
```

## 10. Banking, payment, government and authenticator applications

There is no technical reason to exclude these applications from the same ADB + Play Store reinstall workflow. The tested method only opens the official Play Store page; Google Play still downloads and verifies the application normally.

So these packages can be mixed into the same list as ordinary applications and queued in exactly the same way.

What should remain separate is **data restoration**. For banking, payment, government-ID and authenticator apps, prefer a clean Play Store install followed by the app's normal login, device registration, activation or identity-verification process. Avoid restoring old private app data unless you know that application explicitly supports it.

This is especially relevant after returning from a custom ROM to locked stock firmware, where the goal is to let security-sensitive apps establish their state cleanly on the restored device.

### If the bootloader was ever unlocked, the integrity verdict may stay reduced

Relocking the bootloader and reflashing signed stock firmware restores `ro.boot.flash.locked=1`, `ro.boot.verifiedbootstate=green` and `ro.build.tags=release-keys` — every *software*-visible signal looks clean. On the tested device that was not enough to restore the full integrity verdict, and the cause was **not conclusively identified**. `iswarrantyvoid: yes` was reported by `fastboot getvar` throughout, but the device owner reports the phone had passed certification at earlier points *after* its bootloader had already been unlocked once, so a permanent "was unlocked" record is a suspect, not an established explanation. Other candidates that were not ruled out:

- **Build-specific certification.** Only one build (`V1TDS35H.83-20-5-12`) has been checked for integrity while locked. Once that build advanced the fused AVB rollback value, older builds can no longer boot locked at all (see [`relock-bootloader.md`](relock-bootloader.md#check-the-fused-rollback-value-before-you-relock-instead-of-inferring-it)), so the earlier, previously-certified builds cannot be re-tested on that phone.
- **The phone's attestation keys or server-side state.** Google's remote key provisioning was still issuing the phone fresh attestation keys (a chain ending at Google's "Key Attestation CA1" root), which argues against the keys simply being blocked, but revocation applied later on Google's side was not ruled out.

Practically, this was confirmed on the tested device using the [Play Integrity API Checker](https://play.google.com/store/apps/details?id=gr.nikolasspyr.integritycheck) app (the current replacement for the deprecated SafetyNet checkers like YASNAC — SafetyNet's backend no longer exists):

- `MEETS_BASIC_INTEGRITY`: **passed**
- `MEETS_DEVICE_INTEGRITY`: **failed**
- `MEETS_STRONG_INTEGRITY`: **failed**

The Play Store's own "Play Protect certification" status showed "Device is not certified" alongside it. None of these changed the result on the tested device: a factory-reset-equivalent wipe, a full stock reflash while locked (`flashfile.xml`), a repair reflash (`servicefile.xml`), and clearing the data of Google Play services, the Google Services Framework and the Play Store.

**This did not stop Revolut from installing and running** on the tested device — many banking/fintech apps only require `MEETS_BASIC_INTEGRITY`, not the device/strong tiers. But this is app-specific and not guaranteed: some banking, payment or government-ID apps do check for `MEETS_DEVICE_INTEGRITY` and will refuse to run, or run in a restricted mode, on a device that fails it — and on the tested phone nothing documented in Part I or Part II has changed that so far. If you've ever unlocked this device's bootloader (including just to test Part IV's custom ROM path), install the integrity checker app first and know your actual verdict before relying on a banking app's full functionality, rather than assuming stock-and-locked is equivalent to never-unlocked.

## 11. Package names that no longer exist

A historical package list may contain applications that:

- were removed from Google Play;
- changed package name;
- are not available in your country;
- are incompatible with the current Android version;
- were OEM/ROM-specific rather than normal Play Store applications.

If the Play Store page says the item cannot be found, do not assume ADB failed. Verify the package name first.

## 12. Restore normal screen behaviour

If you did not use the script's cleanup handler, run:

```bash
adb shell svc power stayon false
```

## Why use Play Store rather than bulk `adb install`?

For ordinary and security-sensitive applications after returning to stock Android, Play Store installation has several advantages:

- correct APK splits are selected automatically;
- signatures come from the normal distribution source;
- Play Store keeps ownership/update information;
- architecture and density variants are handled automatically;
- there is no need to maintain a local archive of APK files.

For this project that made it the preferred reinstall method after the stock restore.
