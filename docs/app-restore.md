# App reinstall and Seedvault recovery notes

After restoring stock firmware and finishing the debloat pass, application recovery can be handled separately from firmware restoration.

## Reinstalling ordinary apps

Android does not expose an official command such as:

```text
playstore install PACKAGE.NAME
```

A practical ADB-assisted workflow is to keep a text file with package IDs and open each app directly in Google Play:

```bash
while read -r pkg; do
    adb shell am start \
      -a android.intent.action.VIEW \
      -d "market://details?id=$pkg"
    read -rp "Install it, then press Enter for next..."
done < normal-install.txt
```

Google Play can queue multiple installations in the background.

To keep the display awake while connected over USB:

```bash
adb shell svc power stayon true
```

Restore normal timeout behavior afterward:

```bash
adb shell svc power stayon false
```

## Seedvault backups

A useful desktop inspection tool is Seednaut:

https://github.com/Baltram/seednaut

It can list, verify and extract Seedvault snapshots offline.

Example:

```bash
seednaut list /path/to/.SeedVaultAndroidBackup
seednaut verify /path/to/.SeedVaultAndroidBackup
seednaut extract /path/to/.SeedVaultAndroidBackup --export --out ./recovered
```

`--export` unpacks full app-data backups and converts key/value backups to a human-readable representation where supported.

## Important limitation on stock Motorola ROM

The tested stock ROM exposed these Android backup transports:

```text
com.android.localtransport/.LocalTransport
com.google.android.gms/.backup.migrate.service.D2dTransport
com.google.android.gms/.backup.BackupTransportService
com.google.android.apps.restore/.transport.BackupTransportService
```

Seedvault itself was **not** registered as an Android backup transport on stock Motorola firmware.

Therefore, an extracted Seedvault backup cannot simply be restored with `bmgr` unless a compatible backup transport is present.

Similarly, `adb push` is not a replacement for a proper Seedvault restore: an unrooted stock system cannot normally write arbitrary files into another application's private `/data/user/0/PACKAGE` directory with the correct ownership, SELinux labels and backup semantics.

## Sensitive apps

Banking, wallet, government-ID and authentication applications should generally be installed cleanly and reactivated rather than having old private data transplanted manually.

For ordinary cloud-backed applications, their own login or cloud-restore mechanism is usually preferable.

## Never publish extracted app data

Seedvault exports may contain:

- private databases
- account identifiers
- authentication/session information
- registration tokens
- private configuration files
- cryptographic material

Keep those exports outside the Git repository. The project's `.gitignore` intentionally excludes common backup/database/key formats.
