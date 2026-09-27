# Stock package reference

These files preserve the package state captured on the tested Moto G54 5G (`cancunf`) running Motorola stock firmware `V1TDS35H.83-20-5-12` before the documented debloat.

## `all-packages.txt`

A plain package-name inventory derived from the stock snapshot. It is useful for simple comparisons with another device or another stage of the debloat.

Equivalent capture command:

```bash
adb shell pm list packages | sed 's/^package://' > all-packages.txt
```

Example comparison:

```bash
comm -3 \
  <(sort reference/all-packages.txt) \
  <(sort all-packages-current.txt)
```

## `packages-with-paths.txt`

The corresponding package inventory with the APK/source path retained. Each line has the form:

```text
package:/path/to/Application.apk=com.example.package
```

This was especially useful during debloat analysis because the path helps distinguish packages coming from locations such as:

- `/system`
- `/system_ext`
- `/product`
- `/vendor`
- `/apex`
- `/data/app`

For example, a package under `/product/priv-app` is a privileged product/system package, while an updated application may appear under `/data/app` even when an original system copy also exists in the firmware.

A similar live snapshot can be produced with:

```bash
adb shell pm list packages -f > packages-with-paths-raw.txt
```

Android normally prints entries as:

```text
package:/path/to/base.apk=com.example.package
```

## Confirmed identical stock set on `V1TDS35H.83-20-5-8-4`

A later snapshot taken on the Motorola Software Fix build `V1TDS35H.83-20-5-8-4`, after signing into a Google account, initially showed 489 packages instead of 403. After excluding 86 packages identified as Google Play "restore apps" reinstalling the account's own previously-used apps, the remaining set matched this file's 403 packages exactly. See [`../docs/stock-applications.md`](../docs/stock-applications.md#watch-out-for-google-play-auto-restore-on-a-fresh-flash) for the full comparison and methodology — useful if you need to tell a genuine firmware package apart from a personal app restored after sign-in.

## Signing into Google via Settings instead of the setup wizard: fewer auto-installed apps

A second snapshot, `all-packages-settings-signin.txt` / `packages-with-paths-settings-signin.txt`, was captured on the same firmware build (`V1TDS35H.83-20-5-12`) right after a bootloader relock and a full data wipe, but with a deliberately different setup path: the account/restore step in the setup wizard was skipped entirely, and the Google account was instead added afterward from **Settings → Accounts**.

This snapshot has **397 packages** (393 system, 4 third-party) instead of the 403 in `all-packages.txt`/`packages-with-paths.txt` (which were captured after going through the setup wizard's own Google sign-in step). Diffing the two:

Present in the setup-wizard capture but **not** in the Settings-sign-in capture:

```text
com.brave.browser
com.google.android.apps.adm
com.google.android.apps.docs.editors.docs
com.google.android.apps.docs.editors.sheets
com.google.android.apps.docs.editors.slides
com.google.android.apps.fitness
com.google.android.apps.magazines
com.google.android.apps.podcasts
com.google.android.apps.walletnfcrel
com.google.android.server.deviceconfig.resources
```

Present in the Settings-sign-in capture but **not** in the setup-wizard capture:

```text
all.documentreader.filereader.office.viewer
com.documentreader.free.viewer.all
com.google.android.signature
ringtonesforandroidphonefree.ringtones.ringtonessongs.ringtonesapp
```

Read together, this suggests two separate effects rather than one:

- Signing in through the **setup wizard's own account step** appears to trigger a bundled auto-install of core Google productivity/lifestyle apps (Docs, Sheets, Slides, Fit, Magazines, Podcasts, Wallet, Find My Device/`adm`) that does **not** happen when the same account is instead added later from Settings. If you want the leanest possible starting point, skipping the wizard's account step and signing in afterward avoids this whole bundle.
- A small set of promotional third-party apps (a document reader, a ringtones app, or `com.brave.browser` in the other capture) still gets silently installed by Play Store independent of the sign-in path. This set looks like it rotates/varies per install rather than being a fixed list, so expect *some* small sponsor app(s) either way — `com.facebook.katana` is the one constant between both captures, so it's likely a genuine bundled partner app rather than part of this rotation.

`com.google.android.signature` and `com.google.android.server.deviceconfig.resources` are minor GMS/module churn between the two captures and weren't investigated further.

## Play Store display names vs. package names

The Play Store's "Manage apps & device > Updates available" screen lists apps by their display name, not their package name, which can make it hard to tell whether a listed app is one this project has already made a KEEP/REMOVE decision about. Confirmed on the tested device (via `pm path`/`pm list packages -f`, and for the ambiguous one below, by pulling the APK and checking its actual `application-label` with `aapt dump badging`):

| Play Store display name | Package | Existing decision |
|---|---|---|
| Moto | `com.motorola.moto` | KEEP — see [`docs/stock-applications.md`](../docs/stock-applications.md); confirmed still actively maintained (received a 102 MB update) |
| Moto Secure | `com.motorola.securityhub` | KEEP |
| Secure folder | `com.motorola.securevault` | KEEP — Motorola's equivalent of Samsung's Secure Folder (an encrypted vault for private photos/files/apps), not something to remove |
| Σχόλια Moto / Moto Feedback | `com.motorola.help` | KEEP — this is `MotoHelp.apk` itself (labeled "Motorola Help" in this project's docs); its Greek `application-label-el` string is a literal, exact match for "Σχόλια Moto". Not to be confused with `com.motorola.help.extlog`, a separate package (`MotoFeedbackAssistant.apk`) also KEEP — see the section 9 reasoning in [`docs/debloat.md`](../docs/debloat.md) |
| Ενέργειες Moto / Moto Actions | `com.motorola.actions` | KEEP |
| Τηλ. Google / Google Phone | `com.google.android.dialer` | KEEP |

None of the packages listed as pending updates on the tested device were anything this project had removed reappearing — all of them are either `KEEP` decisions or packages never touched by the debloat (Calculator, Clock, Contacts, Accessibility Suite, Switch Access, Personal Safety, Google's own core apps). That's the expected result: a package removed only for user 0 doesn't reappear in Play Store's own update list unless it's reinstalled first.

## Important

These files are a **reference snapshot, not a universal debloat list**. Different regions, carrier configurations, OTA revisions, and Motorola firmware builds can contain different packages or paths.

See [`../docs/stock-applications.md`](../docs/stock-applications.md) for the human-reviewed application list and [`../docs/debloat.md`](../docs/debloat.md) for the actual removal decisions and commands used on the tested phone.
