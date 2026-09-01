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

## Important

These files are a **reference snapshot, not a universal debloat list**. Different regions, carrier configurations, OTA revisions, and Motorola firmware builds can contain different packages or paths.

See [`../docs/stock-applications.md`](../docs/stock-applications.md) for the human-reviewed application list and [`../docs/debloat.md`](../docs/debloat.md) for the actual removal decisions and commands used on the tested phone.
